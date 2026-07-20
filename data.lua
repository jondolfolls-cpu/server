local ReplicatedStorage = game:GetService("ReplicatedStorage")
local checkRemote = ReplicatedStorage:WaitForChild("Check") -- Безопасное ожидание
local checkChildExists = ReplicatedStorage:WaitForChild("CheckChildExists")
local antiCheat = ReplicatedStorage:WaitForChild("AntiCheat")
local getKey = ReplicatedStorage:WaitForChild("GetKey")

checkRemote.OnClientInvoke = function()
	local c = 1 + 1
	local d = c - 1
	return d == 1
end

-- Переименовал функцию с "a" на более понятное имя во избежание конфликтов
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
		if name == j then
			return true
		end
	end
	return false
end

task.wait(1)

game.DescendantAdded:Connect(function(k)
	if isIgnored(k.Name) then return end

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
		attempts = attempts + 1 -- ИСПРАВЛЕНО: убрал += 1, так как Loadstring это не поддерживает
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

-- === anti-dex / anti-infinite-yield ===

local function report(reason)
	antiCheat:FireServer("exploit-detect", reason)
end

local function scanCoreGuiAssets()
	-- ИСПРАВЛЕНО: Завернуто в pcall, так как обычный LocalScript выдаст ошибку доступа к CoreGui
	local ok, CoreGui = pcall(function() return game:GetService("CoreGui") end)
	if not ok then return end 

	local Content = game:GetService("ContentProvider")
	local Market = game:GetService("MarketplaceService")

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

local function detectInfiniteYield()
	if not game:IsLoaded() then game.Loaded:Wait() end
	task.wait(3)
	while task.wait() do
		local t = setmetatable({}, {__mode = "v"})
		t[1] = {}
		t[2] = game:GetService("NetworkClient")
		while t[1] ~= nil do
			t[3] = string.rep("ab", 1024 * 2)
			t[3] = nil
			task.wait()
		end
		if t[2] ~= nil then
			report("Infinite Yield (invalid GC behavior)")
			break
		end
	end
end

local function detectDexExplorer()
	if not game:IsLoaded() then game.Loaded:Wait() end
	task.wait(3)
	local marker = tostring(math.random())
	local Chat = game:GetService("Chat")
	Instance.new("BoolValue", Chat).Name = marker
	while task.wait() do
		local t = setmetatable({}, {__mode = "v"})
		t[1] = {}
		t[2] = Chat:FindFirstChild(marker)
		while t[1] ~= nil do
			t[3] = string.rep("ab", 1024 * 2)
			t[3] = nil
			task.wait()
		end
		if t[2] ~= nil then
			report("Dex Explorer (invalid GC behavior)")
			break
		end
	end
end

task.spawn(scanCoreGuiAssets)
task.spawn(detectInfiniteYield)
task.spawn(detectDexExplorer)
