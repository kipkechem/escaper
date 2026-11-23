--!strict
-- Floating weight display above plates and lift platforms: a label, "23 / 40 KG" and a bar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Gauge = {}
Gauge.__index = Gauge

export type Gauge = typeof(setmetatable(
	{} :: {
		gui: BillboardGui,
		value: TextLabel,
		fill: Frame,
	},
	Gauge
))

local function label(parent: Instance, name: string, position: UDim2, size: UDim2, text: string): TextLabel
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = name
	textLabel.BackgroundTransparency = 1
	textLabel.Position = position
	textLabel.Size = size
	textLabel.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	textLabel.TextScaled = true
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextStrokeTransparency = 0.4
	textLabel.Text = text
	textLabel.Parent = parent
	return textLabel
end

function Gauge.new(adornee: BasePart, title: string, offset: Vector3): Gauge
	local gui = Instance.new("BillboardGui")
	gui.Name = "WeightGauge"
	gui.Size = UDim2.new(6, 0, 2.2, 0)
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Adornee = adornee

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	background.BackgroundTransparency = 0.35
	background.BorderSizePixel = 0
	background.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.12, 0)
	corner.Parent = background

	label(background, "Title", UDim2.fromScale(0.05, 0.04), UDim2.fromScale(0.9, 0.3), title)
	local value = label(background, "Value", UDim2.fromScale(0.05, 0.34), UDim2.fromScale(0.9, 0.36), "")

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromScale(0.08, 0.76)
	bar.Size = UDim2.fromScale(0.84, 0.14)
	bar.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
	bar.BorderSizePixel = 0
	bar.Parent = background
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Config.Colors.Off
	fill.Parent = bar

	gui.Parent = adornee
	return setmetatable({ gui = gui, value = value, fill = fill }, Gauge)
end

function Gauge.set(self: Gauge, mass: number, required: number, active: boolean)
	self:show(string.format("%d / %d KG", mass, required), mass / math.max(required, 1), active)
end

function Gauge.show(self: Gauge, text: string, fraction: number, active: boolean)
	self.value.Text = text
	self.fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	self.fill.BackgroundColor3 = if active then Config.Colors.On else Config.Colors.Off
end

function Gauge.destroy(self: Gauge)
	self.gui:Destroy()
end

return Gauge
