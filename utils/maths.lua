function math.formatBytes(bytes)
    return ('%0.2x%0.2x%0.2x%0.2x'):format(
        bytes:sub(1,1):byte(),
        bytes:sub(2,2):byte(),
        bytes:sub(3,3):byte(),
        bytes:sub(4,4):byte()
    )
end
function math.flipFormatBytes(bytes)
    return ('%0.2x%0.2x%0.2x%0.2x'):format(
        bytes:sub(4,4):byte(),
        bytes:sub(3,3):byte(),
        bytes:sub(2,2):byte(),
        bytes:sub(1,1):byte()
    )
end

local fficast   = require'ffi'.cast
local ffistring = require'ffi'.string
local ffinew    = require'ffi'.new

function math.IBMShort(bytes) return fficast('uint16_t*', bytes)[0] end
function math.IMBUInt(bytes)  return fficast('uint32_t*', bytes)[0] end
function math.IMBInt(bytes)   return fficast('int32_t*',  bytes)[0] end
function math.IMBFloat(bytes) return fficast('float*',    bytes)[0] end

function math.shortToIBM(val) return ffistring(fficast('uint8_t(*)[4]', ffinew("uint16_t[1]", {val}))[0], 4) end
function math.uIntToIBM(val)  return ffistring(fficast('uint8_t(*)[4]', ffinew("uint32_t[1]", {val}))[0], 4) end
function math.intToIBM(val)   return ffistring(fficast('uint8_t(*)[4]', ffinew("int32_t[1]",  {val}))[0], 4) end
function math.floatToIBM(val) return ffistring(fficast('uint8_t(*)[4]', ffinew("float[1]",    {val}))[0], 4) end
