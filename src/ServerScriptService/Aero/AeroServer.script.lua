-- Aero Server
-- Crazyman32
-- July 21, 2017



local AeroServer = {
    Services = {};
    Modules = {};
    Scripts = {};
    Shared = {};
    Events = {};
    ClientEvents = {};
}

local USE_CUSTOM_ERROR_HANDLING = false

local mt = { __index = AeroServer }

local servicesFolder = game:GetService("ServerStorage"):WaitForChild("Aero"):WaitForChild("Services")
local modulesFolder = game:GetService("ServerStorage"):WaitForChild("Aero"):WaitForChild("Modules")
local scriptsFolder = game:GetService("ServerStorage"):WaitForChild("Aero"):WaitForChild("Scripts")
local sharedFolder = game:GetService("ReplicatedStorage"):WaitForChild("Aero"):WaitForChild("Shared")

local remoteServices = Instance.new("Folder")
remoteServices.Name = "AeroRemoteServices"

function AeroServer:RegisterEvent(eventName)
    assert(not AeroServer.Events[eventName], string.format("The event name '%s' is already registered.", eventName))
    local event = self.Shared.Event.new()
    AeroServer.Events[eventName] = event
    return event
end

function AeroServer:RegisterClientEvent(eventName)
    assert(not AeroServer.ClientEvents[eventName], string.format("The client event name '%s' is already registered.", eventName))
    local event = Instance.new("RemoteEvent")
    event.Name = eventName
    event.Parent = self._remoteFolder
    AeroServer.ClientEvents[eventName] = event
    return event
end

function AeroServer:FireEvent(eventName, ...)
    assert(AeroServer.Events[eventName], string.format("The event name '%s' is not registered.", eventName))
    AeroServer.Events[eventName]:Fire(...)
end

function AeroServer:FireClientEvent(eventName, client, ...)
    assert(AeroServer.ClientEvents[eventName], string.format("The event name '%s' is not registered.", eventName))
    AeroServer.ClientEvents[eventName]:FireClient(client, ...)
end

function AeroServer:FireAllClientsEvent(eventName, ...)
    assert(AeroServer.ClientEvents[eventName], string.format("The event name '%s' is not registered.", eventName))
    AeroServer.ClientEvents[eventName]:FireAllClients(...)
end

function AeroServer:ConnectEvent(eventName, func)
    assert(AeroServer.Events[eventName], string.format("The event name '%s' is not registered.", eventName))
    return AeroServer.Events[eventName]:Connect(func)
end

function AeroServer:ConnectClientEvent(eventName, func)
    assert(AeroServer.ClientEvents[eventName], string.format("The event name '%s' is not registered.", eventName))
    return AeroServer.ClientEvents[eventName].OnServerEvent:Connect(func)
end

function AeroServer:WaitForEvent(eventName)
    return AeroServer.Events[eventName]:Wait()
end

function AeroServer:WaitForClientEvent(eventName)
    return AeroServer.ClientEvents[eventName]:Wait()
end

function AeroServer:RegisterClientFunction(funcName, func)
    local remoteFunc = Instance.new("RemoteFunction")
    remoteFunc.Name = funcName
    remoteFunc.OnServerInvoke = function(...)
        return func(self.Client, ...)
    end
    remoteFunc.Parent = self._remoteFolder
    return remoteFunc
end

function RunSafe(name, f)
    -- Run function
    local status, err = xpcall(f, debug.traceback)
    if not status then

        -- Print error
        local firstLine = true
        local msg = " --- SERVER ERROR ---"
        for s in err:gmatch("[^\r\n]+") do
            local isAero = s:find("AeroServer")
            local isStack = s == "Stack Begin" or s == "Stack End"
            if not isAero and not isStack then
                if firstLine then
                    msg = msg .. "\nUnhandled error in " .. name .. ": " .. s .. "\nSTACK TRACE:\n"
                    firstLine = false
                else
                    msg = msg .. "        at " .. s .. "\n"
                end
            end
        end
        msg = msg .. "\nORIGINAL ERROR:\n" .. err .. "\n"
        warn(msg)
    end
