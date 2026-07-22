local a = game.ReplicatedStorage
local b = "Check"
a[b].OnClientInvoke = function()
	local c = 1 + 1
	local d = c - 1
	return d == 1
end

-- собирает цепочку предков объекта
local function getAncestors(obj)
	local chain = {}
	local par = obj.Parent
	while par do
		table.insert(chain, par)
		par = par.Parent
	end
	return chain
end

-- CoreGui - клиентское виртуальное пространство (F9-консоль, чат, лидерборд и т.д.)
-- сервер никогда не тегает объекты внутри него ключом, поэтому его нужно полностью
-- исключать из проверки, иначе штатный Roblox UI флагается как эксплойт
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

game.DescendantAdded:Connect(function(k)
	if h(k.Name) then return end
	if isUnderCoreGui(k) then return end -- штатный Roblox UI (F9, чат, лидерборд) - не проверяем

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
		if not k or not k.Parent then return end -- уничтожен раньше проверки - короткоживущий VFX/снаряд, не флагаем

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
-- GC-based детекты (проверка через сборщик мусора) убраны полностью:
-- они завязаны на точное время срабатывания GC, что ненадёжно само по себе,
-- а под кастомным Lua-VM (Rerubi) тайминги искажаются ещё сильнее.
-- Именно это давало и ложные срабатывания, и краш Code(182), и нестабильность "через раз".
-- Оставлены только детерминированные проверки: по asset ID и по структуре интерфейса.

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

local function detectKnownDexVariants()
	while task.wait(5) do
		local ok, err = pcall(function()
			local CoreGui = game:GetService("CoreGui")
			for _, gui in ipairs(CoreGui:GetChildren()) do
				if gui.Name == "RobloxGui" then
					-- это собственный UI Roblox (топбар, чат, F9-консоль и т.д.) - пропускаем целиком
				else
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
		end)
		if not ok then
			warn("[antidex] detectKnownDexVariants error (safely caught): " .. tostring(err))
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
		totalDelta = totalDelta + delta
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
		scrollCount = scrollCount + 1
		if scrollCount >= 10 then
			reportSoft("scroll input consumed without camera response (possible overlay UI)")
			scrollCount = 0
		end
	end
end

UserInputService.InputChanged:Connect(onMouseWheel)

task.spawn(scanCoreGuiAssets)
task.spawn(detectKnownDexVariants)
