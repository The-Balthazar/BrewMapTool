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
function math.IMBInt(bytes)
    local num = tonumber(('%0.2x%0.2x%0.2x%0.2x'):format(
        bytes:sub(4,4):byte(),
        bytes:sub(3,3):byte(),
        bytes:sub(2,2):byte(),
        bytes:sub(1,1):byte()
    ), 16)
    if num==4294967295 then return -1 end
    if num>2147483647 then
        --TODO negative int unconverted.
        return bytes
    end
    return num
end
function math.IMBIntUnsigned(bytes)
    return tonumber(('%0.2x%0.2x%0.2x%0.2x'):format(
        bytes:sub(4,4):byte(),
        bytes:sub(3,3):byte(),
        bytes:sub(2,2):byte(),
        bytes:sub(1,1):byte()
    ), 16)
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

local scmapDef = {
    header = {
        'Map\026',
        '\002\000\000\000',
        '\237\254\239\190',--little endian decimal of the big hex BEEF FEED
    },
}

function scmapUtils.validateHeader(scmapData)
    return  scmapData:getString(0,  4)==scmapDef.header[1]
        and scmapData:getString(4,  4)==scmapDef.header[2]
        and scmapData:getString(8,  4)==scmapDef.header[3]
        and scmapData:getString(12, 4)==scmapDef.header[2]
end

