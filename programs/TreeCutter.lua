local tArgs = { ... }

if not turtle then
    print("Requires a turtle")
    return
end

if false then
    print("Turtle requires a valid tool")
    return
end

if tArgs[1] and not tonumber(tArgs[1]) or tArgs[2] and not tonumber(tArgs[2]) then
    print("Usage: length(number) waitTime(number)")
    return
end

local length = tArgs[1] and tonumber(tArgs[1]) or 1
local waitTime = tArgs[2] and tonumber(tArgs[2]) or 5

local position = {x=0, y=0, z=0, w="z"}
local furnaceTime = os.clock()

local _fuel = {}
_fuel["minecraft:lava_bucket"] = {power=1000, stack=1}
_fuel["minecraft:coal_block"] = {power=800, stack=64}
_fuel["minecraft:blaze_rod"] = {power=120, stack=64}
_fuel["minecraft:coal"] = {power=80, stack=64}

local function printPosition()
    print("X: "..tostring(position.x)..", Y: "..tostring(position.y)..", Z: "..tostring(position.z))
end

local function workAreaBlocked(dir)
    printError(dir .. " block is inaccessible. Please release the area and press any key...")
    os.pullEvent( "key" )
end

local function notEnoughSaplings(amount)
    printError("Not enough saplings in turtle inventory. Add "..amount.." saplings or more...")
    os.pullEvent( "turtle_inventory" )
end

local function notEnoughFuel()
    printError("Not enough fuel. Insert some fuel...")
    os.pullEvent( "turtle_inventory" )
end

local function workbenchError(missing)
    printError("Item "..missing.." is missing. Please add some or set the area and press any key...")
    while true do
        local sEvent = os.pullEvent()
        if sEvent == "key" or sEvent == "turtle_inventory" then
            break
        end
    end
end

local function inventoryFull()
    printError("Inventory is full. Please release some slot...")
    os.pullEvent( "turtle_inventory" )
end

local function filteredDetect(name, dir)
    local turtleInspect = dir and turtle["inspect"..dir] or turtle.inspect
    local detect, data = turtleInspect()
    return detect and string.find(data.name, name)
end

local function place(items, dir)
    local turtlePlace = dir and turtle["place"..dir] or turtle.place
    local index = turtle.getSelectedSlot()
    for i, v in ipairs(items) do
        if v.count > 0 then
            turtle.select(v.index)
            if turtlePlace() then
                v.count = v.count - 1
                items.count = items.count - 1
                turtle.select(index)
                return true
            end
        end
    end
    turtle.select(index)
    return false
end

local function drop(items, amount, dir)
    local turtleDrop = dir and turtle["drop"..dir] or turtle.drop
    local index = turtle.getSelectedSlot()
    for i, v in ipairs(items) do
        if v.count > 0 then
            turtle.select(v.index)
            if not amount then
                amount = v.count
            else
                amount = math.min(amount, v.count)
            end
            if turtleDrop(amount) then
                v.count = v.count - amount
                items.count = items.count - amount
                turtle.select(index)
                return true
            end
        end
    end
    turtle.select(index)
    return false
end

local function getItemDetail(index)
    local data = turtle.getItemDetail(index)
    if data then
        data.fullName = data.name .. "_" .. tostring(data.damage)
        data.index = index
    end
    return data
end

local function stackItems()
    local index = turtle.getSelectedSlot()
    for i=1, 15 do
        for j=i+1, 16 do
            if turtle.getItemCount(j) > 0 then
                turtle.select(j)
                turtle.transferTo(i)
            end
        end
    end
    turtle.select(index)
end

