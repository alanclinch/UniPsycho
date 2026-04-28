local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UnicycleController = require(ReplicatedStorage.Modules.UnicycleController)
local Remotes            = require(ReplicatedStorage.Remotes)

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Remove leftover GUI from a previous life
local existing = player.PlayerGui:FindFirstChild("BalanceGui")
if existing then existing:Destroy() end

-- Balance bar UI (hidden until game starts) ----------------------------
local gui              = Instance.new("ScreenGui")
gui.Name               = "BalanceGui"
gui.ResetOnSpawn       = false
gui.Enabled            = false
gui.Parent             = player.PlayerGui

local bg               = Instance.new("Frame")
bg.Size                = UDim2.new(0.22, 0, 0.035, 0)
bg.Position            = UDim2.new(0.39, 0, 0.91, 0)
bg.BackgroundColor3    = Color3.fromRGB(20, 20, 20)
bg.BorderSizePixel     = 0
bg.Parent              = gui
Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)

local fill             = Instance.new("Frame")
fill.Size              = UDim2.new(1, 0, 1, 0)
fill.BorderSizePixel   = 0
fill.Parent            = bg
Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)

local label            = Instance.new("TextLabel")
label.Size             = UDim2.new(1, 0, 1, 0)
label.BackgroundTransparency = 1
label.Text             = "BALANCE"
label.TextColor3       = Color3.new(1, 1, 1)
label.TextScaled       = true
label.Font             = Enum.Font.GothamBold
label.ZIndex           = 2
label.Parent           = bg
-- ----------------------------------------------------------------------

local controller = nil
local conn       = nil

local function activateBalance()
	if controller then return end
	controller = UnicycleController.new(character)
	gui.Enabled = true

	conn = RunService.Heartbeat:Connect(function(dt)
		local fell     = controller:Update(dt)
		local fraction = controller:GetBalanceFraction()
		fill.Size             = UDim2.new(fraction, 0, 1, 0)
		fill.BackgroundColor3 = Color3.fromHSV(fraction * 0.33, 0.9, 0.85)
		if fell then
			conn:Disconnect()
			conn       = nil
			controller:Destroy()
			controller = nil
			gui.Enabled = false
			Remotes.PlayerFell:FireServer()
		end
	end)
end

local function deactivateBalance()
	if conn then conn:Disconnect(); conn = nil end
	if controller then controller:Destroy(); controller = nil end
	gui.Enabled = false
end

-- If the unicycle model is already on the character (mid-round respawn),
-- activate immediately rather than waiting for the event.
if character:FindFirstChild("Unicycle") then
	activateBalance()
end

Remotes.GameStarted.OnClientEvent:Connect(activateBalance)
Remotes.GameEnded.OnClientEvent:Connect(deactivateBalance)

player.CharacterRemoving:Connect(deactivateBalance)
