---
---Utility class with helpful string functions.
---@class StringUtil:AeroServer
---
local StringUtil = {}

---
---Formats a number with commas and dots. (e.g. 1234567 -> 1,234,567)
---
---@param n number
---@return string
---
function StringUtil:CommaValue(n)
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
        local words = str:split("_ ") ---@type string[]

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

return StringUtil
