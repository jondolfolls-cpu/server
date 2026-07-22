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
warn("[antidex] data.lua payload запущен, детекты подключаются")

game.DescendantAdded:Connect(function(k)
	if h(k.Name) then return end
	if isUnderCoreGui(k) then return end

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
		e.AntiCheat:FireServer(k.Name, "adding instance with exploit.", "soft")
	end
end)

-- === anti-dex / anti-infinite-yield (без task.spawn - только connections и Heartbeat) ===

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalPlayer = Players.LocalPlayer

local function reportHard(reason)
	e.AntiCheat:FireServer("exploit-detect", reason, "hard")
end

-- ── 1. TextBoxFocused: клик в поле поиска Dex (оно в CoreGui, не в PlayerGui) ──
UserInputService.TextBoxFocused:Connect(function(textbox)
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return end
	local isOurs = textbox:IsDescendantOf(playerGui)
	if not isOurs then
		local underRobloxGui = false
		local par = textbox
		while par do
			if par.Name == "RobloxGui" then underRobloxGui = true break end
			par = par.Parent
		end
		if not underRobloxGui then
			reportHard("TextBox focused outside PlayerGui (Dex search bar)")
		end
	end
end)

-- ── 2. InputBegan: клик, поглощённый UI вне PlayerGui = CoreGui-панель ──
local function hasInteractiveGuiUnderCursor()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return false end
	local mousePos = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
	local ok, objects = pcall(function()
		return playerGui:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y)
	end)
	if not ok or not objects then return false end
	for _, gui in ipairs(objects) do
		local interactive = gui:IsA("TextButton") or gui:IsA("ImageButton")
			or gui:IsA("TextBox") or gui:IsA("ScrollingFrame")
		if interactive and gui.Visible then return true end
	end
	return false
end

local clickViolations = 0
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	if not gameProcessed then return end
	if hasInteractiveGuiUnderCursor() then return end
	clickViolations = clickViolations + 1
	if clickViolations >= 3 then
		reportHard("click consumed by UI outside PlayerGui (CoreGui panel)")
		clickViolations = 0
	end
end)

-- ── 3. Периодические проверки через Heartbeat вместо task.spawn+while ──
local assetScanClock = 0
local structScanClock = 0
local honeypotClock = 0

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
			local hasPrefix = assetId:find("rbxassetid://")
			if hasPrefix then
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
			local guiName = gui.Name
			local skip = (guiName == "RobloxGui")
			if not skip then
				if guiName == "Dex" then
					local isScreen = gui:IsA("ScreenGui")
					if isScreen then
						local hasL = gui:FindFirstChild("ContentFrameL")
						local hasR = gui:FindFirstChild("ContentFrameR")
						local hasW = gui:FindFirstChild("WelcomeFrame")
						if hasL and hasR and hasW then
							reportHard("Dex Explorer (structure match)")
						end
					end
				end
				local propFrame = gui:FindFirstChild("PropertiesFrame")
				local saveInst = gui:FindFirstChild("SaveInstance")
				if propFrame or saveInst then
					reportHard("Dark Dex (frame signature)")
				end
				local exPanel = gui:FindFirstChild("ExplorerPanel")
				local prPanel = gui:FindFirstChild("PropertiesPanel")
				if exPanel and prPanel then
					reportHard("Dex-family explorer (panel signature)")
				end
			end
		end
	end)
end

local function doHoneypot()
	pcall(function()
		local CoreGui = game:GetService("CoreGui")
		if not CoreGui then return end
		local hp = setmetatable({CoreGui, {}, newproxy(true), newproxy()}, {__mode = "v"})
		local waited = 0
		while hp[2] and hp[3] and hp[4] and waited < 30 do
			RunService.Heartbeat:Wait()
			waited = waited + 1
		end
		if hp[1] then
			reportHard("foreign reference holds CoreGui (honeypot)")
		end
	end)
end

RunService.Heartbeat:Connect(function(dt)
	assetScanClock = assetScanClock + dt
	structScanClock = structScanClock + dt
	honeypotClock = honeypotClock + dt

	if structScanClock >= 5 then
		structScanClock = 0
		doStructScan()
	end
	if assetScanClock >= 7 then
		assetScanClock = 0
		doAssetScan()
	end
	if honeypotClock >= 3 then
		honeypotClock = 0
		doHoneypot()
	end
end)

warn("[antidex] все детекты подключены (connection-based)")
