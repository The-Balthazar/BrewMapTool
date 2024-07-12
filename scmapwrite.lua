require'utils.maths'
require'utils.table'
require'utils.scmap'
require'love.system'

local channel = love.thread.getChannel'scmapwrite'
local dir = channel:demand()

local components = {
    ["data.lua"] = true,
    ["heightmap.raw"] = true,
    normalMap = true,
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
    ["waveGenerators.lua"] = true,
    ["props.lua"] = true,
    ["decals.lua"] = true,
}
local count = 0
for i, v in ipairs(love.filesystem.getDirectoryItems(dir)) do
    local key = components[v] and v or v:match'^([^.]*)'
    if components[key] then
        if v:sub(-4)=='.lua' then
            components[key] = love.filesystem.load(dir..v)()
        else
            components[key] = love.filesystem.read(dir..v)
        end
        count = count+1
    end
    if optional[v] then
        optional[v] = love.filesystem.load(dir..v)()
    end
end
for k, d in pairs(optional) do
    if type(d)=='table' then
        components['data.lua'][k:match'^([^.]*)'] = d
    end
end
if count==11 then
    local data = components['data.lua']
    data.waveGenerators = data.waveGenerators or data.waveGenerators.waterSettings--NOTE: Legacy
    local progressTotal = #data.waveGenerators
                        + #data.decals
                        + #data.decalGroups
                        + #data.props
                        + 20

    local filename = dir:match'folderMount/(.*)/'
    love.thread.getChannel(dir):push(progressTotal)
    scmapUtils.writeDatastream(components, filename, dir)
else
    return print("Folder contains", count, "of the 11 expected files. Expected:", [[

        data.lua
        heightmap.raw
        normalMap.dds
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
