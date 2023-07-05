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
            if fs.exists(paths.config.."locales.lua") then
                local file = fs.open(paths.config.."locales.lua", "r")
                LOCALES = textutils.unserialize(file.readAll())
                file.close()
                return
            end
            LOCALES = {
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
        local file = fs.open(paths.config.."locales.lua", "w")
        file.write(textutils.serialize(LOCALES))
        file.close()
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

function getMessages(program_name)
    local path = paths.messages
    local lang = LOCALES.language
    local messages = dofile(path..program_name.."/"..lang.default..".lua", _ENV)
    if lang.default ~= lang.value then
        if fs.exists(path..program_name.."/"..lang.value..".lua") then
            local translated = dofile(path..program_name.."/"..lang.value..".lua", _ENV)
            for k, v in pairs(translated) do
                messages[k] = v
            end
        end
    end
    return messages
end