local REPO = "https://raw.githubusercontent.com/hartontw/minecraftCC/master/repository/"

print("Loading system...")
shell.run("wget", REPO.."system/system.lua")
os.loadAPI("system.lua")

print("Generating paths...")
for _, v in pairs(system.paths) do
    fs.makeDir(v)
    print(v)
end
shell.setPath(shell.path()..":"..system.paths.programs)

print("Running cube...")
shell.run("wget", "run", REPO.."cube/cube.lua")

print("Installing startup script...")
shell.run("wget", REPO.."startup.lua")

print("Deleting installation files...")
fs.delete("system.lua")

print("Installation complete!")
sleep(1)
print("Reboot 5s...")
sleep(5)
os.reboot()