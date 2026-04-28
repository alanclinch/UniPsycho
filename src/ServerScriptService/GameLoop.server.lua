local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BulletManager = require(script.Parent.BulletManager)
local Remotes       = require(ReplicatedStorage.Remotes)

-- Kill the character for any player whose balance hits 0 (fired from client)
Remotes.PlayerFell.OnServerEvent:Connect(function(player)
	local char = player.Character
	if char then
		local hum = char:FindFirstChild("Humanoid")
		if hum then hum.Health = 0 end
	end
end)

local ARENA_CENTER   = Vector3.new(0, 4, 0)
local WAVE_DURATION  = 30   -- seconds each wave runs
local BETWEEN_WAVES  = 5    -- seconds of breathing room between waves
local PREGAME_DELAY  = 3    -- countdown before wave 1

--[[
  Wave table. Each wave is a list of attack patterns that fire simultaneously.
  Types:
    radial  – even ring of `count` bullets from the center
    aimed   – one bullet per living player, tracked from the center
    spiral  – rotating arms; fires repeatedly with increasing angleOffset
]]
local WAVES = {
	{   -- Wave 1: slow warmup ring
		{ type = "radial", count = 8,  interval = 2.0,  color = "Bright red"    },
	},
	{   -- Wave 2: denser ring + tracking shots
		{ type = "radial", count = 12, interval = 1.6,  color = "Bright orange" },
		{ type = "aimed",              interval = 1.4,  color = "Bright yellow" },
	},
	{   -- Wave 3: 4-arm spiral + tracking
		{ type = "spiral", arms = 4,   interval = 0.18, color = "Hot pink"      },
		{ type = "aimed",              interval = 1.0,  color = "Cyan"          },
	},
	{   -- Wave 4: fast 6-arm spiral + barrage + tracking
		{ type = "spiral", arms = 6,   interval = 0.12, color = "Lime green"    },
		{ type = "radial", count = 16, interval = 1.4,  color = "Bright red"    },
		{ type = "aimed",              interval = 0.8,  color = "White"         },
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

-- Starts all patterns in a wave. Returns a stop() function.
local function runWave(waveDef)
	local connections = {}

	for _, pattern in waveDef do
		local timer       = 0
		local spiralAngle = 0
		local height      = ARENA_CENTER.Y + 1

		local conn = RunService.Heartbeat:Connect(function(dt)
			timer -= dt
			if timer > 0 then return end
			timer = pattern.interval

			if pattern.type == "radial" then
				BulletManager.SpawnRadial(ARENA_CENTER, pattern.count, height, pattern.color)
			elseif pattern.type == "aimed" then
				BulletManager.SpawnAimed(ARENA_CENTER, height, pattern.color)
			elseif pattern.type == "spiral" then
				BulletManager.SpawnSpiral(ARENA_CENTER, pattern.arms, spiralAngle, height, pattern.color)
				spiralAngle += math.pi / 14
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
	print("[UniPsycho] Starting in " .. PREGAME_DELAY .. "s…")
	task.wait(PREGAME_DELAY)

	for waveIndex, waveDef in WAVES do
		print("[UniPsycho] Wave " .. waveIndex .. " — begin!")
		local stopWave = runWave(waveDef)

		-- Run the wave until time is up or everyone is dead
		local elapsed = 0
		while elapsed < WAVE_DURATION do
			task.wait(0.5)
			elapsed += 0.5
			if countAlivePlayers() == 0 then break end
		end

		stopWave()

		if countAlivePlayers() == 0 then
			print("[UniPsycho] All players eliminated on wave " .. waveIndex .. ".")
			break
		end

		if waveIndex < #WAVES then
			print("[UniPsycho] Wave " .. waveIndex .. " cleared! Next wave in " .. BETWEEN_WAVES .. "s…")
			task.wait(BETWEEN_WAVES)
		else
			print("[UniPsycho] All waves cleared — you win!")
		end
	end

	print("[UniPsycho] Restarting in 10s…")
	task.wait(10)
end

-- Outer loop: wait for at least one player, then run the game
task.spawn(function()
	while true do
		if Players.NumPlayers > 0 then
			runGame()
		else
			task.wait(2)
		end
	end
end)
