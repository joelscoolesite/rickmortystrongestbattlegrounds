-- GunClient
-- Zet dit als "LocalScript" in StarterPlayer > StarterPlayerScripts.
-- Houdt de muis ingedrukt terwijl je de Gun vasthoudt = automatisch schieten.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local FIRE_RATE = 0.15
local RANGE = 1000

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

local function getEquippedGun()
	local character = player.Character
	local tool = character and character:FindFirstChild("Gun")
	if tool and tool:IsA("Tool") then
		return tool
	end
	return nil
end

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

while true do
	local gun = getEquippedGun()
	mouse.Icon = gun and "rbxasset://SystemCursors/Cross" or ""

	if gun and triggerDown then
		shootEvent:FireServer(getAimPosition())
		task.wait(FIRE_RATE)
	else
		task.wait()
	end
end
