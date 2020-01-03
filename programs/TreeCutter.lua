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

local corners = {left=0, right=length-1, bottom=1+space, top=length+space}
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
_sapling[0] = {name="Oak", stack=64, config={{length=1, space=0}}}
_sapling[1] = {name="Spruce", stack=64, config={{length=1, space=0}, {length=2, space=1}}}
_sapling[2] = {name="Birch", stack=64, config={{length=1, space=0}}}
_sapling[3] = {name="Jungle", stack=64, config={{length=1, space=0}, {length=2, space=1}}}
_sapling[4] = {name="Acacia", stack=64, config={{length=1, space=0}}}
_sapling[5] = {name="Dark Oak", stack=64, config={{length=2, space=0}}}

local function round(n)
    return math.floor(n+0.5)
end

local function checkPlantSetup(data)
    local info = nil
    if data and data[1].name == "minecraft:sapling" then
        info = _sapling[data[1].damage]
        if info then
            local index = 0
            for i, v in ipairs(info.config) do
                if v.length == length then
                    index = i
                    break
                end
            end
            if index == 0 then
                printn(tostring(length).."x"..tostring(length).." is not an appropiate setup for "..info.name.." tree.")
            elseif info.config[index].space > space then
                printn(info.name.." sapling with "..tostring(length).."x"..tostring(length).." setup, needs at least "..tostring(info.config[index].space).." empty blocks around.")
            end
        end
    end
    return info
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

local function detectTreePart(dir)
    local turtleInspect = dir and turtle["inspect"..dir] or turtle.inspect
    local detect, data = turtleInspect()
    return detect and (string.find(data.name, ":log") or string.find(data.name, ":leaves"))
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
                        items[fn] = { fullname = fn, count = 0 }
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

local function addBoneMeal()
    local boneFilter = function(data) return data and data.name == "minecraft:dye" and data.damage == 15 end
    local boneMeal = getMostAbundant(getItems(boneFilter))
    while not detectTreePart() and place(boneMeal) do end
end

local function turnLeft()
    if turtle.turnLeft() then
        rotation = (rotation - 90) % 360
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

local function lookAt(face)
    if rotation ~= face then
        if (rotation+90)%360 == face then
            turnRight()
        elseif (rotation-90)%360 == face then
            turnLeft()
        else
            turnBack()
        end
    end
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
        printError("("..tostring(rotation)..") Rotation error!\n")
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
            printError("("..tostring(rotation)..") Rotation error!\n")
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

local function goTo(pos)
    local height = position.y < pos.y and up or down
    for i=1, math.abs(pos.y-position.y) do
        height()
    end

    if pos.x == position.x and pos.z == position.z then
        return
    end

    --pos: 3, 5
    --position: 4, 4

    local horizontal = pos.x < position.x and 270 or 90
    local vertical = pos.z < position.z and 180 or 0
    local order, facing

    if math.abs(horizontal-rotation) < math.abs(vertical-rotation) then
        order = {math.abs(pos.x-position.x), math.abs(pos.z-position.z)}
        facing = horizontal
    else
        order = {math.abs(pos.z-position.z), math.abs(pos.x-position.x)}
        facing = vertical
    end

    lookAt(facing)

    facing = rotation == vertical and horizontal or vertical

    for i=1, order[1] do
        forward()
    end

    if (rotation+90)%360 == facing then
        turnRight()
    else
        turnLeft()
    end

    for i=1, order[2] do
        forward()
    end
end

local function forwardSuck()
    forward()
    turtle.suck()
    if position.y > 0 then
        turtle.suckDown()
    end
end

local function backSuck()
    back()
    turtle.suck()
    if position.y > 0 then
        turtle.suckDown()
    end
end

local function upSuck()
    up()
    turtle.suck()
end

