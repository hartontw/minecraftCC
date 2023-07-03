local paths = {
    temp = "/usr/temp/",
    info = "/usr/info/",
    config = "/usr/config/",
    locales = "/usr/locales/",
    messages = "/usr/locales/messages/",
    apis = "/usr/apis/",
    modules = "/usr/modules/",
    programs = "/usr/programs/"
}

for k, v in pairs(paths) do
    settings.define("paths."..k, {
        default = v,
        description = "Path to "..k.." files",
        type = "string",
    })
    fs.makeDir(v)
end

settings.define("locale.lang", {
    default = "en",
    description = "System language",
    type = "string"
})

settings.define("locale.timezone", {
    default = "UTC",
    description = "Time zone",
    type = "string"
})

local cubeFile = http.get("https://github.com/hartontw/minecraftCC/blob/master/repository/cube/cube.lua")
local code, res = cubeFile.getResponseCode()
if code ~= 200 then
    error({
        code=code,
        msg=res
    })
end
local file = fs.open(paths.temp.."install.lua", "w")
file.write(res)
file.close()
shell.run(paths.temp.."install.lua")
fs.delete(paths.temp.."install.lua")
fs.delete("install.lua")