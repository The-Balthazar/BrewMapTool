require'utils.maths'
require'utils.table'
require'utils.scmap'
require'utils.heightmap'
require'utils.fileformats'

local drawcanvas

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
        local yPos = 10+(i-1)*40
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

local formats = {
    scmap = function(filename, file)
        local data = scmapUtils.readDatastream(file:read'data')
        if not data then return end

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

        if love.window then
            local heightmapData, minHeight, maxHeight = heightmapUtils.read(data.heightmap[1], data.size[1], data.size[2], data.heightmapScale)
            drawcanvas = heightmapUtils.renderToCanvas(nil, heightmapData, minHeight, maxHeight)
            heightmapUtils.renderOverlayToCanvas(drawcanvas, heightmapUtils.getBlockingData(heightmapData), {1,0,0}, 'multiply')
            local watermap, abyssmap = heightmapUtils.getWaterData(heightmapData, data.waterSettings.elevation)
            heightmapUtils.renderOverlayToCanvas(drawcanvas, abyssmap, {0.75,0,0.5}, 'multiply')
            heightmapUtils.renderOverlayToCanvas(drawcanvas, watermap, {0,0,0.5}, 'screen')

            love.window.setTitle("Map: "..filename.." - Render scale: x"..math.min(1025/(data.size[1]+1), 1025/(data.size[2]+1)))
        end
    end,
    raw = function(filename, file)
        local data = file:read'data'
        local sizeGuess = math.sqrt(data:getSize()/2)
        if sizeGuess%1~=0 then return print"Can't guess raw file size" end
        local heightmapData, minHeight, maxHeight = heightmapUtils.read(data:getString(), sizeGuess-1, sizeGuess-1, 1)
        drawcanvas = heightmapUtils.renderToCanvas(nil, heightmapData, minHeight, maxHeight)

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
        file:close()
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

            if love.window and love.filesystem.getInfo(dir..'heightmap.raw') then
                local heightmapRaw = love.filesystem.read(dir..'heightmap.raw')
                local sizeGuess = math.sqrt(heightmapRaw:len()/2)
                if sizeGuess%1~=0 then return print"Can't guess heightmap size for preview" end
                local heightmapData, minHeight, maxHeight = heightmapUtils.read(heightmapRaw, sizeGuess-1, sizeGuess-1, 1)
                drawcanvas = heightmapUtils.renderToCanvas(nil, heightmapData, minHeight, maxHeight)
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

function love.load(arg, unfilteredArg)
    if not arg[1] then
        require'love.font'
        require'love.window'
        require'love.graphics'
        love.window.setMode(1025, 1025, {
            fullscreen = false,
            usedpiscale = false,
            resizable = true,
        })
        love.window.setTitle'BrewMapTool'
    end
end

