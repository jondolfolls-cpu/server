local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local checkRemote = ReplicatedStorage:WaitForChild("Check")
local checkChildExists = ReplicatedStorage:WaitForChild("CheckChildExists")
local antiCheat = ReplicatedStorage:WaitForChild("AntiCheat")
local getKey = ReplicatedStorage:WaitForChild("GetKey")

checkRemote.OnClientInvoke = function()
	local c = 1 + 1
	local d = c - 1
	return d == 1
end

local function getParentsList(b)
	local c = {}
	local d = b.Parent
	while d do
		table.insert(c, d)
		d = d.Parent
	end
	return c
end

local ignoreList = {
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

local function isIgnored(name)
	for _, j in ipairs(ignoreList) do
		if name == j then return true end
	end
	return false
end

-- Безопасная зона для локальных объектов (чтобы не кикало за интерфейс и консоли)
local function isSafeLocalPath(instance)
	if not instance then return true end

	if instance:IsA("GuiBase") or instance:IsA("UIComponent") then return true end
	if instance:FindFirstAncestorOfClass("ProximityPrompt") or instance:IsA("ProximityPrompt") then return true end

	local safe = false
	pcall(function()
		if instance:IsDescendantOf(LocalPlayer) then safe = true end
		if LocalPlayer.Character and instance:IsDescendantOf(LocalPlayer.Character) then safe = true end
		if instance:IsDescendantOf(game:GetService("Chat")) then safe = true end
		if instance:IsDescendantOf(game:GetService("CoreGui")) then safe = true end 
	end)
	
	return safe or isIgnored(instance.Name)
end

task.wait(1)

game.DescendantAdded:Connect(function(k)
	if isSafeLocalPath(k) then return end

	local parents = getParentsList(k)
	for _, n in ipairs(parents) do
		if n.Name == "ReplicatedStorage" then
			antiCheat:FireServer("???", "using exploit.")
			return
		end
	end

	local existsOnServer = checkChildExists:InvokeServer(k.Parent.Name, k.Name)
	local serverKey = getKey:InvokeServer()

	local keyObj = k:FindFirstChild("Key")
	local attempts = 0
	while not keyObj and attempts < 5 do
		task.wait(0.2)
		if not k or not k.Parent then return end 
		keyObj = k:FindFirstChild("Key")
		attempts = attempts + 1 
	end

	if keyObj and existsOnServer then
		if keyObj.Value ~= serverKey then
			antiCheat:FireServer(k.Name, "adding instance with wrong key - exploit.")
		end
	elseif k.Name == "Key" then
		if k.Value then
			if k.Value ~= serverKey then
				antiCheat:FireServer(k.Name, "adding instance with wrong key - exploit.")
			end
		end
	elseif not keyObj and not existsOnServer then
		antiCheat:FireServer(k.Name, "adding instance with exploit.")
	end
end)

-- === Обнаружение инжектов UI (Dex и другие) ===

local function report(reason)
	antiCheat:FireServer("exploit-detect", reason)
end

local function scanCoreGuiAssets()
	local ok, CoreGui = pcall(function() return game:GetService("CoreGui") end)
	if not ok then return end 

	local Content = game:GetService("ContentProvider")
	local Market = game:GetService("MarketplaceService")

	-- Если чит вставит свой интерфейс в CoreGui, этот кусок его поймает
	local known = {
		["rbxassetid://5642383285"] = "Dex Explorer",
		["rbxassetid://1204397029"] = "Infinite Yield",
		["rbxassetid://4702850565"] = "Hydroxide",
	}

	while task.wait(7) do
		pcall(function()
			Content:PreloadAsync({CoreGui}, function(assetId, _status)
				if known[assetId] then
					report(known[assetId])
					return
				end
				if assetId:find("rbxassetid://") then
					local id = tonumber(assetId:match("%d+"))
					if id then
						local okInfo, info = pcall(Market.GetProductInfo, Market, id, Enum.InfoType.Asset)
						if okInfo and info and info.Creator and info.Creator.CreatorTargetId ~= 1 then
							report("unrecognized asset in CoreGui: " .. assetId)
						end
					end
				end
			end)
		end)
	end
end
local function detectExploitTools()
	if not game:IsLoaded() then game.Loaded:Wait() end
	task.wait(5) -- Даем игре прогрузиться

	while task.wait(3) do
		pcall(function()
			-- 1. Проверка на наличие характерных глобальных сред или следов Dex/Hydroxide
			-- Большинство эксплойтов оставляют следы в getgenv() или registry, если они активны
			if syn and syn.protect_gui then
				-- Если окружение Synapse-подобное, проверяем специфичные паттерны
			end

			-- 2. Сканирование CoreGui на наличие неавторизованных инжектов (надежный поиск по именам окон Dex)
			local ok, CoreGui = pcall(function() return game:GetService("CoreGui") end)
			if ok and CoreGui then
				for _, child in ipairs(CoreGui:GetChildren()) do
					local name = child.Name
					-- Стандартные имена окон популярных Dex (Dark Dex, Dex Explorer и т.д.)
					if name == "Dex" or name == "DarkDex" or name == "DexExplorer" or name == "Hydroxide" then
						antiCheat:FireServer("exploit-detect", "Dex/Explorer UI detected in CoreGui: " .. name)
						break
					end
				end
			end
		end)
	end
end

task.spawn(detectExploitTools)
task.spawn(scanCoreGuiAssets)
