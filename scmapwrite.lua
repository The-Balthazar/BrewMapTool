require'utils.maths'
require'utils.table'
require'utils.scmap'
require'love.system'

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
    for i, filename in ipairs(arbitrary) do
        table.insert(arbitraryFiles, love.filesystem.read(dir..'arbitrary/'..filename))
    end
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
