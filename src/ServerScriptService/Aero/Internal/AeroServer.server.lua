---
---@class AeroServer
---
local AeroServer = {
    Loaded = false;
    Events = {};
    ClientEvents = {};
}

local mt = { __index = AeroServer }

local servicesFolders = {}
local modulesFolders = {}
local scriptsFolders = {}
local sharedFolders = {}
local required = {}

local ParamUtil  ---@type ParamUtil
local Event      ---@type Event

local remoteServices = Instance.new("Folder")
remoteServices.Name = "AeroRemoteServices"
remoteServices.Parent = game:GetService("ReplicatedStorage")

local remoteServicesLoadedValue = Instance.new("BoolValue") ---@type BoolValue
remoteServicesLoadedValue.Name = "AeroLoadedValue"
remoteServicesLoadedValue.Parent = remoteServices

---
---Requires a dependency by its name. It can be a module, script, service, all kinds of dependencies will be checked.
---@param name string
---@return any
---
function AeroServer:Require(name)
    local result = required[name]

    -- Error - Module not found
    if not result then
        error("Failed to require dependency called \"" .. tostring(name) .. "\".", 2)
    end

    -- Init module if necessary
    if not result.Init then
        local status, err = pcall(function()
            AeroServer:WrapModule(result.Module)
            result.Init = true
        end)
        if not status then
            error("Failed to require dependency called \"" .. tostring(name) .. "\": " .. tostring(err), 2)
        end
    end

    -- Return module
    return result.Module
end

---
---Registers a server-side event with the given name. All events need unique names.
---@param eventName string
---@return Event
---
function AeroServer:RegisterEvent(eventName)
    assert(not AeroServer.Events[eventName], string.format("The event name '%s' is already registered.", eventName))
    local event = Event.new()
    AeroServer.Events[eventName] = event
    return event
end

---
---Registers an event from server to client with the given name. All events need unique names.
---@param eventName string
---@return Event
---
function AeroServer:RegisterClientEvent(eventName)
    assert(not AeroServer.ClientEvents[eventName], string.format("The client event name '%s' is already registered.", eventName))
    local event = Instance.new("RemoteEvent")
    event.Name = eventName
    event.Parent = self._remoteFolder
    AeroServer.ClientEvents[eventName] = event
    return event
end

---
---Fires an event to this server.
---@param eventName string
---@vararg any Multiple parameters are accepted, but usually a table holding all data (recommended).
---
function AeroServer:FireEvent(eventName, ...)
    assert(AeroServer.Events[eventName], string.format("The event name '%s' is not registered.", eventName))
    AeroServer.Events[eventName]:Fire(...)
end

---
---Fires an event to a specific client.
---@param eventName string
---@param client Player Client receiving the event.
---@vararg any Multiple parameters are accepted, but usually a table holding all data (recommended).
---
function AeroServer:FireClientEvent(eventName, client, ...)
    assert(AeroServer.ClientEvents[eventName], string.format("The event name '%s' is not registered.", eventName))
    local success, err = ParamUtil:IsValidForNetworking({ ... })
    if not success then
        error("Error while firing event to client: " .. err, 2)
    end
    AeroServer.ClientEvents[eventName]:FireClient(client, ...)
end

---
---Fires an event to all connected clients at once.
---@param eventName string
---@vararg any Multiple parameters are accepted, but usually a table holding all data (recommended).
---
function AeroServer:FireAllClientsEvent(eventName, ...)
    assert(AeroServer.ClientEvents[eventName], string.format("The event name '%s' is not registered.", eventName))
    local success, err = ParamUtil:IsValidForNetworking({ ... })
    if not success then
        error("Error while firing event to client: " .. err, 2)
    end
    AeroServer.ClientEvents[eventName]:FireAllClients(...)
end

---
---Connects a listener function to an event, which will be called each time the event is fired.
---@param eventName string
---@param func fun(table) Listener function that receives a table parameter containing all event data.
---
function AeroServer:ConnectEvent(eventName, func)
    assert(AeroServer.Events[eventName], string.format("The event name '%s' is not registered.", eventName))
    return AeroServer.Events[eventName]:Connect(func)
end

---
---Connects a listener function to a client event that was registered via "RegisterClientEvent".
---This is usually not wanted, as client events are meant to be listened in the client, not in the server.
---@param eventName string
---@param func fun(table) Listener function that receives a table parameter containing all event data.
---
function AeroServer:ConnectClientEvent(eventName, func)
    assert(AeroServer.ClientEvents[eventName], string.format("The event name '%s' is not registered.", eventName))
    return AeroServer.ClientEvents[eventName].OnServerEvent:Connect(func)
end