local function getItems(...)
    local args = {...}

    if #args == 0 then
        args[1] = function(data) return data ~= nil end
    elseif #args == 1 then
        if type(args[1]) == "string" then
            local str = args[1]
            args[1] = function(data) return data and string.find(data.name, str) end
        end
    else
        local functions = {}
        for i, v in ipairs(args) do
            if type(v) == "string" then
                local str = v
                args[i] = {key=str, filter=function(data) return data and string.find(data.name, str) end}
            elseif type(v) == "function" then
                local fi = #functions+1
                functions[fi] = v
                args[i] = {key="filtered", filter=functions[fi]}
            end
        end
        if #functions == #args then
            args = { function (data)
                for i, v in ipairs(functions) do
                    if v(data) then
                        return true
                    end
                end
                return false
            end}
        end
    end

    local single = #args == 1 and type(args[1]) == "function"

    local index = turtle.getSelectedSlot()

    local items = {}
    local others = {}
    local empty = {}

    for i=1, 16 do
        local data = getItemDetail(i)
        if data then
            local found = false
            turtle.select(i)
            if single then
                if args[1](data) then
                    local fn = data.fullName
                    if not items[fn] then
                        items[fn] = { fullname = fn, count=0 }
                    end
                    items[fn][#items[fn] + 1] = data
                    items[fn].count = items[fn].count + data.count
                    found = true
                end
            else
                for j, v in ipairs(args) do
                    if v.filter(data) then
                        local key = v.key
                        if not items[key] then
                            items[key] = {}
                        end
                        local fn = data.fullName
                        if not items[key][fn] then
                            items[key][fn] = { fullname = fn, count=0 }
                        end
                        items[key][fn][#items[key][fn] + 1] = data
                        items[key][fn].count = items[key][fn].count + data.count
                        found = true
                    end
                end
            end
            if not found then
                others[#others + 1] = i
            end
        else
            empty[#empty + 1] = i
        end
    end

    turtle.select(index)
    return items, others, empty
end

local function getMostAbundant(items)
    local most = nil
    if items then
        for key, value in pairs(items) do
            if not most or value.count > most.count then
                most = value
            end
        end
    end
    return most
end

local function refuel(moves)
    moves = moves or 1

    local fuelLevel = turtle.getFuelLevel()

    if fuelLevel == "unlimited" or fuelLevel >= moves then
        return true
    end

    local index = turtle.getSelectedSlot()

    local fuel = {key="fuel", filter = function(data)
        return data and not string.find(data.name, "sapling") and not string.find(data.name, "log") and turtle.refuel(0)
     end}
 
    local items = getItems(fuel, "log", "sapling")

    local itemRefuel = function(item, reject)
        if item then
            for k, v in pairs(item) do
                if v ~= reject then
                    for i, w in ipairs(v) do
                        turtle.select(w.index)
                        while w.count > 0 and turtle.getFuelLevel() < moves do
                            if turtle.refuel(1) then
                                w.count = w.count - 1
                                v.count = v.count - 1
                            else
                                break
                            end
                        end
                        if turtle.getFuelLevel() >= moves then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    if itemRefuel(items.fuel) or itemRefuel(items.log) then
        turtle.select(index)
        return true
    elseif items.sapling then
        local sapling = getMostAbundant(items.sapling)
        if (sapling.count - length*length) * 5 < moves then
            if itemRefuel(items.sapling, sapling) then
                turtle.select(index)
                return true
            end
        elseif itemRefuel(items.sapling) then
            turtle.select(index)
            return true
        end
    end

    turtle.select(index)
    return false
end

local function turnLeft()
    local w = position.w

    if w == "-z" then
        w = "x"
    elseif w == "x" then
        w = "z"
    elseif w == "z" then
        w = "-x"
    elseif w == "-x" then
        w = "-z"
    else
        print("Invalid rotation")
    end

    if w ~= position.w then
        turtle.turnLeft()
        position.w = w
    end
end

local function turnRight()
    local w = position.w

    if w == "-z" then
        w = "-x"
    elseif w == "-x" then
        w = "z"
    elseif w == "z" then
        w = "x"
    elseif w == "x" then
        w = "-z"
    else
        print("Invalid rotation")
    end

    if w ~= position.w then
        turtle.turnRight()
        position.w = w
    end
end

local function forward()
    while not refuel() do
        notEnoughFuel()
    end

    while not turtle.forward() do
        if turtle.detect() then
            if not turtle.dig() then
                workAreaBlocked("Forward")
            end
        else
            if not turtle.attack() then
                sleep( 0.5 )
            end
        end
    end

    local index = position.w:gsub("-", "")
    local sign = string.find(position.w, "-") and -1 or 1
    position[index] = position[index] + sign
end

local function back()
    while not refuel() do
        notEnoughFuel()
    end

    if not turtle.back() then
        turnLeft()
        turnLeft()
        forward()
        turnLeft()
        turnLeft()
    else
        local index = position.w:gsub("-", "")
        local sign = string.find(position.w, "-") and 1 or -1
        position[index] = position[index] + sign
    end
end

local function up()
    while not refuel() do
        notEnoughFuel()
    end

    while not turtle.up() do
        if turtle.detectUp() then
            if not turtle.digUp() then
                workAreaBlocked("Top")
            end
        else
            if not turtle.attackUp() then
                sleep( 0.5 )
            end
        end
    end

    position.y = position.y + 1
end

local function down()
    while not refuel() do
        notEnoughFuel()
    end

    while not turtle.down() do
        if turtle.detectDown() then
            if not turtle.digDown() then
                workAreaBlocked("Bottom")
            end
        else
            if not turtle.attackDown() then
                sleep( 0.5 )
            end
        end
    end

    position.y = position.y + 1
end

local function chestSetup(dir)
    local turtleSuck = dir and turtle["suck"..dir] or turtle.suck
    local turtleDrop = dir and turtle["drop"..dir] or turtle.drop

    turtle.select(1)
    while turtleSuck() do end

    local filter = {"log, sapling"}
    for k, v in pairs(_fuel) do
        filter[#filter+1] = k
    end

    local items, others, empty = getItems(unpack(filter))

    for i=1, #others do
        turtle.select(others[i])
        turtleDrop()
    end

    local save = function (item, max)
        local total = 0
        for k, v in pairs(item) do
            for i, w in ipairs(v) do
                if total + w.count > max then
                    local sub = w.count - (max - total)
                    turtle.select(w.index)
                    turtleDrop(sub)
                    total = max
                else
                    total = total + w.count
                end
            end
        end
    end

    for k, v in pairs(items) do
        if _fuel[k] then
            save(v, _fuel[k].stack)
        end
    end

    if items.log then
        save(items.log, 64)
    end

    if items.sapling then
        save(items.sapling, 64)
    end

end

local function furnaceSetup(hopper)
    
    furnaceTime = furnaceTime - os.clock()
    if furnaceTime > 0 then
        print("Waiting "..tostring(math.floor(furnaceTime)).. " seconds for furnace to finish...")
        sleep(furnaceTime)
    end

    if not hopper then
        down()
        forward()
        turtle.suckUp()
        back()
        up()
    end

    turtle.suck()

    local items = getItems("coal", "log", "sapling")

    if not items.log then
        return false
    end

    local mostCoal = getMostAbundant(items.coal)
    local mostLog = getMostAbundant(items.log)
    local mostSapling = getMostAbundant(items.sapling)

    local logs = math.min(64, mostLog.count)

    if mostCoal and logs >= 8 and mostCoal.count * 8 >= logs then
        local c = math.floor(logs/8)
        drop(mostCoal, c)
        furnaceTime = c * 80        
        logs = c * 8
    elseif mostSapling and (mostSapling.count - length*length) * 0.5 >= logs then
        logs = math.min(32, logs)
        drop(mostSapling, logs*2)
        furnaceTime = logs * 2 * 5
    else
        if logs < 3 then
            return false
        end

        local total = 0
        for k, v in pairs(items.log) do
            total = total + v.count
        end

        local same = logs == total

        local r = logs % 3
        logs = logs-r

        local other = nil
        if not same then
            for k, v in pairs(items.log) do
                if v ~= mostLog then
                    if v.count >= logs / 1.5 then
                        other = v
                        break
                    end
                end
            end
        end
        if not other then
            if logs < 5 then
                return false
            end
            while r < logs / 1.5 do
                logs = logs - 3
                r = r + 3
            end
        else
            mostLog = other
        end
        r = logs / 1.5
        drop(mostLog, r)
        furnaceTime = r * 15
    end

    up()
    forward()

    turtle.suckDown()
    drop(mostLog, logs, "Down")
    furnaceTime = os.clock() + furnaceTime

    back()
    down()

    return true
end

local function hopperSetup(items)
    up()
    while not filteredDetect("furnace") do
        if not items.furnace or not place(getMostAbundant(items.furnace)) then
            workbenchError("furnace")
            items.furnace = getItems("furnace")
        end
    end
    furnaceSetup(true)
    down()
    if not filteredDetect("chest", "Down") then
        down()
        local most = getMostAbundant(items.chest)
        while not filteredDetect("chest") do
            if not most or not place(most) then
                workbenchError("chest")
                items.chest = getItems("chest")
            end
        end
        chestSetup()
        up()
        if most and most.count > 0 then
            place(most, "Down")
        end
    else
        chestSetup("Down")
    end
end

local function workbenchSetup()
    turnLeft()
    turnLeft()

    stackItems()

    local items = getItems("hopper", "chest", "furnace")

    if not turtle.detect() then
        if items.hopper then
            place(getMostAbundant(items.hopper))
        elseif items.chest then
            place(getMostAbundant(items.chest))
        elseif items.furnace then
            place(getMostAbundant(items.furnace))
        end
    end
    
    if filteredDetect("hopper") then
        hopperSetup(items)
    elseif filteredDetect("chest") then
        chestSetup()
    elseif filteredDetect("furnace") then
        furnaceSetup()
    end

    local emptySlots = 0
    for i=1, 16 do
        if turtle.getItemSpace(i) > 0 then
            emptySlots = emptySlots + 1
        end
    end

    while emptySlots < 2 do
        inventoryFull()
    end

    turnLeft()
    turnLeft()
end

local function rawPlant(sapling)
    while not place(sapling) do
        if turtle.detect() then
            if not turtle.dig() then
                workAreaBlocked("Forward")
            end
        elseif not turtle.attack() then
            sleep( 0.5 )
        end
    end
end

local function plantRight(sapling)
    for i=1, length-1 do
        turnLeft()
        rawPlant(sapling)
        turnRight()
        turnRight()
        rawPlant(sapling)
        turnLeft()
        back()
        rawPlant(sapling)
    end
end

local function plantLeft(sapling, top, bottom)
    for i=1, length-1 do
        if top then
            turnLeft()
            rawPlant(sapling)
            turnRight()
            if bottom then
                turnRight()
                rawPlant(sapling)
                turnLeft()
            end
        end
        back()
        rawPlant(sapling)
    end
end

local function plant()
    stackItems()

    local index = turtle.getSelectedSlot()
    local sapling = getMostAbundant(getItems("sapling"))
    local blocks = length*length

    if sapling and sapling.count >= blocks then
        if length == 1 then
            turtle.select(sapling[1].index)
            turtle.place()
            turtle.select(index)
        else
            for i=1, length-1 do
                forward()
            end

            local remain = length
            while remain > 0 do
                if position.x == 0 then
                    if remain > 3 then
                        turnLeft()
                        plantRight(sapling)
                        remain = remain - 3
                        turnRight()
                        rawPlant(sapling)
                        back()
                        rawPlant(sapling)
                        back()
                        rawPlant(sapling)
                        if remain > 1 then
                            back()
                        end
                        turnRight()
                    else
                        turnRight()
                        for i=1, length-1 do
                            forward()
                        end
                    end
                else
                    plantLeft(sapling, remain > 1, remain > 2)
                    turnLeft()
                    if remain > 1 then
                        rawPlant(sapling)
                        back()
                        rawPlant(sapling)
                        if remain > 2 then
                            back()
                            rawPlant(sapling)
                            if remain > 4 then
                                back()
                            end
                        end
                    else
                        back()
                        rawPlant(sapling)
                    end
                    remain = remain - 3
                end
            end
        end
    else
        notEnoughSaplings(blocks)
    end
end

local function cut()
    
end

local function main()

    length = math.max(length, 1)
    waitTime = math.max(waitTime, 1)

    print("length("..tostring(length)..") waitTime("..tostring(waitTime)..")")

    while true do
        if filteredDetect(":log") then
            cut()
            workbenchSetup()
        elseif not filteredDetect(":sapling") then
            plant()
        end
        sleep(waitTime)
    end

end

main()