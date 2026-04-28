local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")

local BulletManager = {}

local SPEED       = 28
local DAMAGE      = 34
local LIFETIME    = 8
local HIT_RADIUS  = 2.5
local SPAWN_RADIUS = 55  -- just outside the 45-stud arena edge

local bullets = {}

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

-- Wall of bullets marching in from one edge of the arena.
-- `angle` picks which edge; rotate it each call for variety.
function BulletManager.SpawnEdgeWave(center, count, angle, height, color)
	local inward  = Vector3.new(-math.cos(angle), 0, -math.sin(angle))
	local perp    = Vector3.new(-math.sin(angle), 0,  math.cos(angle))
	local edgePos = Vector3.new(
		center.X + math.cos(angle) * SPAWN_RADIUS,
		height,
		center.Z + math.sin(angle) * SPAWN_RADIUS
	)
	for i = 1, count do
		local offset = (i - (count + 1) / 2) * 5
		spawn(edgePos + perp * offset, inward, color)
	end
end

-- One bullet per player, spawned from a random edge point aimed at that player.
function BulletManager.SpawnPerimeterAimed(center, height, color)
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		if not char then continue end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then continue end
		local a      = math.random() * 2 * math.pi
		local origin = Vector3.new(
			center.X + math.cos(a) * SPAWN_RADIUS,
			height,
			center.Z + math.sin(a) * SPAWN_RADIUS
		)
		local dir = Vector3.new(hrp.Position.X, height, hrp.Position.Z) - origin
		if dir.Magnitude > 0.1 then
			spawn(origin, dir.Unit, color)
		end
	end
end

-- Rotating arms from the perimeter all moving inward — call repeatedly with
-- increasing angleOffset to produce a spiral sweeping across the arena.
function BulletManager.SpawnSpiralEdge(center, arms, angleOffset, height, color)
	for i = 1, arms do
		local a      = (2 * math.pi / arms) * (i - 1) + angleOffset
		local origin = Vector3.new(
			center.X + math.cos(a) * SPAWN_RADIUS,
			height,
			center.Z + math.sin(a) * SPAWN_RADIUS
		)
		spawn(origin, Vector3.new(-math.cos(a), 0, -math.sin(a)), color)
	end
end

function BulletManager.ClearAll()
	for _, b in bullets do
		if b.part.Parent then b.part:Destroy() end
	end
	table.clear(bullets)
end

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

		if not hit then i += 1 end
	end
end)

return BulletManager
