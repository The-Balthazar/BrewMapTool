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

    --[[data.floatWidth =]] float()
    --[[data.floatHeight =]] float()

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
    local waveGeneratorCount = int()
    data.waveGenerators = table.new(waveGeneratorCount, 0)
    for i=1, waveGeneratorCount do
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

    local decalCount = int()
    data.decals = table.new(decalCount, 0)
    for i=1, decalCount do
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

    --[[data.intWidth =]] int()
    --[[data.intHeight =]] int()

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

    local propCount = int()
    data.props = table.new(propCount, 0)
    for i=1, propCount do
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
local function hex2bin4(a,b,c,d) return hex2bin(a)..hex2bin(b)..hex2bin(c)..hex2bin(d) end
local function hexSplit4(val) return hex2bin4(val:sub(-8,-7),val:sub(-6,-5),val:sub(-4,-3),val:sub(-2,-1)) end
local function rvec3(vec) return math.floatToIBM(vec[1])..math.floatToIBM(vec[2])..math.floatToIBM(vec[3]) end

local function progressReport(dir, filename, message, i, t)
    love.thread.getChannel(dir):push(-1)
    if not i then
        love.thread.getChannel(dir):push(message)
    elseif i==1 or i==t or i%10==0 then
        love.thread.getChannel(dir):push(('%s - %d of %d'):format(message, i, t))
    end
end

