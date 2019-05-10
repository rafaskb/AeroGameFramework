---
---@class AeroClient
---
local Aero = {
    Controllers = {};
    Modules = {};
    Scripts = {};
    Shared = {};
    Services = {};
    Events = {};
    ServiceEvents = {};
    Player = game:GetService("Players").LocalPlayer;
}

local mt = { __index = Aero }

local controllersFolders = {}
local modulesFolders = {}
local scriptsFolders = {}
local sharedFolders = {}

---
---Requires a dependency by its name. It can be a module, script, service, all kinds of dependencies will be checked.
---@generic T
---@param name string
---@return T
---
function Aero:Require(name)
    return self.Controllers[name] or self.Modules[name] or self.Scrips[name] or self.Shared[name] or self.Services[name]
end

---
---Registers a client-side event with the given name. All events need unique names.
---@param eventName string
---@return Event
---
function Aero:RegisterEvent(eventName)
    assert(not Aero.Events[eventName], string.format("The event name '%s' is already registered.", eventName))

    local event = self.Shared.Event.new()
    Aero.Events[eventName] = event
    return event
end

---
---Fires an event to this client.
---@param eventName string
---@vararg data Multiple parameters are accepted, but usually a table holding all data (recommended).
---
function Aero:FireEvent(eventName, ...)
    assert(Aero.Events[eventName], string.format("The event name '%s' is not registered.", eventName))
    Aero.Events[eventName]:Fire(...)
end

---
---Connects a listener function to an event, which will be called each time the event is fired.
---@param eventName string
---@param func fun(table) Listener function that receives a table parameter containing all event data.
---
function Aero:ConnectEvent(eventName, func)
    assert(Aero.Events[eventName], string.format("The event name '%s' is not registered.", eventName))
    return Aero.Events[eventName]:Connect(func)
end

---
---Connects a listener function to an event fired from the server to this client.
---@param eventName string
---@param func fun(table) Listener function that receives a table parameter containing all event data.
---
function Aero:ConnectServiceEvent(eventName, func)
    assert(Aero.ServiceEvents[eventName], string.format("The service event name '%s' is not registered.", eventName))
    return Aero.ServiceEvents[eventName]:Connect(func)
end

---
---Waits for an event to be fired, yielding the thread.
---@param eventName string
---
function Aero:WaitForEvent(eventName)
    return Aero.Events[eventName]:Wait()
end

---
---Runs a function asynchronously via coroutines.
---@param func function Function to be executed asynchronously.
---@param module table Aero module passed as self to the given function. Optional.
---@param name string Name of the function for debug purposes.Optional.
---
function Aero:RunAsync(func, module, name)
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
function Aero:WrapModule(tbl)
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
        Aero:RunAsync(tbl.Start, tbl, "Wrapped Module")
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
    Aero.Services[serviceFolder.Name] = service
    for _, v in pairs(serviceFolder:GetChildren()) do
        if (v:IsA("RemoteEvent")) then
            local event = Aero.Shared.Event.new()
            local fireEvent = event.Fire
            function event:Fire(...)
                v:FireServer(...)
            end
            v.OnClientEvent:Connect(function(...)
                fireEvent(event, ...)
            end)
            Aero.ServiceEvents[v.Name] = event
            service[v.Name] = event
        elseif (v:IsA("RemoteFunction")) then
            local func = function(self, ...)
                return v:InvokeServer(...)
            end
            Aero.ServiceEvents[v.Name] = func
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
                    Aero:WrapModule(obj)
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
    Aero.Controllers[module.Name] = controller
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
        Aero:RunAsync(controller.Start, controller, name)
    end
end

local function LoadScript(module)
    local clientScript = require(module)
    Aero.Scripts[module.Name] = clientScript
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
        Aero:RunAsync(clientScript.Start, clientScript, name)
    end
end

local function InitControllers()
    -- Load service modules:
    for _, controllersFolder in pairs(controllersFolders) do
        LoadModuleRecursively(controllersFolder, LoadController)
    end

    -- Initialize controllers:
    for name, controller in pairs(Aero.Controllers) do
        InitController(controller, name)
    end

    -- Start controllers:
    for name, controller in pairs(Aero.Controllers) do
        StartController(controller, name)
    end
end

local function InitScripts()
    -- Load script modules:
    for _, scriptsFolder in pairs(scriptsFolders) do
        LoadModuleRecursively(scriptsFolder, LoadScript)
    end

    -- Initialize scripts:
    for name, clientScript in pairs(Aero.Scripts) do
        InitScript(clientScript, name)
    end

    -- Start scripts:
    for name, clientScript in pairs(Aero.Scripts) do
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

    local clientSourceFolder = Aero.Player.PlayerScripts:WaitForChild("Source")
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
    -- Give other scripts some time to run before Aero
    wait(1)

    -- Fetch folders
    FetchFolders()

    -- Lazy load modules:
    LazyLoadSetup(Aero.Modules, modulesFolders, true)
    LazyLoadSetup(Aero.Shared, sharedFolders, true)
    LazyLoadSetup(Aero.Scripts, scriptsFolders, true)

    -- Load server-side services:
    LoadServices()

    -- Init controllers and scripts
    InitControllers()
    InitScripts()

    -- Expose client framework globally:
    _G.Aero = Aero

end

Init()