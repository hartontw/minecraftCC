return {
    getLang = function()
        return settings.get("locale.lang")
    end,
    getMessages = function(program_name)
        local path = settings.get("paths.messages")
        local lang = settings.getDetails("locale.lang")
        local messages = require(path..program_name.."/"..lang.default)
        if lang.default ~= lang.value then
            if fs.exists(path..program_name.."/"..lang.value..".lua") then
                local translate = require(path..program_name.."/"..lang.value)
                for k, v in pairs(translate) do
                    messages[k] = v
                end
            end
        end
        return messages
    end
}