local tArgs = {...}

local position, rotation
local blocks, whitelist = {}

local blockFile = "blocks.txt"

local function addBlock(pos)
    if not blocks[pos.x] then blocks[pos.x] = {} end
    if not blocks[pos.x][pos.y] then blocks[pos.x][pos.y] = {} end
    blocks[pos.x][pos.y][pos.z] = true
end
 
local function loadBlocks()
    if fs.exists(blockFile) then
        local h = fs.open(blockFile , "r")
        local line = h.readLine()
        while line do          
            local c = {}
            for i in string.gmatch(line, "%S+") do
                c[#c+1] = i
            end
            addBlock(vector.new(c[1],c[2],c[3]))
            line = h.readLine()
        end
        h.close()
    end
end
 
local function saveBlocks()
    local h = fs.open(blockFile , "w")
    for i, x in pairs(blocks) do
        for j, y in pairs(x) do
            for k, z in pairs(y) do
                h.writeLine(i.." "..j.." "..k)
            end
        end
    end
    h.close()
end

local function getPosition(timeOut)
    local x, y, z = gps.locate(timeOut or 1)
    return x and vector.new(x, y, z) or nil
end

local function isWhitelisted(data)
    return data and whitelist and whitelist[data.fullName] ~= nil
end

local function distance(a, b)
    return math.abs(a.x-b.x) + math.abs(a.y-b.y) + math.abs(a.z-b.z)
end

local function available(nodes, position)
    return not nodes[position.x] or not nodes[position.x][position.y] or not nodes[position.x][position.y][position.z]
end

local function validBlock(position)
    return available(blocks, position) or isWhitelisted(blocks[position.x][position.y][position.z])
end

local function addToNodes(nodes, node)
    if not nodes[node.x] then
        nodes[node.x] = {}
    end
    if not nodes[node.x][node.y] then
        nodes[node.x][node.y] = {}
    end
    nodes[node.x][node.y][node.z] = node
end

local function createNode(parent, position, destination)
    local node = {}
    node.x = position.x
    node.y = position.y
    node.z = position.z
    node.position = function() return vector.new(node.x, node.y, node.z) end
    node.parent = parent
    node.g = parent and parent.g + 1 or 0
    node.h = distance(destination, node.position())
    node.f = function() return node.g + node.h end
    node.open = true
    return node
end

local function getLower(openList)
    local l = #openList
    local lower = openList[l]

    for i=#openList-1, 1, -1 do
        local node = openList[i]
        local nf = node.f()
        local lf = lower.f()
        if nf < lf or nf == lf and node.h < lower.h then
            lower = node
            l = i
        end
    end

    if lower then
        lower.open = false
        table.remove(openList, l)
    end

    return lower
end

local function generateAdjacent(nodes, openList, parent, destination)
    local check = function(x, y, z)
        local position = vector.new(x, y, z)
        if validBlock(position) then
            if available(nodes, position) then
                local node = createNode(parent, position, destination)
                addToNodes(nodes, node)
                openList[#openList+1] = node
            elseif nodes[x][y][z].open and nodes[x][y][z].g > parent.g + 1 then
                nodes[x][y][z].g = parent.g + 1
                nodes[x][y][z].parent = parent
            end
        end
    end
    check(parent.x-1, parent.y, parent.z)
    check(parent.x+1, parent.y, parent.z)
    check(parent.x, parent.y-1, parent.z)
    check(parent.x, parent.y+1, parent.z)
    check(parent.x, parent.y, parent.z-1)
    check(parent.x, parent.y, parent.z+1)
end

local function findPath(start, destination, maxNodes)
    if not available(blocks, destination) then
        print("Destination is occupied")
        return nil
    end

    print("Searching path...")

    local parent = createNode(nil, start, destination)
    local nodes, openList = {}, {}

    addToNodes(nodes, parent)
    parent.open = false

    local s = os.clock()
    while parent.x ~= destination.x or parent.y ~= destination.y or parent.z ~= destination.z do
        generateAdjacent(nodes, openList, parent, destination)
        if maxNodes and #openList > maxNodes then
            print("Max nodes limit reached")
            return nil
        end

        parent = getLower(openList)
        if not parent then
            print("Destination is not reacheable")
            return nil
        end

        if os.clock() - s > 1 then
            sleep(0)
            s = os.clock()
        end
    end

    local reversePath = {}
    while parent do
        reversePath[#reversePath+1] = parent
        parent = parent.parent
    end

    local path = {}
    for i=#reversePath, 1, -1 do
        path[#path+1] = reversePath[i]
    end

    print("Path found. "..#path.." movements.")

    return path
end

local function forward()
    local block = turtle.detect() or not turtle.forward()
    local pos = vector.new(position.x, position.y, position.z)

    if rotation == 0 then
        pos.z = pos.z - 1
    elseif rotation == 90 then
        pos.x = pos.x + 1
    elseif rotation == 180 then
        pos.z = pos.z + 1
    elseif rotation == 270 then
        pos.x = pos.x - 1
    end

    if block then
        addBlock(pos)
        return false
    end

    position = pos
    return true
end

local function up()
    local block = turtle.detectUp() or not turtle.up()
    local pos = vector.new(position.x, position.y+1, position.z)

    if block then
        addBlock(pos)
        return false
    end

    position = pos
    return true
end

local function down()
    local block = turtle.detectDown() or not turtle.down()
    local pos = vector.new(position.x, position.y-1, position.z)

    if block then
        addBlock(pos)
        return false
    end

    position = pos
    return true
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
    else
        return turnRight() and turnRight()
    end
end

local function lookAt(destination)
    if rotation ~= destination then
        if (rotation+90)%360 == destination then
            return turnRight()
        elseif (rotation-90)%360 == destination then
            return turnLeft()
        else
            return turnBack()
        end
    end
    return true
end

local function getTransform(timeOut)
    local rot = 0
    local pos = getPosition(timeOut)
    if not pos then
        return
    end

    local t = 0
    while turtle.detect() do
        turtle.turnLeft()
        t = t + 1
        if t > 3 then
            return
        end
    end

    turtle.forward()
    local moved = getPosition(timeOut)
    turtle.back()

    if moved.x > pos.x then
        rot = 90
    elseif moved.z > pos.z then
        rot = 180
    elseif moved.x < pos.x then
        rot = 270
    end

    return pos, rot
end

local function goTo(destination)
   local x = destination.x-position.x
   local y = destination.y-position.y
   local z = destination.z-position.z

    if x ~= 0 then
        if x > 0 then
            lookAt(90)
        else
            lookAt(270)
        end
        if not forward() then return false end
    elseif y ~= 0 then
        if y > 0 then
            if not up() then return false end
        else
            if not down() then return false end
        end
    elseif z ~= 0 then
        if z > 0 then
            lookAt(180)
        else
            lookAt(0)
        end
        if not forward() then return false end
    end

    return true
end

local function goToDestination()
    position, rotation = getTransform(5)
    if not position then
        print("GPS FAIL")
        return
    end

    local destination = vector.new(tonumber(tArgs[1]), tonumber(tArgs[2]), tonumber(tArgs[3]))
    local maxNodes = tonumber(tArgs[4])

    print("----------------------------")
    print("Start ("..position.x..", "..position.y..", "..position.z..")")
    print("Destination ("..destination.x..", "..destination.y..", "..destination.z..")")
    print("----------------------------")

    while distance(position, destination) > 0 do
        local path = findPath(position, destination, maxNodes)
        if not path then
            print("Not posible path")
            return
        end
        for i=2 , #path do
            if not goTo(path[i].position()) then
                break
            end
        end
        saveBlocks()
        sleep(0)
    end
    print("Destination reached!")
end

loadBlocks()
goToDestination()