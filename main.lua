require'utils.maths'
require'utils.table'
require'utils.scmap'

local drawcanvas
function love.load()
end

local progressChannels = {}
local workingFileNames = {}

function love.threaderror(thread, errorstr)
    print("Thread error:", errorstr)
end

function love.draw()
    if drawcanvas then
        local w,h = drawcanvas:getDimensions()
        local scale = math.min(1025/w, 1025/h)
        love.graphics.draw(drawcanvas, 0, 0, 0, scale, scale)
    end
    for i, data in ipairs(progressChannels) do
        local yPos = 512+(i-1)*40
        love.graphics.setColor(0,0,0)
        local title = data.name..(data.msg and ' - '..data.msg or '')
        for x=-1, 1 do
            for y=-1, 1 do
                love.graphics.print(title, 5+x, yPos+y)
            end
        end
        love.graphics.setColor(0.2,0.2,0.2)
        love.graphics.rectangle("fill", 1, yPos+20, 1023, 20, 5, 5, 5)
        if data.progress and data.total then
            local progressNormal = data.progress/data.total
            love.graphics.setColor(0.2,0.9,0.2)
            love.graphics.rectangle("fill", 1+2.5, yPos+22.5, 1018*progressNormal, 20-5, 2.5, 2.5, 2.5)
            love.graphics.setColor(0.3,0.8,0.3)
            love.graphics.rectangle("line", 1+2.5, yPos+22.5, 1018*progressNormal, 20-5, 2.5, 2.5, 2.5)
        end
        love.graphics.setColor(0,0,0)
        love.graphics.rectangle("line", 1, yPos+20, 1023, 20, 5, 5, 5)
        love.graphics.setColor(1,1,1)
        love.graphics.print(title, 5, yPos)
    end
end

function love.update(delta)
    for i, data in ipairs(progressChannels) do
        while not data.done and data.channel and data.channel:peek() do
            local val = data.channel:pop()
            if type(val)=='string' then
                data.msg = val
            elseif val>0 then
                data.total = val
            else
                data.progress = (data.progress or 0)-val
            end
        end
    end
    for i=#progressChannels, 1, -1 do
        local data = progressChannels[i]
        if data.total and data.progress and data.progress>=data.total and not data.done then
            data.done = true
            --table.remove(progressChannels, i)
            workingFileNames[data.id] = nil
        end
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

local formats = {
    scmap = function(filename, file)
        local data = scmapUtils.readDatastream(file:read'data')

        if workingFileNames[filename] then
            print(filename, "Already under way")
        else
            workingFileNames[filename] = true
            love.thread.getChannel'scmapunpack':push(data)
            love.thread.getChannel'scmapunpack':push(filename)
            love.thread.newThread[[
                require'utils.maths'
                require'utils.table'
                require'utils.scmap'
                require'love.system'

                local channel = love.thread.getChannel'scmapunpack'
                scmapUtils.exportScmapData(channel:demand(), channel:demand())
            ]]:start()
            table.insert(progressChannels, {channel=love.thread.getChannel(filename), name=filename, id=filename})
        end

        local heightmap, minHeight, maxHeight = scmapUtils.readHeightmap(data.heightmap[1], data.size[1], data.size[2], heightmapScale)--data.heightmapScale is currently an unparsed float.
        drawcanvas = scmapUtils.renderHeightmapToCanvas(nil, heightmap, minHeight, maxHeight)
        scmapUtils.renderBlockingToCanvas(drawcanvas, scmapUtils.getBlockingData(heightmap))

        love.window.setTitle("Map: "..filename.." - Render scale: x"..math.min(1025/(data.size[1]+1), 1025/(data.size[2]+1)))
    end,
    raw = function(filename, file)
        local data = file:read'data'
        local sizeGuess = math.sqrt(data:getSize()/2)
        if sizeGuess%1~=0 then return print"Can't guess raw file size" end
        local heightmap, minHeight, maxHeight = scmapUtils.readHeightmap(data:getString(), sizeGuess-1, sizeGuess-1, 1)
        drawcanvas = scmapUtils.renderHeightmapToCanvas(nil, heightmap, minHeight, maxHeight)

        love.window.setTitle("Raw: "..filename.." - Render scale: x"..math.min(1025/sizeGuess, 1025/sizeGuess))
    end,
}

function love.filedropped(file)
    local filedir = file:getFilename()
    local filename = filedir:match'[^\\/]*$'
    local format = filename:match'%.([^.]*)$'
    local handler = format and formats[format:lower()]
    if handler then
        if not file:open'r' then return print(filename, "failed to load") end
        handler(filename, file)
    else
        print("Unknown file format: ", format)
    end
end

local directoryFormats = {
    scmap = function(dir)
        local id = dir:match'([^/]*)/*$'
        if workingFileNames[dir] then
            print(id, "Already under way")
        else
            workingFileNames[dir] = true
            love.thread.newThread'scmapwrite.lua':start()
            love.thread.getChannel'scmapwrite':push(dir)
            table.insert(progressChannels, {channel=love.thread.getChannel(dir), name=id, id=dir})

            if love.filesystem.getInfo(dir..'heightmap.raw') then
                local heightmapRaw = love.filesystem.read(dir..'heightmap.raw')
                local sizeGuess = math.sqrt(heightmapRaw:len()/2)
                if sizeGuess%1~=0 then return print"Can't guess heightmap size for preview" end
                local heightmap, minHeight, maxHeight = scmapUtils.readHeightmap(heightmapRaw, sizeGuess-1, sizeGuess-1, 1)
                drawcanvas = scmapUtils.renderHeightmapToCanvas(nil, heightmap, minHeight, maxHeight)
            end
        end
    end,
    map = function(dir)
        print"Folder received. Doing nothing with it. Drop an scmap file or extracted scmap folder."
    end,
}

function love.directorydropped(folder)
    local foldername = folder:match'[^\\/]*$'
    local format = foldername:match'%.([^.]*)$'
    local handler = format and directoryFormats[format:lower()] or directoryFormats.map
    if handler then
        local mountpoint = "folderMount/"..foldername
        if not love.filesystem.mount(folder, mountpoint) then return print(foldername, "failed to mount") end
        handler(mountpoint..'/')
    end
end
