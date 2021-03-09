---
---Utility class to help with math operations.
---@class MathUtil
---
local MathUtil = {}

local LARGE_NUMBER_ENCODING_VERSION = 1

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
---Returns a pseudorandom float uniformly distributed over [min, max].
---@param min number
---@param max number
---@return number
---
function MathUtil:NextNumber(min, max)
    return self:Lerp(min, max, math.random())
end

---
---Returns a boolean indicating if the given chance was met when compared with a random value. Chance must be between 0 and 1.
---@param chance number Number between 0 and 1
---@return boolean
---
function MathUtil:NextChance(chance)
    return math.random() <= (chance or 0)
end

---
---Returns a pseudorandom integer uniformly distributed over [min, max].
---@param min number
---@param max number
---@return number
---
function MathUtil:NextInteger(min, max)
    return math.floor(self:Lerp(min, max, math.random()) + 0.5)
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
    -- Sanitize
    if not around then
        around = (min + max) / 2
    end
    if min > max then
        local originalMin = min
        local originalMax = max
        min = originalMax
        max = originalMin
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
    if not wereDecimalsRequested or areDecimalsZero then
        result = round(result)
    end

    -- Return result
    return result
end

---
---Rounds a number keeping a certain amount of significant figures.
---
---Examples:
--- - SignificantFigures(123.45,  5) = 123.45
--- - SignificantFigures(123.45,  4) = 123.5
--- - SignificantFigures(123.45,  3) = 123
--- - SignificantFigures(123.45,  2) = 120
--- - SignificantFigures(123.45,  1) = 100
--- - SignificantFigures(123.45,  0) = 0.0
---
---@param value number Number to be rounded.
---@param figures number Amount of significant figures to keep
---
function MathUtil:SignificantFigures(value, figures)
    local x = figures - math.ceil(math.log10(math.abs(value)))
    return math.floor(value * 10 ^ x + 0.5) / 10 ^ x
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

---
---Encodes any large number supported by Lua into a database format that's smaller than 64 bits.
---12 significant figures are preserved, while the others are lost.
---
---@param number number Any number supported by lua, both positive or negative.
---@param printDebug boolean If true, the encoding process will be printed to the output.
---@return number Encoded number
---@overload fun(number:number):number
---
function MathUtil:EncodeLargeNumber(number, printDebug)
    --[[
        FORMAT = |V|SEEE|SMMMMMMMMMMMM|
             V = Version
             S = Sign (1 for positive, 0 for negative)
             E = Exponent (3 digits)
             M = Mantissa (12 digits)

        EXAMPLE: 110731498700000000
                 1----------------- => Version: 1
                 -1---------------- => Exponent Sign: 1 (Exponent is positive)
                 --073------------- => Exponent: 73
                 -----1------------ => Mantissa Sign: 1 (Mantissa is positive)
                 ------498700000000 => Mantissa: 498700000000 (Becomes 0.498700000000)
    --]]

    -- Sanitize
    number = number or 0

    -- Extract mantissa and exponent
    local mantissa, exponent = math.frexp(number) ---@type number
    local encodedVersion = LARGE_NUMBER_ENCODING_VERSION * 1e17
    local encodedExponent = math.floor(math.abs(exponent * 1e13))
    local encodedMantissa = math.floor(math.abs(mantissa * 1e12))
    local encodedExponentSign = exponent > 0 and 1e16 or 0
    local encodedMantissaSign = mantissa > 0 and 1e12 or 0
    local encodedNumber = encodedVersion + encodedExponentSign + encodedExponent + encodedMantissaSign + encodedMantissa

    -- Debug printing
    if printDebug then
        print("\tEncoding number:", number)
        print(("\t%f -> %s"):format(mantissa, "mantissa"))
        print(("\t%f -> %s"):format(exponent, "exponent"))
        print(("\t%018.0f -> %s"):format(encodedVersion, "encodedVersion"))
        print(("\t%018.0f -> %s"):format(encodedExponentSign, "encodedExponentSign"))
        print(("\t%018.0f -> %s"):format(encodedExponent, "encodedExponent"))
        print(("\t%018.0f -> %s"):format(encodedMantissaSign, "encodedMantissaSign"))
        print(("\t%018.0f -> %s"):format(encodedMantissa, "encodedMantissa"))
        print(("\t%018.0f -> %s"):format(encodedNumber, "encodedNumber"))
    end

    return encodedNumber
end

---
---Decodes any large number supported by Lua from a database format that's smaller than 64 bits.
---12 significant figures are preserved, while the others are lost.
---
---@param number number
---@param printDebug boolean If true, the encoding process will be printed to the output.
---@return number Decoded number
---
---@overload fun(number:number):number
---
function MathUtil:DecodeLargeNumber(number, printDebug)
    -- Decode version from number (in case the number was encoded with a version -- Otherwise this will be zero)
    local version = math.floor(number / 1e17)

    -- Current version
    if version == LARGE_NUMBER_ENCODING_VERSION then
        --[[
            FORMAT = |V|SEEE|SMMMMMMMMMMMM|
                 V = Version
                 S = Sign (1 for positive, 0 for negative)
                 E = Exponent (3 digits)
                 M = Mantissa (12 digits)
        --]]

        local exponentSign = math.floor((number / 1e16) % 1e1) == 1 and 1 or -1
        local exponent = math.floor((number / 1e13) % 1e3) * exponentSign
        local mantissaSign = math.floor((number / 1e12) % 1e1) == 1 and 1 or -1
        local mantissa = ((number % 1e12) / 1e12) * mantissaSign
        local decodedNumber = math.ldexp(mantissa, exponent)

        -- Debug printing
        if printDebug then
            print(("\tDecoding number: %018.0f"):format(number))
            print(("\t%f -> %s"):format(version, "version"))
            print(("\t%f -> %s"):format(exponentSign, "exponentSign"))
            print(("\t%f -> %s"):format(exponent, "exponent"))
            print(("\t%f -> %s"):format(mantissaSign, "mantissaSign"))
            print(("\t%f -> %s"):format(mantissa, "mantissa"))
            print(("\t%f -> %s"):format(decodedNumber, "decodedNumber"))
        end

        return decodedNumber
    end

    -- Version 0 (before versioning was implemented)
    if version == 0 then
        --[[
            FORMAT = |H|EEE|SSSS|
                 H = Fixed "1" header
                 E = 3 digits exponent
                 C = 4 significant digits
        --]]

        -- Make sure number is greater than our header
        local h = 10000000
        number = math.max(h, number)

        -- Decode
        local exponent = math.floor((number - 10000000) / 10000)
        local significant = (number - (math.floor(number / 10000) * 10000)) / 1000
        local decoded = significant * math.pow(10, exponent)

        -- Debug printing
        if printDebug then
            print(("\tDecoding number: %018.0f"):format(number))
            print(("\t%f -> %s"):format(version, "version"))
            print(("\t%f -> %s"):format(exponent, "exponent"))
            print(("\t%f -> %s"):format(significant, "significant"))
            print(("\t%f -> %s"):format(decoded, "decoded"))
        end

        return decoded
    end
end

return MathUtil
