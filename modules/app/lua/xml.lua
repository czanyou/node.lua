local exports = {}

local function newNode(name)
    ---@class XmlNode
    ---@field public ___props XmlProperty[]
    local node = {}
    node.___value = nil
    node.___name = name
    node.___children = {}
    node.___props = {}

    function node:value() return self.___value end
    function node:setValue(val) self.___value = val end
    function node:name() return self.___name end
    function node:setName(name) self.___name = name end
    function node:children() return self.___children end
    function node:numChildren() return #self.___children end
    function node:addChild(child)
        if self[child:name()] ~= nil then
            if type(self[child:name()].name) == "function" then
                local tempTable = {}
                table.insert(tempTable, self[child:name()])
                self[child:name()] = tempTable
            end
            table.insert(self[child:name()], child)
        else
            self[child:name()] = child
        end
        table.insert(self.___children, child)
    end

    function node:properties() return self.___props end
    function node:numProperties() return #self.___props end
    function node:addProperty(name, value)
        local lName = "@" .. name
        if self[lName] ~= nil then
            if type(self[lName]) == "string" then
                local tempTable = {}
                table.insert(tempTable, self[lName])
                self[lName] = tempTable
            end
            table.insert(self[lName], value)
        else
            self[lName] = value
        end

        ---@class XmlProperty
        ---@field public name string
        ---@field public value any
        local property = { name = name, value = self[name] }
        table.insert(self.___props, property)
    end

    return node
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--
-- xml.lua - XML parser for use with the Corona SDK.
--
-- version: 1.2
--
-- CHANGELOG:
--
-- 1.2 - Created new structure for returned table
-- 1.1 - Fixed base directory issue with the loadFile() function.
--
-- NOTE: This is a modified version of Alexander Makeev's Lua-only XML parser
-- found here: http://lua-users.org/wiki/LuaXml
--
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
function exports.newParser()

    ---@class XmlParser
    local XmlParser = {};

    function XmlParser:toXmlString(value)
        value = string.gsub(value, "&", "&amp;"); -- '&' -> "&amp;"
        value = string.gsub(value, "<", "&lt;"); -- '<' -> "&lt;"
        value = string.gsub(value, ">", "&gt;"); -- '>' -> "&gt;"
        value = string.gsub(value, "\"", "&quot;"); -- '"' -> "&quot;"
        value = string.gsub(value, "([^%w%&%;%p%\t% ])",
            function(c)
                return string.format("&#x%X;", string.byte(c))
            end);
        return value;
    end

    function XmlParser:fromXmlString(value)
        value = string.gsub(value, "&#x([%x]+)%;",
            function(h)
                return string.char(tonumber(h, 16))
            end);
        value = string.gsub(value, "&#([0-9]+)%;",
            function(h)
                return string.char(tonumber(h, 10))
            end);
        value = string.gsub(value, "&quot;", "\"");
        value = string.gsub(value, "&apos;", "'");
        value = string.gsub(value, "&gt;", ">");
        value = string.gsub(value, "&lt;", "<");
        value = string.gsub(value, "&amp;", "&");
        return value;
    end

    function XmlParser:parseArgs(node, s)
        string.gsub(s, "(%w+)=([\"'])(.-)%2", function(w, _, a)
            node:addProperty(w, self:fromXmlString(a))
        end)
    end

    ---@param xmlText string
    function XmlParser:parseXmlText(xmlText)
        -- console.log('parseXmlText', xmlText)

        local stack = {}
        local top = newNode()
        table.insert(stack, top)
        local ni, c, label, xarg, empty
        local i, j = 1, 1
        while true do
            ni, j, c, label, xarg, empty = string.find(xmlText, "<(%/?)([%w%-_:]+)(.-)(%/?)>", i)
            if not ni then break end
            local text = string.sub(xmlText, i, ni - 1);
            if not string.find(text, "^%s*$") then
                local lVal = (top:value() or "") .. self:fromXmlString(text)
                stack[#stack]:setValue(lVal)
            end
            if empty == "/" then -- empty element tag
                local lNode = newNode(label)
                self:parseArgs(lNode, xarg)
                top:addChild(lNode)
            elseif c == "" then -- start tag
                local lNode = newNode(label)
                self:parseArgs(lNode, xarg)
                table.insert(stack, lNode)
		        top = lNode
            else -- end tag
                local toclose = table.remove(stack) -- remove top

                top = stack[#stack]
                if #stack < 1 then
                    error("XmlParser: nothing to close with " .. label)
                end
                if toclose:name() ~= label then
                    error("XmlParser: trying to close " .. (toclose:name()) .. " with " .. label)
                end
                top:addChild(toclose)
            end
            i = j + 1
        end
        local text = string.sub(xmlText, i);
        if #stack > 1 then
            error("XmlParser: unclosed " .. stack[#stack]:name())
        end
        return top
    end

    return XmlParser
end

---@param xmlText string
function exports.parse(xmlText)
    if (type(xmlText) ~= 'string') then
        return nil, 'xmlText must be string'
    elseif (xmlText == '') then
        return nil, 'xmlText is empty'
    end

	local parser = exports.newParser()
    local document = parser:parseXmlText(xmlText)
    return document
end

-- 将 XML 节点转换为 Lua 表格
---@param element XmlNode
---@return table
function exports.xmlToTable(element)
    if (not element) then
        return
    end

    local function getXmlNodeName(name)
        if (type(name) ~= 'string') then
            return name
        end

        local pos = string.find(name, ':')
        if (pos and pos > 0) then
            name = string.sub(name, pos + 1)
        end

        return name
    end

    local name = getXmlNodeName(element:name())
    local properties = element:properties();
    local children = element:children();

    if (children and #children > 0) then
        local item = {}

        -- children
        for _, value in ipairs(children) do
            local key, ret = exports.xmlToTable(value)
            local lastValue = item[key]
            if (lastValue == nil) then
                item[key] = ret

            elseif (type(lastValue) == 'table') and (lastValue[1]) then
                table.insert(lastValue, ret)

            else
                item[key] = { lastValue, ret }
            end
        end

        -- properties
        if (properties and #properties > 0) then
            for _, property in ipairs(properties) do
                local value = element['@' .. property.name]
                item['@' .. property.name] = value
            end
        end

        return name, item

    else
        -- properties
        if (properties and #properties > 0) then
            -- console.log(name, properties)
            local item = {}
            for _, property in ipairs(properties) do
                local value = element['@' .. property.name]
                -- console.log(name, property, value)

                item['@' .. property.name] = value
            end

            item.value = element:value()

            -- console.log(name, item)
            return name, item

        else
            return name, element:value()
        end
    end
end

return exports
