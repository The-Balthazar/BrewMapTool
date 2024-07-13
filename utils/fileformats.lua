fileformats = {
    isDDS = function(file) return file:sub(1,5)=='DDS |' and 'dds' end,
    isTGA = function(file) return file:sub(-18)=='TRUEVISION-XFILE.\00' and 'tga' end,
    isPNG = function(file) return file:sub(1,8)=='\137PNG\13\10\26\10' and 'png' end,
    isJPG = function(file) return file:sub(1,2)=='\255\216' and file:sub(-2)=='\255\217' and 'jpg' end,
    isBMP = function(file) return file:sub(1,2)=='BM' and file:len()==math.IMBInt(file:sub(3,6)) and 'bmp' end,
    isIndex = function(file) return file:sub(1,5)=='INDEX' and 'index' end,
    indexLuaToBin = function(array) return 'INDEX'..math.intToIBM(#array)..table.concat(array, '\000')..'\000' end,
    indexBinToLua = function(data)
        local count = math.IMBInt(data:sub(6,9))
        local offset = 10
        local array = {}
        for i=1, count do
            local str = ''
            local byte = data:sub(offset, offset)
            offset = offset+1
            while byte and byte~='\000' do
                str=str..byte
                byte = data:sub(offset, offset)
                offset = offset+1
            end
            table.insert(array, str)
        end
        return array
    end
}
