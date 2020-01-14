function getFirst(sType, remote, filter)
    if remote then
        for _, name in ipairs( peripheral.getNames() ) do
            if (not sType or peripheral.getType(name) == sType) and (not filter or name:find(filter)) then
                return peripheral.wrap(name)
            end
        end
    else
        for _, side in ipairs( rs.getSides() ) do
            if not sType or peripheral.getType(side) == sType then
                return peripheral.wrap(side)
            end
        end
    end
end

function getPerSide(sType, remote, filter)
    local p = {}
    for _, side in ipairs( rs.getSides() ) do
        local t = peripheral.getType(side)
        if not sType or t == sType then
            p[side] = peripheral.wrap(side)
        elseif remote and t == "modem" then
            local m = {}
            for _, name in ipairs(peripheral.call(side, "getNamesRemote")) do
                if peripheral.getType(name) == sType and (not filter or name:find(filter)) then
                    m[#m+1] = peripheral.wrap(name)
                end
            end
            p[side] = #m > 0 and m
        end
    end
    return p
end

function getPerType(filter)
    local p = {}
    for _, name in ipairs(peripheral.getNames()) do
        if not filter or name:find(filter) then
            local sType = peripheral.getType(name)
            if not p[sType] then
                p[sType] = {}
            end
            p[sType][#p[sType]+1] = peripheral.wrap(name)
        end
    end
    return p
end

function find(sType, func)
    local f = { peripheral.find(sType, func) }
    return f
end

function match(filter)
    for _, name in ipairs(peripheral.getNames()) do
        if name:find(filter) then
            return peripheral.wrap(name)
        end
    end
end

function matchAll(filter)
    local p = {}
    for _, name in ipairs(peripheral.getNames()) do
        if name:find(filter) then
            p[#p+1] = peripheral.wrap(name)
        end
    end
    return p
end

function getList(filter)
    local p = {}
    for _, name in ipairs(peripheral.getNames()) do
        if not filter or name:find(filter) then
            p[#p+1] = peripheral.wrap(name)
        end
    end
    return p
end

function modem()
    for _, side in ipairs( rs.getSides() ) do
        if peripheral.getType(side) == "modem" then
            return peripheral.wrap(side)
        end
    end
end

function modems(filter)
    local m = getPerSide("modem")
    if filter then
        if filter == "wired" or filter == "wireless" then
            local f = {}
            for side, modem in pairs(m) do
                if filter == "wired" and not modem.isWireless() or filter == "wireless" and modem.isWireless() then
                    f[side] = modem
                end
            end
            return f
        else
            return m[filter]
        end
    end
    return m
end

function printer(remote, filter) return getFirst("printer", remote, filter) end
function printers(remote, filter) return getPerSide("printer", remote, filter) end

function drive(remote, filter) return getFirst("drive", remote, filter) end
function drives(remote, filter) return getPerSide("drive", remote, filter) end

--disks

function monitor(remote, filter) return getFirst("monitor", remote, filter) end
function monitors(remote, filter) return getPerSide("monitor", remote, filter) end

function speaker(remote, filter) return getFirst("speaker", remote, filter) end
function speakers(remote, filter) return getPerSide("speaker", remote, filter) end

function computer(remote, filter) return getFirst("computer", remote, filter) end
function computers(remote, filter) return getPerSide("computer", remote, filter) end

function turtle(remote, filter) return getFirst("turtle", remote, filter) end
function turtles(remote, filter) return getPerSide("turtle", remote, filter) end

function advancedMonitor(remote, filter)
    local m = monitors(remote, filter)
    for _, v in pairs(m) do
        if v.isColor() then
            return v
        end
    end
    return m
end

function advancedMonitors(remote, filter)
    local m = monitors(remote, filter)
    local a = {}
    for s, v in pairs(m) do
        if v.isColor() then
            a[s] = v
        end
    end
    return a
end

function getComputerById(id, remote)
    return searchByMethod("computer", "getID", id, remote)
end

function getComputerByLabel(label, remote)
    return searchByMethod("computer", "getLabel", label, remote)
end

function getTurtleById(id, remote)
    return searchByMethod("turtle", "getID", id, remote)
end

function getTurtleByLabel(label, remote)
    return searchByMethod("turtle", "getLabel", label, remote)
end