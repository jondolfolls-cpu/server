local a = game.ReplicatedStorage
local b = "Check"
a[b].OnClientInvoke = function()
	local c = 1 + 1
	local d = c - 1
	return d == 1
end

local function a(b)
	local c = {}
	local d = b.Parent
	while d do
		table.insert(c, d)
		d = d.Parent
	end
	return c
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

game.DescendantAdded:Connect(function(k)
	if h(k.Name) then return end

	local m = a(k)
	for _, n in ipairs(m) do
		if n.Name == "ReplicatedStorage" then
			e.AntiCheat:FireServer("???", "using exploit.", "hard")
			return
		end
	end

	local l = f:InvokeServer(k.Parent.Name, k.Name)
	local p = e.GetKey:InvokeServer()

	local o = k:FindFirstChild("Key")
	local attempts = 0
	while not o and attempts < 5 do
		task.wait(0.2)
		if not k or not k.Parent then return end
		o = k:FindFirstChild("Key")
		attempts += 1
	end

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
		e.AntiCheat:FireServer(k.Name, "adding instance with exploit.", "hard")
	end
end)

-- === anti-dex / anti-infinite-yield ===

local function reportHard(reason)
	e.AntiCheat:FireServer("exploit-detect", reason, "hard")
end

local function reportSoft(reason)
	e.AntiCheat:FireServer("exploit-detect", reason, "soft")
end

local function scanCoreGuiAssets()
	local CoreGui = game:GetService("CoreGui")
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
					reportHard(known[assetId])
					return
				end
				if assetId:find("rbxassetid://") then
					local id = tonumber(assetId:match("%d+"))
					if id then
						local ok, info = pcall(Market.GetProductInfo, Market, id, Enum.InfoType.Asset)
						if ok and info and info.Creator and info.Creator.CreatorTargetId ~= 1 then
							reportHard("unrecognized asset in CoreGui: " .. assetId)
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
			reportHard("Infinite Yield (invalid GC behavior)")
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
			reportHard("Dex Explorer (invalid GC behavior)")
			break
		end
	end
end

local function detectKnownDexVariants()
	local CoreGui = game:GetService("CoreGui")
	while task.wait(5) do
		for _, gui in ipairs(CoreGui:GetChildren()) do
			if gui.Name == "Dex" and gui:IsA("ScreenGui") then
				local hasStructure = gui:FindFirstChild("ContentFrameL")
					and gui:FindFirstChild("ContentFrameR")
					and gui:FindFirstChild("WelcomeFrame")
				if hasStructure then
					reportHard("Dex Explorer (Alter-X/Moon build - structure match)")
				end
			end
			if gui:FindFirstChild("PropertiesFrame") or gui:FindFirstChild("SaveInstance") then
				reportHard("Dark Dex (frame signature match)")
			end
			if gui:FindFirstChild("ExplorerPanel") and gui:FindFirstChild("PropertiesPanel") then
				reportHard("Dex-family explorer (panel signature match)")
			end
		end
	end
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local scrollWindowStart = 0
local scrollCount = 0

local function isMouseInAnyGui()
	local mousePos = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	for _, gui in ipairs(playerGui:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y)) do
		if gui:IsA("GuiObject") then
			return true
		end
	end
	return false
end

local function getCameraDistance()
	local character = LocalPlayer.Character
	if not character then return 0 end
	local head = character:FindFirstChild("Head")
	if not head then return 0 end
	return (Camera.CFrame.Position - head.Position).Magnitude
end

local function onMouseWheel(input)
	if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
	if isMouseInAnyGui() then return end

	local before = getCameraDistance()
	local maxDelta, totalDelta = 0, 0
	for _ = 1, 5 do
		RunService.RenderStepped:Wait()
		local after = getCameraDistance()
		local delta = after - before
		totalDelta += delta
		maxDelta = math.max(maxDelta, math.abs(delta))
		before = after
	end

	local minZoom = LocalPlayer.CameraMinZoomDistance
	local maxZoom = LocalPlayer.CameraMaxZoomDistance
	local distance = getCameraDistance()
	if distance <= minZoom + 0.2 or distance >= maxZoom - 0.2 then return end

	local threshold = math.max(0.02, distance * 0.003)
	if maxDelta < threshold and math.abs(totalDelta) < threshold then
		local now = tick()
		if now - scrollWindowStart > 0.5 then
			scrollWindowStart = now
			scrollCount = 0
		end
		scrollCount += 1
		if scrollCount >= 10 then
			reportSoft("scroll input consumed without camera response (possible overlay UI)")
			scrollCount = 0
		end
	end
end

UserInputService.InputChanged:Connect(onMouseWheel)

task.spawn(scanCoreGuiAssets)
task.spawn(detectInfiniteYield)
task.spawn(detectDexExplorer)
task.spawn(detectKnownDexVariants)