local function downSuck()
    down()
    turtle.suck()
    if position.y > 0 then
        turtle.suckDown()
    end
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
    filter[#filter+1] = {key="boneMeal", filter=function(data) return data and data.name == "minecraft:dye" and data.damage == 15 end}

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
    if not filteredDetect("minecraft:chest", "Down") then
        down()
        local most = getMostAbundant(items.chest)
        while not filteredDetect("chest") do
            dig()
            if not most or not place(most) then
                workbenchError("chest")
                items.chest = getItems("chest")
                most = getMostAbundant(items.chest)
            end
        end
        if most and most.count > 0 and most.fullName == "minecraft:chest_0" then
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
        backSuck()
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
    backSuck()
    rawPlant(sapling)
    if top then
        backSuck()
        rawPlant(sapling)
    end
end

local function plant()
    stackItems()

    local sapling = getMostAbundant(getItems("sapling"))
    local blocks = length*length
    
    if not sapling or sapling.count < blocks then
        workbenchSetup()
        sapling = getMostAbundant(getItems("sapling"))
        while not sapling or sapling.count < blocks do
            notEnoughSaplings(blocks)
        end
    end
        
    local info = checkPlantSetup(sapling)
    local name = info and info.name or sapling.fullName
    printn("Planting "..tostring(blocks).." "..name.." saplings...")

    if length == 1 then
        rawPlant(sapling)
    elseif length == 2 then
        while not refuel(4) do
            notEnoughFuel()
        end
        forwardSuck()
        forwardSuck()
        turnRight()
        rawPlant(sapling)
        turnLeft()
        backSuck()
        rawPlant(sapling)
        turnRight()
        rawPlant(sapling)
        turnLeft()
        backSuck()
        rawPlant(sapling)
    elseif length == 3 then
        while not refuel(8) do
            notEnoughFuel()
        end
        forwardSuck()
        forwardSuck()
        turnRight()
        forwardSuck()
        forwardSuck()
        plantLeft(sapling, 2, true, true)
        turnLeft()
        rawPlant(sapling)
        backSuck()
        rawPlant(sapling)
        backSuck()
        rawPlant(sapling)
    else
        local groups = math.ceil(length/3)
        local pases = groups + (groups%2 ~= 2 and 1 or 0)
        local moves = pases * length + length - (length%2 ~= 0 and 1 or 0) + 2
        while not refuel(moves) do
            notEnoughFuel()
        end

        forwardSuck()
        forwardSuck()
        turnLeft()
        backSuck()

        local rows = length
        local top, bottom
        while rows > 0 do
            if rows < length then
                climbRow(sapling, top, turnRight)
                backSuck()
                turnRight()
            end

            top = rows%3 == 0 and (rows/3)%2 == 0
            plantRight(sapling, length-2, top, true)
            rows = top and rows - 3 or rows - 2
            climbRow(sapling, top, turnLeft)

            top = rows%3 == 0 and (rows/3)%2 == 1
            bottom = rows > 1
            if bottom then
                backSuck()
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
            backSuck()
            rawPlant(sapling)
        end
    end

    plantingInfo.last = os.clock()
    plantingInfo.works = plantingInfo.works + 1
    printn("Tree "..tostring(plantingInfo.works).." planted. Waiting...")
end

local function digTreePart(dir)
    if detectTreePart(dir) then
        dig()
        return true
    end
    return false
end

local function expand(shape, dir)
    dir = dir or rotation
    if dir == 0 then
        shape.top = shape.top + 1
    elseif dir == 90 then
        shape.right = shape.right + 1
    elseif dir == 180 then
        shape.bottom = shape.bottom - 1
    elseif dir == 270 then
        shape.left = shape.left - 1
    end
    print("Left: "..tostring(shape.left)..", Right: "..tostring(shape.right)..", Bottom: "..tostring(shape.bottom)..", Top: "..tostring(shape.top))
end

local function contract(shape, dir)
    print("contract")
    dir = dir or rotation
    if dir == 0 then
        shape.top = math.max(shape.top - 1, corners.top + 1)
    elseif dir == 90 then
        shape.right = math.max(shape.right - 1, corners.right + 1)
    elseif dir == 180 then
        shape.bottom = math.min(shape.bottom + 1, corners.bottom - 1)
    elseif dir == 270 then
        shape.left = math.min(shape.left + 1, corners.left - 1)
    end
end

local function printPosition()
    print("X: "..position.x..", Y: "..position.y..", Z: "..position.z)
end

local function cutPerimeter(shape)
    print("cutPerimeter")
    local start = vector.new(0, position.y, 0)
    start.x = math.abs(shape.left-position.x) < math.abs(shape.right-position.x) and shape.left or shape.right
    start.z = math.abs(shape.bottom-position.z) < math.abs(shape.top-position.z) and shape.bottom or shape.top
    
    local moves, facing = math.abs(start.x-position.x) + math.abs(start.z-position.z)
    goTo(start)

    if position.x == shape.left then
        facing = position.z == shape.bottom and 270 or 0
    else
        facing = position.z == shape.bottom and 180 or 90
    end
    lookAt(facing)

    for i=1, 4 do
        digTreePart()
        turnRight()
        local size = rotation%180==0 and shape.top-shape.bottom or shape.right-shape.left
        for j=1, size do
            forward()
            turnLeft()
            digTreePart()
            turnRight()
        end
        moves = moves + size
    end

    return moves
end

local function cutContent(shape)
    print("cutContent")
    local moves = 0

    local rows, cols, facing, reverse

    local start = vector.new(0, position.y, 0)
    start.x = math.abs(shape.left-position.x) < math.abs(shape.right-position.x) and shape.left or shape.right
    start.z = math.abs(shape.bottom-position.z) < math.abs(shape.top-position.z) and shape.bottom or shape.top

    if shape.right-shape.left > shape.top-shape.bottom then
        reverse = (start.x == shape.right and start.z == shape.bottom) or (start.x == shape.left and start.z == shape.top)
        facing = start.x == shape.left and 90 or 270
        cols = shape.right-shape.left+1
        rows = shape.top-shape.bottom+1
        if math.floor(rows/3) > 0 or rows%3 == 2 then
            start.z = start.z == shape.bottom and start.z + 1 or start.z - 1
        end
    else
        reverse = (start.x == shape.right and start.z == shape.top) or (start.x == shape.left and start.z == shape.bottom)
        facing = start.z == shape.bottom and 0 or 180
        cols = shape.top-shape.bottom+1
        rows = shape.right-shape.left+1
        if math.floor(rows/3) > 0 or rows%3 == 2 then
            start.x = start.x == shape.left and start.x + 1 or start.x - 1
        end
    end

    moves = moves + math.abs(start.x-position.x) + math.abs(start.z-position.z)

    goTo(start)
    lookAt(facing)

    local fwd = function ()
        forward()
        moves = moves + 1
    end

    local three = math.floor(rows/3)
    rows = rows%3

    local turnUp, turnDown

    for i=1, three do
        turnUp = reverse and turnRight or turnLeft
        turnDown = reverse and turnLeft or turnRight
        
        for j=1, cols-1 do
            if i == 1 or j > 1 then
                turnDown()
                dig()
                turnUp()
                turnUp()
                dig()
                turnDown()
            end
            fwd()
        end

        turnDown()
        dig()
        turnUp()
        turnUp()

        if i < three then
            fwd()
            fwd()
            fwd()
            dig()
            turnUp()
        elseif rows > 0 then
            fwd()
            fwd()
            if rows > 1 then
                fwd()
            end
            turnUp()
        else
            dig()
            turnDown()
        end

        reverse = not reverse
    end

    if rows > 0 then
        turnUp = reverse and turnRight or turnLeft
        turnDown = reverse and turnLeft or turnRight

        for i=1, cols do
            if rows > 1 and (three == 0 or i > 1) then
                turnDown()
                dig()
                turnUp()
            end
            if i < cols then
                fwd()
            end
        end
    end

    return moves
end

local function cutBranch()
    local moves = 0

    local pos = 0
    local startRotation = rotation
    local startPosition = vector.new(position.x, position.y, position.z)
    local shape = {left=0, right=0, top=0, bottom=0}

    local fwd = function ()
        forward()
        moves = moves + 1
        local p = position:sub(startPosition)
        if p.x < shape.left or p.x > shape.right or p.z < shape.bottom or p.z > shape.top then
            expand(shape)
        end
        if rotation == startRotation then
            pos = pos + 1
        elseif rotation == (startRotation+180)%360 then
            pos = pos - 1
            return pos > 1
        end
        return true
    end

    local left = function ()
        if rotation == (startRotation-90)%360 then
            if startRotation == 0 then
                return position.x <= startPosition.x
            elseif startRotation == 90 then
                return position.z >= startPosition.z
            elseif startRotation == 180 then
                return position.x >= startPosition.x
            elseif startRotation == 270 then
                return position.z <= startPosition.z
            end
        end
        return false
    end

    local cbr = function ()
        while detectTreePart() and not left() do
            turnLeft()
        end

        if not fwd() then
            return false
        end

        turnRight()
        return true
    end

    while cbr() do end

    shape.left = shape.left + 1 + startPosition.x
    shape.right = shape.right - 1 + startPosition.x
    shape.bottom = shape.bottom + 1 + startPosition.z
    shape.top = shape.top - 1 + startPosition.z
    moves = moves + cutContent(shape)

    moves = moves + math.abs(startPosition.x-position.x) + math.abs(startPosition.z-position.z)
    goTo(startPosition)
    lookAt(startRotation)

    return moves
end

local function cutFast()
    forward()
    local moves = 1

    if length < 3 then
        while detectTreePart("Up") do
            digTreePart()
            up()
        end
        digTreePart()

        local height = position.y

        if length == 2 then
            turnRight()
            forward()
            turnLeft()
        end

        while position.y > 0 do
            digTreePart()
            down()
        end

        if length == 2 then
            turnLeft()
            forward()
            turnRight()
        end

        back()
        moves = height * 2 + 1 + (length == 2 and 2 or 0)
    else
        while detectTreePart("Up") do
            moves = moves + cutContent(corners) + 1
            up()
        end
        moves = moves + cutContent(corners)

        moves = moves + math.abs(position.x) + position.y + math.abs(position.z)

        goTo(vector.new(0,0,0))
        lookAt(0)
    end

    return moves
end

local function cutAverage()
    forward()
    local moves = 1

    if length == 1 then
        local digAll = function()
            digTreePart()
            turnLeft()
            digTreePart()
            turnLeft()
            digTreePart()
            turnLeft()
            digTreePart()
            turnLeft()
        end

        digAll()
        while detectTreePart("Up") do
            up()
            digAll()
            moves = moves + 1
        end

        moves = moves + position.y
        while position.y > 0 do down() end

        back()
        moves = moves + 1
    else
        moves = moves + cutPerimeter(corners)
        while detectTreePart("Up") do
            up()
            moves = moves + cutPerimeter(corners) + 1
        end

        if length == 2 then
            moves = moves + position.y + 1
            while position.y > 0 do down() end
            back()
        elseif length == 3 then
            forward()
            turnRight()
            moves = moves + 1 + position.y
            digTreePart()
            while position.y > 0 do
                down()
                digTreePart()
            end
            turnLeft()
            back()
            back()
            moves = moves + 2
        else
            moves = moves + position.y
            while position.y > 0 do
                moves = moves + cutContent(corners)
                down()
            end
            moves = moves + cutContent(corners)
    
            moves = moves + math.abs(position.x) + math.abs(position.z)

            goTo(vector.new(0,0,0))
            lookAt(0)
        end
    end

    return moves
end

local function cutIntensive()
    local moves = 0
    local shape = {left=corners.left-1, right=corners.right+1, top=corners.top+1, bottom=corners.bottom-1}
    local size = function() return rotation%180 == 0 and shape.top-shape.bottom or shape.right-shape.left end

    turnLeft()
    forward()

    while true do
        
        local goUp = false

        for i=1, 4 do
            if detectTreePart() then
                moves = moves + cutBranch()
            end

            turnRight()

            for j=1, size() do
                forward()
                moves = moves + 1

                if i==1 and j==1 then
                    turnRight()
                    goUp = detectTreePart()
                    turnLeft()
                end

                turnLeft()
                if detectTreePart() then
                    moves = moves + cutBranch()
                end
                turnRight()
            end
        end

        if goUp then
            up()
        else
            break
        end
    end

    moves = moves + position.y * 2
    while position.y > 0 do
        moves = moves + cutContent(corners)
        down()
    end
    moves = moves + cutContent(corners)

    moves = moves + math.abs(position.x) + math.abs(position.z)

    goTo(vector.new(0, 0, 0))
    lookAt(0)

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

    local sapling = getMostAbundant(getItems("sapling"))

    local moves = 0

    if not sapling or sapling.count < length*length then
        moves = cutIntensive()
    elseif sapling.count < _sapling[sapling[1].damage].stack then
        moves = cutAverage()
    else
        moves = cutFast()
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

    while true do
        for i=1, space do forward() end

        if filteredDetect(":sapling") then
            addBoneMeal()
        end
        
        if detectTreePart() then
            cut()
            for i=1, space do back() end
        elseif not filteredDetect(":sapling") then
            plant()
            if detectTreePart() then
                cut()
                for i=1, space do back() end
            else
                for i=1, space do back() end
                workbenchSetup()
                sleep(waitTime)
            end
        else
            for i=1, space do back() end
            sleep(waitTime)
        end
    end

end

main()