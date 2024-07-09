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
function math.IMBInt(bytes)
    local num = math.IMBIntUnsigned(bytes)
    if num==4294967295 then return -1 end
    if num>2147483647 then
        --TODO negative int unconverted.
        return bytes
    end
    return num
end
