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

-- === anti-dex / anti-infinite-yield ===

local function reportHard(reason)
	e.AntiCheat:FireServer("exploit-detect", reason, "hard")
end

-- 1. Asset-ID сканирование (расширенный список из форума devforum.roblox.com/t/detect-scripts-and-exploits/3368051)
local function scanCoreGuiAssets()
	local CoreGui = game:GetService("CoreGui")
	if not CoreGui then return end

	local Content = game:GetService("ContentProvider")
	local Market = game:GetService("MarketplaceService")

	local known = {
		["rbxassetid://5642383285"] = "Dex Explorer",
		["rbxassetid://1204397029"] = "Infinite Yield",
		["rbxassetid://4702850565"] = "Hydroxide",
		["rbxassetid://137842439297855"] = "known exploit UI",
		["rbxassetid://2764171053"] = "known exploit UI",
		["rbxassetid://1352543873"] = "known exploit UI",
	}

	while task.wait(7) do
		local preloadOk = pcall(function()
			Content:PreloadAsync({CoreGui}, function(assetId, _status)
				local knownName = known[assetId]
				if knownName then
					reportHard(knownName)
					return
				end
				local hasPrefix = assetId:find("rbxassetid://")
				if hasPrefix then
					local id = tonumber(assetId:match("%d+"))
					if id then
						local infoOk, info = pcall(Market.GetProductInfo, Market, id, Enum.InfoType.Asset)
						if infoOk and info and info.Creator and info.Creator.CreatorTargetId ~= 1 then
							reportHard("unrecognized asset in CoreGui: " .. assetId)
						end
					end
				end
			end)
		end)
		if not preloadOk then
			warn("[antidex] scanCoreGuiAssets: PreloadAsync ошибка (безопасно поймана)")
		end
	end
end

-- 2. Структурное сканирование (плоский код, без вложенных if/elseif - обход бага компилятора Rerubi)
local function detectKnownDexVariants()
	while task.wait(5) do
		local ok, err = pcall(function()
			local CoreGui = game:GetService("CoreGui")
			if not CoreGui then return end

			local children = CoreGui:GetChildren()
			if not children then return end

			for _, gui in ipairs(children) do
				local guiName = gui.Name

				local skipThis = (guiName == "RobloxGui")

				if not skipThis then
					if guiName == "Dex" then
						local isScreenGui = gui:IsA("ScreenGui")
						if isScreenGui then
							local hasL = gui:FindFirstChild("ContentFrameL")
							local hasR = gui:FindFirstChild("ContentFrameR")
							local hasWelcome = gui:FindFirstChild("WelcomeFrame")
							local structMatch = hasL and hasR and hasWelcome
							if structMatch then
								reportHard("Dex Explorer (Alter-X/Moon build - structure match)")
							end
						end
					end

					local propFrame = gui:FindFirstChild("PropertiesFrame")
					local saveInstance = gui:FindFirstChild("SaveInstance")
					local darkDexMatch = propFrame or saveInstance
					if darkDexMatch then
						reportHard("Dark Dex (frame signature match)")
					end

					local explorerPanel = gui:FindFirstChild("ExplorerPanel")
					local propertiesPanel = gui:FindFirstChild("PropertiesPanel")
					local panelMatch = explorerPanel and propertiesPanel
					if panelMatch then
						reportHard("Dex-family explorer (panel signature match)")
					end
				end
			end
		end)
		if not ok then
			warn("[antidex] detectKnownDexVariants ошибка (безопасно поймана): " .. tostring(err))
		end
	end
end

-- 3. HoneyPot: универсальный GC-детект держания ссылки на CoreGui
-- источник техники: devforum.roblox.com/t/coregui-reference-detection/2645406 (XoifailTheGod)
-- ловит любой скрипт, который держит ссылку на CoreGui/объекты в нём (типично для Dex, IY, JJSploit
-- и большинства несинапс-экзекьюторов), не завязан на конкретную структуру или asset ID
local function detectCoreGuiHoneypot()
	while task.wait(2) do
		local ok, err = pcall(function()
			local CoreGui = game:GetService("CoreGui")
			if not CoreGui then return end

			local honeyPot = setmetatable(
				{CoreGui, {}, newproxy(true), newproxy()},
				{__mode = "v"}
			)

			local waited = 0
			while honeyPot[2] and honeyPot[3] and honeyPot[4] and waited < 50 do
				task.wait()
				waited = waited + 1
			end

			if honeyPot[1] then
				reportHard("посторонняя ссылка удерживает CoreGui (HoneyPot GC-детект)")
			end
		end)
		if not ok then
			warn("[antidex] detectCoreGuiHoneypot ошибка (безопасно поймана): " .. tostring(err))
		end
	end
end

task.spawn(scanCoreGuiAssets)
task.spawn(detectKnownDexVariants)
task.spawn(detectCoreGuiHoneypot)
