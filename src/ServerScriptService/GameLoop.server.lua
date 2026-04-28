local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BulletManager = require(script.Parent.BulletManager)
local Remotes       = require(ReplicatedStorage.Remotes)

local ARENA_CENTER  = Vector3.new(0, 4, 0)
local WAVE_DURATION = 30
local BETWEEN_WAVES = 5
local PREGAME_DELAY = 3
local gameRunning   = false

-- Unicycle model --------------------------------------------------------
local function giveUnicycle(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local existing = character:FindFirstChild("Unicycle")
	if existing then existing:Destroy() end

	local model    = Instance.new("Model")
	model.Name     = "Unicycle"

	-- Wheel: Roblox Cylinder axis runs along X by default, so with no
	-- rotation this is already a vertical disc — correct for a wheel.
	local wheel          = Instance.new("Part")
	wheel.Name           = "Wheel"
	wheel.Size           = Vector3.new(0.35, 2.4, 2.4)  -- thin disc, 1.2 stud radius
	wheel.Shape          = Enum.PartType.Cylinder
	wheel.BrickColor     = BrickColor.new("Really black")
	wheel.Material       = Enum.Material.SmoothPlastic
	wheel.Massless       = true
	wheel.CanCollide     = false
	wheel.CastShadow     = false
	wheel.CFrame         = hrp.CFrame * CFrame.new(0, -2.2, 0)  -- at foot level
	wheel.Parent         = model
	local ww             = Instance.new("WeldConstraint")
	ww.Part0             = hrp
	ww.Part1             = wheel
	ww.Parent            = wheel

	-- Seat post: thin rod from wheel axle up to the seat
	local post           = Instance.new("Part")
	post.Name            = "Post"
	post.Size            = Vector3.new(0.15, 1.6, 0.15)
	post.BrickColor      = BrickColor.new("Medium stone grey")
	post.Material        = Enum.Material.Metal
	post.Massless        = true
	post.CanCollide      = false
	post.CastShadow      = false
	post.CFrame          = hrp.CFrame * CFrame.new(0, -1.3, 0)
	post.Parent          = model
	local wp             = Instance.new("WeldConstraint")
	wp.Part0             = hrp
	wp.Part1             = post
	wp.Parent            = post

	-- Seat: small flat block just below HRP
	local seat           = Instance.new("Part")
	seat.Name            = "Seat"
	seat.Size            = Vector3.new(0.9, 0.15, 0.4)
	seat.BrickColor      = BrickColor.new("Dark grey")
	seat.Material        = Enum.Material.SmoothPlastic
	seat.Massless        = true
	seat.CanCollide      = false
	seat.CastShadow      = false
	seat.CFrame          = hrp.CFrame * CFrame.new(0, -0.5, 0)
	seat.Parent          = model
	local ws             = Instance.new("WeldConstraint")
	ws.Part0             = hrp
	ws.Part1             = seat
	ws.Parent            = seat

	model.Parent = character
end

local function removeUnicycle(character)
	local uni = character:FindFirstChild("Unicycle")
	if uni then uni:Destroy() end
end
-- -----------------------------------------------------------------------

-- Kill the character server-side when their balance hits 0
Remotes.PlayerFell.OnServerEvent:Connect(function(player)
	local char = player.Character
	if char then
		local hum = char:FindFirstChild("Humanoid")
		if hum then hum.Health = 0 end
	end
end)

-- Give unicycle + signal any player who respawns mid-round
local function onCharacterAdded(player, character)
	if not gameRunning then return end
	task.delay(0.5, function()
		if character.Parent and gameRunning then
			giveUnicycle(character)
			Remotes.GameStarted:FireClient(player)
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(player, char)
	end)
end)
for _, plr in Players:GetPlayers() do
	plr.CharacterAdded:Connect(function(char)
		onCharacterAdded(plr, char)
	end)
end

