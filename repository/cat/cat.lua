local program_name = arg[0] or fs.getName(shell.getRunningProgram())

if locale == nil then print(program_name .. " requires locale api running") return end
if rargs == nil then print(program_name .. " requires rargs api running") return end

local messages = locale.getMessages(program_name)
local commands = {
    {name = "number", alias = "n", type = "boolean" },
    {name = "number", alias = "n", type = "boolean" },
}

local function showHelp()
    print(messages.usage)
    print(messages.explanation)
end

local tArgs = { ... }

if #tArgs < 1 then
    showHelp()
    return
end

local filePath = tArgs[1]

if not fs.exists(filePath) then
 print("No such file or directory")
 return
end

local file = fs.open(filePath, "r")
local content = file.readAll()
file.close()