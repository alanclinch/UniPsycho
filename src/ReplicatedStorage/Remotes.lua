local RS         = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

if RunService:IsServer() then
	local e        = Instance.new("RemoteEvent")
	e.Name         = "PlayerFell"
	e.Parent       = RS
	Remotes.PlayerFell = e
else
	Remotes.PlayerFell = RS:WaitForChild("PlayerFell")
end

return Remotes
