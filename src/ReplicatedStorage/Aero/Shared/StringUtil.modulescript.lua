--[[

	StringUtil.CommaValue(n)

--]]

local StringUtil = {}


-- Separates a value with commas.
local function CommaValue(n)
    -- credit http://richard.warburton.it
    local left, num, right = string.match(n, '^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

StringUtil.CommaValue = CommaValue

return StringUtil
