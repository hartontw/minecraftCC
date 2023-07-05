os.loadAPI("/usr/apis/system.lua")
shell.setPath(shell.path()..":"..system.paths.programs)
if fs.exists("/home/startup") then
    shell.run("/home/startup")
end