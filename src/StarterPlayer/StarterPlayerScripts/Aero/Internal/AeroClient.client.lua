---
---@class AeroClient
---
local AeroClient = {
    Loaded = false;
    Events = {};
    ServiceEvents = {};

    ---@type Player
    Player = game:GetService("Players").LocalPlayer;
}

local mt = { __index = AeroClient }

local controllersFolders = {}
local modulesFolders = {}
local scriptsFolders = {}
local sharedFolders = {}
local required = {}

local ParamUtil ---@type ParamUtil
local Event ---@type Event

---
---Requires a dependency by its name. It can be a module, script, service, all kinds of dependencies will be checked.
---@generic T
---@param name string
---@return T
---
function AeroClient:Require(name)
    local result = required[name]

    -- Error - Module not found
    if not result then
        error("Failed to require dependency called \"" .. tostring(name) .. "\".", 2)
    end

    -- Init module if necessary
    if not result.Init then
        local status, err = pcall(function()
            AeroClient:WrapModule(result.Module)
        end)
        if not status then
            error("Failed to require dependency called \"" .. tostring(name) .. "\": " .. tostring(err), 2)
        end
    end

    -- Return module
    return result.Module
end

---
---Registers a client-side event with the given name. All events need unique names.
---@param eventName string
---@return Event
---
function AeroClient:RegisterEvent(eventName)
    assert(not AeroClient.Events[eventName], string.format("The event name '%s' is already registered.", eventName))
    local event = Event.new()
    AeroClient.Events[eventName] = event
    return event
end

---
---Fires an event to this client.
---@param eventName string
---@vararg data Multiple parameters are accepted, but usually a table holding all data (recommended).
---
function AeroClient:FireEvent(eventName, ...)
    assert(AeroClient.Events[eventName], string.format("The event name '%s' is not registered.", eventName))
    AeroClient.Events[eventName]:Fire(...)
end

---
---Connects a listener function to an event, which will be called each time the event is fired.
---@param eventName string
---@param func fun(table) Listener function that receives a table parameter containing all event data.
---
function AeroClient:ConnectEvent(eventName, func)
    assert(AeroClient.Events[eventName], string.format("The event name '%s' is not registered.", eventName))
    return AeroClient.Events[eventName]:Connect(func)
end

---
---Connects a listener function to an event fired from the server to this client.
---@param eventName string
---@param func fun(table) Listener function that receives a table parameter containing all event data.
---
function AeroClient:ConnectServiceEvent(eventName, func)
    assert(AeroClient.ServiceEvents[eventName], string.format("The service event name '%s' is not registered.", eventName))
    return AeroClient.ServiceEvents[eventName]:Connect(func)
end

---
---Waits for an event to be fired, yielding the thread.
---@param eventName string
---
function AeroClient:WaitForEvent(eventName)
    assert(AeroClient.Events[eventName], string.format("The event name '%s' is not registered.", eventName))
    return AeroClient.Events[eventName]:Wait()
end

---
---Waits for an event to be fired from the server to this client, yielding the thread.
---@param eventName string
---
function AeroClient:WaitForServiceEvent(eventName)
    assert(AeroClient.ServiceEvents[eventName], string.format("The service event name '%s' is not registered.", eventName))
    return AeroClient.ServiceEvents[eventName]:Wait()
end

---
---Runs a function asynchronously via coroutines.
---@param func function Function to be executed asynchronously.
---@param module table Aero module passed as self to the given function. Optional.
---@param name string Name of the function for debug purposes.Optional.
---
function AeroClient:RunAsync(func, module, name)
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
---Wraps a table as an Aero module, inheriting all Aero functions.
---Init and Start functions are automatically called.
---@param tbl table
---@param skipInit boolean Whether or not initialization functions should be skipped. Defaults to false.
---@return T
---
function AeroClient:WrapModule(tbl, skipInit)
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
            AeroClient:RunAsync(tbl.Start, tbl, "Wrapped Module")
        end
    end
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
            warn("[AeroClient] There is already a module registered with the same name: " .. tostring(name))
            return
        end

        -- Require and wrap script
        local status, requiredScript = pcall(function()
            local obj = require(instance)
            if (type(obj) == "table") then
                AeroClient:WrapModule(obj, true)
                return obj
            end
            return obj
        end)

        -- Error - Failed to load dependency
        if not status then
            local err = tostring(requiredScript)
            warn("[AeroClient] Failed to register dependency: " .. tostring(instance:GetFullName() .. ". Error: " .. err))
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

