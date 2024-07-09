local drawcanvas
function love.load()
end

function love.draw()
    if drawcanvas then
        local w,h = drawcanvas:getDimensions()
        local scale = math.min(1025/w, 1025/h)
        love.graphics.draw(drawcanvas, 0, 0, 0, scale, scale)
    end
end

local scmapUtils = {}

function scmapUtils.printHeightmapHeaderHexDec(scmapData)
    local heightmapHeader = scmapData:getString(262304+2, 16)
    local hexrep, decrep = '', ''
    for b in heightmapHeader:gmatch'.' do
        hexrep = hexrep..('%0.2x'):format(b:byte())..' '
        decrep = decrep..('%0.2d'):format(b:byte())..' '
    end
    print("hex", hexrep, heightmapHeader)
    print("dec", decrep, heightmapHeader)
end

function scmapUtils.getSizes(scmapData)
    return tonumber(('%0.2x%0.2x'):format(
        scmapData:getString(262306+5, 1):byte(),
        scmapData:getString(262306+4, 1):byte()
    ), 16), tonumber(('%0.2x%0.2x'):format(
        scmapData:getString(262306+5+4, 1):byte(),
        scmapData:getString(262306+4+4, 1):byte()
    ), 16)
end

function scmapUtils.getHeightmapRawString(scmapData)
    local sizeX, sizeZ = scmapUtils.getSizes(scmapData)
    return scmapData:getString(262322, (sizeX+1)*(sizeZ+1)*2)
end

function math.IBMShort(bytes)
    return tonumber(('%0.2x%0.2x'):format(bytes:sub(2,2):byte(), bytes:sub(1,1):byte()), 16)
end
function math.IBMShort2(little, big)
    return tonumber(('%0.2x%0.2x'):format(big:byte(), little:byte()), 16)
end

function scmapUtils.getHeightData(scmapData)
    local width, height = scmapUtils.getSizes(scmapData)
    local heightmapRawString = scmapUtils.getHeightmapRawString(scmapData)
    local min, max = math.huge, 0

    local heightmap = {}
    local currentRow
    local height
    local index = -1
    local yIndex = 0

    for little, big in heightmapRawString:gmatch'(.)(.)' do
        index=index+1
        if index>width then index=0 end
        if index==0 then
            currentRow = {}
            heightmap[yIndex] = currentRow
            yIndex = yIndex+1
        end
        height = math.IBMShort2(little, big)/128--TODO get conversion from map. 128 is the default and only val in Ozones editor.
        min = math.min(min, height)
        max = math.max(max, height)
        currentRow[index] = height
    end
    return heightmap, min, max
end

function scmapUtils.renderHeightmapToCanvas(canvas, heightmap, minHeight, maxHeight)
    local width, height = #heightmap[0], #heightmap
    if not canvas then canvas = love.graphics.newCanvas(width+1, height+1) end
    love.graphics.setCanvas(canvas)
    for x=0,width do
        for y=0,height do
            local normal = (heightmap[y][x]-minHeight)/(maxHeight-minHeight)
            love.graphics.setColor(normal, normal, normal)
            love.graphics.points(x+0.5,y+0.5)
        end
    end
    love.graphics.setCanvas()
    love.graphics.setColor(1,1,1)
    return canvas
end

function scmapUtils.renderBlockingToCanvas(canvas, blockmap, offset)
    local width, height = #blockmap[1], #blockmap
    if not canvas then canvas = love.graphics.newCanvas(width, height) end
    love.graphics.setCanvas(canvas)
    for x=1,width do
        for y=1,height do
            if blockmap[y][x] then
                love.graphics.setColor(1, 0, 0)
                love.graphics.points(x+(offset or 0.5),y+(offset or 0.5))
            end
        end
    end
    love.graphics.setCanvas()
    love.graphics.setColor(1,1,1)
    return canvas
end

local max, abs = math.max, math.abs
local function canPathSlope(h,x,y)
    local a,b,c,d = h[y-1][x-1],h[y][x-1],h[y][x],h[y-1][x]
    return max(abs(a-b), abs(b-c), abs(c-d), abs(d-a)) <= 0.75--NOTE 0.75 MaxSlope from footprints.lua
end

function scmapUtils.getBlockingData(heightmap)
    local width, height = #heightmap[0], #heightmap
    local blockingMap = {}
    for y=1, height do
        blockingMap[y] = {}
        for x=1, width do
            blockingMap[y][x] = not canPathSlope(heightmap,x,y)
        end
    end
    return blockingMap
end

function love.filedropped(file)
    local filedir = file:getFilename()
    local filename = filedir:match'[^\\/]*$'
    if not filename:match'.scmap$' then return print(filename, "isn't a .scmap file") end
    if not file:open'r' then return print(filename, "failed to load") end

	local data, bytesRead = file:read'data'
    local width, height = scmapUtils.getSizes(data)
    local heightmap, minHeight, maxHeight = scmapUtils.getHeightData(data)

    drawcanvas = scmapUtils.renderHeightmapToCanvas(canvas, heightmap, minHeight, maxHeight)
    scmapUtils.renderBlockingToCanvas(drawcanvas, scmapUtils.getBlockingData(heightmap))

    --love.filesystem.write(filename:match'(.*)%.scmap$'..'.raw', scmapUtils.getHeightmapRawString(data))
    love.window.setTitle("Map: "..filename.." - Render scale: x"..math.min(1025/(width+1), 1025/(height+1)))
end
