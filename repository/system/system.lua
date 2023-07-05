local LOCALES = nil
local PATHS = {
    info = "/usr/info/",
    config = "/usr/config/",
    temp = "/usr/temp/",
    locales = "/usr/locales/",
    messages = "/usr/locales/messages/",
    apis = "/usr/apis/",
    modules = "/usr/modules/",
    programs = "/usr/programs/",
    home = "/home/"
}

local function getData(path)
    if not fs.exists(path) then return nil end
    local file = fs.open(path, "r")
    local data = textutils.unserialize(file.readAll())
    file.close()
    return data
end

local function setData(path, data)
    local file = fs.open(path, "w")
    file.write(textutils.serialize(data))
    file.close()
end

paths = setmetatable({}, {
    __index = function(_, k) return PATHS[k] end,
    __pairs = function(_)
        local function iter(_, k)
            local v
            k, v = next(PATHS, k)
            if v ~= nil then return k, v end
        end
        return iter, PATHS, nil
    end,
    __newindex = function() error("system.paths is read only") end,
    __metatable = false
});

locales = setmetatable({}, {
    __index = function(_, k)
        if not LOCALES then
            LOCALES = getData(paths.config.."locales.lua") or {
                language = {
                    default = "en",
                    description = "System language",
                    type = "string",
                    value = "en"
                },
                timezone = {
                    default = "UTC",
                    description = "System timezone",
                    type = "string",
                    value = "UTC"
                }
            }
        end
        return LOCALES[k]
    end,
    __newindex = function(_, k, v)
        LOCALES[k] = v
        setData(paths.config.."locales.lua", LOCALES)
    end
});

function load(api)
    os.loadAPI(paths.apis..api..".lua")
end

function import(module)
    return dofile(paths.modules..module..".lua", _ENV)
end

function run(program, args)
    if args and #args > 0 then
        shell.run(paths.programs..program, table.unpack(args))
    else
        shell.run(paths.programs..program)
    end
end

function loadConfig(name)
    return getData(PATHS.config..name..".lua")
end

function writeConfig(name, data)
    setData(PATHS.config..name, data)
end

function loadInfo(name)
    return getData(PATHS.info..name..".lua")
end

function getMessages(program_name)
    local path = paths.messages
    local lang = locales.language
    local messages = getData(path..program_name.."/"..lang.default..".lua")
    if lang.default == lang.value then return messages end
    local translated = getData(path..program_name.."/"..lang.value..".lua")
    if translated then
        for k, v in pairs(translated) do
            messages[k] = v
        end
    end
    return messages
end