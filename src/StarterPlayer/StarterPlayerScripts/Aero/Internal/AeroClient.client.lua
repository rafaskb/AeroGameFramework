---
---@class AeroClient
---
local AeroClient = {
    Loaded = false;
    Controllers = {};
    Modules = {};
    Scripts = {};
    Shared = {};
    Services = {};
    Events = {};
    ServiceEvents = {};
    Player = game:GetService("Players").LocalPlayer;
}

local mt = { __index = AeroClient }

local controllersFolders = {}
local modulesFolders = {}
local scriptsFolders = {}
local sharedFolders = {}

---@type ParamUtil
local ParamUtil

---
---Requires a dependency by its name. It can be a module, script, service, all kinds of dependencies will be checked.
---@generic T
---@param name string
---@return T
---
function AeroClient:Require(name)
    return self.Controllers[name] or self.Modules[name] or self.Scrips[name] or self.Shared[name] or self.Services[name]
end

---
---Registers a client-side event with the given name. All events need unique names.
---@param eventName string
---@return Event
---
function AeroClient:RegisterEvent(eventName)
    assert(not AeroClient.Events[eventName], string.format("The event name '%s' is already registered.", eventName))

    local event = self.Shared.Event.new()
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
    return AeroClient.Events[eventName]:Wait()
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
---@return T
---
function AeroClient:WrapModule(tbl)
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

    if (type(tbl.Init) == "function" and not tbl.__aeroPreventInit) then
        tbl:Init()
    end
    if (type(tbl.Start) == "function" and not tbl.__aeroPreventStart) then
        AeroClient:RunAsync(tbl.Start, tbl, "Wrapped Module")
    end
end

local function LoadModuleRecursively(module, loadFunc)
    if module:IsA("ModuleScript") then
        local success, err = pcall(function()
            loadFunc(module)
        end)
        if not success then
            warn("[AeroClient] Error loading module " .. tostring(module) .. ": " .. tostring(err))
        end
    elseif module:IsA("Folder") then
        for _, child in pairs(module:GetChildren()) do
            LoadModuleRecursively(child, loadFunc)
        end
    end
end

local function LoadService(serviceFolder)
    local service = {}
    AeroClient.Services[serviceFolder.Name] = service
    for _, v in pairs(serviceFolder:GetChildren()) do
        if (v:IsA("RemoteEvent")) then
            local event = AeroClient.Shared.Event.new()
            local fireEvent = event.Fire
            function event:Fire(...)
                local success, err = ParamUtil:IsValidForNetworking({ ... })
                if not success then
                    error("Error while firing event to server: " .. err, 1)
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
                    error("Error while firing event to server: " .. err, 1)
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


-- Setup table to load modules on demand:
local function LazyLoadSetup(tbl, folderArray, recursive)
    setmetatable(tbl, {
        __index = function(t, i)
            local rawObj
            for _, folder in pairs(folderArray) do
                rawObj = folder:FindFirstChild(i)
                if rawObj ~= nil then
                    break
                end
            end

            local status, obj = pcall(function()
                local obj = require(rawObj)
                if (type(obj) == "table") then
                    AeroClient:WrapModule(obj)
                end
                return obj
            end)

            if not status then
                if recursive then
                    local name = tostring(rawObj)
                    local childTable = {}
                    tbl[name] = childTable
                    LazyLoadSetup(childTable, rawObj)
                    rawset(t, i, childTable)
                    obj = childTable
                else
                    error("Attempted to index nil value: " .. i)
                end
            end

            rawset(t, i, obj)
            return obj
        end;
    })
end

local function LoadController(module)
    local controller = require(module)
    AeroClient.Controllers[module.Name] = controller
    setmetatable(controller, mt)
end

local function InitController(controller, name)
    if (type(controller.Init) == "function") then
        controller:Init()
    end
end

local function StartController(controller, name)
    -- Start controllers on separate threads:
    if (type(controller.Start) == "function") then
        AeroClient:RunAsync(controller.Start, controller, name)
    end
end

local function LoadScript(module)
    local clientScript = require(module)
    AeroClient.Scripts[module.Name] = clientScript
    setmetatable(clientScript, mt)
end

local function InitScript(clientScript, name)
    if (type(clientScript.Init) == "function") then
        clientScript:Init()
    end
end

local function StartScript(clientScript, name)

    -- Start scripts on separate threads:
    if (type(clientScript.Start) == "function") then
        AeroClient:RunAsync(clientScript.Start, clientScript, name)
    end
end

local function InitControllers()
    -- Load service modules:
    for _, controllersFolder in pairs(controllersFolders) do
        LoadModuleRecursively(controllersFolder, LoadController)
    end

    -- Initialize controllers:
    for name, controller in pairs(AeroClient.Controllers) do
        InitController(controller, name)
    end

    -- Start controllers:
    for name, controller in pairs(AeroClient.Controllers) do
        StartController(controller, name)
    end
end

local function InitScripts()
    -- Load script modules:
    for _, scriptsFolder in pairs(scriptsFolders) do
        LoadModuleRecursively(scriptsFolder, LoadScript)
    end

    -- Initialize scripts:
    for name, clientScript in pairs(AeroClient.Scripts) do
        InitScript(clientScript, name)
    end

    -- Start scripts:
    for name, clientScript in pairs(AeroClient.Scripts) do
        StartScript(clientScript, name)
    end
end

local function FetchFolders()
    local function isAeroFolder(folder)
        if folder:IsA("Folder") then
            if folder.Name == "Aero" then
                return true
            end
            local aeroFolderValue = folder:FindFirstChild("AeroFolder")
            if aeroFolderValue and aeroFolderValue.Value then
                return true
            end
        end
        return false
    end

    local clientSourceFolder = AeroClient.Player.PlayerScripts:WaitForChild("Source")
    for _, child in pairs(clientSourceFolder:GetChildren()) do
        if isAeroFolder(child) then
            table.insert(controllersFolders, child:FindFirstChild("Controllers"))
            table.insert(modulesFolders, child:FindFirstChild("Modules"))
            table.insert(scriptsFolders, child:FindFirstChild("Scripts"))
        end
    end

    local sharedSourceFolder = game:GetService("ReplicatedStorage"):WaitForChild("Source")
    for _, child in pairs(sharedSourceFolder:GetChildren()) do
        if isAeroFolder(child) then
            table.insert(sharedFolders, child:FindFirstChild("Shared"))
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

    -- Lazy load modules:
    LazyLoadSetup(AeroClient.Modules, modulesFolders, true)
    LazyLoadSetup(AeroClient.Shared, sharedFolders, true)
    LazyLoadSetup(AeroClient.Scripts, scriptsFolders, true)

    -- Init dependencies
    ParamUtil = AeroClient.Shared.ParamUtil

    -- Load server-side services:
    LoadServices()

    -- Init controllers and scripts
    InitControllers()
    InitScripts()

    -- Set framework as loaded
    AeroClient.Loaded = true
end

Init()