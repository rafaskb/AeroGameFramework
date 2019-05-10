---
---@class AeroServer
---
local AeroServer = {
    Services = {};
    Modules = {};
    Scripts = {};
    Shared = {};
    Events = {};
    ClientEvents = {};
}

local mt = { __index = AeroServer }

local servicesFolders = {}
local modulesFolders = {}
local scriptsFolders = {}
local sharedFolders = {}

local remoteServices = Instance.new("Folder")
remoteServices.Name = "AeroRemoteServices"
remoteServices.Parent = game:GetService("ReplicatedStorage")

---
---Requires a dependency by its name. It can be a module, script, service, all kinds of dependencies will be checked.
---@generic T
---@param name string
---@return T
---
function AeroServer:Require(name)
    return self.Services[name] or self.Modules[name] or self.Scrips[name] or self.Shared[name]
end

---
---Registers a server-side event with the given name. All events need unique names.
---@param eventName string
---@return Event
---
function AeroServer:RegisterEvent(eventName)
    assert(not AeroServer.Events[eventName], string.format("The event name '%s' is already registered.", eventName))
    local event = self.Shared.Event.new()
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
---@vararg data Multiple parameters are accepted, but usually a table holding all data (recommended).
---
function AeroServer:FireEvent(eventName, ...)
    assert(AeroServer.Events[eventName], string.format("The event name '%s' is not registered.", eventName))
    AeroServer.Events[eventName]:Fire(...)
end

---
---Fires an event to a specific client.
---@param eventName string
---@param client Player Client receiving the event.
---@vararg data Multiple parameters are accepted, but usually a table holding all data (recommended).
---
function AeroServer:FireClientEvent(eventName, client, ...)
    assert(AeroServer.ClientEvents[eventName], string.format("The event name '%s' is not registered.", eventName))
    AeroServer.ClientEvents[eventName]:FireClient(client, ...)
end

---
---Fires an event to all connected clients at once.
---@param eventName string
---@vararg data Multiple parameters are accepted, but usually a table holding all data (recommended).
---
function AeroServer:FireAllClientsEvent(eventName, ...)
    assert(AeroServer.ClientEvents[eventName], string.format("The event name '%s' is not registered.", eventName))
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
---@param func function Function to be executed asynchronously.
---@param module table Aero module passed as self to the given function. Optional.
---@param name string Name of the function for debug purposes.Optional.
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
---Wraps a table as an Aero module, inheriting all Aero functions.
---Init and Start functions are automatically called.
---@param tbl table
---@return T
---
function AeroServer:WrapModule(tbl)
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
        AeroServer:RunAsync(tbl.Start, tbl, "Wrapped Module")
    end
end

local function LoadModuleRecursively(module, loadFunc)
    if module:IsA("ModuleScript") then
        local success, err = pcall(function()
            loadFunc(module)
        end)
        if not success then
            warn("[AeroServer] Error loading module " .. tostring(module) .. ": " .. tostring(err))
        end
    elseif module:IsA("Folder") then
        for _, child in pairs(module:GetChildren()) do
            LoadModuleRecursively(child, loadFunc)
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
                    AeroServer:WrapModule(obj)
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


-- Load service from module:
local function LoadService(module)
    local remoteFolder = Instance.new("Folder")
    remoteFolder.Name = module.Name
    remoteFolder.Parent = remoteServices

    local service = require(module)
    AeroServer.Services[module.Name] = service

    if (type(service.Client) ~= "table") then
        service.Client = {}
    end
    service.Client.Server = service

    setmetatable(service, mt)

    service._remoteFolder = remoteFolder

end

local function InitService(service, name)

    -- Initialize:
    if (type(service.Init) == "function") then
        service:Init()
    end

    -- Client functions:
    for funcName, func in pairs(service.Client) do
        if (type(func) == "function") then
            service:RegisterClientFunction(funcName, func)
        end
    end
end

local function StartService(service, name)
    if (type(service.Start) == "function") then
        AeroServer:RunAsync(service.Start, service, name)
    end
end


-- Load script from module:
local function LoadScript(module)

    local serverScript = require(module)
    AeroServer.Scripts[module.Name] = serverScript

    setmetatable(serverScript, mt)

end

local function InitScript(serverScript, name)

    -- Initialize:
    if (type(serverScript.Init) == "function") then
        serverScript:Init()
    end

end

local function StartScript(serverScript, name)

    -- Start scripts on separate threads:
    if (type(serverScript.Start) == "function") then
        AeroServer:RunAsync(serverScript.Start, serverScript, name)
    end
end

local function InitServices()
    -- Load service modules:
    for _, servicesFolder in pairs(servicesFolders) do
        LoadModuleRecursively(servicesFolder, LoadService)
    end

    -- Initialize services:
    for name, service in pairs(AeroServer.Services) do
        InitService(service, name)
    end

    -- Start services:
    for name, service in pairs(AeroServer.Services) do
        StartService(service, name)
    end
end

local function InitScripts()
    -- Load script modules:
    for _, scriptsFolder in pairs(scriptsFolders) do
        LoadModuleRecursively(scriptsFolder, LoadScript)
    end

    -- Initialize scripts:
    for name, serverScript in pairs(AeroServer.Scripts) do
        InitScript(serverScript, name)
    end

    -- Start scripts:
    for name, serverScript in pairs(AeroServer.Scripts) do
        StartScript(serverScript, name)
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

    local serverSourceFolder = game:GetService("ServerStorage"):WaitForChild("Source")
    for _, child in pairs(serverSourceFolder:GetChildren()) do
        if isAeroFolder(child) then
            table.insert(servicesFolders, child:FindFirstChild("Services"))
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
    -- Give other scripts some time to run before Aero
    wait(1)

    -- Fetch folders
    FetchFolders()

    -- Lazy-load server and shared modules:
    LazyLoadSetup(AeroServer.Modules, modulesFolders, true)
    LazyLoadSetup(AeroServer.Shared, sharedFolders, true)
    LazyLoadSetup(AeroServer.Scripts, scriptsFolders, true)

    -- Init services and scripts
    InitServices()
    InitScripts()

    -- Expose server framework to client and global scope:
    _G.Aero = AeroServer
end

Init()