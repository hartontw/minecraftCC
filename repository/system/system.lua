local locales = {
    language = "locales.language",
    timezone = "locales.timezone"
}

paths = setmetatable({}, {
    __index = {
        info = "/usr/info/",
        config = "/usr/config/",
        temp = "/usr/temp/",
        locales = "/usr/locales/",
        messages = "/usr/locales/messages/",
        apis = "/usr/apis/",
        modules = "/usr/modules/",
        programs = "/usr/programs/",
        home = "/home/"
    },
    __newindex = function(table, key, value)
                   error("Attempt to modify read-only table")
                 end,
    __metatable = false
});

local function defaultLocaleSettings()
    if settings.get(locales.language) then return end
    settings.define(locales.language, {
        default = "en",
        description = "System language",
        type = "string"
    })
    settings.define(locales.timezone, {
        default = "UTC",
        description = "System timezone",
        type = "string"
    })
end

function loadLocales()
    defaultLocaleSettings()
    if fs.exists(paths.config.."locales.lua") then
        local config = dofile(paths.config.."locales"..".lua", _ENV)
        settings.set(locales.language, config.language)
        settings.set(locales.timezone, config.timezone)
    end
end

local function writeLocales()
    local localeFile = fs.open(paths.config.."locales.lua", "w")
    localeFile.write("return {\n")
    localeFile.write("lang=\""..settings.get(locales.language).."\",\n")
    localeFile.write("timezone=\""..settings.get(locales.timezone).."\"\n")
    localeFile.write("}\n")
    localeFile.close()
end

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

function getLanguage(details)
    if details then
        return settings.getDetails(locales.language)
    end
    return settings.get(locales.language)
end

function setLanguage(language)
    settings.set(locales.language, language)
    writeLocales()
end

function getTimezone(details)
    if details then
        return settings.getDetails(locales.timezone)
    end
    return settings.get(locales.timezone)
end

function getMessages(program_name)
    local path = paths.messages
    local lang = settings.getDetails(locales.language)
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

loadLocales()