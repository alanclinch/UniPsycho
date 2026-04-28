local RS         = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

if RunService:IsServer() then
	for _, name in { "PlayerFell", "GameStarted", "GameEnded" } do
		local e  = Instance.new("RemoteEvent")
		e.Name   = name
		e.Parent = RS
		Remotes[name] = e
	end
else
	for _, name in { "PlayerFell", "GameStarted", "GameEnded" } do
		Remotes[name] = RS:WaitForChild(name)
	end
end

return Remotes
