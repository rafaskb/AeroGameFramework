--[[

	MathUtil.Clamp(value, min, max)
	MathUtil.NextTriangular(min, max, around)
	MathUtil.Lerp(from, to, progress)
	MathUtil.Round(value)

--]]

local MathUtil = {}

-- Clamps a value between minimum and maximum boundaries.
local function Clamp(value, min, max)
    return math.min(max, math.max(min, value))
end

-- Returns a triangularly distributed random number between "min" and "max", where values close to the "around" one
-- are more likely to be chosen. In the event that "around" is not between the given boundaries, the result is clamped.
-- @param min The lower limit.
-- @param max The upper limit.
-- @param around The point around which the values are more likely.
local function NextTriangular(min, max, around)
    local u = math.random()
    local d = max - min
    if u <= (around - min) / d then
        return min + math.sqrt(u * d * (around - min))
    end
    local r = max - math.sqrt((1 - u) * d * (max - around))
    return Clamp(r, min, max);
end

-- Returns a linear interpolation between the given boundaries at a certain progress.
local function Lerp(from, to, progress)
    return from + (to - from) * progress
end

-- Rounds a value
local function Round(value)
    return math.floor(value + 0.5)
end

MathUtil.Clamp = Clamp
MathUtil.NextTriangular = NextTriangular
MathUtil.Lerp = Lerp
MathUtil.Round = Round

return MathUtil
