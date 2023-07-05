local username = "hartontw"
local reponame = "minecraftCC"
local program_name = "cube"
local msg

local function writeFile(path, content)
    local file = fs.open(path..".lua", "w")
    file.write(content)
    file.close();
end

local function download(path)
    local repository = "https://raw.githubusercontent.com/"..username.."/"..reponame.."/master/repository/"
    
    local response, code, reason

    response, reason = http.get(repository..path)
    if not response then
        return false, {
            code = 404,
            reason = reason or "Unknown"
        }
    end

    code, reason = response.getResponseCode()
    if code ~= 200 then
        response.close();
        return false, {
            code = code,
            reason = reason or "Unknown"
        }
    end

    local body = response.readAll();
    response.close();
    return true, body
end

local function downloadCode(name)
    local res, data = download(name.."/"..name..".lua")
    if not res then
        print(data.code, data.reason)
        return nil
    end
    return data
end

local function downloadInfo(name)
    local res, data = download(name.."/info.lua")
    if not res then
        print(data.code, data.reason)
        return nil
    end
    return textutils.unserialise(data)
end

local function getInfo(name)
    if not fs.exists(system.paths.info..name..".lua") then
        return nil
    end
    local file = fs.open(system.paths.info..name..".lua", "r")
    local info = textutils.unserialise(fs.readAll())
    file.close()
    return info
end

local function installLocales(name)
    local lang = system.locales.language
    local res, data
    res, data = download(name.."/locale/"..lang.default..".lua")
    if not res then
        print(data.code, data.reason)
        return false
    end
    writeFile(system.paths.messages..name.."/"..lang.default, data)
    if lang.default ~= lang.value then
        res, data = download(name.."/locale/"..lang.value..".lua")
        if res then
            writeFile(system.paths.messages..name.."/"..lang.value, data)
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
    if not dependencies or #dependencies == 0 then
        return true
    end
    print(msg.installing_dependencies)
    for name, version in pairs(dependencies) do
        local currentInfo = getInfo(name)
        if currentInfo and not mayorVersion(currentInfo.version, version) then
            print(msg.already_satisfied:gsub("$name", name):gsub("$version", currentInfo.version), "")
        else
            print(msg.fetching_info:gsub("$name", name), "")
            local remoteInfo = downloadInfo(name)
            if not remoteInfo then return false end
            print(msg.installing:gsub("$name", name), "")
            if not installDependencies(remoteInfo.dependencies) then
                return false
            end
            if remoteInfo.locales and not installLocales(name) then
                return false
            end
            local code = downloadCode(name)
            if not code then return false end
            writeFile(system.paths[remoteInfo.category]..name, code)
            writeFile(system.paths.info..name, textutils.serialise(remoteInfo))
        end
    end
    return true
end

local function install(name)
    print(msg.fetching_info:gsub("$name", name), "")
    local currentInfo = getInfo(name)
    local remoteInfo = downloadInfo(name)
    if not remoteInfo then return false end
    if currentInfo and not mayorVersion(currentInfo.version, remoteInfo.version) then
        print(msg.already_newest:gsub("$name", name):gsub("$version", currentInfo.version), "")
        return false
    end
    print(msg.installing:gsub("$name", name), "")
    if not installDependencies(remoteInfo.dependencies) then
        return false
    end
    if remoteInfo.locales and not installLocales(name) then
        return false
    end
    local code = downloadCode(name)
    if not code then return false end
    writeFile(system.paths[remoteInfo.category]..name, code)
    writeFile(system.paths.info..name, textutils.serialise(remoteInfo))
    return true
end

local function search(name)
    local res, data
    local info = getInfo(name)
    if not info then
        print(msg.user..": "..msg.not_installed:gsub("$name", name), "")
    else
        print(msg.user..": "..name.."("..info.version..")")
    end
    local repoTree = "https://api.github.com/repos/"..username.."/"..reponame.."/git/trees/master"
    res, data = download(repoTree)
    if not res then
        print(data.code, data.reason)
        return false
    end
    local tree = textutils.unserialiseJSON(data).tree
    for _, v in ipairs(tree) do
        if v.path == "repository" then
            res, data = download(v.url)
            if not res then
                print(data.code, data.reason)
                return false
            end
            break
        end
    end
    tree = textutils.unserialiseJSON(data).tree
    for _, v in ipairs(tree) do
        if v.path == name..".lua" then
            res, data = downloadInfo(name)
            if not res then
                print(data.code, data.reason)
                return false
            end
            print(msg.remote..": "..name.."("..data.version..")")
            return true
        end
    end
    print(msg.remote..": "..msg.not_found)
    return true
end

local function removeOrphan(name)
    local info = getInfo(name)
    if not info or info.category == "programs" then
        return
    end
    local all = fs.list(system.paths.info)
    for _, value in ipairs(all) do
        local i = getInfo(value:sub(1, string.len(value-4)))
        if i and i.dependencies and i.dependencies[name] then
            return
        end
    end
    fs.delete(system.paths.info..name..".lua")
    fs.delete(system.paths[info.category]..name..".lua")
    if fs.exists(system.paths.messages..name) then
        fs.delete(system.paths.messages..name)
    end
    for k in pairs(info.dependencies) do
        removeOrphan(k)
    end
end

local function remove(name)
    local info = getInfo(name)
    if not info then
        print(msg.not_installed:gsub("$name", name), "")
        return false
    end
    fs.delete(system.paths.info..name..".lua")
    fs.delete(system.paths[info.category]..name..".lua")
    if fs.exists(system.paths.messages..name) then
        fs.delete(system.paths.messages..name)
    end
    for k in pairs(info.dependencies) do
        removeOrphan(k)
    end
    return true
end

local function update()
    install(program_name)
end

local function clean()
    local libraries = table.concat(fs.list(system.paths.apis), fs.list(system.paths.modules))
    for _, lib in ipairs(libraries) do
        removeOrphan(lib:sub(1, string.len(lib-4))) --.lua
    end
end

local function help()
    print(msg.usage)
end

local function firstInstall()
    if not installLocales(program_name) then
        print("Locales not found")
        return
    end
    msg = system.getMessages(program_name)
    print(msg.first_time:gsub("$name", program_name), "")
    install(program_name);
end

local info = getInfo(program_name)
if not info then
    firstInstall()
    return
end

msg = system.getMessages(program_name)
local rargs = system.import("rargs").new()
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