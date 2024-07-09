require'utils.maths'
require'utils.scmap'

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
end
