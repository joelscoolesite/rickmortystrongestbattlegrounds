-- GunClient
-- Zit in het Gun zelf (GunServer zet hem erin). Houd de muis ingedrukt = automatisch schieten.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local FIRE_RATE = 0.15
local RANGE = 1000

local tool = script.Parent
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local shootEvent = ReplicatedStorage:WaitForChild("ShootGun")

local triggerDown = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		triggerDown = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		triggerDown = false
	end
end)

tool.Equipped:Connect(function()
	mouse.Icon = "rbxasset://SystemCursors/Cross"
end)

tool.Unequipped:Connect(function()
	mouse.Icon = ""
	triggerDown = false
end)

-- Bloedspetters op je scherm die naar beneden druipen en vervagen
local function bloodOnScreen(amount)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	local gui = playerGui:FindFirstChild("BloodScreen")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "BloodScreen"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 10
		gui.Parent = playerGui
	end
	if #gui:GetChildren() > 40 then
		return
	end

	for _ = 1, math.floor(6 * amount + 0.5) do
		local size = math.random(40, 150) * amount
		local blob = Instance.new("Frame")
		blob.AnchorPoint = Vector2.new(0.5, 0.5)
		blob.Position = UDim2.fromScale(math.random(), math.random())
		blob.Size = UDim2.fromOffset(size, size * (0.7 + math.random() * 0.6))
		blob.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
		blob.BackgroundTransparency = 0.1
		blob.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = blob

		-- Straaltje dat naar beneden druipt
		local drip = Instance.new("Frame")
		drip.AnchorPoint = Vector2.new(0.5, 0)
		drip.Position = UDim2.fromScale(0.5, 0.5)
		drip.Size = UDim2.fromOffset(size * 0.2, 0)
		drip.BackgroundColor3 = blob.BackgroundColor3
		drip.BackgroundTransparency = 0.1
		drip.BorderSizePixel = 0
		drip.Parent = blob
		blob.Parent = gui

		local fade = TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(blob, fade, {
			BackgroundTransparency = 1,
			Position = blob.Position + UDim2.fromOffset(0, math.random(20, 60)),
		}):Play()
		TweenService:Create(drip, fade, {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(size * 0.2, size * (1 + math.random() * 1.5)),
		}):Play()
		Debris:AddItem(blob, 2.6)
	end
end

ReplicatedStorage:WaitForChild("GoreScreen").OnClientEvent:Connect(bloodOnScreen)

-- Waar wijst de muis naar in de 3D wereld (eigen character genegeerd)
local function getAimPosition()
	local camera = workspace.CurrentCamera
	local mousePosition = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePosition.X, mousePosition.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { player.Character }
	local effects = workspace:FindFirstChild("GoreEffects")
	if effects then
		table.insert(ignore, effects)
	end
	params.FilterDescendantsInstances = ignore

	local result = workspace:Raycast(ray.Origin, ray.Direction * RANGE, params)
	return result and result.Position or ray.Origin + ray.Direction * RANGE
end

while tool.Parent do
	local equipped = player.Character ~= nil and tool.Parent == player.Character
	if equipped and triggerDown then
		shootEvent:FireServer(getAimPosition())
		task.wait(FIRE_RATE)
	else
		task.wait()
	end
end
