require'utils.maths'
require'utils.table'
require'utils.scmap'
require'love.system'
require'utils.fileformats'

local channel = love.thread.getChannel'scmapwrite'
local dir = channel:demand()

local components = {
    ["data.lua"] = true,
    ["heightmap.raw"] = true,
    previewImage = true,
    ["terrainType.raw"] = true,
    textureMaskHigh = true,
    textureMaskLow = true,
    ["waterDepthBiasMask.raw"] = true,
    ["waterFlatness.raw"] = true,
    ["waterFoamMask.raw"] = true,
    waterMap = true,
}
local optional = {
    normalMap = true,
}
local splitData = {
    ["waveGenerators.lua"] = true,
    props = true,
    ["decals.lua"] = true,
}
local count = 0
for i, v in ipairs(love.filesystem.getDirectoryItems(dir)) do
    for i, group in ipairs{components, splitData, optional} do
        local key = group[v] and v or v:match'^([^.]*)'
        if group[key] then
            if v:sub(-4)=='.lua' then
                group[key] = love.filesystem.load(dir..v)()
            else
                group[key] = love.filesystem.read(dir..v)
            end
            if group == components then
                count = count+1
            end
        end
    end
end
if count~=10 then
    return print("Folder contains", count, "of the 10 expected files. Expected:", [[

        data.lua
        heightmap.raw
        previewImage.dds
        terrainType.raw
        textureMaskHigh.dds
        textureMaskLow.dds
        waterDepthBiasMask.raw
        waterFlatness.raw
        waterFoamMask.raw
        waterMap.dds
    ]])
end
for k, d in pairs(optional) do
    if type(d)~='boolean' then
        components[k]=d
    end
end
for k, d in pairs(splitData) do
    if type(d)~='boolean' then
        components['data.lua'][k:match'^([^.]*)'] = d
    end
end
local arbitrary = love.filesystem.getDirectoryItems(dir..'arbitrary/')
if arbitrary and arbitrary[1] then
    table.sort(arbitrary)
    local arbitraryFiles = {}

    local index = table.find(arbitrary, 'index.lua')
    local newIndex = {}
    if index and table.remove(arbitrary, index) then
        index = love.filesystem.load(dir..'arbitrary/index.lua')()
        if index and index[1] then
            for i, filename in ipairs(index) do
                local found = table.find(arbitrary, filename)
                if found and table.remove(arbitrary, found) then
                    local file = love.filesystem.read(dir..'arbitrary/'..filename)
                    table.insert(arbitraryFiles, file )
                    table.insert(newIndex, filename)
                else
                    print(filename, "from index not found in arbitrary file directory. Excluding from index.")
                end
            end
        end
    else
        print("No index found in arbitrary file directory. Generating one.")
    end
    for i, filename in ipairs(arbitrary) do
        local file = love.filesystem.read(dir..'arbitrary/'..filename)
        table.insert(arbitraryFiles, file)
        table.insert(newIndex, filename)
        print("Appending", filename, "to index.")
    end
    table.insert(arbitraryFiles, 1, fileformats.indexLuaToBin(newIndex))
    components.arbitrary = arbitraryFiles
end

local data = components['data.lua']
data.waveGenerators = data.waveGenerators or data.waveGenerators.waterSettings--NOTE: Legacy
local progressTotal = (type(data.waveGenerators)=='table' and #data.waveGenerators or 0)
                    + (type(data.decals)        =='table' and #data.decals or 0)
                    + (type(data.decalGroups)   =='table' and #data.decalGroups or 0)
                    + (type(data.props)         =='table' and #data.props or 0)
                    + 20

local filename = dir:match'folderMount/(.*)/'
love.thread.getChannel(dir):push(progressTotal)
scmapUtils.writeDatastream(components, filename, dir)