---
---Waits for an event to be fired, yielding the thread.
---@param eventName string
---
function AeroServer:WaitForEvent(eventName)
    return AeroServer.Events[eventName]:Wait()
end

---
---Waits for a client event to be fired, yielding the thread.
---This is usually not wanted, as client events are meant to be listened in the client, not in the server.
---@param eventName string
---
function AeroServer:WaitForClientEvent(eventName)
    return AeroServer.ClientEvents[eventName]:Wait()
end

---
---Registers a server function that's supposed to be called from the client.
---This is usually done automatically when registering services with Client tables, but it can also be done manually if necessary.
---@param funcName string
---@param func function
---@return RemoteFunction
---
function AeroServer:RegisterClientFunction(funcName, func)
    local remoteFunc = Instance.new("RemoteFunction")
    remoteFunc.Name = funcName
    remoteFunc.OnServerInvoke = function(...)
        return func(self.Client, ...)
    end
    remoteFunc.Parent = self._remoteFolder
    return remoteFunc
end

---
---Runs a function asynchronously via coroutines.
---
---@param func function Function to be executed asynchronously.
---@param module table Aero module passed as self to the given function. Optional.
---@param name string Name of the function for debug purposes.Optional.
---
---@overload fun(func:function):void
---
function AeroServer:RunAsync(func, module, name)
    name = name or "Unknown Source"
    local thread = coroutine.create(func)
    local status, err = coroutine.resume(thread, module)
    if not status then
        local tracebackMsg = string.format("%s: %s", name, err)
        local traceback = debug.traceback(thread, tracebackMsg, 2)
        warn(traceback)
    end
end

---
---Loops a function asynchronously via coroutines.
---
---@param func function Function to be executed asynchronously.
---@param interval number Interval in seconds for the function to keep running.
---@param module table Aero module passed as self to the given function. Optional.
---@param name string Name of the function for debug purposes. Optional.
---
---@overload fun(func:function, interval:number):void
---
function AeroServer:RunAsyncLoop(func, interval, module, name)
    name = name or "Unknown Source"
    interval = interval or 0

    local innerName = name .. " (Loop's inner function)"
    local rootFunction = function()
        while true do
            self:RunAsync(func, module, innerName)
            wait(interval)
        end
    end

    self:RunAsync(rootFunction, module, name)
end

---
---Wraps a table as an Aero module, inheriting all Aero functions.
---Init and Start functions are automatically called.
---@generic T table
---@param tbl T
---@param skipInit boolean Whether or not initialization functions should be skipped. Defaults to false.
---@return T
---
function AeroServer:WrapModule(tbl, skipInit)
    assert(type(tbl) == "table", "Expected table for argument")

    -- If table has a metatable set up, merge __indexes, otherwise set it directly
    local currentMeta = getmetatable(tbl)
    if currentMeta then
        local oldIndex = currentMeta.__index
        local newMeta = {}
        for key, value in pairs(currentMeta) do
            if key:find("__") == 1 then
                newMeta[key] = value
            end
        end
        newMeta.__index = function(self, key)
            local result

            -- Check existing metatable
            if oldIndex then
                if type(oldIndex) == "function" then
                    result = oldIndex(self, key)
                elseif type(oldIndex) == "table" then
                    result = oldIndex[key]
                end
            end

            -- Check Aero's metatable
            if not result then
                local aeroIndex = mt.__index
                if type(aeroIndex) == "function" then
                    result = aeroIndex(self, key)
                elseif type(aeroIndex) == "table" then
                    result = aeroIndex[key]
                end
            end

            -- Return result
            return result
        end
        setmetatable(tbl, newMeta)
    else
        setmetatable(tbl, mt)
    end

    if not skipInit then
        if (type(tbl.Init) == "function" and not tbl.__aeroPreventInit) then
            tbl:Init()
        end
        if (type(tbl.Start) == "function" and not tbl.__aeroPreventStart) then
            AeroServer:RunAsync(tbl.Start, tbl, "Wrapped Module")
        end
    end

    return tbl
end

