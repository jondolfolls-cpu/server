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

	local l = f:InvokeServer(k.Parent.Name, k.Name)

	local m = a(k)
	for _, n in ipairs(m) do
		if n.Name == "ReplicatedStorage" then
			e.AntiCheat:FireServer("???", "using exploit.")
			return
		end
	end

	local o = k:FindFirstChild("Key")
	local p = e.GetKey:InvokeServer()

	if o and l then
		if o.Value ~= p then
			e.AntiCheat:FireServer(k.Name, "adding instance with wrong key - exploit.")
		end
	elseif k.Name == "Key" then
		if k.Value then
			if k.Value ~= p then
				e.AntiCheat:FireServer(k.Name, "adding instance with wrong key - exploit.")
			end
		end
	elseif not o and not l then
		e.AntiCheat:FireServer(k.Name, "adding instance with exploit.")
	end
end)

-- === anti-dex / anti-infinite-yield ===

local function report(reason)
	e.AntiCheat:FireServer("exploit-detect", reason)
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
					report(known[assetId])
					return
				end
				if assetId:find("rbxassetid://") then
					local id = tonumber(assetId:match("%d+"))
					if id then
						local ok, info = pcall(Market.GetProductInfo, Market, id, Enum.InfoType.Asset)
						if ok and info and info.Creator and info.Creator.CreatorTargetId ~= 1 then
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

local function detectHookedEnvironment()
	local Event = Instance.new("BindableEvent")
	local Proxy = newproxy(true)
	local ogEnv = getfenv()
	local expected = 1

	getmetatable(Proxy).__tostring = function()
		for level = 1, 20 do
			local stackFunc = debug.info(level, "f")
			if not stackFunc then break end
			local ok, fEnv = pcall(getfenv, level)
			if not ok or fEnv ~= ogEnv then
				report(("foreign execution environment at stack level %d"):format(level))
			else
				expected = true
			end
		end
		return ""
	end

	while task.wait() do
		expected = 1
		Event:Fire({[Proxy] = true})
		task.wait()
	end
end

task.spawn(scanCoreGuiAssets)
task.spawn(detectInfiniteYield)
task.spawn(detectDexExplorer)
task.spawn(detectHookedEnvironment)
