-- Creates the arena floor and removes the default Baseplate.
-- Swap this out for a real model once you have art.

local ARENA_SIZE   = Vector3.new(90, 2, 90)
local ARENA_CENTER = Vector3.new(0, 0, 0)

local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then baseplate:Destroy() end

local floor             = Instance.new("Part")
floor.Name              = "ArenaFloor"
floor.Size              = ARENA_SIZE
floor.CFrame            = CFrame.new(ARENA_CENTER)
floor.Anchored          = true
floor.BrickColor        = BrickColor.new("Dark grey")
floor.Material          = Enum.Material.SmoothPlastic
floor.TopSurface        = Enum.SurfaceType.Smooth
floor.BottomSurface     = Enum.SurfaceType.Smooth
floor.Parent            = workspace

-- Optional: kill any player who falls below the floor (Roblox handles this
-- automatically via the void, but an explicit kill zone is more responsive)
local killPart          = Instance.new("Part")
killPart.Name           = "KillZone"
killPart.Size           = Vector3.new(1000, 2, 1000)
killPart.CFrame         = CFrame.new(0, -30, 0)
killPart.Anchored       = true
killPart.CanCollide     = false
killPart.Transparency   = 1
killPart.Parent         = workspace

killPart.Touched:Connect(function(hit)
	local character = hit.Parent
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if hum then hum.Health = 0 end
end)
