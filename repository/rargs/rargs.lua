--[[ 
Name: rargs
Desc: arguments parser
Author: Daniel 'Harton'
Date: 23/06/2023
--]]
local rargs = {}
local program_name = "rargs"
local locale = require(settings.get("paths.modules").."locale")
local msg = locale.getMessages(program_name)

function rargs.new()
    local self = {}

    local options = {}
    local aliases = {}

    local function searchMulti(args)
        local arguments = {}
        local index = 1
        local option = nil
        while index <= #args do
            local arg = args[index]
            if not option then
                local name = arg:match("^%-*(.+)$")
                if name then
                    if arg:sub(1, 2) == "--" then
                        option = options[name]
                        if not option then
                            error(msg.option_not_found:gsub("$name", name), 1)
                        end
                    elseif string.len(name) == 1 then
                        option = aliases[name]
                        if not option then
                            error(msg.invalid_alias:gsub("$name", name), 1)
                        end
                    else
                        error(msg.invalid_alias:gsub("$name", name), 1)
                    end
                    table.insert(arguments, option)
                    table.remove(args, index)
                else
                    index = index + 1
                end
            elseif arg:sub(1, 1) ~= "-" then
                table.insert(option.value, arg)
                table.remove(args, index)
            else
                option = nil
            end
        end
        return arguments
    end

    local function searchFlags(args)
        local arguments = {}
        local index = 1
        while index <= #args do
            local arg = args[index]
            local flags = arg:match("^%-(.+)$")
            if flags then
                for i=1, string.len(flags) do
                    local flag = aliases[flags:sub(i, i)]
                    if not flag then
                        error(msg.invalid_alias:gsub("$name", flag), 1)
                    end
                    if flag.type ~= "flag" then
                        error(msg.not_a_flag:gsub("$name", flag), 1)
                    end
                    table.insert(arguments, flag)
                end
                table.remove(args, index)
            else
                index = index + 1
            end
        end
        return arguments
    end

    local function setValue(option, value)
        if option.type == "number" then
            value = tonumber(value)
            if not value then
                error(msg.invalid_type:gsub("$name", option.name):gsub("$type", "number"), 1)
            end
        elseif option.type == "boolean" then
            value = string.lower(value)
            if value == "true" then
                value = true
            elseif value == "false" then
                value = false
            else
                error(msg.invalid_type:gsub("$name", option.name):gsub("$type", "boolean"), 1)
            end
        end
        option.value = value
    end

    local function searchSingle(args)
        local arguments = {}
        local index = 1
        while index <= #args do
            local arg = args[index]
            local name, value = arg:match("^%-*([^=]+)=(.+)$")
            if name then
                local option
                if arg:sub(1, 2) == "--" then
                    option = options[name]
                    if not option then
                        error(msg.option_not_found:gsub("$name", name), 1)
                    end
                elseif string.len(name) == 1 then
                    option = aliases[name]
                    if not option then
                        error(msg.invalid_alias:gsub("$name", name), 1)
                    end
                else
                    error(msg.invalid_alias:gsub("$name", name), 1)
                end
                if option.type == "strings" then
                    error(msg.invalid_type:gsub("$name", name):gsub("$type", option.type), 1)
                end
                setValue(option, value)
                table.insert(arguments, option)
                table.remove(args, index)
            else
                index = index + 1
            end
        end
        return arguments
    end

    function self.add(option)
        options[option.name] = option
        if option.alias then
            aliases[option.alias] = option
        end
    end

    function self.parse(args)
        local arguments = {}
        local positional = {}

        local single = searchSingle(args)
        local flags = searchFlags(args)
        local multi = searchMulti(args)

        for _, arg in single do arguments[arg.name] = arg end
        for _, arg in flags do arguments[arg.name] = arg end
        for _, arg in multi do arguments[arg.name] = arg end
        for _, arg in ipairs(args) do table.insert(positional, arg) end

        return arguments, positional
    end

    return self
end

return rargs
