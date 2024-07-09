local reserved = {
    ['and']    = 'and',
    ['break']  = 'break',
    ['do']     = 'do',
    ['else']   = 'else',
    ['elseif'] = 'elseif',

    ['end']      = 'end',
    ['false']    = 'false',
    ['for']      = 'for',
    ['function'] = 'function',
    ['if']       = 'if',

    ['in']    = 'in',
    ['local'] = 'local',
    ['nil']   = 'nil',
    ['not']   = 'not',
    ['or']    = 'or',

    ['repeat'] = 'repeat',
    ['return'] = 'return',
    ['then']   = 'then',
    ['true']   = 'true',
    ['until']  = 'until',
    ['while']  = 'while',
}

function table.serialize(val, key, depth)
    depth = depth or 0

    local str = string.rep('    ', depth)
    if type(key) ~= 'number' then
        str = str..(key and key..' = ' or 'return ')
    end

    local valtype = type(val)
    if valtype == 'table' then
        if next(val) then
            str = str .. "{\n"
            if table.len(val) == #val and table.maxi(val) == #val then
                for i, v in ipairs(val) do
                    str =  str .. table.serialize(v, i, depth + 1) .. ",\n"
                end
            else
                for k, v in pairs(val) do
                    if type(k) == 'number' then
                        k = '['..tostring(k)..']'
                    elseif k:find'^%A' or k:find'[^%w_]' or reserved[k] then
                        k = string.format("[%q]", tostring(k) )
                    end
                    str = str .. table.serialize(v, k, depth + 1) .. ",\n"
                end
            end
            str = str .. string.rep('    ', depth) .. '}'

        else
            str = str .. '{}'
        end

    elseif valtype == 'number' or valtype == 'boolean' then
        str = str .. tostring(val)

    elseif valtype == 'string' then
        str = str .. string.format("%q", val)

    else
        str = str .. string.format("%q", tostring(val))
    end

    return str
end

function table.len(a)
    local n = 0
    for i, v in pairs(a) do
        n = n+1
    end
    return n
end

function table.maxi(a)
    local n
    for i, v in pairs(a) do
        if 'number' == type(i) then
            n = not n and i or math.max(n, i)
        end
    end
    return n
end

-- pairs, but sorted
function sortedpairs(set, sort)
    local keys = {}
    for k, v in pairs(set) do
        table.insert(keys, k)
    end
    table.sort(keys, sort)

    local i = 0
    return function()
        i = i+1
        return keys[i], set[ keys[i] ]
    end
end
