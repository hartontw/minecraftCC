local username = "hartontw"
local reponame = "minecraftCC"
local program_name = "cube"
local paths = {
    temp = settings.get("paths.temp"),
    info = settings.get("paths.info"),
    config = settings.get("paths.config"),
    locales = settings.get("paths.locales"),
    messages = settings.get("paths.messages"),
    apis = settings.get("paths.apis"),
    modules = settings.get("paths.modules"),
    programs = settings.get("paths.programs")
}
local msg = nil

local function writeFile(path, content)
    local codeFile = fs.open(path..".lua", "w")
    codeFile.write(content)
    codeFile.close();
end

local function download(path)
    local repository = "https://raw.githubusercontent.com/"..username.."/"..reponame.."/master/repository/"
    
    local code = 404
    local reason = "Unknown"
    local response = nil

    response, reason = http.get(repository..path)
    if not response then
        return false, {
            name = msg and msg.download_error or "Download error",
            data = {
                code = code,
                reason = reason
            }
        }
    end

    code, reason = response.getResponseCode()
    if code ~= 200 then
        response.close();
        return false, {
            name = msg and msg.download_error or "Download error",
            data = {
                code = code,
                reason = reason
            }
        }
    end

    local body = response.readAll();
    response.close();
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
    if not fs.exists(paths.info..name..".lua") then
        return nil
    end
    return require(paths.info..name)
end

local function installLocales(name)
    local lang = settings.getDetails("locale.lang")
    local res, body
    res, body = downloadLocale(name, lang.default)
    if not res then return false end
    writeFile(paths.messages..name.."/"..lang.default, body)
    if lang.default ~= lang.value then
        res, body = downloadLocale(name, lang.value)
        if res then
            writeFile(paths.messages..name.."/"..lang.value, body)
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
            print(msg.already_satisfied:gsub("$name", name):gsub("$version", currentInfo.version), "")
        else
            print(msg.fetching_info:gsub("$name", name), "")
            local remoteInfo = downloadInfo(name)
            print(msg.installing:gsub("$name", name), "")
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
    print(msg.fetching_info:gsub("$name", name), "")
    local currentInfo = getInfo(name)
    local remoteInfo = downloadInfo(name)
    if currentInfo and not mayorVersion(currentInfo.version, remoteInfo.version) then
        print(msg.already_newest:gsub("$name", name):gsub("$version", currentInfo.version), "")
        return false
    end
    print(msg.installing:gsub("$name", name), "")
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
        print(msg.user..": "..msg.not_installed:gsub("$name", name), "")
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
    local all = fs.list(paths.info)
    for index, value in ipairs(all) do
        local i = getInfo(value:sub(1, #value-4))
        if i and i.dependencies and i.dependencies[name] then
            return false
        end
    end
    fs.delete(paths.messages..name)
    fs.delete(paths[info.category]..name..".lua")
    fs.delete(paths.info..name..".lua")
    for k in pairs(info.dependencies) do
        removeOrphan(k)
    end
    return true
end

local function remove(name)
    local info = getInfo(name)
    if not info then
        print(msg.not_installed:gsub("$name", name), "")
        return false
    end
    fs.delete(paths.messages..name)
    fs.delete(paths[info.category]..name..".lua")
    fs.delete(paths.info..name..".lua")
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

local function getMsg()
    local lang = settings.getDetails("locale.lang")
    local messages = require(paths.messages..program_name.."/"..lang.default)
    if lang.default ~= lang.value then
        if fs.exists(paths.messages..program_name.."/"..lang.value..".lua") then
            local translate = require(paths.messages..program_name.."/"..lang.value)
            for k, v in pairs(translate) do
                messages[k] = v
            end
        end
    end
    return messages
end

local function firstInstall()
    if not installLocales(program_name) then
        print("Locales not found")
        return
    end
    msg = getMsg()
    print(msg.first_time:gsub("$name", program_name), "")
    install(program_name);
end

local info = getInfo(program_name)
if not info then
    firstInstall()
    return
end

msg = getMsg()
local rargs = require(paths.modules.."rargs").new()
rargs.add({name="help", alias="h", type="flag", description=msg.help})
rargs.add({name="version", alias="v", type="flag", description=msg.version})
rargs.add({name="update", alias="u", type="flag", description=msg.update})
rargs.add({name="clean", alias="c", type="flag", description=msg.clean})
rargs.add({name="search", alias="s", type="strings", description=msg.search})
rargs.add({name="install", alias="i", type="strings", description=msg.install})
rargs.add({name="remove", alias="r", type="strings", description=msg.remove})

local function main(args)
    args = rargs.parse(args)
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
end

local tArgs = { ... }
local success, err = pcall(function() main(tArgs) end)
if not success then
    print(err)
end