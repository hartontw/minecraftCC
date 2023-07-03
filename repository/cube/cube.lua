print("CUBE")

local username = "hartontw"
local reponame = "minecraftCC"
local program_name = "cube"
local paths = {
    temp = settings.get("path.temp"),
    info = settings.get("path.info"),
    config = settings.get("path.config"),
    locales = settings.get("path.locales"),
    apis = settings.get("path.apis"),
    modules = settings.get("path.modules"),
    programs = settings.get("path.programs")
}
local msg = nil

local function writeFile(path, content)
    local codeFile = fs.open(path..".lua", "w")
    codeFile.write(content)
    codeFile.close();
end

local function download(url)
    local repository = "https://raw.githubusercontent.com/"..username.."/"..reponame.."/master/repository/"
    local file = http.get(repository..url)
    local code, res = file.getResponseCode()
    if code ~= 200 then
        file.close();
        return false, {
            name = msg and msg.download_error or "Download error",
            data = {
                code = code,
                res = res
            }
        }
    end
    local body = file.readAll();
    file.close();
    return true, body
end

local function downloadCode(name)
    local res, data = download(name.."/"..name..".lua")
    if not res then
        error(data)
    end
    return data
end

local function downloadInfo(name)
    local res, data = download(name.."/info.lua")
    if not res then
        error(data)
    end
    writeFile(paths.temp..name, data)
    return require(paths.temp..name)
end

local function downloadLocale(name, lang)
    return download(name.."/locale/"..lang..".lua")
end

local function getInfo(name)
    local path = paths.info..name..".lua"
    if not fs.exists(path) then
        return nil
    end
    local file = fs.open(path, "r")
    local content = file.readAll()
    file.close()
    return require(content)
end

local function installLocales(name)
    local lang = settings.getDetails("locale.lang")
    local res, data
    res, data = downloadLocale(name, lang.default)
    if not res then return false end
    writeFile(paths.messages..name.."/"..data)
    if lang.default ~= lang.value then
        res, data = downloadLocale(name, lang.value)
        if res then
            writeFile(paths.messages..name.."/"..data)
        end
    end
    return true
end

local function mayorVersion(current, remote)
    local reg = "^(%d+)%.(%d+)%.(%d+)$"
    local cM, cm, cf = current:match(reg)
    local rM, rm, rf = remote:match(reg)
    if rM > cM then return true end
    if rM < cM then return false end
    if rm > cm then return true end
    if rm < cm then return false end
    if rf > cf then return true end
    return false
end

local function installDependencies(dependencies)
    if not dependencies then
        return
    end
    print(msg.installing_dependencies)
    for name, version in pairs(dependencies) do
        local currentInfo = getInfo(name)
        if currentInfo and not mayorVersion(currentInfo.version, version) then
            print(msg.already_satisfied:gsub("%s", name):gsub("%v", currentInfo.version))
        else
            print(msg.fetching_info:gsub("%s", name))
            local remoteInfo = downloadInfo(name)
            print(msg.installing:gsub("%s", name))
            installDependencies(remoteInfo.dependencies)
            installLocales(name)
            writeFile(paths[remoteInfo.category]..name, downloadCode(name))
            if fs.exists(paths.info..name..".lua") then
                fs.delete(paths.info..name..".lua")
            end
            fs.move(paths.temp..name..".lua", paths.info..name..".lua")
        end
    end
end

local function install(name)
    print(msg.fetching_info:gsub("%s", name))
    local currentInfo = getInfo(name)
    local remoteInfo = downloadInfo(name)
    if currentInfo and not mayorVersion(currentInfo.version, remoteInfo.version) then
        print(msg.already_newest:gsub("%s", name):gsub("%v", currentInfo.version))
        return false
    end
    print(msg.installing:gsub("%s", name))
    installDependencies(remoteInfo.dependencies)
    installLocales(name)
    writeFile(paths[remoteInfo.category]..name, downloadCode(name))
    if fs.exists(paths.info..name..".lua") then
        fs.delete(paths.info..name..".lua")
    end
    fs.move(paths.temp..name..".lua", paths.info..name..".lua")
    return true
end

local function search(name)
    local info = getInfo(name)
    if not info then
        print(msg.user..": "..msg.not_installed:gsub("%s", name))
    else
        print(msg.user..": "..name.."("..info.version..")")
    end
    local repoTree = "https://api.github.com/repos/"..username.."/"..reponame.."/git/trees/master"
    local body = download(repoTree)
    local tree = textutils.unserialiseJSON(body).tree
    for _, v in ipairs(tree) do
        if v.path == "repository" then
            body = download(v.url)
            break
        end
    end
    tree = textutils.unserialiseJSON(body).tree
    for _, v in ipairs(tree) do
        if v.path == name..".lua" then
            local remoteInfo = downloadInfo(name)
            print(msg.remote..": "..name.."("..remoteInfo.version..")")
            return
        end
    end
    print(msg.remote..": "..msg.not_found)
end

local function removeOrphan(name)
    local info = getInfo(name)
    if not info or info.category == "programs" then
        return false
    end
    local all = fs.list(path.info)
    for index, value in ipairs(all) do
        local i = getInfo(value:sub(1, #value-4))
        if i and i.dependencies and i.dependencies[name] then
            return false
        end
    end
    fs.delete(path.messages..name)
    fs.delete(path[info.category]..name..".lua")
    fs.delete(path.info..name..".lua")
    for k in pairs(info.dependencies) do
        removeOrphan(k)
    end
    return true
end

local function remove(name)
    local info = getInfo(name)
    if not info then
        print(msg.not_installed:gsub("%s", name))
        return false
    end
    fs.delete(path.messages..name)
    fs.delete(path[info.category]..name..".lua")
    fs.delete(path.info..name..".lua")
    for k in pairs(info.dependencies) do
        removeOrphan(k)
    end
    return true
end

local function update()
    install(program_name)
end

local function clean()
    local libraries = table.concat(fs.list(paths.apis), fs.list(paths.modules))
    for i, lib in ipairs(libraries) do
        removeOrphan(lib:sub(1, #lib-4)) --.lua
    end
end

local function help()
    print(msg.usage)
end

local function firstInstall()
    installLocales(program_name)
    msg = require(paths.locales..settings.get("locale.lang").."/"..program_name..".lua")
    print(msg.first_time:gsub("%s", program_name))
    install(program_name);
end

print("HOLA")
local info = getInfo(program_name)
print(info)
if not info then
    firstInstall()
    return
end

msg = require(paths.locales..settings.get("locale.lang").."/"..program_name..".lua")
local rargs = require(paths.modules.."rargs.lua").new()
rargs.add({name="help", alias="h", type="flag", description=msg.help})
rargs.add({name="version", alias="v", type="flag", description=msg.version})
rargs.add({name="update", alias="u", type="flag", description=msg.update})
rargs.add({name="clean", alias="c", type="flag", description=msg.clean})
rargs.add({name="search", alias="s", type="strings", description=msg.search})
rargs.add({name="install", alias="i", type="strings", description=msg.install})
rargs.add({name="remove", alias="r", type="strings", description=msg.remove})

local args = rargs.parse({ ... })
if args["help"] then
    help()
    return
end
if args["version"] then
    print(program_name.."("..info.version..")")
    return
end
if args["update"] then
    update()
end
if args["clean"] then
    clean()
end
if args["search"] then
    for _, package in ipairs(args["search"].value) do
        search(package)
    end
end
if args["install"] then
    for _, package in ipairs(args["install"].value) do
        install(package)
    end
end
if args["remove"] then
    for _, package in ipairs(args["remove"].value) do
        remove(package)
    end
end