function scmapUtils.writeDatastream(files, filename, dir)
    local fileData = {}
    local data = files['data.lua']

    progressReport(dir, filename, "starting packing")

    local function float(val) table.insert(fileData, math.floatToIBM(val)) end
    local function vec2(vec)  table.insert(fileData, math.floatToIBM(vec[1])..math.floatToIBM(vec[2])) end
    local function vec3(vec)  table.insert(fileData, math.floatToIBM(vec[1])..math.floatToIBM(vec[2])..math.floatToIBM(vec[3])) end
    local function vec4(vec)  table.insert(fileData, math.floatToIBM(vec[1])..math.floatToIBM(vec[2])..math.floatToIBM(vec[3])..math.floatToIBM(vec[4])) end
    local function int(val)   table.insert(fileData, math.intToIBM(val)) end
    local function intFile(file) table.insert(fileData, math.intToIBM(file:len())..file) end
    local function stringNull(str) table.insert(fileData, (str or '')..'\000') end

    local expectedHeightmapSize = (data.size[1]+1)*(data.size[2]+1)*2
    if #files['heightmap.raw']~=expectedHeightmapSize then print("Warning: Heightmap", #files['heightmap.raw'], "bytes. expected: ", expectedHeightmapSize, "bytes") end
    progressReport(dir, filename, "Processing heightmap.raw")
    table.insert(fileData, love.data.pack('string',
        '<c4c4c4c4 ff i6 s4 I4 I4I4 f c'..expectedHeightmapSize..'B zzz I4',
        scmapDef.header[1], scmapDef.header[2], scmapDef.header[3], scmapDef.header[2],
        data.size[1], data.size[2],
        0, --i6 Padding for alignment; I CBA faff with alignment stuff in the hopes that the rest lines up.
        files.previewImage,
        data.version,
        data.size[1], data.size[2],
        data.heightmapScale,
        files['heightmap.raw'],--can't do as a z because it can contain 0's and that will error
        0,
        data.shaderPath, data.backgroundPath, data.skyCubePath,
        #data.cubeMaps
    ))

    progressReport(dir, filename, "Processing cubemaps")
    for i, map in ipairs(data.cubeMaps) do
        table.insert(fileData, love.data.pack('string', 'zz', map.name, map.path))
    end

    progressReport(dir, filename, "Processing lighting settings")
    local l = data.lightingSettings
    table.insert(fileData, love.data.pack('string',
        '<f fff fff fff fff ffff f fff ff',
        l.lightingMultiplier,
        l.sunDirection[1], l.sunDirection[2], l.sunDirection[3],
        l.sunAmbience[1], l.sunAmbience[2], l.sunAmbience[3],
        l.sunColor[1], l.sunColor[2], l.sunColor[3],
        l.shadowFillColor[1], l.shadowFillColor[2], l.shadowFillColor[3],
        l.specularColor[1], l.specularColor[2], l.specularColor[3], l.specularColor[4],
        l.bloom,
        l.fogColor[1], l.fogColor[2], l.fogColor[3],
        l.fogStart,
        l.fogEnd
    ))

    progressReport(dir, filename, "Processing water settings")
    l = data.waterSettings
    if #l.waveTextures~=4 then print"Warning: waveTextures an unexpected array length: expected 4" end
    table.insert(fileData, love.data.pack('string',
        '<B fff fff ff fffffff fff fff ff zz ffff ffz ffz ffz ffz',
        l.waterPresent and 1 or 0,
        l.elevation, l.elevationDeep, l.elevationAbyss,
        l.surfaceColor[1], l.surfaceColor[2], l.surfaceColor[3],
        l.colorLerp[1], l.colorLerp[2],
        l.refractionScale,
        l.fresnelBias,
        l.fresnelPower,
        l.unitReflection,
        l.skyReflection,
        l.sunShininess,
        l.sunStrength,
        l.sunDirection[1], l.sunDirection[2], l.sunDirection[3],
        l.sunColor[1], l.sunColor[2], l.sunColor[3],
        l.sunReflection,
        l.sunGlow,
        l.texPathCubeMap,
        l.texPathWaterRamp,--28
        l.waveNormalRepeats[1], l.waveNormalRepeats[2], l.waveNormalRepeats[3], l.waveNormalRepeats[4],
        l.waveTextures[1].movement[1], l.waveTextures[1].movement[2], l.waveTextures[1].path,
        l.waveTextures[2].movement[1], l.waveTextures[2].movement[2], l.waveTextures[2].path,
        l.waveTextures[3].movement[1], l.waveTextures[3].movement[2], l.waveTextures[3].path,
        l.waveTextures[4].movement[1], l.waveTextures[4].movement[2], l.waveTextures[4].path
    ))

    progressReport(dir, filename, "Processing wave generators")
    local waveGenCount = #data.waveGenerators
    local waveGenStrings = {math.intToIBM(waveGenCount)}
    for i, v in ipairs(data.waveGenerators) do
        progressReport(dir, filename, "Processing wave generators", i, waveGenCount)
        table.insert(waveGenStrings, love.data.pack('string',
            'zz<fff f fff ff ff ff fff f',
            (v.textureName or ''),
            (v.rampName or ''),
            v.position[1], v.position[2], v.position[3],
            v.rotation,
            v.velocity[1], v.velocity[2], v.velocity[3],
            v.lifeTimeFirst, v.lifeTimeSecond,
            v.periodFirst, v.periodSecond,
            v.scaleFirst, v.scaleSecond,
            v.frameCount, v.frameRateFirst, v.frameRateSecond,
            v.stripCount
        ))
    end
    table.insert(fileData, table.concat(waveGenStrings))

    progressReport(dir, filename, "Processing minimap data")
    table.insert(fileData, table.concat{
        math.intToIBM(data.miniMapContourInterval),
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
    local decalsStrings = {math.intToIBM(decalCount)}
    for i, decal in ipairs(data.decals) do
        progressReport(dir, filename, "Processing decals", i, decalCount)
        local decalBuffer = {
            love.data.pack('string', '<i4i4i4', --These are probably unsigned, but also probably never big enough to matter
                decal.id,
                decal.type,
                #decal.textures
            )
        }
        for i, path in ipairs(decal.textures) do
            table.insert(decalBuffer, love.data.pack('string', '<s4', path))
        end
        table.insert(decalBuffer, love.data.pack('string', '<fff fff fff ff i4',
            decal.scale[1], decal.scale[2], decal.scale[3],
            decal.position[1], decal.position[2], decal.position[3],
            decal.rotation[1], decal.rotation[2], decal.rotation[3],
            decal.LODCutoff,
            decal.LODCutoffMin,
            decal.army
        ))
        table.insert(decalsStrings, table.concat(decalBuffer))
    end
    table.insert(fileData, table.concat(decalsStrings))

    progressReport(dir, filename, "Processing decal groups")
    local decalGroupCount = #data.decalGroups
    int(decalGroupCount)
    for i, group in ipairs(data.decalGroups) do
        progressReport(dir, filename, "Processing decal groups", i, decalGroupCount)
        table.insert(fileData, love.data.pack('string', '<i4 z I4', group.id, group.name, #group.data))
        for i, v in ipairs(group.data) do
            int(v)
        end
    end

    --These values seem unused, but are either meant to be the pixel size of the normal, or the number of o-grids it's supposed to cover.
    --I'm assuming it's o-grids, not because it means I don't have to check the DDS header, but *because* I could check the DDS header
    --Unless they planned to support other formats, it'd just be duplicated data. So I'm assuming it's grits it's to cover.
    local normalSize = {0,0}
    if files.normalMap and fileformats.isDDS(files.normalMap) then
        normalSize = data.size
    elseif files.arbitrary and #files.arbitrary==4 and fileformats.isDDS(files.arbitrary[1]) then
        normalSize[1] = data.size[1]*0.5
        normalSize[2] = data.size[2]*0.5
    end

    progressReport(dir, filename, files.normalMap and "Processing normalMap" or files.arbitrary and "Processing arbitrary files" or "Doing nothing")
    table.insert(fileData, love.data.pack('string',
        '<I4I4 I4', normalSize[1], normalSize[2],
        files.normalMap and 1 or files.arbitrary and #files.arbitrary or 0
    ))

    if files.normalMap then
        intFile(files.normalMap)
    elseif files.arbitrary then
        for i, data in ipairs(files.arbitrary) do
            intFile(data)
        end
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
    local halfSize = data.size[1]*data.size[1]*0.25

    for i, filename in ipairs{'waterFoamMask.raw', 'waterFlatness.raw', 'waterDepthBiasMask.raw'} do
        if #files[filename]~=halfSize then print("Warning: ", filename, #files[filename], "bytes. expected: ", halfSize, "bytes") end
        table.insert(fileData, files[filename])
    end

    if #files['terrainType.raw']~=data.size[1]*data.size[1] then print("Warning: terrainType.raw", #files['terrainType.raw'], "bytes. expected: ", data.size[1]*data.size[1], "bytes") end
    table.insert(fileData, files['terrainType.raw'])

    progressReport(dir, filename, "Processing skyBox")
    if data.version>=60 then
        l = data.skyBox

        table.insert(fileData, love.data.pack('string',
            '<fff fff i4i4 f fff fff f zz I4',
            l.position[1], l.position[2], l.position[3],
            l.horizonHeight, l.scale, l.subHeight,
            l.subDivAx, l.subDivHeight,
            l.zenithHeight,
            l.horizonColor[1], l.horizonColor[2], l.horizonColor[3],
            l.zenithColor[1], l.zenithColor[2], l.zenithColor[3],
            l.decalGlowMultiplier,
            l.albedo, l.glow,
            l.planets and #l.planets or 0
        ))
        for i, planet in ipairs(l.planets) do
            table.insert(fileData, love.data.pack('string',
                '<fff f ff ffff',
                planet.position[1], planet.position[2], planet.position[3],
                planet.rotation,
                planet.scale[1], planet.scale[2],
                planet.uv[1], planet.uv[2], planet.uv[3], planet.uv[4]
            ))
        end

        table.insert(fileData, love.data.pack('string',
            'BBB <f fff z I4',
            l.midColor[1], l.midColor[2], l.midColor[3],
            l.cirrusMultiplier,
            l.cirrusColor[1], l.cirrusColor[2], l.cirrusColor[3],
            l.cirrusTexture,
            l.cirrusLayers and #l.cirrusLayers or 0
        ))
        for i, layer in ipairs(l.cirrusLayers) do
            table.insert(fileData, love.data.pack('string',
                '<ff f ff',
                layer.frequency[1], layer.frequency[2],
                layer.speed,
                layer.direction[1], layer.direction[2]
            ))
        end

        float(l.clouds7)
    end

    progressReport(dir, filename, "Processing props")
    if type(data.props)=='table' then
        local propCount = #data.props
        local propStrings = {math.intToIBM(propCount)}
        for i, prop in ipairs(data.props) do
            progressReport(dir, filename, "Processing props", i, propCount)
            table.insert(propStrings, love.data.pack('string', 'z<fff fff fff fff fff',
                (prop.path or ''),
                prop.position[1], prop.position[2], prop.position[3],
                prop.rotationX[1], prop.rotationX[2], prop.rotationX[3],
                prop.rotationY[1], prop.rotationY[2], prop.rotationY[3],
                prop.rotationZ[1], prop.rotationZ[2], prop.rotationZ[3],
                prop.scale[1], prop.scale[2], prop.scale[3]
            ))
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

function scmapUtils.exportScmapData(data, folder)
    local channel = folder
    love.thread.getChannel(folder):push(4)
    if folder then love.filesystem.createDirectory(folder) end
    folder = (folder and folder..'/' or '')
    for k, v in pairs(data) do
        if type(v)=='table' and v.__format then
            love.thread.getChannel(channel):push("Writing "..k)
            love.filesystem.write(folder..k..'.'..v.__format, v[1])
            data[k] = nil
        end
    end
    love.thread.getChannel(channel):push(-1)

    for i, foldername in ipairs{'arbitrary', 'utilityTextures'} do
        if data[foldername] then
            love.filesystem.createDirectory(folder..foldername)
            for i, file in ipairs(data[foldername]) do
                local filename = file.__filename or ('_utilityc%d.%s'):format(i-1, file.__format)
                love.thread.getChannel(channel):push("Writing "..filename)
                love.filesystem.write(folder..foldername..'/'..filename, file[1])
            end
            data[foldername] = nil
        end
    end
    love.thread.getChannel(channel):push(-1)

    love.thread.getChannel(channel):push("Writing data.lua")
    -- actual hard limits per file are 21845, 10922, and 10922: 65536 tables per file.
    -- these numbers end up giving around 500kb per file.
    for set, limit in pairs{waveGenerators=750, decals=920, props=870} do
        local count = data[set] and #data[set] or 0
        if count>100 and count<=limit then
            love.filesystem.write(folder..set..'.lua', table.serialize(data[set]))
            data[set] = nil
        elseif count>limit then
            for k=1, math.ceil(count/limit) do
                local subset = table.new(limit, 0)
                for i=1,limit do
                    table.insert(subset, data[set][(k-1)*limit+i])
                end
                love.filesystem.write(folder..set..k..'.lua', table.serialize(subset))
            end
            data[set] = nil
        end
    end

    love.thread.getChannel(channel):push(-1)
    love.filesystem.write(folder..'data.lua', table.serialize(data))

    love.thread.getChannel(channel):push("Done")
    love.thread.getChannel(channel):push(-1)
    love.system.openURL(love.filesystem.getSaveDirectory()..'/'..folder)
end

return scmapUtils
