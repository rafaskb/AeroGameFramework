--[[

	Set is a list that only accepts unique values.


	REQUIRE:

		local Set = require(thisModule)


	CONSTRUCTORS:

        local set = Set.new([values])


    METHODS:

        set:Insert(value)
        set:Remove(value)
        set:Contains(value)
        set:InsertValues(values)

--]]

local Set = {}

function Set.new(values)
    local reverse = {}
    local internalSet = {}

    local set = setmetatable(internalSet, {
        __index = {

            -- insert
            Insert = function(set, value)
                if not reverse[value] then
                    table.insert(set, value)
                    reverse[value] = #set
                end
            end,

            -- remove
            Remove = function(set, value)
                local index = reverse[value]
                if index then
                    reverse[value] = nil
                    -- pop the top element off the set
                    local top = table.remove(set)
                    if top ~= value then
                        -- if it's not the element that we actually want to remove,
                        -- put it back into the set at the index of the element that we
                        -- do want to remove, replacing it
                        reverse[top] = index
                        set[index] = top
                    end
                end
            end,

            -- contains
            Contains = function(set, value)
                return reverse[value] ~= nil
            end,

            -- insertValues
            InsertValues = function(set, values)
                if values then
                    for k, v in pairs(values) do
                        set:insert(v)
                    end
                end
            end
        }
    })

    if values then
        set:InsertValues(values)
    end

    return set
end

return Set
