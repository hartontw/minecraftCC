local REPO = "https://raw.githubusercontent.com/hartontw/minecraftCC/master/repository/"

print("Loading system...")
shell.run("wget", "run", REPO.."system/system.lua")
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

print("Installation complete!")