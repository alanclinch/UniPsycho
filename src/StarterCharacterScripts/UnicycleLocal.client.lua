local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UnicycleController = require(ReplicatedStorage.Modules.UnicycleController)
local Remotes            = require(ReplicatedStorage.Remotes)

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Remove any leftover GUI from a previous life
local existing = player.PlayerGui:FindFirstChild("BalanceGui")
if existing then existing:Destroy() end

local controller = UnicycleController.new(character)

-- Balance bar UI -------------------------------------------------------
local gui               = Instance.new("ScreenGui")
gui.Name                = "BalanceGui"
gui.ResetOnSpawn        = false
gui.Parent              = player.PlayerGui

local bg                = Instance.new("Frame")
bg.Size                 = UDim2.new(0.22, 0, 0.035, 0)
bg.Position             = UDim2.new(0.39, 0, 0.91, 0)
bg.BackgroundColor3     = Color3.fromRGB(20, 20, 20)
bg.BorderSizePixel      = 0
bg.Parent               = gui
Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)

local fill              = Instance.new("Frame")
fill.Size               = UDim2.new(1, 0, 1, 0)
fill.BorderSizePixel    = 0
fill.Parent             = bg
Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)

local label             = Instance.new("TextLabel")
label.Size              = UDim2.new(1, 0, 1, 0)
label.BackgroundTransparency = 1
label.Text              = "BALANCE"
label.TextColor3        = Color3.new(1, 1, 1)
label.TextScaled        = true
label.Font              = Enum.Font.GothamBold
label.ZIndex            = 2
label.Parent            = bg
-- -----------------------------------------------------------------------

local conn
conn = RunService.Heartbeat:Connect(function(dt)
	local fell     = controller:Update(dt)
	local fraction = controller:GetBalanceFraction()

	-- Bar shrinks and shifts from green → red as balance drains
	fill.Size             = UDim2.new(fraction, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromHSV(fraction * 0.33, 0.9, 0.85)

	if fell then
		conn:Disconnect()
		controller:Destroy()
		gui:Destroy()
		Remotes.PlayerFell:FireServer()
	end
end)

player.CharacterRemoving:Connect(function()
	if conn then conn:Disconnect() end
	controller:Destroy()
	gui:Destroy()
end)
