local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")

local BulletManager = {}

local SPEED      = 28     -- studs/s
local DAMAGE     = 34     -- HP per hit
local LIFETIME   = 6      -- seconds before auto-destroy
local HIT_RADIUS = 2.5    -- studs

local bullets = {}  -- { part: Part, vel: Vector3, expireAt: number }

local function spawn(origin, direction, color)
	local part          = Instance.new("Part")
	part.Size           = Vector3.new(0.6, 0.6, 0.6)
	part.Shape          = Enum.PartType.Ball
	part.Anchored       = true
	part.CanCollide     = false
	part.CastShadow     = false
	part.Material       = Enum.Material.Neon
	part.BrickColor     = BrickColor.new(color or "Bright red")
	part.CFrame         = CFrame.new(origin)
	part.Parent         = workspace

	bullets[#bullets + 1] = {
		part     = part,
		vel      = direction.Unit * SPEED,
		expireAt = tick() + LIFETIME,
	}
end

-- Even ring of `count` bullets fired from center at `height`
function BulletManager.SpawnRadial(center, count, height, color)
	for i = 1, count do
		local a   = (2 * math.pi / count) * (i - 1)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		spawn(Vector3.new(center.X, height, center.Z), dir, color)
	end
end

-- One bullet per living player, aimed from center
function BulletManager.SpawnAimed(center, height, color)
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		if not char then continue end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then continue end
		local origin = Vector3.new(center.X, height, center.Z)
		local dir    = Vector3.new(hrp.Position.X, height, hrp.Position.Z) - origin
		if dir.Magnitude > 0.1 then
			spawn(origin, dir.Unit, color)
		end
	end
end

-- `arms` bullets rotated by `angleOffset`, used repeatedly to form a spiral
function BulletManager.SpawnSpiral(center, arms, angleOffset, height, color)
	for i = 1, arms do
		local a   = (2 * math.pi / arms) * (i - 1) + angleOffset
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		spawn(Vector3.new(center.X, height, center.Z), dir, color)
	end
end

function BulletManager.ClearAll()
	for _, b in bullets do
		if b.part.Parent then b.part:Destroy() end
	end
	table.clear(bullets)
end

-- Move bullets and proximity-check hits every frame
RunService.Heartbeat:Connect(function(dt)
	local now = tick()
	local i   = 1
	while i <= #bullets do
		local b = bullets[i]

		if not b.part.Parent or now >= b.expireAt then
			if b.part.Parent then b.part:Destroy() end
			table.remove(bullets, i)
			continue
		end

		b.part.CFrame = CFrame.new(b.part.Position + b.vel * dt)

		local hit = false
		for _, plr in Players:GetPlayers() do
			local char = plr.Character
			if not char then continue end
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local hum = char:FindFirstChild("Humanoid")
			if not hrp or not hum or hum.Health <= 0 then continue end
			if (b.part.Position - hrp.Position).Magnitude <= HIT_RADIUS then
				hum:TakeDamage(DAMAGE)
				b.part:Destroy()
				table.remove(bullets, i)
				hit = true
				break
			end
		end

		if not hit then
			i += 1
		end
	end
end)

return BulletManager
