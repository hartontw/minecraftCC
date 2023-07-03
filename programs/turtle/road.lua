if not turtle then
    printError("Requires a Turtle")
    return
end

local tArgs = { ... }
if #tArgs < 1 then
    local programName = arg[0] or fs.getName(shell.getRunningProgram())
    print("Usage: " .. programName .. " <length>")
    return
end

-- Mine in a quarry pattern until we hit something we can't dig
local length = tonumber(tArgs[1])
if length < 1 then
    print("Tunnel length must be positive")
    return
end
local hasFuel = function() return turtle.getFuelLevel() >= length*2 end
local slot = 1
while not hasFuel() do
    turtle.select(slot)
    if not turtle.refuel(1) then
        slot = slot + 1
        if slot > 16 then
            print("Not enought fuel")
            return
        end
    end
end
local waiting = tArgs[2] and tonumber(tArgs[2]) or 300
local collected = 0

local function collect()
    collected = collected + 1
    if math.fmod(collected, 25) == 0 then
        print("Mined " .. collected .. " items.")
    end
end

local function tryDig()
    while turtle.detect() do
        if turtle.dig() then
            collect()
            sleep(0.5)
        else
            return false
        end
    end
    return true
end

local function tryDigUp()
    while turtle.detectUp() do
        if turtle.digUp() then
            collect()
            sleep(0.5)
        else
            return false
        end
    end
    return true
end

local function tryDigDown()
    while turtle.detectDown() do
        if turtle.digDown() then
            collect()
            sleep(0.5)
        else
            return false
        end
    end
    return true
end

local function refuel()
    local fuelLevel = turtle.getFuelLevel()
    if fuelLevel == "unlimited" or fuelLevel > 0 then
        return
    end

    local function tryRefuel()
        for n = 1, 16 do
            if turtle.getItemCount(n) > 0 then
                turtle.select(n)
                if turtle.refuel(1) then
                    turtle.select(1)
                    return true
                end
            end
        end
        turtle.select(1)
        return false
    end

    if not tryRefuel() then
        print("Add more fuel to continue.")
        while not tryRefuel() do
            os.pullEvent("turtle_inventory")
        end
        print("Resuming Tunnel.")
    end
end

local function tryUp()
    refuel()
    while not turtle.up() do
        if turtle.detectUp() then
            if not tryDigUp() then
                return false
            end
        elseif turtle.attackUp() then
            collect()
        else
            sleep(0.5)
        end
    end
    return true
end

local function tryDown()
    refuel()
    while not turtle.down() do
        if turtle.detectDown() then
            if not tryDigDown() then
                return false
            end
        elseif turtle.attackDown() then
            collect()
        else
            sleep(0.5)
        end
    end
    return true
end

local function tryForward()
    refuel()
    while not turtle.forward() do
        if turtle.detect() then
            if not tryDig() then
                return false
            end
        elseif turtle.attack() then
            collect()
        else
            sleep(0.5)
        end
    end
    return true
end

local function select(name)
    local timeout = function() sleep(waiting) end
    local inventory = function() os.pullEvent("turtle_inventory") end
    while true do
        for i=1, 16 do
            local data = turtle.getItemDetail(i)
            if data and data.name == name then
                turtle.select(i)
                return true
            end
        end
        print("Insert " .. name)
        local index = parallel.waitForAny(timeout, inventory)
        if index == 1 then
            return false
        end
    end
end

print("Tunnelling...")

local b = 0
for n = 1, length do
    tryDigUp()
    tryDigDown()
    if not select("minecraft:cobblestone") then break end
    turtle.placeDown()
    turtle.turnLeft()
    tryDig()
    if not select("minecraft:cobblestone_wall") then break end
    turtle.place()
    turtle.turnRight()
    turtle.turnRight()
    tryDig()
    if not select("minecraft:cobblestone_wall") then break end
    turtle.place()
    turtle.turnLeft()

    if n < length then
        tryDig()
        if not tryForward() then
            print("Aborting Road.")
            print("Mined " .. collected .. " items total.")
            print("Waiting for retrival: " .. waiting)
            sleep(waiting)
            break
        end
        b = b + 1
    else
        print("Road complete.")
        print("Mined " .. collected .. " items total.")
        print("Waiting for retrival: " .. waiting)
        sleep(waiting)
    end
end

turtle.turnLeft()
turtle.turnLeft()
for i=1, b do
    tryForward()
end
turtle.turnLeft()
turtle.turnLeft()
print("Returned to starting point")

