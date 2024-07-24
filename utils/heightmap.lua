heightmapUtils = {}

--takes hightmap raw string, sizes+1
--Outputs z-x array grid, and the min and max
function heightmapUtils.read(heightmapRaw, width, height, heightmapScale)
    local min, max = math.huge, 0

    local heightmap = table.new(height, 1)
    local currentRow
    local height
    local index = -1
    local yIndex = 0

    for short in heightmapRaw:gmatch'(..)' do
        index=index+1
        if index>width then index=0 end
        if index==0 then
            currentRow = table.new(width, 1)
            heightmap[yIndex] = currentRow
            yIndex = yIndex+1
        end
        height = math.IBMShort(short)*(heightmapScale or 0.0078125)
        min = math.min(min, height)
        max = math.max(max, height)
        currentRow[index] = height
    end
    return table.transpose(heightmap), min, max
end

function heightmapUtils.renderToCanvas(canvas, heightmap, minHeight, maxHeight)
    local width, height = #heightmap, #heightmap[0]
    if not canvas then canvas = love.graphics.newCanvas(width+1, height+1) end
    love.graphics.setCanvas(canvas)
    for x=0,width do
        for y=0,height do
            local normal = (heightmap[x][y]-minHeight)/(maxHeight-minHeight)
            love.graphics.setColor(normal, normal, normal)
            love.graphics.points(x+0.5,y+0.5)
        end
    end
    love.graphics.setCanvas()
    love.graphics.setColor(1,1,1)
    return canvas
end

local max, abs = math.max, math.abs
local function canPathSlope(h,x,y)
    local a,b,c,d = h[x-1][y-1],h[x][y-1],h[x][y],h[x-1][y]
    return max(abs(a-b), abs(b-c), abs(c-d), abs(d-a)) <= 0.75--NOTE 0.75 MaxSlope from footprints.lua
end

function heightmapUtils.getBlockingData(heightmap)
    local width, height = #heightmap, #heightmap[0]
    local blockingMap = table.new(width, 0)
    for x=1, width do
        blockingMap[x] = table.new(height, 0)
        for y=1, height do
            blockingMap[x][y] = not canPathSlope(heightmap,x,y)
        end
    end
    return blockingMap
end

function heightmapUtils.renderOverlayToCanvas(canvas, datamap, colour, blend)
    local width, height = #datamap[1], #datamap
    if not canvas then canvas = love.graphics.newCanvas(width, height) end
    love.graphics.setCanvas(canvas)
    love.graphics.setBlendMode(blend, 'premultiplied')
    local r,g,b,a=unpack(colour)
    for x=0,width do
        for y=0,height do
            if datamap[x] and datamap[x][y] then
                love.graphics.setColor(r,g,b,a or tonumber(datamap[x][y]) or 1)
                love.graphics.points(x+0.5,y+0.5)
            end
        end
    end
    love.graphics.setCanvas()
    love.graphics.setBlendMode('alpha')
    love.graphics.setColor(1,1,1)
    return canvas
end

local abyssDepth = 25
function heightmapUtils.getWaterData(heightmap, waterlevel)
    local width, height = #heightmap, #heightmap[0]
    local waterMap = table.new(width, 1)
    local abyssMap = table.new(width, 1)
    for x=0, width do
        waterMap[x] = table.new(height, 1)
        abyssMap[x] = table.new(height, 1)
        for y=0, height do
            waterMap[x][y] = heightmap[x][y]<waterlevel
            abyssMap[x][y] = waterMap[x][y] and heightmap[x][y]<waterlevel-abyssDepth
        end
    end
    return waterMap, abyssMap
end
