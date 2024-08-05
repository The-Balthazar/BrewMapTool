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

--local fficast   = require'ffi'.cast
--local ffistring = require'ffi'.string
--local ffinew    = require'ffi'.new

function math.IBMShort(bytes) return (love.data.unpack('<I2', bytes)) end --fficast('uint16_t*', bytes)[0]
function math.IMBUInt(bytes)  return (love.data.unpack('<I4', bytes)) end --fficast('uint32_t*', bytes)[0]
function math.IMBInt(bytes)   return (love.data.unpack('<i4', bytes)) end --fficast('int32_t*',  bytes)[0]
function math.IMBFloat(bytes) return (love.data.unpack('<f',  bytes)) end --fficast('float*',    bytes)[0]

function math.shortToIBM(val) return love.data.pack('string', '<I2', val) end --ffistring(ffinew("uint16_t[1]", {val}), 4)
function math.uIntToIBM(val)  return love.data.pack('string', '<I4', val) end --ffistring(ffinew("uint32_t[1]", {val}), 4)
function math.intToIBM(val)   return love.data.pack('string', '<i4', val) end --ffistring(ffinew("int32_t[1]",  {val}), 4)
function math.floatToIBM(val) return love.data.pack('string', '<f',  val) end --ffistring(ffinew("float[1]",    {val}), 4)
