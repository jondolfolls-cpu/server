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
	"FrameRateManager",
	"DeviceFeatureLevel",
	"DeviceShadingLanguage",
	"AverageQualityLevel",
	"AutoQuality",
	"NumberOfSettles",
	"AverageSwitches",
	"FramebufferWidth",
	"FramebufferHeight",
	"Batches",
	"Indices",
	"MaterialChanges",
	"VideoMemoryInMB",
	"AverageFPS",
	"FrameTimeVariance",
	"FrameSpikeCount",
	"RenderAverage",
	"PrepareAverage",
	"PerformAverage",
	"AveragePresent",
	"AverageGPU",
	"RenderThreadAverage",
	"TotalFrameWallAverage",
	"PerformVariance",
	"PresentVariance",
	"GpuVariance",
	"MsFrame0",
	"MsFrame1",
	"MsFrame2",
	"MsFrame3",
	"MsFrame4",
	"MsFrame5",
	"MsFrame6",
	"MsFrame7",
	"MsFrame8",
	"MsFrame9",
	"MsFrame10",
	"MsFrame11",
	"Render",
	"Memory",
	"Video",
	"CursorImage",
	"LanguageService"
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
