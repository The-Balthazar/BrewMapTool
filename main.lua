function love.load()
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

function math.IBM16BinToDec(bytes)
    return tonumber(('%0.2x%0.2x'):format(bytes:sub(2,2):byte(), bytes:sub(1,1):byte()), 16)
end
function math.IBM16BinToDec2(little, big)
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
        height = math.IBM16BinToDec2(little, big)/128--TODO get conversion from map. 128 is the default and only val in Ozones editor.
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

function love.filedropped(file)
    local filedir = file:getFilename()
    local filename = filedir:match'[^\\/]*$'
    if not filename:match'.scmap$' then return print(filename, "isn't a .scmap file") end
    if not file:open'r' then return print(filename, "failed to load") end

	local data, bytesRead = file:read'data'
    local width, height = scmapUtils.getSizes(data)
    local heightmapRaw = scmapUtils.getHeightmapRawString(data)

    love.filesystem.write(filename:match'([^\\/]*)%.scmap$'..'.raw', heightmapRaw)
end
