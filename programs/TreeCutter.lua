local tArgs = { ... }

local function printn(str)
    print(str.."\n")
end

if not turtle then
    printn("Requires a turtle")
    return
end

if false then
    printn("Turtle requires a valid tool")
    return
end

if tArgs[1] and not tonumber(tArgs[1]) or tArgs[2] and not tonumber(tArgs[2]) or tArgs[3] and not tonumber(tArgs[3]) then
    printn("Usage: length(number) waitTime(number) space(number)")
    return
end

local length = tArgs[1] and tonumber(tArgs[1]) or 1
local waitTime = tArgs[2] and tonumber(tArgs[2]) or 15
local space = tArgs[3] and tonumber(tArgs[3]) or 0

local position = vector.new(0, 0, 0)
local rotation = 0

local plantingInfo = { works = 0, last = 0, waited = 0 }
local cutingInfo = { works = 0, time = 0, moves = 0 }
local furnaceTime = os.clock()

local _fuel = {}
_fuel["minecraft:lava_bucket"] = {power=1000, stack=1}
_fuel["minecraft:coal_block"] = {power=800, stack=64}
_fuel["minecraft:blaze_rod"] = {power=120, stack=64}
_fuel["minecraft:coal"] = {power=80, stack=64}

local _sapling = {}
_sapling[0] = {name="Oak", lengths={1}, space=0}
_sapling[1] = {name="Spruce", lengths={1, 2}, space=0}
_sapling[2] = {name="Birch", lengths={1}, space=0}
_sapling[3] = {name="Jungle", lengths={1, 2}, space=1}
_sapling[4] = {name="Acacia", lengths={1}, space=0}
_sapling[5] = {name="Dark Oak", lengths={2}, space=0}

local function round(n)
    return math.floor(n+0.5)
end

local function checkPlantSetup(data)
    local info = nil
    if data and data[1].name == "minecraft:sapling" then
        info = _sapling[data[1].damage]
        if info then
            local ok = false
            for i, v in ipairs(info.lengths) do
                if v == length then
                    ok = true
                    break
                end
            end
            if not ok then
                printn(tostring(length).."x"..tostring(length).." is not an appropiate setup for "..info.name.." tree.")
            end
            if info.space > space then
                printn(info.name.." sapling needs at least "..tostring(info.space).." empty blocks around.")
            end
        end
    end
    return info
end

local function printPosition()
    printn("X: "..tostring(position.x)..", Y: "..tostring(position.y)..", Z: "..tostring(position.z))
end

local function workAreaBlocked(dir)
    printError(dir .. " block is inaccessible. Please release the area and press any key...\n")
    os.pullEvent( "key" )
end

local function notEnoughSaplings(amount)
    printError("Not enough saplings in turtle inventory. Add "..amount.." saplings or more...\n")
    os.pullEvent( "turtle_inventory" )
end

local function notEnoughFuel()
    printError("Not enough fuel. Insert some fuel...\n")
    os.pullEvent( "turtle_inventory" )
end

local function workbenchError(missing)
    printError("Item "..missing.." is missing. Please add some...\n")
    os.pullEvent( "turtle_inventory" )
end

local function inventoryFull()
    printError("Inventory is full. Please release some slot...\n")
    os.pullEvent( "turtle_inventory" )
end

local function filteredDetect(name, dir)
    local turtleInspect = dir and turtle["inspect"..dir] or turtle.inspect
    local detect, data = turtleInspect()
    return detect and string.find(data.name, name)
end

local function place(items, dir)
    if items then
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
    end
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
        if turtle.getItemSpace(i) > 0 then
            for j=i+1, 16 do
                if turtle.getItemCount(j) > 0 then
                    turtle.select(j)
                    turtle.transferTo(i)
                end
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
    if turtle.turnLeft() then
        rotation = (rotation + 270) % 360
        return true
    end
    return false
end

local function turnRight()
    if turtle.turnRight() then
        rotation = (rotation + 90) % 360
        return true
    end
    return false
end

local function turnBack()
    if math.random(0, 1) == 0 then
        return turnLeft() and turnLeft()
    end

    return turnRight() and turnRight()
end

