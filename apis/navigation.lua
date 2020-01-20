


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

        if os.clock() - s > yieldTime then
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