local function LoadService(serviceFolder)
    if required[serviceFolder.Name] then
        warn("[AeroClient] There is already a module registered with the same name: " .. tostring(serviceFolder.Name))
        return
    end

    local service = {}
    required[serviceFolder.Name] = {
        Module = service;
        Type = "Service";
        Init = true;
    }
    for _, v in pairs(serviceFolder:GetChildren()) do
        if (v:IsA("RemoteEvent")) then
            local event = Event.new()
            local fireEvent = event.Fire
            function event:Fire(...)
                local success, err = ParamUtil:IsValidForNetworking({ ... })
                if not success then
                    error("Error while firing event to server: " .. err, 2)
                end
                v:FireServer(...)
            end
            v.OnClientEvent:Connect(function(...)
                fireEvent(event, ...)
            end)
            AeroClient.ServiceEvents[v.Name] = event
            service[v.Name] = event
        elseif (v:IsA("RemoteFunction")) then
            local func = function(self, ...)
                local success, err = ParamUtil:IsValidForNetworking({ ... })
                if not success then
                    error("Error while firing event to server: " .. err, 2)
                end
                return v:InvokeServer(...)
            end
            AeroClient.ServiceEvents[v.Name] = func
            service[v.Name] = func
        end
    end
end

local function LoadServices()
    local remoteServices = game:GetService("ReplicatedStorage"):WaitForChild("AeroRemoteServices")
    for _, serviceFolder in pairs(remoteServices:GetChildren()) do
        if (serviceFolder:IsA("Folder")) then
            LoadService(serviceFolder)
        end
    end
end

local function InitControllers()
    -- Collect controllers
    local controllers = {}
    for name, data in pairs(required) do
        if data.Type == "Controller" then
            controllers[name] = data
        end
    end

    -- Initialize controllers:
    for name, data in pairs(controllers) do
        local controller = data.Module

        -- Init
        if (type(controller.Init) == "function") then
            controller:Init()
        end

        -- Mark module as init
        data.Init = true
    end

    -- Start controllers:
    for name, data in pairs(controllers) do
        local controller = data.Module

        if (type(controller.Start) == "function") then
            AeroClient:RunAsync(controller.Start, controller, name)
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
            AeroClient:RunAsync(script.Start, script, name)
        end
    end
end

local function FetchFolders()
    local folderTablesByName = {
        Scripts = scriptsFolders;
        Controllers = controllersFolders;
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

    local clientSourceFolder = AeroClient.Player.PlayerScripts:WaitForChild("Source")
    for _, child in pairs(clientSourceFolder:GetDescendants()) do
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
    -- Expose client framework globally:
    _G.Aero = AeroClient

    -- Give other scripts some time to run before Aero
    wait(1)

    -- Fetch folders
    FetchFolders()

    -- Require lazy dependencies
    RegisterDependencies(modulesFolders, "Module")
    RegisterDependencies(sharedFolders, "Shared")
    RegisterDependencies(scriptsFolders, "Script")
    RegisterDependencies(controllersFolders, "Controller")

    -- Init dependencies
    ParamUtil = AeroClient:Require("ParamUtil")
    Event = AeroClient:Require("Event")

    -- Load server-side services:
    LoadServices()

    -- Init controllers and scripts
    InitControllers()
    InitScripts()

    -- Set framework as loaded
    AeroClient.Loaded = true
end

Init()