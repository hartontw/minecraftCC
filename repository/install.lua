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

print("Generating paths...")
for k, v in pairs(paths) do
    settings.define("paths."..k, {
        default = v,
        description = "Path to "..k.." files",
        type = "string",
    })
    fs.makeDir(v)
end

print("Generating locales...")
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

print("Downloading cube package manager...")
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

print("Running cube...")
shell.run(paths.temp.."install.lua")

print("Deleting installation files...")
fs.delete(paths.temp.."install.lua")
fs.delete("install.lua")

print("Installation complete!")