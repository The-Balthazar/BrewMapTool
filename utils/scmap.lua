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

local function isDDS(file) return file:sub(1,5)=='DDS |' and 'dds' end
local function isTGA(file) return file:sub(-18)=='TRUEVISION-XFILE.\00' and 'tga' end
local function isPNG(file) return file:sub(1,8)=='\137PNG\13\10\26\10' and 'png' end
local function isJPG(file) return file:sub(1,2)=='\255\216' and file:sub(-2)=='\255\217' and 'jpg' end
local function isBMP(file) return file:sub(1,2)=='BM' and file:len()==math.IMBInt(file:sub(3,6)) and 'bmp' end

local function getFormat(file) return isDDS(file) or isTGA(file) or isPNG(file) or isJPG(file) or isBMP(file) or 'unknown' end

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
    local function peekBytes(n)
        assert(n>=0, 'Error: scmap peek out of sync: peekBytes fed a negative byte count')
        if n==0 then return end
        return scmapData:getString(fileOffset, n)
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
    local function intFile()
        local image = readBytes(int())
        return {image, __format = getFormat(image)}
    end

    data.floatWidth = float()
    data.floatHeight = float()

    if readBytes(6)~='\000\000\000\000\000\000' then return print"Unrecognised map file format: missing padding" end

    data.previewImage = intFile()

    data.version = int()
    if data.version~=56 and data.version~=60 then return print("Unexpected scmap type version number", data.version) end

    data.size = {int(),int()}
    data.heightmapScale = float()
    data.heightmap = readBin((data.size[1]+1)*(data.size[2]+1)*2, 'raw')
    if readBytes(1)~='\000' then return print"Unrecognised map file format: no null terminator after heightmap" end

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
    }
    data.waveGenerators = {}
    for i=1, int() do
        table.insert(data.waveGenerators, {
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

    local arbitraryFiles = int()
    if arbitraryFiles==1 and peekBytes(9):sub(-5)=='DDS |' then
        data.normalMap = intFile()
    elseif arbitraryFiles>0 then
        local index
        data.arbitrary = {}
        if peekBytes(9):sub(-5)=='INDEX' then
            index = fileformats.indexBinToLua(readBytes(int()))
            table.insert(data.arbitrary, {table.serialize(index), __filename = 'index.lua'})
            arbitraryFiles = arbitraryFiles-1
        end
        for i=1, arbitraryFiles do
            local file = intFile()
            file.__filename = index and index[i] or nil
            table.insert(data.arbitrary, file)
        end
    end

    data.textureMaskLow = intFile()
    data.textureMaskHigh = intFile()

    local utilityTextures = int()
    if utilityTextures==1 --[[and peekBytes(9):sub(-5)=='DDS |']] then
        data.waterMap = intFile()
    elseif utilityTextures>1 then
        data.utilityTextures = {}
        for i=1, utilityTextures do
            table.insert(data.utilityTextures, intFile())
        end
    end
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
    if math.IMBInt(peekBytes(4))>2900 then -- ~65k/[num values per prop, including tables]
        print("Warning: Prop count might exceed what could be read back in as a Lua table. Writing as binary blob instead.")
        data.props[1] = scmapData:getString(fileOffset)
        fileOffset = scmapData:getSize()
        data.props.__format = 'raw'
    else
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
    end

    print("Parsed", fileOffset, "of", scmapData:getSize(), "total bytes")

    return data
end

local function hex2bin(hex) return string.char(tonumber(hex, 16)) end
local function hex2bin2(a,b) return hex2bin(a)..hex2bin(b) end
local function hex2bin4(a,b,c,d) return hex2bin(a)..hex2bin(b)..hex2bin(c)..hex2bin(d) end
local function hexSplit4(val) return hex2bin4(val:sub(-8,-7),val:sub(-6,-5),val:sub(-4,-3),val:sub(-2,-1)) end
local function hexSplitFlip4(val) return hex2bin4(val:sub(-2,-1),val:sub(-4,-3),val:sub(-6,-5),val:sub(-8,-7)) end

local function rfloat(val) return hexSplit4(val) end
local function rvec2(vec) return rfloat(vec[1])..rfloat(vec[2]) end
local function rvec3(vec) return rfloat(vec[1])..rfloat(vec[2])..rfloat(vec[3]) end
local function rvec4(vec) return rfloat(vec[1])..rfloat(vec[2])..rfloat(vec[3])..rfloat(vec[4]) end
local function rstringNull(str) return (str or '')..'\000' end
local function rint(val) return math.intToIBM(val) end

local function progressReport(dir, filename, message, i, t)
    love.thread.getChannel(dir):push(-1)
    if not i then
        love.thread.getChannel(dir):push(message)
    elseif i==1 or i==t or i%10==0 then
        love.thread.getChannel(dir):push(('%s - %d of %d'):format(message, i, t))
    end
end

function scmapUtils.writeDatastream(files, filename, dir)
    local fileData = {scmapDef.header[1],scmapDef.header[2],scmapDef.header[3],scmapDef.header[2]}
    local data = files['data.lua']

    progressReport(dir, filename, "starting packing")

    local function float(val) table.insert(fileData, hexSplit4(val)) end
    local function vec2(vec)  table.insert(fileData, rvec2(vec)) end
    local function vec3(vec)  table.insert(fileData, rvec3(vec)) end
    local function vec4(vec)  table.insert(fileData, rvec4(vec)) end
    local function int(val)   table.insert(fileData, rint(val)) end
    local function intFile(file) table.insert(fileData, rint(file:len())..file) end
    local function stringNull(str) table.insert(fileData, rstringNull(str)) end

    float(data.floatWidth)
    float(data.floatHeight)

    table.insert(fileData, '\000\000\000\000\000\000')

    intFile(files.previewImage)

    int(data.version)

    int(data.size[1])
    int(data.size[2])
    float(data.heightmapScale)
    local expectedHeightmapSize = (data.size[1]+1)*(data.size[2]+1)*2
    if #files['heightmap.raw']~=expectedHeightmapSize then print("Warning: Heightmap", #files['heightmap.raw'], "bytes. expected: ", expectedHeightmapSize, "bytes") end
    progressReport(dir, filename, "Processing heightmap.raw")
    table.insert(fileData, files['heightmap.raw'])
    table.insert(fileData, '\000')

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
    table.insert(fileData, string.char(l.waterPresent and 1 or 0))
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
    local waveGenCount = #data.waveGenerators
    local waveGenStrings = {rint(waveGenCount)}
    for i, v in ipairs(data.waveGenerators) do
        progressReport(dir, filename, "Processing wave generators", i, waveGenCount)
        table.insert(waveGenStrings, table.concat{
            rstringNull(v.textureName),
            rstringNull(v.rampName),
            rvec3(v.position),
            rfloat(v.rotation),
            rvec3(v.velocity),

            rfloat(v.lifeTimeFirst),
            rfloat(v.lifeTimeSecond),
            rfloat(v.periodFirst),
            rfloat(v.periodSecond),
            rfloat(v.scaleFirst),
            rfloat(v.scaleSecond),
            rfloat(v.frameCount),
            rfloat(v.frameRateFirst),
            rfloat(v.frameRateSecond),
            rfloat(v.stripCount),
        })
    end
    table.insert(fileData, table.concat(waveGenStrings))

    progressReport(dir, filename, "Processing minimap data")
    table.insert(fileData, table.concat{
        rint(data.miniMapContourInterval),
        hexSplit4(data.miniMapDeepWaterColor),
        hexSplit4(data.miniMapContourColor),
        hexSplit4(data.miniMapShoreColor),
        hexSplit4(data.miniMapLandStartColor),
        hexSplit4(data.miniMapLandEndColor),
    })

    if data.version>56 then
        table.insert(fileData, hexSplit4(data.unknownFA))
    end

    if #data.textures~=10 then print"Warning: textures an unexpected array length: expected 10" end
    if #data.normals~=9 then print"Warning: normals an unexpected array length: expected 9" end
    progressReport(dir, filename, "Processing texture paths")
    for i, v in ipairs(data.textures) do stringNull(v.path) float(v.scale) end
    progressReport(dir, filename, "Processing normal paths")
    for i, v in ipairs(data.normals) do stringNull(v.path) float(v.scale) end

    table.insert(fileData, hexSplit4(data.unknown1))
    table.insert(fileData, hexSplit4(data.unknown2))

    progressReport(dir, filename, "Processing decals")
    local decalCount = #data.decals
    local decalsStrings = {rint(decalCount)}
    for i, decal in ipairs(data.decals) do
        progressReport(dir, filename, "Processing decals", i, decalCount)
        local decalBuffer = {
            rint(decal.id),
            rint(decal.type),
            rint(#decal.textures),
        }
        for i, path in ipairs(decal.textures) do
            table.insert(decalBuffer, rint(#path))
            table.insert(decalBuffer, path)
        end
        table.insert(decalsStrings, table.concat(decalBuffer))
        table.insert(decalsStrings, table.concat{
            rvec3(decal.scale),
            rvec3(decal.position),
            rvec3(decal.rotation),
            rfloat(decal.LODCutoff),
            rfloat(decal.LODCutoffMin),
            rint(decal.army),
        })
    end
    table.insert(fileData, table.concat(decalsStrings))

    progressReport(dir, filename, "Processing decal groups")
    local decalGroupCount = #data.decalGroups
    int(decalGroupCount)
    for i, group in ipairs(data.decalGroups) do
        progressReport(dir, filename, "Processing decal groups", i, decalGroupCount)
        int(group.id)
        stringNull(group.name)
        int(#group.data)
        for i, v in ipairs(group.data) do
            int(v)
        end
    end

    int(data.intWidth)
    int(data.intHeight)

    if files.normalMap then
        progressReport(dir, filename, "Processing normalMap")
        int(1)
        intFile(files.normalMap)
    elseif files.arbitrary then
        progressReport(dir, filename, "Processing arbitrary files")
        int(#files.arbitrary)
        for i, data in ipairs(files.arbitrary) do
            intFile(data)
        end
    else
        progressReport(dir, filename, "Doing nothing")
        int(0)
    end

    progressReport(dir, filename, "Processing textureMaskLow")
    intFile(files.textureMaskLow)
    progressReport(dir, filename, "Processing textureMaskHigh")
    intFile(files.textureMaskHigh)

    if files.waterMap then
        progressReport(dir, filename, "Processing waterMap")
        int(1)--Image array count
        intFile(files.waterMap)
    elseif files.utilityTextures then
        progressReport(dir, filename, "Processing utility textures")
        int(#files.utilityTextures)
        if files.utilityTextures[1] and files.utilityTextures[1]:sub(1,5)~='DDS |' then
            print("Warning map wont render correctly if the first utilityTexture file isn't a DDS.")
        end
        for i, data in ipairs(files.utilityTextures) do
            intFile(data)
        end
    else
        progressReport(dir, filename, "Doing nothing")
        int(0)
        print("Warning map wont render correctly with no waterMap/utilityTextures dds image.")
    end

    progressReport(dir, filename, "Processing remaining raw files")
    table.insert(fileData, files['waterFoamMask.raw'])
    table.insert(fileData, files['waterFlatness.raw'])
    table.insert(fileData, files['waterDepthBiasMask.raw'])
    table.insert(fileData, files['terrainType.raw'])

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
        table.insert(fileData, string.char(l.midColor[1]))
        table.insert(fileData, string.char(l.midColor[2]))
        table.insert(fileData, string.char(l.midColor[3]))

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
    if type(data.props)=='table' then
        local propCount = #data.props
        local propStrings = {rint(propCount)}
        for i, prop in ipairs(data.props) do
            progressReport(dir, filename, "Processing props", i, propCount)
            table.insert(propStrings, table.concat{
                rstringNull(prop.path),
                rvec3(prop.position),
                rvec3(prop.rotationX),
                rvec3(prop.rotationY),
                rvec3(prop.rotationZ),
                rvec3(prop.scale),
            })
        end
        table.insert(fileData, table.concat(propStrings))
    elseif type(data.props)=='string' then
        table.insert(fileData, data.props)
    else
        int(0)
    end
    progressReport(dir, filename, "Writing file")
    love.filesystem.createDirectory('packed')
    local done, msg = love.filesystem.write('packed/'..filename, table.concat(fileData))
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
    love.thread.getChannel(folder):push(13 + (data.normapMap and 1 or 0) + (data.arbitrary and #data.arbitrary or 0))
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
    for i, foldername in ipairs{'arbitrary', 'utilityTextures'} do
        if data[foldername] then
            love.filesystem.createDirectory(folder..foldername)
            for i, file in ipairs(data[foldername]) do
                local filename = file.__filename or ('_utilityc%d.%s'):format(i-1, file.__format)
                love.thread.getChannel(channel):push("Writing "..filename)
                love.filesystem.write(folder..foldername..'/'..filename, file[1])
                love.thread.getChannel(channel):push(-1)
            end
            data[foldername] = nil
        end
    end
    love.thread.getChannel(channel):push("Writing data.lua")

    for i, set in ipairs{'waveGenerators', 'decals', 'props'} do
        if data[set] and #data[set]>100 then
            love.filesystem.write(folder..set..'.lua', table.serialize(data[set]))
            data[set] = nil
            love.thread.getChannel(channel):push(-1)
        end
    end

    love.filesystem.write(folder..'data.lua', table.serialize(data))
    love.thread.getChannel(channel):push("Done")
    love.thread.getChannel(channel):push(-1)
    love.system.openURL(love.filesystem.getSaveDirectory()..'/'..folder)
end

return scmapUtils
