-- Aero Client
-- Crazyman32
-- July 21, 2017



local Aero = {
    Controllers = {};
    Modules     = {};
    Scripts     = {};
    Shared      = {};
    Services    = {};
    Events      = {};
    Player      = game:GetService("Players").LocalPlayer;
}

local USE_CUSTOM_ERROR_HANDLING = false

local mt = {__index = Aero}

local controllersFolder = script.Parent:WaitForChild("Controllers")
local modulesFolder = script.Parent:WaitForChild("Modules")
local scriptsFolder = script.Parent:WaitForChild("Scripts")
local sharedFolder = game:GetService("ReplicatedStorage"):WaitForChild("Aero"):WaitForChild("Shared")


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


function Aero:WaitForEvent(eventName)
	return Aero.Events[eventName]:Wait()
end



function RunSafe(name, f)
	-- Run function
	local status, err = xpcall(f, debug.traceback)
	if not status then

		-- Print error
		local firstLine = true
		local msg = " --- CLIENT ERROR ---"
		for s in err:gmatch("[^\r\n]+") do
			local isAero = s:find("AeroClient")
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


function Aero:WrapModule(tbl)
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
			coroutine.wrap(tbl.Sound)(tbl)
		end
	end
end


function LoadService(serviceFolder)
	local service = {}
	Aero.Services[serviceFolder.Name] = service
	for _,v in pairs(serviceFolder:GetChildren()) do
		if (v:IsA("RemoteEvent")) then
			local event = Aero.Shared.Event.new()
			local fireEvent = event.Fire
			function event:Fire(...)
				v:FireServer(...)
			end
			v.OnClientEvent:Connect(function(...)
				fireEvent(event, ...)
			end)
			service[v.Name] = event
		elseif (v:IsA("RemoteFunction")) then
			service[v.Name] = function(self, ...)
				return v:InvokeServer(...)
			end
		end
	end
end


function LoadServices()
	local remoteServices = game:GetService("ReplicatedStorage"):WaitForChild("Aero"):WaitForChild("AeroRemoteServices")
	for _,serviceFolder in pairs(remoteServices:GetChildren()) do
		if (serviceFolder:IsA("Folder")) then
			LoadService(serviceFolder)
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
		if USE_CUSTOM_ERROR_HANDLING then
			RunSafe(name, function()
				controller:Init()
			end)
		else
			controller:Init()
		end
	end
end


function StartController(controller, name)

	-- Start controllers on separate threads:
	if (type(controller.Start) == "function") then
		if USE_CUSTOM_ERROR_HANDLING then
			RunSafe(name, function()
				controller:Start()
			end)
		else
			coroutine.wrap(controller.Start)(controller)
		end
	end
end

function LoadScript(module)
	local clientScript = require(module)
	Aero.Scripts[module.Name] = clientScript
	setmetatable(clientScript, mt)
end


function InitScript(clientScript, name)
	if (type(clientScript.Init) == "function") then
		if USE_CUSTOM_ERROR_HANDLING then
			RunSafe(name, function()
				clientScript:Init()
			end)
		else
			clientScript:Init()
		end
	end
end


function StartScript(clientScript, name)

	-- Start scripts on separate threads:
	if (type(clientScript.Start) == "function") then
		if USE_CUSTOM_ERROR_HANDLING then
			RunSafe(name, function()
				clientScript:Start()
			end)
		else
			coroutine.wrap(clientScript.Start)(clientScript)
		end
	end
end


local function InitControllers()

	-- Load controllers:
	for _,module in pairs(controllersFolder:GetChildren()) do
		if (module:IsA("ModuleScript")) then
			LoadController(module)
		end
	end
	
	-- Initialize controllers:
	for name,controller in pairs(Aero.Controllers) do
		InitController(controller, name)
	end
	
	-- Start controllers:
	for name,controller in pairs(Aero.Controllers) do
		StartController(controller, name)
	end

end


local function InitScripts()

	-- Load scripts:
	for _,module in pairs(scriptsFolder:GetDescendants()) do
		if (module:IsA("ModuleScript")) then
			LoadScript(module)
		end
	end

	-- Initialize scripts:
	for name,clientScript in pairs(Aero.Scripts) do
		InitScript(clientScript, name)
	end

	-- Start scripts:
	for name,clientScript in pairs(Aero.Scripts) do
		StartScript(clientScript, name)
	end

end


function Init()
	
	-- Lazy load modules:
	LazyLoadSetup(Aero.Modules, modulesFolder)
	LazyLoadSetup(Aero.Shared, sharedFolder, true)
	LazyLoadSetup(Aero.Scripts, scriptsFolder)

	-- Load server-side services:
	LoadServices()

	-- Init controllers and scripts
	InitControllers()
	InitScripts()

	-- Expose client framework globally:
	_G.Aero = Aero
	
end


Init()