--[[

	MathUtil.Clamp(value, min, max)
	MathUtil.NextTriangular(min, max, around)
	MathUtil.Lerp(from, to, progress)
	MathUtil.Round(value, bracket, trimDecimals)

--]]

local MathUtil = {}

---
---Linearly normalizes value from a range. Range must not be empty. This is the inverse of lerp. (e.g. a value of 20 with ranges from 10 to 30 will return 0.5)
---@param value number Value to normalize.
---@param rangeStart number Range start normalized to 0.
---@param rangeEnd number Range end normalized to 1.
---@param clamp boolean Whether the result should be clamped between 0 and 1.
---@return number Normalized value.
---
function MathUtil:Normalize(value, rangeStart, rangeEnd, clamp)
    local result = (value - rangeStart) / (rangeEnd - rangeStart)
    if clamp then
        result = math.min(1.0, math.max(0.0, result))
    end
    return result
end

---Linearly map a value from one range to another. Input range must not be empty. This is the same as chaining Normalize from input range and Lerp to output range.
---@param inRangeStart number Input range start
---@param inRangeEnd number Input range end
---@param outRangeStart number Output range start
---@param outRangeEnd number Output range end
---@param value number Value to map
---@param clamp boolean Whether or not to clamp the final value within the out range.
---@return number
---
function MathUtil:Map(inRangeStart, inRangeEnd, outRangeStart, outRangeEnd, value, clamp)
    local result = outRangeStart + (value - inRangeStart) * (outRangeEnd - outRangeStart) / (inRangeEnd - inRangeStart)
    if clamp then
        result = math.clamp(result, math.min(outRangeStart, outRangeEnd), math.max(outRangeStart, outRangeEnd))
    end
    return result
end

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

--- Rounds a number according to the given bracket.
---
--- Examples:
---     Round(123.456789, 100)   -- 100
---     Round(123.456789, 10)    -- 120
---     Round(123.456789, 1)     -- 123
---     Round(123.456789, 0.1)   -- 123.5
---     Round(123.456789, 0.01)  -- 123.46
---     Round(123.456789, 0.001) -- 123.457
---
local function Round(value, bracket)
    bracket = bracket or 1
    if bracket == 0 then
        bracket = 1
    end
    return math.floor(value / bracket + 0.5) * bracket
end

MathUtil.Clamp = Clamp
MathUtil.NextTriangular = NextTriangular
MathUtil.Lerp = Lerp
MathUtil.Round = Round

return MathUtil
