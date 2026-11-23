--!strict
-- Client entry point: grabbing and the HUD, plus server notifications.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GrabController = require(script.GrabController)
local Hud = require(script.Hud)

GrabController.start()

local notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent
notify.OnClientEvent:Connect(function(text: string, kind: string?)
	Hud.toast(text, kind)
end)

Hud.toast("Escape the Loading Dock", "info")
