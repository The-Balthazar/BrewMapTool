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