end

function AeroServer:WrapModule(tbl)
    assert(type(tbl) == "table", "Expected table for argument")
    setmetatable(tbl, mt)
    if (type(tbl.Init) == "function") then
        if USE_CUSTOM_ERROR_HANDLING then
            RunSafe("Wrapped Module", function()
                tbl:Init()
            end)
        else
            tbl:Init()
        end
    end
    if (type(tbl.Start) == "function") then
        if USE_CUSTOM_ERROR_HANDLING then
            RunSafe("Wrapped Module", function()
                tbl:Start()
            end)
        else
            coroutine.wrap(tbl.Start)(tbl)
        end
    end
end

-- Setup table to load modules on demand:
function LazyLoadSetup(tbl, folder, recursive)
    setmetatable(tbl, {
        __index = function(t, i)
            local rawObj = folder[i]

            if rawObj == nil then
                error("Attempted to index nil value: " .. i)
                return nil
            end

            local status, obj = pcall(function()
                local obj = require(rawObj)
                if (type(obj) == "table") then
                    AeroServer:WrapModule(obj)
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


-- Load service from module:
function LoadService(module)
	
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

function InitService(service, name)

    -- Initialize:
    if (type(service.Init) == "function") then
        if USE_CUSTOM_ERROR_HANDLING then
            RunSafe(name, function()
                service:Init()
            end)
        else
            service:Init()
        end
    end

    -- Client functions:
    for funcName, func in pairs(service.Client) do
        if (type(func) == "function") then
            if USE_CUSTOM_ERROR_HANDLING then
                RunSafe(name, function()
                    service:RegisterClientFunction(funcName, func)
                end)
            else
                service:RegisterClientFunction(funcName, func)
            end
        end
    end
end

function StartService(service, name)
    if (type(service.Start) == "function") then
        if USE_CUSTOM_ERROR_HANDLING then
            RunSafe(name, function()
                service:Start()
            end)
        else
            coroutine.wrap(service.Start)(service)
        end
    end
end


-- Load script from module:
function LoadScript(module)

	local serverScript = require(module)
	AeroServer.Scripts[module.Name] = serverScript

	setmetatable(serverScript, mt)

end

function InitScript(serverScript, name)

    -- Initialize:
    if (type(serverScript.Init) == "function") then
        if USE_CUSTOM_ERROR_HANDLING then
            RunSafe(name, function()
                serverScript:Init()
            end)
        else
            serverScript:Init()
        end
    end

end

function StartScript(serverScript, name)

    -- Start scripts on separate threads:
    if (type(serverScript.Start) == "function") then
        if USE_CUSTOM_ERROR_HANDLING then
            RunSafe(name, function()
                serverScript:Start()
            end)
        else
            coroutine.wrap(serverScript.Start)(serverScript)
        end
    end
end

local function InitServices()
    -- Load service modules:
    for _, module in pairs(servicesFolder:GetChildren()) do
        if (module:IsA("ModuleScript")) then
            LoadService(module)
        end
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
    for _, module in pairs(scriptsFolder:GetDescendants()) do
        if (module:IsA("ModuleScript")) then
            LoadScript(module)
        end
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

function Init()

    -- Lazy-load server and shared modules:
    LazyLoadSetup(AeroServer.Modules, modulesFolder)
    LazyLoadSetup(AeroServer.Shared, sharedFolder, true)
    LazyLoadSetup(AeroServer.Scripts, scriptsFolder)

    -- Init services and scripts
    InitServices()
    InitScripts()

    -- Expose server framework to client and global scope:
    remoteServices.Parent = game:GetService("ReplicatedStorage").Aero
    _G.AeroServer = AeroServer

end

Init()