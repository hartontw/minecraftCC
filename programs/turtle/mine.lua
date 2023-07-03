if not turtle then
    printError("Requires a Turtle")
    return
end

local tArgs = { ... }

local ring = #tArgs > 0 and tonumber(tArgs[1]) or 1
local rings = #tArgs > 1 and tonumber(tArgs[2]) + ring or ring

local collected = 0

local function collect()
    collected = collected + 1
    if math.fmod(collected, 25) == 0 then
        print("Mined " .. collected .. " items.")
    end
end

local function hasSpace()
    for i=1, 16 do
        if turtle.getItemCount(i) == 0 then
            return true
        end
    end
    return false
end

local function dropInChest(down)
    local function getChest()
        for i=1, 16 do
            local item = turtle.getItemDetail(i)
            if item ~= nil and item.name == "minecraft:chest" then
                return i
            end
        end
        return 0
    end

    local function canPlaceChestFront()
        return turtle.place()
    end

    local function canPlaceUp()
        return down and turtle.placeUp()
    end

    local function canPlaceDown()
        return not down and turtle.placeDown()
    end

    local chestIndex = getChest()
    if chestIndex == 0 then
        return false
    end
    turtle.select(chestIndex)
    turtle.turnLeft()
    turtle.turnLeft()
    local drop = nil
    if canPlaceChestFront() then
        drop = turtle.drop
    elseif canPlaceDown() then
        drop = turtle.dropDown
    elseif canPlaceUp() then
        drop = turtle.dropUp
    else
        turtle.turnLeft()
        turtle.turnLeft()
        return false
    end

    for i=1, 16 do
        turtle.select(i)
        local item = turtle.getItemDetail()
        if item ~= nil and item.name ~= "minecraft:chest" and item.name ~= "minecraft:torch" and not turtle.refuel(0) then
            turtle.select(i)
            drop()
        end
    end
    turtle.turnLeft()
    turtle.turnLeft()
    return true
end

local function checkInventory(down)
    while not hasSpace() and not dropInChest(down) do
        print("Inventory full...")
        os.pullEvent("turtle_inventory")
    end
end

local function tryDig()
    while turtle.detect() do
        checkInventory(false)
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
        checkInventory(false)
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
        checkInventory(true)
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
            local item = turtle.getItemDetail(n)
            if item ~= nil and item.name ~= "minecraft:chest" then
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

local function placeTorch()
    turtle.turnLeft()
    turtle.turnLeft()
    while true do
        for i=1, 16 do
            local detail = turtle.getItemDetail(i)
            if detail ~= nil and detail.name == "minecraft:torch" then
                turtle.select(i)
                turtle.place()
                turtle.turnLeft()
                turtle.turnLeft()
                return
            end
        end
        print("Add a Torch to continue.")
        os.pullEvent("turtle_inventory")
    end
end

local function forward()
    tryDigUp()
    tryDigDown()
    tryForward()
end

local function internalRing(r)
    local size = r * 5
    local t = r%2 == 0 and 3 or 6

    local function half(start)
        for i=start, size+start-1 do
            forward()
            if i%8 == 0 then
                placeTorch()
            end
        end
    end

    tryForward()
    turtle.turnRight()
    for i=1, 4 do
        half(3)
        turtle.turnRight()
        half(t)
    end
    turtle.turnLeft()
end

local function middleRing(r)
    local size = r * 5 + 1
    tryForward()
    turtle.turnRight()
    for i=1, size do
        forward()
    end
    turtle.turnRight()
    for j=1, 3 do
        for i=1, size*2 do
            forward()
        end
        turtle.turnRight()
    end
    for i=1, size do
        forward()
    end
    turtle.turnLeft()
end

local function externalRing(r)
    local size = r * 5 + 2
    local function firstWall()
        forward()
        forward()
        turtle.turnRight()
        forward()
        turtle.turnRight()
        forward()
        forward()
        turtle.turnLeft()
        for i=1, size-1 do
            forward()
        end
        turtle.turnRight()
    end

    local function nextWall()
        for i=1, size-1 do
            forward()
        end
        turtle.turnLeft()
        forward()
        forward()
        turtle.turnRight()
        forward()
        forward()
        turtle.turnRight()
        forward()
        turtle.turnRight()
        forward()
        turtle.turnLeft()
        forward()
        turtle.turnLeft()
        for i=1, size do
            forward()
        end
        turtle.turnRight()
    end

    local function lastWall()
        for i=1, size-1 do
            forward()
        end
        turtle.turnLeft()
        forward()
        forward()
        turtle.turnRight()
        forward()
        turtle.turnLeft()
    end

    tryForward()
    firstWall()
    for j=1, 3 do
        nextWall()
    end
    lastWall()
end

local function firstInternalRing()
    tryForward()
    turtle.turnRight()
    forward()
    forward()
    placeTorch()
    forward()
    forward()
    forward()
    turtle.turnRight()
    for j=1, 3 do
        for i=1, 10 do
            forward()
            if i == 6 then
                placeTorch()
            end
        end
        turtle.turnRight()
    end
    for i=1, 5 do
        forward()
    end
    placeTorch()
    turtle.turnLeft()
end

for r=ring, rings do
    print("Tunnelling ring: " .. r)
    if r == 1 then
        firstInternalRing()
    else
        internalRing(r)
    end
    middleRing(r)
    externalRing(r)
end

print("Tunnel complete.")
print("Mined " .. collected .. " items total.")
