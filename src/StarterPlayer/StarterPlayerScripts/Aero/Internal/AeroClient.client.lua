-- Aero Client
-- Crazyman32
-- July 21, 2017



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

function Aero:RegisterEvent(eventName)
    assert(not Aero.Events[eventName], string.format("The event name '%s' is already registered.", eventName))

    local event = self.Shared.Event.new()
    Aero.Events[eventName] = event
    return event
end

function Aero:FireEvent(eventName, ...)
    assert(Aero.Events[eventName], string.format("The event name '%s' is not registered.", eventName))
    Aero.Events[eventName]:Fire(...)
end

function Aero:ConnectEvent(eventName, func)
    assert(Aero.Events[eventName], string.format("The event name '%s' is not registered.", eventName))
    return Aero.Events[eventName]:Connect(func)
end

function Aero:ConnectServiceEvent(eventName, func)
    assert(Aero.ServiceEvents[eventName], string.format("The service event name '%s' is not registered.", eventName))
    return Aero.ServiceEvents[eventName]:Connect(func)
end

function Aero:WaitForEvent(eventName)
    return Aero.Events[eventName]:Wait()
end

function Aero:RunAsync(func, service, name)
    name = name or "Unknown Source"
    local thread = coroutine.create(func)
    local status, err = coroutine.resume(thread, service)
    if not status then
        local tracebackMsg = string.format("%s: %s", name, err)
        local traceback = debug.traceback(thread, tracebackMsg, 2)
        warn(traceback)
    end
end

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

function LoadService(serviceFolder)
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
function LazyLoadSetup(tbl, folderArray, recursive)
    setmetatable(tbl, {
        __index = function(t, i)
            local rawObj
            for _, folder in pairs(folderArray) do
                rawObj = folder[i]
                if rawObj ~= nil then
                    break
                end
            end

            if rawObj == nil then
                error("Attempted to index nil value: " .. i)
                return nil
            end

            local status, obj = pcall(function()
                local obj = require(rawObj)
                if (type(obj) == "table") then
                    Aero:WrapModule(obj)
                end
                return obj
            end)

            if not status and recursive then
                local name = tostring(rawObj)
                local childTable = {}
                tbl[name] = childTable
                LazyLoadSetup(childTable, rawObj)
                rawset(t, i, childTable)
                obj = childTable
            end

            rawset(t, i, obj)
            return obj
        end;
    })
end

function LoadController(module)
    local controller = require(module)
    Aero.Controllers[module.Name] = controller
    setmetatable(controller, mt)
end

function InitController(controller, name)
    if (type(controller.Init) == "function") then
        controller:Init()
    end
end

function StartController(controller, name)
    -- Start controllers on separate threads:
    if (type(controller.Start) == "function") then
        Aero:RunAsync(controller.Start, controller, name)
    end
end

function LoadScript(module)
    local clientScript = require(module)
    Aero.Scripts[module.Name] = clientScript
    setmetatable(clientScript, mt)
end

function InitScript(clientScript, name)
    if (type(clientScript.Init) == "function") then
        clientScript:Init()
    end
end

function StartScript(clientScript, name)

    -- Start scripts on separate threads:
    if (type(clientScript.Start) == "function") then
        Aero:RunAsync(clientScript.Start, clientScript, name)
    end
end

local function InitControllers()
    -- Load controllers:
    for _, controllersFolder in pairs(controllersFolders) do
        for _, module in pairs(controllersFolder:GetChildren()) do
            if (module:IsA("ModuleScript")) then
                local success, err = pcall(function()
                    LoadController(module)
                end)
                if not success then
                    warn("[AeroClient] Error loading controller " .. tostring(module) .. ": " .. tostring(err))
                end
            end
        end
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
    -- Load scripts:
    for _, scriptsFolder in pairs(scriptsFolders) do
        for _, module in pairs(scriptsFolder:GetDescendants()) do
            if (module:IsA("ModuleScript")) then
                local success, err = pcall(function()
                    LoadScript(module)
                end)
                if not success then
                    warn("[AeroClient] Error loading script " .. tostring(module) .. ": " .. tostring(err))
                end
            end
        end
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

function Init()
    -- Give other scripts some time to run before Aero
    wait(1)

    -- Fetch folders
    FetchFolders()

    -- Lazy load modules:
    LazyLoadSetup(Aero.Modules, modulesFolders)
    LazyLoadSetup(Aero.Shared, sharedFolders, true)
    LazyLoadSetup(Aero.Scripts, scriptsFolders)

    -- Load server-side services:
    LoadServices()

    -- Init controllers and scripts
    InitControllers()
    InitScripts()

    -- Expose client framework globally:
    _G.Aero = Aero

end

Init()