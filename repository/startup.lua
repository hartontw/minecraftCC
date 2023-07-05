os.loadAPI("/usr/apis/system")
shell.setPath(shell.path()..":"..system.paths.programs)
if fs.exists("/home/startup") then
    shell.run("/home/startup")
end