local function rawDig(dir)
    dir = dir or ""
    if turtle["detect"..dir]() then
        if not turtle["dig"..dir]() then
            workAreaBlocked(string.len(dir) > 0 and dir or "Forward")
        end
    else
        if not turtle["attack"..dir]() then
            sleep( 0.5 )
        end
    end
end

local function dig()
    rawDig()
end

local function digDown()
    rawDig("Down")
end

local function digUp()
    rawDig("Up")
end

local function forward()
    while not refuel() do
        notEnoughFuel()
    end

    while not turtle.forward() do
        dig()
    end

    if rotation == 0 then
        position.z = position.z + 1
    elseif rotation == 90 then
        position.x = position.x + 1
    elseif rotation == 180 then
        position.z = position.z - 1
    elseif rotation == 270 then
        position.x = position.x - 1
    else
        printError("Rotation error!\n")
        os.pullEvent("key")
    end
end

local function back()
    while not refuel() do
        notEnoughFuel()
    end

    if not turtle.back() then
        turnBack()
        forward()
        turnBack()
    else
        if rotation == 0 then
            position.z = position.z - 1
        elseif rotation == 90 then
            position.x = position.x - 1
        elseif rotation == 180 then
            position.z = position.z + 1
        elseif rotation == 270 then
            position.x = position.x + 1
        else
            printError("Rotation error!\n")
            os.pullEvent("key")
        end
    end
end

local function up()
    while not refuel() do
        notEnoughFuel()
    end

    while not turtle.up() do
        digUp()
    end

    position.y = position.y + 1
end

local function down()
    while not refuel() do
        notEnoughFuel()
    end

    while not turtle.down() do
        digDown()
    end

    position.y = position.y - 1
end

