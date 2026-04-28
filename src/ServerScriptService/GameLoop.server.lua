local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local BulletManager = require(script.Parent.BulletManager)
local Remotes       = require(ReplicatedStorage.Remotes)

local ARENA_CENTER  = Vector3.new(0, 4, 0)
local PREGAME_DELAY = 3
local GRACE_PERIOD  = 10  -- seconds after round start before any bullets spawn
local gameRunning   = false
local gameStartTime = 0

-- Unicycle model --------------------------------------------------------
local function giveUnicycle(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local existing = character:FindFirstChild("Unicycle")
	if existing then existing:Destroy() end

	local template = ServerStorage:FindFirstChild("Unicycle")
	if not template then
		warn("[UniPsycho] Put your Unicycle model in ServerStorage named 'Unicycle'")
		return
	end

	local model  = template:Clone()
	model.Name   = "Unicycle"
	model.Parent = character

	-- Position below the character AND face the same direction as the player.
	-- Adjust Y_OFFSET if the wheel is buried (more positive = higher up).
	local Y_OFFSET  = -1.5
	local targetPos = hrp.Position + Vector3.new(0, Y_OFFSET, 0)
	local look      = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	if look.Magnitude < 0.01 then look = Vector3.new(0, 0, -1) end
	model:PivotTo(CFrame.lookAt(targetPos, targetPos + look.Unit))

	-- Pass 1: disable physics
	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") then continue end
		part.Massless   = true
		part.CanCollide = false
		part.Anchored   = false
	end

	-- Pass 2: weld to HRP
	local welded = 0
	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") then continue end
		local weld  = Instance.new("Weld")
		weld.Part0  = hrp
		weld.Part1  = part
		weld.C0     = hrp.CFrame:Inverse() * part.CFrame
		weld.C1     = CFrame.new()
		weld.Parent = hrp
		welded     += 1
	end
	print("[UniPsycho] Unicycle attached to", character.Name, "—", welded, "parts welded")
end

local function removeUnicycle(character)
	local uni = character:FindFirstChild("Unicycle")
	if uni then uni:Destroy() end
end
-- -----------------------------------------------------------------------

Remotes.PlayerFell.OnServerEvent:Connect(function(player)
	local char = player.Character
	if char then
		local hum = char:FindFirstChild("Humanoid")
		if hum then hum.Health = 0 end
	end
end)

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
	player.CharacterAdded:Connect(function(char) onCharacterAdded(player, char) end)
end)
for _, plr in Players:GetPlayers() do
	plr.CharacterAdded:Connect(function(char) onCharacterAdded(plr, char) end)
end

-- Vampire Survivors-style spawner table --------------------------------
-- Spawners unlock at `unlockAt` seconds into the round.
-- All intervals shrink over time so everything accelerates continuously.
local SPAWNERS = {
	-- t=0:   one slow aimed bullet — the whole game starts with just this
	{ unlockAt =   0, type = "perimAimed",              baseInterval = 4.0, color = "Bright red"    },
	-- t=25:  a wall of 5 bullets from one edge
	{ unlockAt =  25, type = "edgeWave",   count =  5,  baseInterval = 4.0, color = "Bright orange" },
	-- t=50:  second aimed bullet stream (different color so players can read them)
	{ unlockAt =  50, type = "perimAimed",              baseInterval = 3.0, color = "Bright yellow" },
	-- t=80:  3-arm spiral sweeping inward from the perimeter
	{ unlockAt =  80, type = "spiralEdge", arms  =  3,  baseInterval = 0.28, color = "Hot pink"     },
	-- t=110: bigger edge wave
	{ unlockAt = 110, type = "edgeWave",   count =  9,  baseInterval = 3.0, color = "Cyan"          },
	-- t=140: 5-arm spiral
	{ unlockAt = 140, type = "spiralEdge", arms  =  5,  baseInterval = 0.18, color = "Lime green"   },
	-- t=170: dense wall
	{ unlockAt = 170, type = "edgeWave",   count = 14,  baseInterval = 2.2, color = "Bright red"    },
	-- t=200: fast 7-arm spiral — near-endgame chaos
	{ unlockAt = 200, type = "spiralEdge", arms  =  7,  baseInterval = 0.10, color = "White"        },
}

-- Interval scales to 15% of base over ~8 minutes so the game keeps accelerating
local function scaledInterval(base, elapsed)
	return math.max(base * 0.15, base * (1 - elapsed / 500))
end

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

local function runGame()
	gameRunning   = true
	gameStartTime = tick()

	print("[UniPsycho] Starting in " .. PREGAME_DELAY .. "s…")
	task.wait(PREGAME_DELAY)

	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		if char then giveUnicycle(char) end
	end
	Remotes.GameStarted:FireAllClients()

	local activeConns = {}

	-- Schedule each spawner to unlock after its delay
	for _, spawner in SPAWNERS do
		local s = spawner
		task.delay(s.unlockAt + GRACE_PERIOD, function()
			if not gameRunning then return end
			print("[UniPsycho] +" .. s.type .. " unlocked at t=" .. s.unlockAt .. "s")

			local timer       = 0
			local spiralAngle = math.random() * 2 * math.pi
			local waveAngle   = math.random() * 2 * math.pi
			local height      = ARENA_CENTER.Y + 1

			local conn = RunService.Heartbeat:Connect(function(dt)
				if not gameRunning then return end
				local elapsed = tick() - gameStartTime
				timer -= dt
				if timer > 0 then return end
				timer = scaledInterval(s.baseInterval, elapsed)

				if s.type == "perimAimed" then
					BulletManager.SpawnPerimeterAimed(ARENA_CENTER, height, s.color)
				elseif s.type == "edgeWave" then
					BulletManager.SpawnEdgeWave(ARENA_CENTER, s.count, waveAngle, height, s.color)
					waveAngle += math.pi / 5
				elseif s.type == "spiralEdge" then
					BulletManager.SpawnSpiralEdge(ARENA_CENTER, s.arms, spiralAngle, height, s.color)
					spiralAngle += math.pi / 12
				end
			end)

			table.insert(activeConns, conn)
		end)
	end

	-- Run until everyone is dead
	while countAlivePlayers() > 0 do
		task.wait(0.5)
	end

	-- Stop everything before any pending task.delays fire new spawners
	gameRunning = false
	for _, c in activeConns do c:Disconnect() end
	BulletManager.ClearAll()

	Remotes.GameEnded:FireAllClients()
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		if char then removeUnicycle(char) end
	end

	print("[UniPsycho] Game over. Restarting in 10s…")
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
