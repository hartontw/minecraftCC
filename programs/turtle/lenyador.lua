local compass = peripheral.wrap("left")

local function turn()
    turtle.dig()
    turtle.turnLeft()
    turtle.dig()
    turtle.turnLeft()
    turtle.dig()
    turtle.turnLeft()
    turtle.dig()
end

local function face(start)
    local current = compass.getFacing()
    if current == start then return end
    local poles = { north=0, east=1, south=2, west=3 }
    local is = poles[start]
    local ic = poles[current]
    local d = math.abs(is - ic)
    if d == 2 then
        turtle.turnLeft()
        turtle.turnLeft()
    else
        local tA = d == 1 and turtle.turnRight or turtle.turnLeft
        local tB = d == 1 and turtle.turnLeft or turtle.turnRight
        if is > ic then
            tA()
        else
            tB()
        end
    end
end

local function writeFacing(f)
    local file = fs.open("facing", "w")
    file.write(f)
    file.close()
end

local function up()
    while turtle.detectUp() do
        turtle.digUp()
        turtle.up()
        turn()
    end
end

local function down()
    local detect, data = turtle.inspectDown()
    while not detect or data.name ~= "minecraft:dirt" and data.name ~= "minecraft:grass_block" do
        turtle.digDown()
        turtle.down()
        detect, data = turtle.inspectDown()
    end
end

local function chopAndReplant(facing)
    up()
    down()
    face(facing)
    turtle.back()
    turtle.select(1)
    turtle.place()
end

local function initialSetup()
    if fs.exists("facing") then
        local detect, data = turtle.inspectDown()
        if detect and data.name == "minecraft:dirt" or data.name == "minecraft:grass_block" then
            turtle.turnLeft()
            if detect and data.name == "minecraft:birch_sappling" or data.name == "minecraft:birch_log" then
                turtle.turnRight()
                if not turtle.detect() then
                    turtle.select(1)
                    turtle.place()
                    return
                end
            end
        end
        local file = fs.open("facing", "r")
        local facing = file.readAll()
        file.close()
        chopAndReplant(facing)
    end
end

initialSetup()
while true do
    local start_facing = compass.getFacing()
    writeFacing(start_facing)
    if not turtle.detect() then
        turtle.select(1)
        turtle.place()
    end
    if not turtle.compare() then
        turtle.dig()
        turtle.forward()
        chopAndReplant(start_facing)
    end
    sleep(2)
    turtle.turnLeft()
end