local function chestSetup(dir)
    local turtleSuck = dir and turtle["suck"..dir] or turtle.suck
    local turtleDrop = dir and turtle["drop"..dir] or turtle.drop

    turtle.select(1)
    while turtleSuck() do end

    local filter = {"log", "sapling"}
    for k, v in pairs(_fuel) do
        filter[#filter+1] = {key=k, filter=function(data) return data and data.name == k end}
    end

    local items, others = getItems(unpack(filter))

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
        save(items.sapling, math.max(64, length*length))
    end

end

local function furnaceSetup(hopper)
    
    furnaceTime = furnaceTime - os.clock()
    if furnaceTime > 0 then
        printn("Waiting "..tostring(round(furnaceTime)).. " seconds for furnace to finish...")
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

    local filter = {"log", "sapling"}
    for k, v in pairs(_fuel) do
        filter[#filter+1] = {key=k, filter=function(data) return data and data.name == k end}
    end

    local items = getItems(unpack(filter))

    if not items.log then
        return false
    end

    local mostLog = getMostAbundant(items.log)
    local logs = math.min(64, mostLog.count)

    local fuelFound = false
    for k, v in pairs(items) do
        if _fuel[k] and _fuel[k].power <= 640 then
            local most = getMostAbundant(v)
            local operations = _fuel[k].power/10
            if most and logs >= operations and most.count * operations >= logs then
                local c = math.floor(logs/operations)
                drop(most, c)
                furnaceTime = c * _fuel[k].power
                logs = c * operations
                fuelFound = true
                break
            end
        end
    end

    if not fuelFound then
        local mostSapling = getMostAbundant(items.sapling)

        if mostSapling and (mostSapling.count - length*length) * 0.5 >= logs then
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
                most = getMostAbundant(items.chest)
            end
        end
        if most and most.count > 0 then
            up()
            place(most, "Down")
            chestSetup("Down")
        else
            chestSetup()
            up()
        end
    else
        chestSetup("Down")
    end
end

local function workbenchSetup()
    turnBack()

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

    turnBack()
end

local function rawPlant(sapling)
    local detect, data = turtle.inspect()
    if not detect or data.name ~= sapling[1].name or data.metadata ~= sapling[1].damage then
        while not place(sapling) do
            if detect then
                if not turtle.dig() then
                    workAreaBlocked("Forward")
                end
            elseif not turtle.attack() then
                sleep( 0.5 )
            end
        end
    end
end

local function linePlant(sapling, blocks, sideA, sideB, turnA, turnB)
    for i=1, blocks do
        if sideB then
            turnA()
            rawPlant(sapling)
            turnB()
        end
        if sideA then
            turnB()
            rawPlant(sapling)
            turnA()
        end
        back()
        rawPlant(sapling)
    end
end

local function plantRight(sapling, blocks, top, bottom)
    linePlant(sapling, blocks, top, bottom, turnLeft, turnRight)
end

local function plantLeft(sapling, blocks, top, bottom)
    linePlant(sapling, blocks, top, bottom, turnRight, turnLeft)
end

local function climbRow(sapling, top, turn)
    turn()
    rawPlant(sapling)
    back()
    rawPlant(sapling)
    if top then
        back()
        rawPlant(sapling)
    end
end

local function plant()
    stackItems()

    local sapling = getMostAbundant(getItems("sapling"))
    local blocks = length*length

    if sapling and sapling.count >= blocks then
        
        local info = checkPlantSetup(sapling)
        local name = info and info.name or sapling.fullName
        printn("Planting "..tostring(blocks).." "..name.." saplings...")

        if length == 1 then
            rawPlant(sapling)
            plantingInfo.last = os.clock()
            plantingInfo.works = plantingInfo.works + 1
            printn("Tree "..tostring(plantingInfo.works).." planted. Waiting...")
            return
        end

        forward()
        forward()
            
        if length == 2 then
            turnRight()
            rawPlant(sapling)
            turnLeft()
            back()
            rawPlant(sapling)
            turnRight()
            rawPlant(sapling)
            turnLeft()
            back()
            rawPlant(sapling)
        elseif length == 3 then
            turnRight()
            forward()
            forward()
            plantLeft(sapling, length-1, true, true)
            turnLeft()
            rawPlant(sapling)
            back()
            rawPlant(sapling)
            back()
            rawPlant(sapling)
        else
            turnLeft()
            back()

            local rows = length
            local top, bottom
            while rows > 0 do
                if rows < length then
                    climbRow(sapling, top, turnRight)
                    back()
                    turnRight()
                end

                top = rows%3 == 0 and (rows/3)%2 == 0
                plantRight(sapling, length-2, top, true)
                rows = top and rows - 3 or rows - 2
                climbRow(sapling, top, turnLeft)

                top = rows%3 == 0 and (rows/3)%2 == 1
                bottom = rows > 1
                if bottom then
                    back()
                end
                turnLeft()
                plantLeft(sapling, length-2, top, bottom)
                rows = top and rows - 3 or rows - 2
            end
            plantLeft(sapling, 1, top, bottom)

            turnLeft()
            if top then
                rawPlant(sapling)
                rows = length - 1
            else
                rows = length
            end

            for i=1, rows do
                back()
                rawPlant(sapling)
            end
        end

        plantingInfo.last = os.clock()
        plantingInfo.works = plantingInfo.works + 1
        printn("Tree "..tostring(plantingInfo.works).." planted. Waiting...")
    else
        notEnoughSaplings(blocks)
    end
end

local function lineCut(blocks, sideA, sideB, turnA, turnB)
    for i=1, blocks do        
        if sideB then
            turnB()
            dig()
            turnA()
        end
        if sideA then
            turnA()
            dig()
            turnB()
        end
        if i < blocks then
            forward()
        end
    end
end

local function cutBranch(moves)
    local startRotation = rotation
    local startPosition = vector.new(position.x, position.y, position.z)

    if filteredDetect(":log") or filteredDetect(":leaves") or filteredDetect(":vine") then
        
    end

    return moves
end

local function cutPerimeter(moves)
    for j=1, 4 do
        for i=1, length do
            if i > 1 then
                turnLeft()
                moves = cutBranch(moves)
                turnRight()
            end
            if i < length then
                forward()
                moves = moves + 1
            end
        end
        moves = cutBranch(moves)
        turnRight()
    end
    return moves
end

local function cutInside(moves, far)
    local sides = 0
    local cols = length - 2
    local rows = length - 2

    while rows > 0 do
        local top = rows > 2
        local bottom = rows > 1 and (far and position.z > 2 or not far and position.z < length-1)
        local right = far and sides % 2 == 0
        local turnA = right and turnLeft or turnRight
        local turnB = right and turnRight or turnLeft

        lineCut(cols, top, bottom, turnA, turnB)
        moves = moves + cols - 1
        rows = rows - 1
        if top then rows = rows - 1 end
        if bottom then rows = rows - 1 end
        turnA()
        if rows > 0 then
            if top then
                forward()
                moves = moves + 1
            end
            forward()
            moves = moves + 1
            if rows > 2 then
                forward()
                moves = moves + 1
            end
        end
        turnA()
        sides = sides + 1
    end

    return moves
end

local function cut()
    turtle.select(1)

    if plantingInfo.works > 0 then
        local waited = os.clock() - plantingInfo.last
        plantingInfo.waited = plantingInfo.waited + waited
        printn("Waited "..tostring(round(waited)).." seconds. Average waiting time: "..os.date("!%X", plantingInfo.waited / plantingInfo.works))
    end

    printn("Cut work in progress..")
    local cutStart = os.clock()

    forward()
    local moves = cutPerimeter(1)
    while filteredDetect("log", "Up") or filteredDetect("leaves", "Up") do
        up()
        moves = cutPerimeter(moves)
    end

    if length < 3 then
        up()
        moves = cutPerimeter(moves)
    elseif length == 3 then
        forward()
        turnRight()
        forward()
        moves = moves + 2 + position.y
        while position.y > 0 do down() end
        back()
        turnLeft()
        back()
        back()
    elseif length == 4 then
        forward()
        turnRight()
        forward()
        moves = moves + 2
        local turnA = turnLeft
        local turnB = turnRight
        local height = position.y
        while true do
            turnA()
            dig()
            turnB()
            forward()
            moves = moves + 1
            turnA()
            dig()
            turnA()
            if position.y > 0 then
                down()
                moves = moves + 1
            else
                break
            end
            turnA = turnA == turnLeft and turnRight or turnLeft
            turnB = turnB == turnRight and turnLeft or turnRight
        end
        if height % 2 == 0 then
            forward()
            forward()
            turnRight()
            back()
            back()
            moves = moves + 4
        else
            back()
            turnLeft()
            back()
            back()
            moves = moves + 3
        end
    elseif length > 4 then
        forward()
        forward()
        turnRight()
        forward()
        local height = position.y
        while position.y > 0 do
            moves = cutInside(moves, (height-position.y) % 2 == 0)
            down()
            moves = moves + 1
        end
        moves = cutInside(moves, (height-position.y) % 2 == 0)
        while position.x > 0 do
            if rotation == 90 then
                back()
            else
                forward()
            end
            moves = moves + 1
        end
        if rotation == 90 then
            turnLeft()
        else
            turnRight()
        end
        while position.z > 0 do
            back()
            moves = moves + 1
        end
    end

    cutingInfo.works = cutingInfo.works + 1
    cutingInfo.moves = cutingInfo.moves + moves
    cutingInfo.time = os.clock() - cutStart
    print("Cut work finished:")
    print("· "..tostring(moves).." moves. Average moves: "..tostring(round(cutingInfo.moves / cutingInfo.works)))
    printn("· "..tostring(round(cutingInfo.time)).." seconds. Average working time: "..os.date("!%X", cutingInfo.time / cutingInfo.works))
end

local function main()

    length = math.max(length, 1)
    waitTime = math.max(waitTime, 1)

    term.clear()
    term.setCursorPos(1, 1)
    printn(shell.getRunningProgram()..": length("..tostring(length)..") waitTime("..tostring(waitTime)..") space("..tostring(space)..")")    

    workbenchSetup()
    while true do
        for i=1, space do forward() end
        if filteredDetect(":log") or filteredDetect(":leaves") or filteredDetect(":vine") then
            cut()
            for i=1, space do back() end
            workbenchSetup()
            plant()
        elseif not filteredDetect(":sapling") then
            plant()
            for i=1, space do back() end
        else
            for i=1, space do back() end
        end
        sleep(waitTime)
    end

end

main()