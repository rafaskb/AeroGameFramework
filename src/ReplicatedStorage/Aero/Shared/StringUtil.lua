--[[

    FUNCTIONS:

	    StringUtil.CommaValue(n) - Separates a value with commas. (e.g. 1234567 -> 1,234,567)

	    StringUtil.Split(input, separator, limit) - Splits a string according to the separator and returns a table with the results.
	        @arg input - String to be used as source.
	        @arg separator - Single character to be used as separator. If nil, any whitespace is used.
	        @arg limit - Amount of matches to group. Defaults to infinite.

--]]

local StringUtil = {}

local function CommaValue(n)
    -- credit http://richard.warburton.it
    local left, num, right = string.match(n, '^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

local function Split(input, separator, limit)
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

StringUtil.CommaValue = CommaValue
StringUtil.Split = Split

return StringUtil
