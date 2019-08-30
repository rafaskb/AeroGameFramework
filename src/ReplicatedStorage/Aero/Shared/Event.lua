--[[

	NOTE ON MEMORY LEAK PREVENTION:
		If an event is no longer being used, be sure to invoke the 'Destroy' method
		to ensure that all events are properly released. Failure to do so could
		result in memory leaks due to connections still being referenced.

	WHY NOT BINDABLE EVENTS:
		This module passes by reference, whereas BindableEvents pass by value.
		In other words, BindableEvents will create a copy of whatever is passed
		rather than the original value itself. This becomes difficult when dealing
		with tables, where passing by reference is usually most ideal.

--]]

---
---@class Event
---
local Event = {}
Event.__index = Event

-- Fast references
local ASSERT = assert
local SELECT = select
local UNPACK = unpack
local TYPE = type

---
---Creates a new Event.
---@return Event
---
function Event.new()
    local self = setmetatable({
        _connections = {};
        _destroyed = false;
        _firing = false;
        _bindable = Instance.new("BindableEvent");
    }, Event)
    return self
end

---
---Fires an event
---@vararg any
---
function Event:Fire(...)
    local connections = self._connections
    self._args = { ... }
    self._numArgs = SELECT("#", ...)
    self._bindable:Fire()
end

---
---Waits until this event is fired.
---@return any
---
function Event:Wait()
    self._bindable.Event:Wait()
    return UNPACK(self._args, 1, self._numArgs)
end

---
---Connects a function to this event.
---@param func fun(...)
---
function Event:Connect(func)
    ASSERT(not self._destroyed, "Cannot connect to destroyed event")
    ASSERT(TYPE(func) == "function", "Argument must be function")
    return self._bindable.Event:Connect(function()
        func(UNPACK(self._args, 1, self._numArgs))
    end)
end

---
---Disconnects all functions from this event.
---
function Event:DisconnectAll()
    self._bindable:Destroy()
    self._bindable = Instance.new("BindableEvent")
end

---
---Destroys this event, important to prevent memory leaks.
---
function Event:Destroy()
    if (self._destroyed) then
        return
    end
    self._destroyed = true
    self._bindable:Destroy()
end

return Event