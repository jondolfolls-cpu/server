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

-- === anti-dex / anti-infinite-yield (connection + Heartbeat) ===

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalPlayer = Players.LocalPlayer

local function reportHard(reason)
	e.AntiCheat:FireServer("exploit-detect", reason, "hard")
end

-- ── TextBoxFocused: клик в поле ввода вне PlayerGui = поле из CoreGui (поиск Dex/IY) ──
-- самый надёжный сигнал. Исключаем родной чат/консоль Roblox (они под RobloxGui).
UserInputService.TextBoxFocused:Connect(function(textbox)
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return end
	if textbox:IsDescendantOf(playerGui) then return end

	local par = textbox
	while par do
		if par.Name == "RobloxGui" then return end -- родной UI Roblox (чат, F9), не флагаем
		par = par.Parent
	end

	reportHard("TextBox focused outside PlayerGui (Dex/IY search bar)")
end)

-- ── Периодические проверки через Heartbeat ──
local assetScanClock = 0
local structScanClock = 0

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

-- структурный скан по ТИПАМ, а не по именам: Dex/IY - это ScreenGui в CoreGui,
-- не принадлежащий RobloxGui, с большим числом фреймов/кнопок/скроллов внутри.
local function doStructScan()
	pcall(function()
		local CoreGui = game:GetService("CoreGui")
		if not CoreGui then return end
		local children = CoreGui:GetChildren()
		if not children then return end

		for _, gui in ipairs(children) do
			if gui.Name ~= "RobloxGui" and gui:IsA("ScreenGui") then
				-- точные сигнатуры известных сборок
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

				-- эвристика по типам: считаем ScrollingFrame'ы и TextButton'ы внутри.
				-- у Dex - большой explorer (ScrollingFrame) + много кнопок-нод.
				-- у IY - командная строка (TextBox) + вывод (ScrollingFrame).
				local descendants = gui:GetDescendants()
				local scrolls = 0
				local textboxes = 0
				for _, d in ipairs(descendants) do
					if d:IsA("ScrollingFrame") then
						scrolls = scrolls + 1
					elseif d:IsA("TextBox") then
						textboxes = textboxes + 1
					end
				end
				-- Dex: минимум 2 ScrollingFrame (explorer + properties)
				if scrolls >= 2 and textboxes >= 1 then
					reportHard("exploit UI heuristic (scrollframes+textbox in foreign ScreenGui)")
				end
			end
		end
	end)
end

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

warn("[antidex] детекты подключены (v2)")
