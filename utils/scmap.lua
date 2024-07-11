scmapUtils = {}

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

    local function readBin(n, format)
        return {readBytes(n), __format = format}
    end

    local function int() return math.IMBInt(readBytes(4)) end
    local function float() return math.IMBFloat(readBytes(4)) end
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
        return readBin(bytes, 'dds')
    end

    data.floatWidth = float()
    data.floatHeight = float()

    if readBytes(6)~='\000\000\000\000\000\000' then return print"Unrecognised map file format" end

    data.previewImage = dds()

    data.version = int()
    if data.version~=56 and data.version~=60 then return print("Unexpected scmap type version number", data.version) end

    data.size = {int(),int()}
    data.heightmapScale = float()
    data.heightmap = readBin((data.size[1]+1)*(data.size[2]+1)*2, 'raw')
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
    data.miniMapDeepWaterColor = math.formatBytes(readBytes(4))
    data.miniMapContourColor = math.formatBytes(readBytes(4))
    data.miniMapShoreColor = math.formatBytes(readBytes(4))
    data.miniMapLandStartColor = math.formatBytes(readBytes(4))
    data.miniMapLandEndColor = math.formatBytes(readBytes(4))

    if data.version>56 then
        data.unknownFA = math.formatBytes(readBytes(4))
    end

    data.textures = {}
    data.normals = {}
    for i=1, 10 do table.insert(data.textures, {path = stringNull(), scale = float()}) end
    for i=1, 9  do table.insert(data.normals,  {path = stringNull(), scale = float()}) end

    data.unknown1 = math.formatBytes(readBytes(4))
    data.unknown2 = math.formatBytes(readBytes(4))

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
            table.insert(group.data, int())
        end
        table.insert(data.decalGroups, group)
    end

    data.intWidth = int()
    data.intHeight = int()

    if int()~=1 then return print"Unrecognised map file format" end

    data.normalMap = dds()
    data.textureMaskLow = dds()
    data.textureMaskHigh = dds()

    if int()~=1 then return print"Unrecognised map file format" end

    data.waterMap = dds()
    local halfSize = data.size[1]/2*data.size[2]/2
    data.waterFoamMask = readBin(halfSize, 'raw')
    data.waterFlatness = readBin(halfSize, 'raw')
    data.waterDepthBiasMask = readBin(halfSize, 'raw')

    data.terrainType = readBin(data.size[1]*data.size[2], 'raw')

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

local function hex2bin(hex) return string.char(tonumber(hex, 16)) end
local function hex2bin2(a,b) return hex2bin(a)..hex2bin(b) end
local function hex2bin4(a,b,c,d) return hex2bin(a)..hex2bin(b)..hex2bin(c)..hex2bin(d) end
local function hexSplit4(val) return hex2bin4(val:sub(-8,-7),val:sub(-6,-5),val:sub(-4,-3),val:sub(-2,-1)) end
local function hexSplitFlip4(val) return hex2bin4(val:sub(-2,-1),val:sub(-4,-3),val:sub(-6,-5),val:sub(-8,-7)) end

local function progressReport(dir, filename, message, i, t)
    love.thread.getChannel(dir):push(-1)
    if not i then
        love.thread.getChannel(dir):push(message)
    elseif i==1 or i==t or i%10==0 then
        love.thread.getChannel(dir):push(('%s - %d of %d'):format(message, i, t))
    end
end

