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
---@param around number The point around which the values are more likely. Defaults to the average between min and max.
---@return number
---
function MathUtil:NextTriangular(min, max, around)
    if not around then
        around = (min + max) / 2
    end
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
---Basic round function
---@param value number
---
local function round(value)
    return math.floor(value + 0.5)
end

---
---Rounds a number according to the desired amount of decimals.
---
---Examples:
--- - Round(184.123,  3) = 184.123
--- - Round(184.123,  2) = 184.12
--- - Round(184.123,  1) = 184.1
--- - Round(184.123,  0) = 184
--- - Round(184.123, -1) = 190
--- - Round(184.123, -2) = 200
---
---@param value number Value to be rounded.
---@param decimals number Amount of wanted decimals, or negative values to round to the left. Defaults to 0.
---
---@return number Rounded value
---
function MathUtil:Round(value, decimals)
    -- Sanitize
    value = value or 0
    decimals = decimals or 0

    -- Round value
    local a = 10 ^ decimals
    local result = round(value * a) / a

    -- Strip unwanted decimals
    local wereDecimalsRequested = decimals and decimals >= 1
    local areDecimalsZero = (result % math.floor(result)) <= 0.01
    if wereDecimalsRequested or areDecimalsZero then
        result = round(result)
    end

    -- Return result
    return result
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