---
---Registers a dependency to this framework, so it can be loaded with Require later.
---@param instance table|Folder|ModuleScript Instance to register.
---@param moduleType string Type of the module
---
local function RegisterDependencies(instance, moduleType)
    -- Get type
    local instanceType = string.lower(typeof(instance))
    local isTable = instanceType == "table"
    local isInstance = not isTable and instanceType == "instance"
    local isFolder = isInstance and instance:IsA("Folder")
    local isScript = isInstance and instance:IsA("ModuleScript")

    -- Parse table
    if isTable then
        for k, v in pairs(instance) do
            RegisterDependencies(v, moduleType)
        end
    end

    -- Parse folder
    if isFolder then
        for k, v in pairs(instance:GetChildren()) do
            RegisterDependencies(v, moduleType)
        end
    end

    -- Register script
    if isScript then

        -- Error - There's already a module registered with that name
        local name = instance.Name
        if required[name] then
            warn("[AeroServer] There is already a module registered with the same name: " .. tostring(name))
            return
        end

        -- Require and wrap script
        local status, requiredScript = pcall(function()
            local obj = require(instance)
            if (type(obj) == "table") then
                AeroServer:WrapModule(obj, true)
                return obj
            end
            return obj
        end)

        -- Error - Failed to load dependency
        if not status then
            local err = tostring(requiredScript)
            warn("[AeroServer] Failed to register dependency: " .. tostring(instance:GetFullName() .. ". Error: " .. err))
            return
        end

        -- Register
        required[name] = {
            Module = requiredScript;
            Type = moduleType;
            Init = false;
        }
    end
end

local function InitServices()
    -- Collect services
    local services = {}
    for name, data in pairs(required) do
        if data.Type == "Service" then
            services[name] = data
        end
    end

    -- Create client data:
    for name, data in pairs(services) do
        local service = data.Module

        -- Create remote folders
        local remoteFolder = Instance.new("Folder")
        remoteFolder.Name = name
        remoteFolder.Parent = remoteServices

        -- Create client table
        if (type(service.Client) ~= "table") then
            service.Client = {}
        end
        service.Client.Server = service

        -- Set remote folder
        service._remoteFolder = remoteFolder
    end

    -- Initialize services:
    for name, data in pairs(services) do
        local service = data.Module

        -- Init
        if (type(service.Init) == "function") then
            service:Init()
        end

        -- Register client functions
        for funcName, func in pairs(service.Client) do
            if (type(func) == "function") then
                service:RegisterClientFunction(funcName, func)
            end
        end

        -- Mark module as init
        data.Init = true
    end

    -- Mark remote services as loaded
    remoteServicesLoadedValue.Value = true

    -- Start services:
    for name, data in pairs(services) do
        local service = data.Module
        if (type(service.Start) == "function") then
            AeroServer:RunAsync(service.Start, service, name)
        end
    end
end

local function InitScripts()
    -- Collect scripts
    local scripts = {}
    for name, data in pairs(required) do
        if data.Type == "Script" then
            scripts[name] = data
        end
    end

    -- Initialize scripts:
    for name, data in pairs(scripts) do
        local script = data.Module

        -- Init
        if (type(script.Init) == "function") then
            script:Init()
        end

        -- Mark module as init
        data.Init = true
    end

    -- Start scripts:
    for name, data in pairs(scripts) do
        local script = data.Module

        if (type(script.Start) == "function") then
            AeroServer:RunAsync(script.Start, script, name)
        end
    end
end

local function FetchFolders()
    local folderTablesByName = {
        Scripts = scriptsFolders;
        Services = servicesFolders;
        Modules = modulesFolders;
        Shared = sharedFolders;
    }

    local function isAeroFolder(folder)
        if folder:IsA("Folder") then
            if folderTablesByName[folder.Name] then
                local ignoreAeroValue = folder:FindFirstChild("IgnoreAero")
                if not ignoreAeroValue or not ignoreAeroValue.Value then
                    return true
                end
            end
        end
        return false
    end

    local serverSourceFolder = game:GetService("ServerStorage"):WaitForChild("Source")
    for _, child in pairs(serverSourceFolder:GetDescendants()) do
        if isAeroFolder(child) then
            local folderTable = folderTablesByName[child.Name]
            table.insert(folderTable, child)
        end
    end

    local sharedSourceFolder = game:GetService("ReplicatedStorage"):WaitForChild("Source")
    for _, child in pairs(sharedSourceFolder:GetDescendants()) do
        if isAeroFolder(child) then
            local folderTable = folderTablesByName[child.Name]
            table.insert(folderTable, child)
        end
    end
end

local function Init()
    -- Expose server framework to client and global scope:
    _G.Aero = AeroServer

    -- Give other scripts some time to run before Aero
    wait(1)

    -- Fetch folders
    FetchFolders()

    -- Require lazy dependencies
    RegisterDependencies(modulesFolders, "Module")
    RegisterDependencies(sharedFolders, "Shared")
    RegisterDependencies(scriptsFolders, "Script")
    RegisterDependencies(servicesFolders, "Service")

    -- Init dependencies
    ParamUtil = AeroServer:Require("ParamUtil")
    Event = AeroServer:Require("Event")

    -- Init services and scripts
    InitServices()
    InitScripts()

    -- Give scripts and services time to start and register everything
    wait(5)

    -- Set framework as loaded
    AeroServer.Loaded = true
end

Init()