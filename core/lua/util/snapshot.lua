local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function cleanup_key_value(input)
    local ret = {}

    for k, value in pairs(input) do
        local lines = string.split(value, '\n')
        -- console.log('lines', lines)

        local key = tostring(k)
        local cleanKey = key:gmatch("userdata: 0x(%w+)")()
        local valueType

        local fileline = nil
        local firstLine = lines[1]
        if firstLine:startsWith("table") then
            valueType = "table"

        elseif firstLine:startsWith("func") then
            valueType = "function"
            fileline = firstLine

        elseif firstLine:startsWith("thread") then
            valueType = "thread"
        else
            valueType = "userdata"
        end

        local nextLine = lines[2]
        local tokens = (nextLine and string.split(nextLine, ' : ')) or {}
        -- console.log('tokens', tokens)

        local parent = tokens[1] and tokens[1]:sub(3)
        local valueKey = tokens[2]
        local extra = tokens[3]

        local data = {
            type = valueType,
            parent = parent,
            extra = extra,
            line = fileline,
            key = valueKey
        }

        --[[
        for i = 3, #lines do
            tokens = string.split(lines[i], ' : ')

            parent = tokens[1] and tokens[1]:sub(3)
            valueKey = tokens[2]
            extra = tokens[3]

            if (valueKey) then
                --console.log('index', i, parent, valueKey, extra)
                data[valueKey] = { parent = parent, extra = extra }
            end
        end
        --]]

        --console.log('data', cleanKey, data)
        ret[cleanKey] = data
    end

    return ret
end

local function reduce(input_diff)
    local a_set = {}
    local b_set = {}
    local step = 0

    -- 先收入叶节点
    for self_addr, info in pairs(input_diff) do
        local flag = true
        for _, node in pairs(input_diff) do
            if node.parent == self_addr then
                flag = false
                break
            end
        end

        if flag then
            a_set[self_addr] = info
        end
    end

    step = step + 1
    local MAX_DEPTH = 32
    local dirty
    while step < MAX_DEPTH do
        dirty = false
        -- 遍历叶节点，将parent拉进来
        for self_addr, info in pairs(a_set) do
            local key = info.key
            local parent = info.parent
            local parent_node = input_diff[parent]
            if parent_node then
                if not b_set[parent] then
                    b_set[parent] = parent_node
                end
                parent_node[key] = info
                step = step + 1
                dirty = true
            else
                b_set[self_addr] = info
            end
            a_set[self_addr] = nil
        end

        -- 遍历节点，将祖父节点拉进来
        for self_addr, info in pairs(b_set) do
            local key = info.key
            local parent = info.parent
            local parent_node = input_diff[parent]
            if parent_node then
                if not a_set[parent] then
                    a_set[parent] = parent_node
                end
                parent_node[key] = info
                step = step + 1
                dirty = true
            else
                a_set[self_addr] = info
            end
            b_set[self_addr] = nil
        end

        if not dirty then
            break
        end
    end
    return a_set
end

local unwanted_key = {
    --extra = 1,
    --key = 1,
    parent = 1,
}

local function cleanup_forest(input)
    -- local cache = {[input] = "."}
    local cache = {}

    local function _clean(forest)
        if cache[forest] then
            return
        end

        -- console.log('forest', forest)
        if (forest.key == forest.extra) then
            forest.extra = nil
        end

        for k, v in pairs(forest) do
            if unwanted_key[k] then
                forest[k] = nil
            else
                if type(v) == "table" then
                    cleanup_forest(v)
                end
             end
         end
    end

    return _clean(input)
end

local exports = {}

function exports.indentation(diff)
    local clean_diff = cleanup_key_value(diff)
    --local forest = reduce(clean_diff)
    --cleanup_forest(forest)
    return clean_diff
end

function exports.tree(diff)
    local forest = reduce(diff)
    cleanup_forest(forest)
    return forest
end

function exports.functions(diff)
    local result = {}

    for k, value in pairs(diff) do
        if (value.type == 'function') then
            local line = value.line
            if (not result[line]) then
                result[line] = value
            end

            result[line].count = (result[line].count or 0) + 1
        end
    end

    return result
end

function exports.getDiff(s1, s2)
    local diff = {}
    for k,v in pairs(s2) do
        if not s1[k] then
            diff[k] = v
        end
    end

    return diff
end


return exports
