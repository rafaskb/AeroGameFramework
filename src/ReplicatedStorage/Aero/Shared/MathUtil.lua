---
---Utility class to help with math operations.
---@class MathUtil
---
local MathUtil = {}

---
---Linearly normalizes value from a range. Range must not be empty. This is the inverse of lerp.
---Example: function(20, 10, 30) returns 0.5.
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

---
---Linearly map a value from one range to another. Input range must not be empty. This is the same as chaining Normalize from input range and Lerp to output range.
---Example: function(20, 10, 30, 50, 100) returns 75.
---@param value number Value to map
---@param inRangeStart number Input range start
---@param inRangeEnd number Input range end
---@param outRangeStart number Output range start
---@param outRangeEnd number Output range end
---@param clamp boolean Whether or not to clamp the final value within the out range.
---@return number
---
function MathUtil:Map(value, inRangeStart, inRangeEnd, outRangeStart, outRangeEnd, clamp)
    local result = outRangeStart + (value - inRangeStart) * (outRangeEnd - outRangeStart) / (inRangeEnd - inRangeStart)
    if clamp then
        result = math.clamp(result, math.min(outRangeStart, outRangeEnd), math.max(outRangeStart, outRangeEnd))
    end
    return result
end

---
---Returns a pseudorandom integer uniformly distributed over [min, max].
---@param min number
---@param max number
---@return number
---
function MathUtil:NextNumber(min, max)
    return self:Lerp(min, max, math.random())
end

---
---Returns a pseudorandom integer uniformly distributed over [min, max].
---@param min number
---@param max number
---@return number
---
function MathUtil:NextInteger(min, max)
    return self:Round(self:Lerp(min, max, math.random()), 1)
end

---
---Returns a pseudorandom boolean.
---@return boolean
---
function MathUtil:NextBoolean()
    return math.random() >= 0.5
end

---
---Returns a triangularly distributed random number between "min" and "max", where values close to the "around" one
---are more likely to be chosen. In the event that "around" is not between the given boundaries, the result is clamped.
---@param min number The lower limit.
---@param max number The upper limit.
---@param around number The point around which the values are more likely.
---@return number
---
function MathUtil:NextTriangular(min, max, around)
    local u = math.random()
    local d = max - min
    local r = 0
    if u <= (around - min) / d then
        r = min + math.sqrt(u * d * (around - min))
    else
        r = max - math.sqrt((1 - u) * d * (max - around))
    end
    return math.clamp(r, min, max)
end

---
---Returns a linear interpolation between the given boundaries at a certain progress.
---@param from number
---@param to number
---@param progress number From 0 to 1.
---@return number
---
function MathUtil:Lerp(from, to, progress)
    return from + (to - from) * progress
end

---
---Rounds a number according to the given bracket.
---
---Examples:
---    Round(123.456789, 100)   -- 100
---    Round(123.456789, 10)    -- 120
---    Round(123.456789, 1)     -- 123
---    Round(123.456789, 0.1)   -- 123.5
---    Round(123.456789, 0.01)  -- 123.46
---    Round(123.456789, 0.001) -- 123.457
---
---@param value number
---@param bracket number
---@return number
---
function MathUtil:Round(value, bracket)
    bracket = bracket or 1
    if bracket == 0 then
        bracket = 1
    end
    return math.floor(value / bracket + 0.5) * bracket
end

---
---Makes a weighted choice based on the given table (keys are entries, values are weights).
---@generic T
---@param t table<T,number>
---@return T
---
function MathUtil:WeightedChoice(t)
    local sum = 0
    for _, v in pairs(t) do
        assert(v >= 0, "[MathUtil:WeightedChoice] Weight value cannot be less than zero.")
        sum = sum + v
    end
    assert(sum ~= 0, "[MathUtil:WeightedChoice] The sum of all weights is zero.")
    local rnd = self:NextNumber(0, sum)
    local last = nil
    for k, v in pairs(t) do
        last = k
        if rnd < v then
            return k
        end
        rnd = rnd - v
    end
    return last
end

return MathUtil
