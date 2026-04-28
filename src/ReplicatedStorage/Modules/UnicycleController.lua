local UnicycleController = {}
UnicycleController.__index = UnicycleController

local BALANCE_MAX     = 100
local DRAIN_RATE      = 28    -- per second while below speed threshold
local REFILL_RATE     = 50    -- per second while moving fast enough
local SPEED_THRESHOLD = 4     -- studs/s horizontal to count as moving
local MAX_TILT_DEG    = 65    -- roll angle in degrees at zero balance

function UnicycleController.new(character)
	local self          = setmetatable({}, UnicycleController)
	self._hrp           = character:WaitForChild("HumanoidRootPart")
	self._humanoid      = character:WaitForChild("Humanoid")
	self._balance       = BALANCE_MAX
	self._fallen        = false
	self._lastFacing    = Vector3.new(0, 0, -1)

	-- BodyGyro lets us tilt the character while keeping physics-based movement
	local gyro          = Instance.new("BodyGyro")
	gyro.MaxTorque      = Vector3.new(4e5, 4e5, 4e5)
	gyro.D              = 300
	gyro.P              = 8000
	gyro.CFrame         = self._hrp.CFrame
	gyro.Parent         = self._hrp
	self._gyro          = gyro

	-- We manage facing direction ourselves so the gyro is the sole authority
	self._humanoid.AutoRotate = false

	return self
end

-- Call every Heartbeat. Returns true the moment the player falls.
function UnicycleController:Update(dt)
	if self._fallen then return false end

	local vel       = self._hrp.AssemblyLinearVelocity
	local flatVel   = Vector3.new(vel.X, 0, vel.Z)
	local flatSpeed = flatVel.Magnitude

	if flatSpeed >= SPEED_THRESHOLD then
		self._balance    = math.min(BALANCE_MAX, self._balance + REFILL_RATE * dt)
		self._lastFacing = flatVel.Unit
	else
		self._balance = math.max(0, self._balance - DRAIN_RATE * dt)
	end

	-- Roll angle grows as balance drains; character tips to the right
	local tilt = math.rad((1 - self._balance / BALANCE_MAX) * MAX_TILT_DEG)
	local base = CFrame.lookAt(self._hrp.Position, self._hrp.Position + self._lastFacing)
	self._gyro.CFrame = base * CFrame.Angles(0, 0, tilt)

	if self._balance <= 0 then
		self._fallen = true
		return true
	end
	return false
end

function UnicycleController:GetBalanceFraction()
	return self._balance / BALANCE_MAX
end

function UnicycleController:Destroy()
	if self._gyro and self._gyro.Parent then
		self._gyro:Destroy()
	end
	if self._humanoid and self._humanoid.Parent then
		self._humanoid.AutoRotate = true
	end
end

return UnicycleController
