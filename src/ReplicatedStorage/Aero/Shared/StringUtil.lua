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
                result = result + firstLetter

                if len > 1 then
                    local rest = word:sub(2, len)
                    result = result + rest
                end

                if i < #words then
                    result = result + " "
                end
            end
        end
    end

    return result
end

return StringUtil
