local a = game.ReplicatedStorage
local b = "Check"
a[b].OnClientInvoke = function()
	local c = 1 + 1
	local d = c - 1
	return d == 1
end

local function getAncestors(obj)
	local chain = {}
	local par = obj.Parent
	while par do
		table.insert(chain, par)
		par = par.Parent
	end
	return chain
end

local function isUnderCoreGui(obj)
	local par = obj
	while par do
		if par.Name == "CoreGui" then return true end
		par = par.Parent
	end
	return false
end

local e = game:GetService("ReplicatedStorage")
local f = e:WaitForChild("CheckChildExists")

local g = {
	"FrameRateManager", "DeviceFeatureLevel", "DeviceShadingLanguage",
	"AverageQualityLevel", "AutoQuality", "NumberOfSettles", "AverageSwitches",
	"FramebufferWidth", "FramebufferHeight", "Batches", "Indices",
	"MaterialChanges", "VideoMemoryInMB", "AverageFPS", "FrameTimeVariance",
	"FrameSpikeCount", "RenderAverage", "PrepareAverage", "PerformAverage",
	"AveragePresent", "AverageGPU", "RenderThreadAverage", "TotalFrameWallAverage",
	"PerformVariance", "PresentVariance", "GpuVariance",
	"MsFrame0", "MsFrame1", "MsFrame2", "MsFrame3", "MsFrame4", "MsFrame5",
	"MsFrame6", "MsFrame7", "MsFrame8", "MsFrame9", "MsFrame10", "MsFrame11",
	"Render", "Memory", "Video", "CursorImage", "LanguageService"
}

local function h(i)
	for _, j in ipairs(g) do
		if i == j then
			return true
		end
	end
	return false
end

task.wait(1)
warn("[antidex] data.lua payload запущен")

-- контейнеры/типы, которые Roblox и клиентские системы создают ЛОКАЛЬНО без ключа.
-- их надо исключать, иначе легитимные объекты (ProximityPrompt UI, партиклы, звуки) кикают игрока.
local function isLegitLocalObject(obj)
	-- ProximityPrompt создаёт свой UI локально - исключаем и сам промпт, и его потомков
	local par = obj
	while par do
		if par:IsA("ProximityPrompt") then return true end
		if par:IsA("BillboardGui") then return true end -- часто локальный UI
		par = par.Parent
	end
	-- типы, которые почти всегда создаются движком/клиентом локально
	if obj:IsA("ParticleEmitter") then return true end
	if obj:IsA("Sound") then return true end
	if obj:IsA("Trail") then return true end
	if obj:IsA("Beam") then return true end
	if obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then return true end
	if obj:IsA("Light") then return true end
	if obj:IsA("Highlight") then return true end
	if obj:IsA("Attachment") then return true end
	return false
end

game.DescendantAdded:Connect(function(k)
	if h(k.Name) then return end
	if isUnderCoreGui(k) then return end
	if isLegitLocalObject(k) then return end -- ProximityPrompt UI, партиклы, звуки - не читы

	local chain = getAncestors(k)
	for _, n in ipairs(chain) do
		if n.Name == "ReplicatedStorage" then
			e.AntiCheat:FireServer("???", "using exploit.", "hard")
			return
		end
	end

	local o, l
	local attempts = 0
	while attempts < 5 do
		if not k or not k.Parent then return end

		o = k:FindFirstChild("Key")
		local ok, result = pcall(function()
			return f:InvokeServer(k.Parent.Name, k.Name)
		end)
		l = ok and result

		if o or l then break end

		task.wait(0.2)
		attempts = attempts + 1
	end

	if not k or not k.Parent then return end

	local p = e.GetKey:InvokeServer()

	if o and l then
		if o.Value ~= p then
			e.AntiCheat:FireServer(k.Name, "adding instance with wrong key - exploit.", "hard")
		end
	elseif k.Name == "Key" then
		if k.Value then
			if k.Value ~= p then
				e.AntiCheat:FireServer(k.Name, "adding instance with wrong key - exploit.", "hard")
			end
		end
	elseif not o and not l then
		-- soft порог 3: как в старой 273-строчной версии
		e.AntiCheat:FireServer(k.Name, "adding instance with exploit.", "soft")
	end
end)

-- === Heartbeat-сканы CoreGui ===
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local MarketplaceService = game:GetService("MarketplaceService")

local function reportHard(reason)
	e.AntiCheat:FireServer("exploit-detect", reason, "hard")
end

local knownAssets = {
	["rbxassetid://5642383285"] = "Dex Explorer",
	["rbxassetid://1204397029"] = "Infinite Yield",
	["rbxassetid://4702850565"] = "Hydroxide",
	["rbxassetid://137842439297855"] = "known exploit UI",
	["rbxassetid://2764171053"] = "known exploit UI",
	["rbxassetid://1352543873"] = "known exploit UI",
}

local function doAssetScan()
	local CoreGui = game:GetService("CoreGui")
	if not CoreGui then return end
	pcall(function()
		ContentProvider:PreloadAsync({CoreGui}, function(assetId, _status)
			local knownName = knownAssets[assetId]
			if knownName then
				reportHard(knownName)
				return
			end
			if assetId:find("rbxassetid://") then
				local id = tonumber(assetId:match("%d+"))
				if id then
					local infoOk, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, Enum.InfoType.Asset)
					if infoOk and info and info.Creator and info.Creator.CreatorTargetId ~= 1 then
						reportHard("unrecognized asset in CoreGui: " .. assetId)
					end
				end
			end
		end)
	end)
end

local function doStructScan()
	pcall(function()
		local CoreGui = game:GetService("CoreGui")
		if not CoreGui then return end
		local children = CoreGui:GetChildren()
		if not children then return end

		for _, gui in ipairs(children) do
			if gui.Name ~= "RobloxGui" and gui:IsA("ScreenGui") then
				local hasL = gui:FindFirstChild("ContentFrameL")
				local hasR = gui:FindFirstChild("ContentFrameR")
				local hasW = gui:FindFirstChild("WelcomeFrame")
				if hasL and hasR and hasW then
					reportHard("Dex Explorer (structure match)")
				end
				local pf = gui:FindFirstChild("PropertiesFrame")
				local si = gui:FindFirstChild("SaveInstance")
				if pf or si then
					reportHard("Dark Dex (frame signature)")
				end
				local ep = gui:FindFirstChild("ExplorerPanel")
				local pp = gui:FindFirstChild("PropertiesPanel")
				if ep and pp then
					reportHard("Dex-family (panel signature)")
				end

				local descendants = gui:GetDescendants()
				local scrolls = 0
				local textboxes = 0
				for _, dsc in ipairs(descendants) do
					if dsc:IsA("ScrollingFrame") then
						scrolls = scrolls + 1
					elseif dsc:IsA("TextBox") then
						textboxes = textboxes + 1
					end
				end
				if scrolls >= 2 and textboxes >= 1 then
					reportHard("exploit UI heuristic (scrollframes+textbox in foreign ScreenGui)")
				end
			end
		end
	end)
end

local assetScanClock = 0
local structScanClock = 0

RunService.Heartbeat:Connect(function(dt)
	structScanClock = structScanClock + dt
	assetScanClock = assetScanClock + dt
	if structScanClock >= 3 then
		structScanClock = 0
		doStructScan()
	end
	if assetScanClock >= 7 then
		assetScanClock = 0
		doAssetScan()
	end
end)

warn("[antidex] data.lua детекты подключены")
