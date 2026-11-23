--!strict
-- Tag: Lever (a model with an anchored "Handle" part; the prompt goes on "Base" if present)
-- Attributes:
--   Output (string)       signal the lever drives
--   Mode (string)         "Toggle" (default): each pull flips it
--                         "Timed": a pull turns it on for Duration seconds
--   Duration (number)     seconds for Timed mode (default 6)
--   Label (string)        prompt text, e.g. "Shutter"
-- The handle swings about its bottom edge; on and off are 35 degrees either side of
-- how it was built.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Signals = require(script.Parent.Parent.Services.Signals)

local SWING = math.rad(35)
local SWING_TIME = 0.25

local Lever = {}
Lever.__index = Lever

export type Lever = typeof(setmetatable(
	{} :: {
		instance: Instance,
		scope: Instance,
		output: string,
		mode: string,
		duration: number,
		on: boolean,
		handle: BasePart?,
		pivot: CFrame,
		offset: CFrame,
		prompt: ProximityPrompt,
		lamp: BasePart?,
		token: number,
	},
	Lever
))

function Lever.new(instance: Instance): Lever
	local handle = instance:FindFirstChild("Handle")
	local handlePart: BasePart? = if handle and handle:IsA("BasePart") then handle else nil
	local promptParent = instance:FindFirstChild("Base") or handlePart or instance
	local lamp = instance:FindFirstChild("Lamp")

	local pivot = CFrame.identity
	local offset = CFrame.identity
	if handlePart then
		handlePart.Anchored = true
		pivot = handlePart.CFrame * CFrame.new(0, -handlePart.Size.Y / 2, 0)
		offset = pivot:Inverse() * handlePart.CFrame
	end

	local label = instance:GetAttribute("Label")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LeverPrompt"
	prompt.ActionText = "Pull"
	prompt.ObjectText = if type(label) == "string" then label else "Lever"
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptParent

	local mode = instance:GetAttribute("Mode")
	local duration = instance:GetAttribute("Duration")
	local output = instance:GetAttribute("Output")
	local self = setmetatable({
		instance = instance,
		scope = Signals.scopeFor(instance),
		output = if type(output) == "string" then output else "",
		mode = if mode == "Timed" then "Timed" else "Toggle",
		duration = if type(duration) == "number" then duration else 6,
		on = false,
		handle = handlePart,
		pivot = pivot,
		offset = offset,
		prompt = prompt,
		lamp = if lamp and lamp:IsA("BasePart") then lamp else nil,
		token = 0,
	}, Lever)

	prompt.Triggered:Connect(function()
		if self.mode == "Timed" then
			self:set(true)
			self.token += 1
			local token = self.token
			task.delay(self.duration, function()
				if self.token == token then
					self:set(false)
				end
			end)
		else
			self:set(not self.on)
		end
	end)

	self:set(false, true)
	return self
end

function Lever.set(self: Lever, on: boolean, instant: boolean?)
	self.on = on
	Signals.set(self.scope, self.output, self, on)
	self.instance:SetAttribute("On", on)
	if self.lamp then
		self.lamp.Color = if on then Config.Colors.On else Config.Colors.Off
	end
	local handle = self.handle
	if handle then
		local goal = self.pivot * CFrame.Angles(if on then SWING else -SWING, 0, 0) * self.offset
		if instant then
			handle.CFrame = goal
		else
			TweenService:Create(handle, TweenInfo.new(SWING_TIME, Enum.EasingStyle.Back), { CFrame = goal })
				:Play()
		end
	end
end

function Lever.reset(self: Lever)
	self.token += 1
	self:set(false)
end

function Lever.destroy(self: Lever)
	self.token += 1
	Signals.set(self.scope, self.output, self, false)
	self.prompt:Destroy()
end

return Lever
