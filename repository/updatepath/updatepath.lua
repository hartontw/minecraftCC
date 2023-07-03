local programs = settings.get("paths.programs")
local path = shell.path()
if not path:match(programs) then
    shell.setPath(path..":"..programs)
end