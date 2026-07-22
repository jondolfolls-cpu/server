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

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local AntiCheat = ReplicatedStorage:WaitForChild("AntiCheat")

local function reportHard(reason)
	AntiCheat:FireServer("input-detect", reason, "hard")
end

-- есть ли под курсором интерактивный GuiObject в НАШЕМ PlayerGui
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

-- открыта ли сейчас F9-консоль разработчика
-- когда консоль открыта, клики по ней - это клики по родному UI Roblox, не по Dex
local function isDevConsoleOpen()
	local ok, visible = pcall(function()
		return GuiService.DevConsoleVisible
	end)
	return ok and visible == true
end

local clickViolations = 0

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	if not gameProcessed then return end -- ввод не поглощён UI - обычный игровой клик

	-- если открыта F9-консоль - клик мог поглотить именно она, не флагаем
	if isDevConsoleOpen() then return end

	-- клик поглотил наш UI (PlayerGui) - легитимно
	if hasInteractiveGuiUnderCursor() then return end

	-- клик поглощён UI, которого нет в PlayerGui и это не F9-консоль = CoreGui-панель (Dex)
	clickViolations = clickViolations + 1
	if clickViolations >= 3 then
		reportHard("click consumed by UI outside PlayerGui (CoreGui panel - Dex)")
		clickViolations = 0
	end
end)

-- TextBoxFocused - дополнительный сигнал: фокус поля ввода вне PlayerGui
UserInputService.TextBoxFocused:Connect(function(textbox)
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return end
	if textbox:IsDescendantOf(playerGui) then return end

	-- исключаем родной UI Roblox (чат, консоль под RobloxGui)
	local par = textbox
	while par do
		if par.Name == "RobloxGui" then return end
		par = par.Parent
	end

	reportHard("TextBox focused outside PlayerGui (Dex/IY search bar)")
end)

warn("[antidex] InputDetect подключён (с фильтром F9-консоли)")
