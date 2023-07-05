local REPO = "https://raw.githubusercontent.com/hartontw/minecraftCC/master/repository/"

print("Loading system...")
shell.run("wget", REPO.."system/system.lua")
os.loadAPI("system")

print("Generating paths...")
for k, v in pairs(system.paths) do
    fs.makeDir(v)
end
shell.setPath(shell.path()..":"..system.paths.programs)

print("Running cube...")
shell.run("wget", "run", REPO.."cube/cube.lua")

print("Installing startup script...")
shell.run("wget", REPO.."startup.lua")

print("Deleting installation files...")
fs.delete("system.lua")

print("Installation complete!")
sleep(2)
os.reboot()