-- Wave definitions ------------------------------------------------------
-- edgeWave:   wall of bullets marching in from one side (angle rotates each fire)
-- perimAimed: bullet per player from a random edge point, aimed at them
-- spiralEdge: rotating arms from the perimeter sweeping inward
local WAVES = {
	{   -- Wave 1: slow wall warmup
		{ type = "edgeWave", count = 7,  interval = 2.2, color = "Bright red"    },
	},
	{   -- Wave 2: walls + tracking
		{ type = "edgeWave",   count = 9,  interval = 1.8, color = "Bright orange" },
		{ type = "perimAimed",             interval = 1.3, color = "Bright yellow" },
	},
	{   -- Wave 3: 4-arm spiral + tracking
		{ type = "spiralEdge", arms = 4,   interval = 0.20, color = "Hot pink" },
		{ type = "perimAimed",             interval = 1.0,  color = "Cyan"     },
	},
	{   -- Wave 4: fast 6-arm spiral + wall barrage + tracking
		{ type = "spiralEdge", arms = 6,   interval = 0.13, color = "Lime green" },
		{ type = "edgeWave",   count = 12, interval = 1.3,  color = "Bright red" },
		{ type = "perimAimed",             interval = 0.7,  color = "White"      },
	},
}

local function countAlivePlayers()
	local n = 0
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		if not char then continue end
		local hum = char:FindFirstChild("Humanoid")
		if hum and hum.Health > 0 then n += 1 end
	end
	return n
end

local function runWave(waveDef)
	local connections = {}
	local height      = ARENA_CENTER.Y + 1

	for _, pattern in waveDef do
		local timer       = 0
		local spiralAngle = 0
		local waveAngle   = math.random() * 2 * math.pi

		local conn = RunService.Heartbeat:Connect(function(dt)
			timer -= dt
			if timer > 0 then return end
			timer = pattern.interval

			if pattern.type == "edgeWave" then
				BulletManager.SpawnEdgeWave(ARENA_CENTER, pattern.count, waveAngle, height, pattern.color)
				waveAngle += math.pi / 5
			elseif pattern.type == "perimAimed" then
				BulletManager.SpawnPerimeterAimed(ARENA_CENTER, height, pattern.color)
			elseif pattern.type == "spiralEdge" then
				BulletManager.SpawnSpiralEdge(ARENA_CENTER, pattern.arms, spiralAngle, height, pattern.color)
				spiralAngle += math.pi / 12
			end
		end)

		table.insert(connections, conn)
	end

	return function()
		for _, c in connections do c:Disconnect() end
		BulletManager.ClearAll()
	end
end

local function runGame()
	gameRunning = true
	print("[UniPsycho] Starting in " .. PREGAME_DELAY .. "s…")
	task.wait(PREGAME_DELAY)

	-- Mount everyone on their unicycles
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		if char then giveUnicycle(char) end
	end
	Remotes.GameStarted:FireAllClients()

	for waveIndex, waveDef in WAVES do
		print("[UniPsycho] Wave " .. waveIndex)
		local stopWave = runWave(waveDef)

		local elapsed = 0
		while elapsed < WAVE_DURATION do
			task.wait(0.5)
			elapsed += 0.5
			if countAlivePlayers() == 0 then break end
		end
		stopWave()

		if countAlivePlayers() == 0 then
			print("[UniPsycho] Everyone eliminated on wave " .. waveIndex)
			break
		end

		if waveIndex < #WAVES then
			print("[UniPsycho] Wave " .. waveIndex .. " cleared! Next in " .. BETWEEN_WAVES .. "s…")
			task.wait(BETWEEN_WAVES)
		else
			print("[UniPsycho] All waves cleared — you win!")
		end
	end

	Remotes.GameEnded:FireAllClients()
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		if char then removeUnicycle(char) end
	end

	print("[UniPsycho] Restarting in 10s…")
	gameRunning = false
	task.wait(10)
end

task.spawn(function()
	while true do
		if Players.NumPlayers > 0 then
			runGame()
		else
			task.wait(2)
		end
	end
end)
