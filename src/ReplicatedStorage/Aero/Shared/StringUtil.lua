---
---Utility class with helpful string functions.
---@class StringUtil:AeroServer
---
local StringUtil = {}

-- Constants

--- Value used in string <---> byte conversion
local MAX_TUPLE = 7997

---
---Formats a number with commas and dots. (e.g. 1234567 -> 1,234,567)
---
---@param n number
---@return string
---
function StringUtil:CommaValue(n)
    if n == math.huge then
        return "Infinite"
    end

    -- credit http://richard.warburton.it
    local left, num, right = string.match(n, '^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

---
---Parses the given string and produces a friendly version of it, stripping underscores and properly capitalizing words.
---
---@param str string
---@return string
---
function StringUtil:GetFriendlyString(str)
    local result = ""

    if str then
        str = str:lower()
        local words = str:split("_", " ") ---@type string[]

        for i, word in ipairs(words) do
            local len = word:len()
            if len > 0 then
                local firstLetter = word:sub(1, 1):upper()
                result = result .. firstLetter

                if len > 1 then
                    local rest = word:sub(2, len)
                    result = result .. rest
                end

                if i < #words then
                    result = result .. " "
                end
            end
        end
    end

    return result
end

---
---Splits a string according to the separator and returns a table with the results.
---
---@param input string String to be used as source.
---@param separator string Single character to be used as separator. If nil, any whitespace is used.
---@param limit number Amount of matches to group. Defaults to infinite.
---
---@return string[]
---
function StringUtil:Split(input, separator, limit)
    separator = separator or "%s"
    limit = limit or -1
    local t = {}
    local i = 1
    for str in string.gmatch(input, "([^" .. separator .. "]+)") do
        t[i] = str
        i = i + 1
        if limit >= 0 and i > limit then
            break
        end
    end
    return t
end

---
---Escapes a string from pattern characters, prefixing any special pattern characters with a %.
---
---@param str string
---@return string
---
function StringUtil:Escape(str)
    local escaped = str:gsub("([%.%$%^%(%)%[%]%+%-%*%?%%])", "%%%1")
    return escaped
end

---
---Trims whitespace from the start and end of the string.
---
---@param str string
---@return string
---
function StringUtil:Trim(str)
    return str:match("^%s*(.-)%s*$")
end

---
---Trims whitespace from the start of the string.
---
---@param str string
---@return string
---
function StringUtil:TrimStart(str)
    return str:match("^%s*(.+)")
end

---
---Trims whitespace from the end of the string.
---
---@param str string
---@return string
---
function StringUtil:TrimEnd(str)
    return str:match("(.-)%s*$")
end

---
---Replaces all whitespace with a single space.
---
---@param str string
---@return string
---
function StringUtil:RemoveExcessWhitespace(str)
    return str:gsub("%s+", " ")
end

---
---Removes all whitespace from a string.
---
---@param str string
---@return string
---
function StringUtil:RemoveWhitespace(str)
    return str:gsub("%s+", "")
end

---
---Checks if a string starts with a certain string.
---
---@param str string
---@param starts string
---@return boolean
---
function StringUtil:StartsWith(str, starts)
    return str:match("^" .. StringUtil.Escape(starts)) ~= nil
end

---
---Checks if a string ends with a certain string.
---
---@param str string
---@param ends string
---@return boolean
---
function StringUtil:EndsWith(str, ends)
    return str:match(StringUtil.Escape(ends) .. "$") ~= nil
end

---
---Checks if a string contains another string.
---
---@param str string
---@param contains string
---@return boolean
---
function StringUtil:Contains(str, contains)
    return str:find(contains) ~= nil
end

---
---Returns a table of all the characters in the string, in the same order and including duplicates.
---
---@param str string
---@return string[]
---
function StringUtil:ToCharArray(str)
    local len = #str
    local chars = table.create(len)
    for i = 1, len do
        chars[i] = str:sub(i, 1)
    end
    return chars
end

---
---Returns a table of all the bytes of each character in the string.
---
---@param str string
---@return number[]
---
function StringUtil:ToByteArray(str)
    local len = #str
    if (len == 0) then
        return {}
    end
    if (len <= MAX_TUPLE) then
        return table.pack(str:byte(1, #str))
    end
    local bytes = table.create(len)
    for i = 1, len do
        bytes[i] = str:sub(i, 1):byte()
    end
    return bytes
end

---
---Transforms an array of bytes into a string
---
---@param bytes number[]
---@return string
---
function StringUtil:ByteArrayToString(bytes)
    local size = #bytes
    if (size <= MAX_TUPLE) then
        return string.char(table.unpack(bytes))
    end
    local numChunks = math.ceil(size / MAX_TUPLE)
    local stringBuild = table.create(numChunks)
    for i = 1, numChunks do
        local chunk = string.char(table.unpack(bytes, ((i - 1) * MAX_TUPLE) + 1, math.min(size, ((i - 1) * MAX_TUPLE) + MAX_TUPLE)))
        stringBuild[i] = chunk
    end
    return table.concat(stringBuild, "")
end

---
---Checks if two strings are equal.
---
---@param str1 string
---@param str2 string
---@return boolean
---
function StringUtil:Equals(str1, str2)
    return (str1 == str2)
end

---
---Checks if two strings are equal, but ignores their case.
---
---@param str1 string
---@param str2 string
---@return boolean
---
function StringUtil:EqualsIgnoreCase(str1, str2)
    return (str1:lower() == str2:lower())
end

---
---Returns a string in camelCase.
---
---@param str string
---@return string
---
function StringUtil:ToCamelCase(str)
    str = str:gsub("[%-_]+([^%-_])", function(s)
        return s:upper()
    end)
    return str:sub(1, 1):lower() .. str:sub(2)
end

---
---Returns a string in PascalCase.
---
---@param str string
---@return string
---
function StringUtil:ToPascalCase(str)
    str = StringUtil.ToCamelCase(str)
    return str:sub(1, 1):upper() .. str:sub(2)
end

---
---Returns a string in snake_case or SNAKE_CASE.
---
---@param str string
---@param uppercase boolean
---@return string
---
function StringUtil:ToSnakeCase(str, uppercase)
    str = str:gsub("[%-_]+", "_"):gsub("([^%u%-_])(%u)", function(s1, s2)
        return s1 .. "_" .. s2:lower()
    end)
    if (uppercase) then
        str = str:upper()
    else
        str = str:lower()
    end
    return str
end

---
---Returns a string in kebab-case or KEBAB-CASE
---
---@param str string
---@param uppercase boolean
---@return string
---
function StringUtil:ToKebabCase(str, uppercase)
    str = str:gsub("[%-_]+", "-"):gsub("([^%u%-_])(%u)", function(s1, s2)
        return s1 .. "-" .. s2:lower()
    end)
    if (uppercase) then
        str = str:upper()
    else
        str = str:lower()
    end
    return str
end

---
---Internal Aero function.
---@private
---
function StringUtil:Start()
end

return StringUtil
