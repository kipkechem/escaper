--!strict
-- Tag: Indicator (a part that lights up)
-- Attributes:
--   Input (string)   expression of signals; the light is green while it is true
-- Put these above doors and along walls so players can see what is connected to what.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Signals = require(script.Parent.Parent.Services.Signals)
local Wiring = require(script.Parent.Parent.Services.Wiring)

local Indicator = {}
Indicator.__index = Indicator

export type Indicator = typeof(setmetatable(
	{} :: {
		instance: BasePart,
		scope: Instance,
		watcher: Wiring.Watcher?,
	},
	Indicator
))

function Indicator.new(instance: Instance): Indicator?
	if not instance:IsA("BasePart") then
		return nil
	end
	local input = instance:GetAttribute("Input")
	local self = setmetatable({
		instance = instance,
		scope = Signals.scopeFor(instance),
		watcher = nil,
	}, Indicator)
	instance.Material = Enum.Material.Neon
	if type(input) == "string" then
		self.watcher = Wiring.watch(instance, input, function(value)
			self:render(value)
		end)
	end
	self:render(if self.watcher then self.watcher.value else false)
	return self
end

function Indicator.render(self: Indicator, on: boolean)
	self.instance.Color = if on then Config.Colors.On else Config.Colors.Off
end

function Indicator.destroy(self: Indicator)
	if self.watcher then
		self.watcher.disconnect()
	end
end

return Indicator
