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
shell.setPath(shell.path()..":"..paths.programs)

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

print("Running cube...")
shell.run("wget", "run", "https://raw.githubusercontent.com/hartontw/minecraftCC/master/repository/cube/cube.lua")
print("Installation complete!")