function scmapUtils.writeDatastream(files, filename, dir)
    local fileData = scmapDef.header[1]..scmapDef.header[2]..scmapDef.header[3]..scmapDef.header[2]
    local data = files['data.lua']

    progressReport(dir, filename, "starting packing")

    local function float(val) fileData = fileData..hexSplit4(val) end
    local function vec2(vec) float(vec[1]) float(vec[2]) end
    local function vec3(vec) float(vec[1]) float(vec[2]) float(vec[3]) end
    local function vec4(vec) float(vec[1]) float(vec[2]) float(vec[3]) float(vec[4]) end
    local function int(val)
        if type(val)=='string' then
            fileData = fileData..hexSplit4(val)
        elseif val==-1 then
            fileData = fileData..'\255\255\255\255'
        elseif type(val)=='number' then
            fileData = fileData..hexSplitFlip4(('%0.8x'):format(val))
        end
    end
    local function image(img)
        int(img:len())
        fileData = fileData..img
    end
    local function stringNull(str) fileData = fileData..(str or '')..'\000' end

    float(data.floatWidth)
    float(data.floatHeight)

    fileData = fileData..'\000\000\000\000\000\000'

    if files['previewImage.dds']:len()~=262272 then print"Warning preview image isn't the expected 262272 bytes" end
    image(files['previewImage.dds'])

    int(data.version)

    int(data.size[1])
    int(data.size[2])
    float(data.heightmapScale)
    local expectedHeightmapSize = (data.size[1]+1)*(data.size[2]+1)*2
    if #files['heightmap.raw']~=expectedHeightmapSize then print("Warning: Heightmap", #files['heightmap.raw'], "bytes. expected: ", expectedHeightmapSize, "bytes") end
    progressReport(dir, filename, "Processing heightmap.raw")
    fileData = fileData..files['heightmap.raw']..'\000'

    stringNull(data.shaderPath)
    stringNull(data.backgroundPath)
    stringNull(data.skyCubePath)

    progressReport(dir, filename, "Processing cubemaps")
    int(#data.cubeMaps)
    for i, map in ipairs(data.cubeMaps) do
        stringNull(map.name)
        stringNull(map.path)
    end

    progressReport(dir, filename, "Processing lighting settings")
    local l = data.lightingSettings
    float(l.lightingMultiplier)
    vec3(l.sunDirection)
    vec3(l.sunAmbience)
    vec3(l.sunColor)
    vec3(l.shadowFillColor)
    vec4(l.specularColor)
    float(l.bloom)
    vec3(l.fogColor)
    float(l.fogStart)
    float(l.fogEnd)

    progressReport(dir, filename, "Processing water settings")
    l = data.waterSettings
    fileData = fileData..string.char(l.waterPresent and 1 or 0)
    float(l.elevation)
    float(l.elevationDeep)
    float(l.elevationAbyss)
    vec3(l.surfaceColor)
    vec2(l.colorLerp)
    float(l.refractionScale)
    float(l.fresnelBias)
    float(l.fresnelPower)
    float(l.unitReflection)
    float(l.skyReflection)
    float(l.sunShininess)
    float(l.sunStrength)
    vec3(l.sunDirection)
    vec3(l.sunColor)
    float(l.sunReflection)
    float(l.sunGlow)
    stringNull(l.texPathCubeMap)
    stringNull(l.texPathWaterRamp)
    vec4(l.waveNormalRepeats)
    if #l.waveTextures~=4 then print"Warning: waveTextures an unexpected array length: expected 4" end
    for i, v in ipairs(l.waveTextures) do
        vec2(v.movement)
        stringNull(v.path)
    end

    progressReport(dir, filename, "Processing wave generators")
    local waveGenCount = #l.waveGenerators
    int(waveGenCount)
    for i, v in ipairs(l.waveGenerators) do
        stringNull(v.textureName)
        stringNull(v.rampName)
        vec3(v.position)
        float(v.rotation)
        vec3(v.velocity)

        float(v.lifeTimeFirst)
        float(v.lifeTimeSecond)
        float(v.periodFirst)
        float(v.periodSecond)
        float(v.scaleFirst)
        float(v.scaleSecond)
        float(v.frameCount)
        float(v.frameRateFirst)
        float(v.frameRateSecond)
        float(v.stripCount)
        progressReport(dir, filename, "Processing wave generators", i, waveGenCount)
    end

    progressReport(dir, filename, "Processing minimap data")
    int(data.miniMapContourInterval)
    fileData = fileData..hexSplit4(data.miniMapDeepWaterColor)
    fileData = fileData..hexSplit4(data.miniMapContourColor)
    fileData = fileData..hexSplit4(data.miniMapShoreColor)
    fileData = fileData..hexSplit4(data.miniMapLandStartColor)
    fileData = fileData..hexSplit4(data.miniMapLandEndColor)

    if data.version>56 then
        fileData = fileData..hexSplit4(data.unknownFA)
    end

    if #data.textures~=10 then print"Warning: textures an unexpected array length: expected 10" end
    if #data.normals~=9 then print"Warning: normals an unexpected array length: expected 9" end
    progressReport(dir, filename, "Processing texture paths")
    for i, v in ipairs(data.textures) do stringNull(v.path) float(v.scale) end
    progressReport(dir, filename, "Processing normal paths")
    for i, v in ipairs(data.normals) do stringNull(v.path) float(v.scale) end

    fileData = fileData..hexSplit4(data.unknown1)
    fileData = fileData..hexSplit4(data.unknown2)

    progressReport(dir, filename, "Processing decals")
    local decalCount = #data.decals
    int(decalCount)
    for i, decal in ipairs(data.decals) do
        int(decal.id)
        int(decal.type)
        int(#decal.textures)
        for i, path in ipairs(decal.textures) do
            int(#path)
            fileData = fileData..path
        end
        vec3(decal.scale)
        vec3(decal.position)
        vec3(decal.rotation)
        float(decal.LODCutoff)
        float(decal.LODCutoffMin)
        int(decal.army)
        progressReport(dir, filename, "Processing decals", i, decalCount)
    end

    progressReport(dir, filename, "Processing decal groups")
    local decalGroupCount = #data.decalGroups
    int(decalGroupCount)
    for i, group in ipairs(data.decalGroups) do
        int(group.id)
        stringNull(group.name)
        int(#group.data)
        for i, v in ipairs(group.data) do
            int(v)
        end
        progressReport(dir, filename, "Processing decal groups", i, decalGroupCount)
    end

    int(data.intWidth)
    int(data.intHeight)

    int(1)

    progressReport(dir, filename, "Processing normalMap.dds")
    image(files['normalMap.dds'])
    progressReport(dir, filename, "Processing textureMaskLow.dds")
    image(files['textureMaskLow.dds'])
    progressReport(dir, filename, "Processing textureMaskHigh.dds")
    image(files['textureMaskHigh.dds'])

    int(1)

    progressReport(dir, filename, "Processing waterMap.dds")
    image(files['waterMap.dds'])

    progressReport(dir, filename, "Processing remaining raw files")
    fileData = fileData
        ..files['waterFoamMask.raw']
        ..files['waterFlatness.raw']
        ..files['waterDepthBiasMask.raw']
        ..files['terrainType.raw']

    progressReport(dir, filename, "Processing skyBox")
    if data.version>=60 then
        l = data.skyBox
        vec3(l.position)
        float(l.horizonHeight)
        float(l.scale)
        float(l.subHeight)
        int(l.subDivAx)
        int(l.subDivHeight)
        float(l.zenithHeight)
        vec3(l.horizonColor)
        vec3(l.zenithColor)
        float(l.decalGlowMultiplier)

        stringNull(l.albedo)
        stringNull(l.glow)

        int(#l.planets)
        for i, planet in ipairs(l.planets) do
            vec3(planet.position)
            float(planet.rotation)
            vec2(planet.scale)
            vec4(planet.uv)
        end
        fileData = fileData
            ..string.char(l.midColor[1])
            ..string.char(l.midColor[2])
            ..string.char(l.midColor[3])

        float(l.cirrusMultiplier)
        vec3(l.cirrusColor)
        stringNull(l.cirrusTexture)

        int(#l.cirrusLayers)
        for i, layer in ipairs(l.cirrusLayers) do
            vec2(layer.frequency)
            float(layer.speed)
            vec2(layer.direction)
        end

        float(l.clouds7)
    end

    progressReport(dir, filename, "Processing props")
    local propCount = #data.props
    int(propCount)
    for i, prop in ipairs(data.props) do
        stringNull(prop.path)
        vec3(prop.position)
        vec3(prop.rotationX)
        vec3(prop.rotationY)
        vec3(prop.rotationZ)
        vec3(prop.scale)
        progressReport(dir, filename, "Processing props", i, propCount)
    end
    progressReport(dir, filename, "Writing file")
    love.filesystem.createDirectory('packed')
    local done, msg = love.filesystem.write('packed/'..filename, fileData)
    progressReport(dir, filename, done and "Write complete" or msg)
    love.system.openURL(love.filesystem.getSaveDirectory()..'/packed')
end

function scmapUtils.readHeightmap(heightmapRaw, width, height, heightmapScale)
    local min, max = math.huge, 0

    local heightmap = {}
    local currentRow
    local height
    local index = -1
    local yIndex = 0

    for little, big in heightmapRaw:gmatch'(.)(.)' do--Look brothers, TITS!
        index=index+1
        if index>width then index=0 end
        if index==0 then
            currentRow = {}
            heightmap[yIndex] = currentRow
            yIndex = yIndex+1
        end
        height = math.IBMShort2(little, big)/(heightmapScale and (1/heightmapScale) or 128)
        min = math.min(min, height)
        max = math.max(max, height)
        currentRow[index] = height
    end
    return heightmap, min, max
end

function scmapUtils.exportScmapData(data, folder)
    local channel = folder
    love.thread.getChannel(folder):push(11)
    if folder then love.filesystem.createDirectory(folder) end
    folder = (folder and folder..'/' or '')
    for k, v in pairs(data) do
        if type(v)=='table' and v.__format then
            love.thread.getChannel(channel):push("Writing "..k)
            love.filesystem.write(folder..k..'.'..v.__format, v[1])
            data[k] = nil
            love.thread.getChannel(channel):push(-1)
        end
    end
    love.thread.getChannel(channel):push("Writing data.lua")
    love.filesystem.write(folder..'data.lua', table.serialize(data))
    love.thread.getChannel(channel):push("Done")
    love.thread.getChannel(channel):push(-1)
    love.system.openURL(love.filesystem.getSaveDirectory()..'/'..folder)
end

--NOTE lazy functions that assume a lot and don't parse the whole file

--NOTE assumes that the embedded preview image is a fixed size. Use scmapUtils.readDatastream(scmapData).size[1] and [2] instead.
function scmapUtils.getSizes(scmapData)
    return math.IBMShort(scmapData:getString(262306+4, 2)),
           math.IBMShort(scmapData:getString(262306+4+4, 2))
end

--NOTE assumes that the embedded preview image is a fixed size. Use scmapUtils.readDatastream(scmapData).heightmap[1] instead.
function scmapUtils.getHeightmapRaw(scmapData)
    local sizeX, sizeZ = scmapUtils.getSizes(scmapData)
    return scmapData:getString(262322, (sizeX+1)*(sizeZ+1)*2)
end

--NOTE assumes that the embedded preview image is a fixed size, and that heightmapScale is default.
function scmapUtils.getHeightData(scmapData)
    return scmapUtils.readHeightmap(scmapUtils.getHeightmapRaw(scmapData), scmapUtils.getSizes(scmapData))
end

return scmapUtils
