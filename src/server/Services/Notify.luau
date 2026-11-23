--!strict
-- Short on-screen messages ("Checkpoint reached", "Alex reset the room").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

local Notify = {}

export type Kind = "info" | "success" | "warning"

function Notify.player(player: Player, text: string, kind: Kind?)
	remote:FireClient(player, text, kind or "info")
end

function Notify.all(text: string, kind: Kind?)
	remote:FireAllClients(text, kind or "info")
end

function Notify.others(except: Player, text: string, kind: Kind?)
	for _, player in Players:GetPlayers() do
		if player ~= except then
			remote:FireClient(player, text, kind or "info")
		end
	end
end

return Notify
