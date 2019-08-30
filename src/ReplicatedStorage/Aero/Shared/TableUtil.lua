---
---Utility class to help with table operations.
---@class TableUtil
---
local TableUtil = {}

local http = game:GetService("HttpService") ---@type HttpService

---
---Performs a deep copy of the given table and all its values.
---@generic T : table
---@param t T
---@return T
---
function TableUtil:DeepCopy(t)
    assert(type(t) == "table", "First argument must be a table")
    local tCopy = {}
    for k, v in pairs(t) do
        if (type(v) == "table") then
            tCopy[k] = self:DeepCopy(v)
        else
            tCopy[k] = v
        end
    end
    return tCopy
end

---
---Performs a shallow copy of the given table, simply passing its values around.
---@generic T : table<any,any>
---@param t T
---@return T
---
function TableUtil:ShallowCopy(t)
    assert(type(t) == "table", "First argument must be a table")
    local tCopy = {}
    for k, v in pairs(t) do
        tCopy[k] = v
    end
    return tCopy
end

---
---Synchronizes a table to a template table. If the table does not have an item that exists within the template,
---it gets added. If the table has something that the template does not have, it gets removed.
---@param tbl table<any,any>
---@param templateTbl table<any,any>
---
function TableUtil:Sync(tbl, templateTbl)
    assert(type(tbl) == "table", "First argument must be a table")
    assert(type(templateTbl) == "table", "Second argument must be a table")

    -- If 'tbl' has something 'templateTbl' doesn't, then remove it from 'tbl'
    -- If 'tbl' has something of a different type than 'templateTbl', copy from 'templateTbl'
    -- If 'templateTbl' has something 'tbl' doesn't, then add it to 'tbl'
    for k, v in pairs(tbl) do
        local vTemplate = templateTbl[k]

        -- Remove keys not within template:
        if (vTemplate == nil) then
            tbl[k] = nil

            -- Synchronize data types:
        elseif (type(v) ~= type(vTemplate)) then
            if (type(vTemplate) == "table") then
                tbl[k] = self:DeepCopy(vTemplate)
            else
                tbl[k] = vTemplate
            end

            -- Synchronize sub-tables:
        elseif (type(v) == "table") then
            self:Sync(v, vTemplate)
        end
    end

    -- Add any missing keys:
    for k, vTemplate in pairs(templateTbl) do
        local v = tbl[k]
        if (v == nil) then
            if (type(vTemplate) == "table") then
                tbl[k] = self:DeepCopy(vTemplate)
            else
                tbl[k] = vTemplate
            end
        end
    end
end

---
---Removes an item from the given array by replacing its index with the last element to avoid expensive table reordering. Only use this if you do NOT care about the order of your array.
---@generic T : any
---@param t T[]
---@param i number
---@return T
---
function TableUtil:FastRemove(t, i)
    local n = #t
    t[i] = t[n]
    t[n] = nil
    return n
end

---
---Removes an item from the given array by replacing its index with the last element to avoid expensive table reordering. Only use this if you do NOT care about the order of your array.
---@generic T : any
---@param t T[]
---@param element T
---@return boolean,number Success flag and the element index.
---
function TableUtil:FastRemoveIndexOf(t, element)
    local i = self:IndexOf(t, element)
    if i then
        self:FastRemove(t, i)
        return true, i
    end
    return false, -1
end

---
---This allows you to construct a new table by calling the given function on each item in the table.
---@generic T : any
---@generic R : any
---@param t T[]
---@param f fun(T):R
---@return R[]
---
function TableUtil:Map(t, f)
    assert(type(t) == "table", "First argument must be a table")
    assert(type(f) == "function", "Second argument must be a function")
    local newT = {}
    for k, v in pairs(t) do
        newT[k] = f(v, k, t)
    end
    return newT
end

