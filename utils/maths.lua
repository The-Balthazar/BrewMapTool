function math.formatBytes(bytes)
    return ('%0.2x%0.2x%0.2x%0.2x'):format(
        bytes:sub(1,1):byte(),
        bytes:sub(2,2):byte(),
        bytes:sub(3,3):byte(),
        bytes:sub(4,4):byte()
    )
end
function math.IBMShort(bytes)
    return tonumber(('%0.2x%0.2x'):format(bytes:sub(2,2):byte(), bytes:sub(1,1):byte()), 16)
end
function math.IBMShort2(little, big)
    return tonumber(('%0.2x%0.2x'):format(big:byte(), little:byte()), 16)
end
function math.IMBIntUnsigned(bytes)
    return tonumber(('%0.2x%0.2x%0.2x%0.2x'):format(
        bytes:sub(4,4):byte(),
        bytes:sub(3,3):byte(),
        bytes:sub(2,2):byte(),
        bytes:sub(1,1):byte()
    ), 16)
end
function math.IMBFloat(bytes)
    return 'FLOAT:'..math.formatBytes(bytes)
end
function math.IMBInt(bytes)
    local num = math.IMBIntUnsigned(bytes)
    if num==4294967295 then return -1 end
    if num>2147483647 then
        --TODO negative int unconverted.
        return 'INT:'..math.formatBytes(bytes)
    end
    return num
end

local function hex2bin(hex) return string.char(tonumber(hex, 16)) end
local function hex2bin2(a,b) return hex2bin(a)..hex2bin(b) end
local function hex2bin4(a,b,c,d) return hex2bin(a)..hex2bin(b)..hex2bin(c)..hex2bin(d) end
local function hexSplit4(val) return hex2bin4(val:sub(-8,-7),val:sub(-6,-5),val:sub(-4,-3),val:sub(-2,-1)) end
local function hexSplitFlip4(val) return hex2bin4(val:sub(-2,-1),val:sub(-4,-3),val:sub(-6,-5),val:sub(-8,-7)) end

function math.intToIBM(val)
    if type(val)=='string' then
        return hexSplit4(val)
    elseif val==-1 then
        return '\255\255\255\255'
    elseif type(val)=='number' then
        return hexSplitFlip4(('%0.8x'):format(val))
    end
end