function scmapUtils.readDatastream(scmapData)
    if not scmapUtils.validateHeader(scmapData) then return print"Unrecognised map header" end
    local data = {}
    local fileOffset = 16

    local function readBytes(n)
        assert(n>=0, 'Error: scmap read out of sync: readBytes fed a negative byte count')
        if n==0 then return '' end
        fileOffset = fileOffset+n
        return scmapData:getString(fileOffset-n, n)
    end

    local function int() return math.IMBInt(readBytes(4)) end
    local function float() return (readBytes(4)) end
    local function short() return math.IBMShort(readBytes(2)) end
    local function vec2() return {float(),float()} end
    local function vec3() return {float(),float(),float()} end
    local function vec4() return {float(),float(),float(),float()} end
    local function stringNull()
        local str = ''
        local byte = readBytes(1)
        while byte and byte~='\000' do
            str=str..byte
            byte = readBytes(1)
        end
        return str
    end
    local function dds()
        local bytes = int()
        return readBytes(bytes)
    end

    data.width1 = float() --NOTE I have no idea what these are the width and height of
    data.height1 = float()

    if readBytes(6)~='\000\000\000\000\000\000' then return print"Unrecognised map file format" end

    data.previewImage = dds()--love.filesystem.write('preview.dds', data.previewImage)

    data.version = int()
    if data.version~=56 and data.version~=60 then return print("Unexpected scmap type version number", data.version) end

    data.size = {int(),int()}
    data.heightmapScale = float()
    data.heightmap = readBytes((data.size[1]+1)*(data.size[2]+1)*2)--love.filesystem.write('heightmap.raw', data.heightmap)
    if readBytes(1)~='\000' then return print"Unrecognised map file format" end

    data.shaderPath = stringNull()
    data.backgroundPath = stringNull()
    data.skyCubePath = stringNull()

    data.cubeMaps = {}
    for i=1, int() do
        table.insert(data.cubeMaps, {name = stringNull(), path = stringNull()})
    end

    data.lightingSettings = {
        lightingMultiplier = float(),
        sunDirection = vec3(),
        sunAmbience = vec3(),
        sunColor = vec3(),
        shadowFillColor = vec3(),
        specularColor = vec4(),
        bloom = float(),
        fogColor = vec3(),
        fogStart = float(),
        fogEnd = float(),
    }

    data.waterSettings = {
        waterPresent = readBytes(1):byte()==1,
        elevation = float(),
        elevationDeep = float(),
        elevationAbyss = float(),
        surfaceColor = vec3(),
        colorLerp = vec2(),
        refractionScale = float(),
        fresnelBias = float(),
        fresnelPower = float(),
        unitReflection = float(),
        skyReflection = float(),
        sunShininess = float(),
        sunStrength = float(),
        sunDirection = vec3(),
        sunColor = vec3(),
        sunReflection = float(),
        sunGlow = float(),
        texPathCubeMap = stringNull(),
        texPathWaterRamp = stringNull(),
        waveNormalRepeats = vec4(),
        waveTextures = {
            {movement = vec2(), path = stringNull()},
            {movement = vec2(), path = stringNull()},
            {movement = vec2(), path = stringNull()},
            {movement = vec2(), path = stringNull()},
        },
        waveGenerators = {},
    }
    for i=1, int() do
        table.insert(data.waterSettings.waveGenerators, {
            textureName = stringNull(),
            rampName = stringNull(),
            position = vec3(),
            rotation = float(),
            velocity = vec3(),

            lifeTimeFirst = float(),
            lifeTimeSecond = float(),
            periodFirst = float(),
            periodSecond = float(),
            scaleFirst = float(),
            scaleSecond = float(),
            frameCount = float(),
            frameRateFirst = float(),
            frameRateSecond = float(),
            stripCount = float(),
        })
    end

    data.miniMapContourInterval = int()
    data.miniMapDeepWaterColor = int()
    data.miniMapContourColor = int()
    data.miniMapShoreColor = int()
    data.miniMapLandStartColor = int()
    data.miniMapLandEndColor = int()

    if data.version>56 then
        data.unknownFA = readBytes(4)
    end

    data.textures = {}
    data.normals = {}
    for i=1, 10 do table.insert(data.textures, {path = stringNull(), scale = float()}) end
    for i=1, 9  do table.insert(data.normals,  {path = stringNull(), scale = float()}) end

    data.unknown1 = readBytes(4)
    data.unknown2 = readBytes(4)

    data.decals = {}
    for i=1, int() do
        local decal = {
            id = int(),
            type = int(),
            textures = {},
        }
        for i=1, int() do
            table.insert(decal.textures, readBytes(int()))
        end
        decal.scale = vec3()
        decal.position = vec3()
        decal.rotation = vec3()
        decal.LODCutoff = float()
        decal.LODCutoffMin = float()
        decal.army = int()
        table.insert(data.decals, decal)
    end

    data.decalGroups = {}
    for i=1, int() do
        local group = {
            id = int(),
            name = stringNull(),
            data = {},
        }
        for i=1, int() do
            table.insert(data.group, int())
        end
        table.insert(data.decalGroups, group)
    end

    data.width2 = int()
    data.height2 = int()

    if int()~=1 then return print"Unrecognised map file format" end

    data.normalMap = dds()
    data.textureMaskLow = dds()
    data.textureMaskHigh = dds()

    if int()~=1 then return print"Unrecognised map file format" end

    data.waterMap = dds()
    local halfSize = data.size[1]/2*data.size[2]/2
    data.waterFoamMask = readBytes(halfSize)
    data.waterFlatness = readBytes(halfSize)
    data.waterDepthBiasMask = readBytes(halfSize)

    data.terrainType = readBytes(data.size[1]*data.size[2])

    if data.version>=60 then
        data.skyBox = {
            position = vec3(),
            horizonHeight = float(),
            scale = float(),
            subHeight = float(),
            subDivAx = int(),
            subDivHeight = int(),
            zenithHeight = float(),
            horizonColor = vec3(),
            zenithColor = vec3(),
            decalGlowMultiplier = float(),

            albedo = stringNull(),
            glow = stringNull(),

            planets = {},
        }
        for i=1, int() do
            table.insert(data.skyBox.planets, {
                position = vec3(),
                rotation = float(),
                scale = vec2(),
                uv = vec4(),
            })
        end
        data.skyBox.midColor = {readBytes(1):byte(), readBytes(1):byte(), readBytes(1):byte()}
        data.skyBox.cirrusMultiplier = float()
        data.skyBox.cirrusColor = vec3()
        data.skyBox.cirrusTexture = stringNull()
        data.skyBox.cirrusLayers = {}
        for i=1, int() do
            table.insert(data.skyBox.cirrusLayers, {
                frequency = vec2(),
                speed = float(),
                direction = vec2(),
            })
        end
        data.skyBox.clouds7 = float()
    end

    data.props = {}
    for i=1, int() do
        table.insert(data.props, {
            path = stringNull(),
            position = vec3(),
            rotationX = vec3(),
            rotationY = vec3(),
            rotationZ = vec3(),
            scale = vec3(),
        })
    end

    print("Parsed", fileOffset, "of", scmapData:getSize(), "total bytes")

    return data
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
