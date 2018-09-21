-- Aero Client
-- Crazyman32
-- July 21, 2017



local Aero = {
	Controllers = {};
	Modules     = {};
	Scripts     = {};
	Shared      = {};
	Services    = {};
	Player      = game:GetService("Players").LocalPlayer;
}

local mt = {__index = Aero}

local controllersFolder = script.Parent:WaitForChild("Controllers")
local modulesFolder = script.Parent:WaitForChild("Modules")
local scriptsFolder = script.Parent:WaitForChild("Scripts")
local sharedFolder = game:GetService("ReplicatedStorage"):WaitForChild("Aero"):WaitForChild("Shared")


function Aero:RegisterEvent(eventName)
	local event = self.Shared.Event.new()
	self._events[eventName] = event
	return event
end


function Aero:FireEvent(eventName, ...)
	self._events[eventName]:Fire(...)
end


function Aero:ConnectEvent(eventName, func)
	return self._events[eventName]:Connect(func)
end


function Aero:WaitForEvent(eventName)
	return self._events[eventName]:Wait()
end


function Aero:WrapModule(tbl)
	assert(type(tbl) == "table", "Expected table for argument")
	tbl._events = {}
	setmetatable(tbl, mt)
	if (type(tbl.Init) == "function") then
		tbl:Init()
	end
	if (type(tbl.Start) == "function") then
		coroutine.wrap(tbl.Start)(tbl)
	end
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
		warn(msg)
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
function LazyLoadSetup(tbl, folder)
	setmetatable(tbl, {
		__index = function(t, i)
			local obj = require(folder[i])
			if (type(obj) == "table") then
				Aero:WrapModule(obj)
			end
			rawset(t, i, obj)
			return obj
		end;
	})
end


function LoadController(module)
	local controller = require(module)
	Aero.Controllers[module.Name] = controller
	controller._events = {}
	setmetatable(controller, mt)
end


function InitController(controller, name)
	if (type(controller.Init) == "function") then
		RunSafe(name, function()
			controller:Init()
		end)
	end
end


function StartController(controller, name)

	-- Start controllers on separate threads:
	if (type(controller.Start) == "function") then
		RunSafe(name, function()
			controller:Start()
		end)
	end

end

function LoadScript(module)
	local clientScript = require(module)
	Aero.Scripts[module.Name] = clientScript
	setmetatable(clientScript, mt)
end


function InitScript(clientScript, name)
	if (type(clientScript.Init) == "function") then
		RunSafe(name, function()
			clientScript:Init()
		end)
	end
end


function StartScript(clientScript, name)

	-- Start scripts on separate threads:
	if (type(clientScript.Start) == "function") then
		RunSafe(name, function()
			clientScript:Start()
		end)
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
	LazyLoadSetup(Aero.Shared, sharedFolder)
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