---
---This allows you to create a table based on the given table and a filter
---function. If the function returns 'true', the item remains in the new
---table; if the function returns 'false', the item is discluded from the
---new table.
---@generic T : any
---@param t T[]
---@param f fun(element:T):boolean
---@return T[]
---
function TableUtil:Filter(t, f)
    assert(type(t) == "table", "First argument must be a table")
    assert(type(f) == "function", "Second argument must be a function")
    local newT = {}
    if (#t > 0) then
        local n = 0
        for i = 1, #t do
            local v = t[i]
            if (f(v, i, t)) then
                n = (n + 1)
                newT[n] = v
            end
        end
    else
        for k, v in pairs(t) do
            if (f(v, k, t)) then
                newT[k] = v
            end
        end
    end
    return newT
end

---
---This allows you to reduce an array to a single value. Useful for quickly summing up an array.
---@generic T : any
---@param t T[]
---@param f fun(accumulator:number, value:T):number
---@param init number|nil
---@return number
---
function TableUtil:Reduce(t, f, init)
    assert(type(t) == "table", "First argument must be a table")
    assert(type(f) == "function", "Second argument must be a function")
    assert(init == nil or type(init) == "number", "Third argument must be a number or nil")
    local result = (init or 0)
    for k, v in pairs(t) do
        result = f(result, v, k, t)
    end
    return result
end

---
---Prints out the table to the output in an easy-to-read format. Good for
---debugging tables. If deep printing, avoid cyclical references.
---@param tbl table
---@param label string
---@param deepPrint boolean
---
function TableUtil:Print(tbl, label, deepPrint)
    assert(type(tbl) == "table", "First argument must be a table")
    assert(label == nil or type(label) == "string", "Second argument must be a string or nil")

    label = (label or "TABLE")

    local strTbl = {}
    local indent = " - "

    -- Insert(string, indentLevel)
    local function Insert(s, l)
        strTbl[#strTbl + 1] = (indent:rep(l) .. s .. "\n")
    end

    local function AlphaKeySort(a, b)
        return (tostring(a.k) < tostring(b.k))
    end

    local function PrintTable(t, lvl, lbl)
        Insert(lbl .. ":", lvl - 1)
        local nonTbls = {}
        local tbls = {}
        local keySpaces = 0
        for k, v in pairs(t) do
            if (type(v) == "table") then
                table.insert(tbls, { k = k, v = v })
            else
                table.insert(nonTbls, { k = k, v = "[" .. typeof(v) .. "] " .. tostring(v) })
            end
            local spaces = #tostring(k) + 1
            if (spaces > keySpaces) then
                keySpaces = spaces
            end
        end
        table.sort(nonTbls, AlphaKeySort)
        table.sort(tbls, AlphaKeySort)
        for _, v in pairs(nonTbls) do
            Insert(tostring(v.k) .. ":" .. (" "):rep(keySpaces - #tostring(v.k)) .. v.v, lvl)
        end
        if (deepPrint) then
            for _, v in pairs(tbls) do
                PrintTable(v.v, lvl + 1, tostring(v.k) .. (" "):rep(keySpaces - #tostring(v.k)) .. " [Table]")
            end
        else
            for _, v in pairs(tbls) do
                Insert(tostring(v.k) .. ":" .. (" "):rep(keySpaces - #tostring(v.k)) .. "[Table]", lvl)
            end
        end
    end

    PrintTable(tbl, 1, label)

    print(table.concat(strTbl, ""))
end

---
---Returns the index of the given item in the table. If not found, this will return nil.
---@generic T : any
---@param tbl T[]
---@param item T
---@return number
---
function TableUtil:IndexOf(tbl, item)
    for i = 1, #tbl do
        if (tbl[i] == item) then
            return i
        end
    end
    return nil
end

---
---Creates a reversed version of the array. Note: This is a shallow
---copy, so existing references will remain within the new table.
---@generic K : any
---@generic V : any
---@param tbl table<K,V>
---@return table<K,V>
---
function TableUtil:Reverse(tbl)
    local tblRev = {}
    local n = #tbl
    for i = 1, n do
        tblRev[i] = tbl[n - i + 1]
    end
    return tblRev
end

---
---Shuffles an array using the Fisher-Yates algorithm.
---@param tbl table
---
function TableUtil:Shuffle(tbl)
    assert(type(tbl) == "table", "First argument must be a table")
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
end

---
---Checks if the given table is empty.
---@param tbl table
---@return boolean
---
function TableUtil:IsEmpty(tbl)
    return (next(tbl) == nil)
end

---
---Generate a JSON string from a Lua table.
---@param tbl table
---@return string
---
function TableUtil:EncodeJSON(tbl)
    return http:JSONEncode(tbl)
end

---
---Decodes a JSON string into a Lua table
---@param str string
---@return table
---
function TableUtil:DecodeJSON(str)
    return http:JSONDecode(str)
end

return TableUtil
