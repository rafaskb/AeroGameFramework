---
---Util class containing functions to check parameters before sending them over the network or storing in DataStores.
---@class ParamUtil
---
local ParamUtil = {}

---
---Checks if a paratemer is valid to be sent over the network. The following constraints are checked:
--- 1. Parameters can only be primitive values.
--- 2. Tables can only contain primitive values.
--- 3. Tables cannot be indexed by both numbers and strings.
--- 4. Tables can only be indexed by numbers or strings (no functions as keys).
--- 5. Parameters cannot be functions.
---
---@return boolean,string Success flag and error message, if any.
---
function ParamUtil:IsValidForNetworking(instance)
    local instanceType = string.lower(typeof(instance))

    if instanceType == "table" then
        -- Check for objects
        if getmetatable(instance) then
            return false, "Parameters cannot have metatables."
        end

        local numbersAsKeys = false
        local stringsAsKeys = false

        -- Check table content
        for k, v in pairs(instance) do
            -- Check table keys
            local keyType = type(k)
            if keyType == "number" then
                numbersAsKeys = true
            elseif keyType == "string" then
                stringsAsKeys = true
            else
                return false, "Parameters cannot have tables can only be indexed by numbers or strings. Found " .. type
            end
            if numbersAsKeys and stringsAsKeys then
                return false, "Parameters cannot have tables indexed both by numbers and strings."
            end


            -- Check table values
            local success, err = self:IsValidForNetworking(v)
            if not success then
                return success, err
            end
        end
    end

    -- Functions are not allowed.
    if instanceType == "function" then
        return false, "Parameters cannot be functions."
    end

    -- Instance is clean
    return true
end

---
---Checks if a paratemer is valid to be stored in DataStores. The following constraints are checked:
--- 1. (Network check) Parameters can only be primitive values.
--- 2. (Network check) Tables can only contain primitive values.
--- 3. (Network check) Tables cannot be indexed by both numbers and strings.
--- 4. (Network check) Tables can only be indexed by numbers or strings (no functions as keys).
--- 5. (Network check) Parameters cannot be functions.
--- 6. Parameter cannot be a Roblox Instance.
---
---@return boolean,string Success flag and error message, if any.
---
function ParamUtil:IsValidForDataStores(instance)
    -- Network checks
    local success, err = self:IsValidForNetworking(instance)
    if not success then
        return success, err
    end

    -- Make sure parameter is not a Roblox instance
    local type = string.lower(typeof(instance))
    if type == "instance" then
        return false, "Parameters cannot be Roblox Instances."
    end

    -- Instance is clean
    return true
end

return ParamUtil
