--!strict
-- On-screen interface: crosshair (for touch, gamepad and shift-lock), the context hint at
-- the bottom, short notifications at the top, and Grab / Throw / Turn buttons on touch screens.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Hud = {}

export type Callbacks = {
	onGrab: () -> (),
	onThrow: () -> (),
	onRotate: () -> (),
}

local toastColors = {
	info = Color3.fromRGB(28, 30, 36),
	success = Color3.fromRGB(32, 110, 60),
	warning = Color3.fromRGB(150, 80, 20),
}

local screen: ScreenGui
local crosshair: Frame
local hint: TextLabel
local toast: TextLabel
local touchFrame: Frame
local grabButton: TextButton
local throwButton: TextButton
local rotateButton: TextButton
local currentHint: string? = nil
local toastToken = 0

local function font(weight: Enum.FontWeight): Font
	return Font.new("rbxasset://fonts/families/GothamSSm.json", weight)
end

local function makeTouchButton(name: string, text: string, order: number, onActivated: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(72, 72)
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, 0, 1, -(order * 84))
	button.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	button.BackgroundTransparency = 0.25
	button.TextColor3 = Color3.new(1, 1, 1)
	button.FontFace = font(Enum.FontWeight.Bold)
	button.TextSize = 17
	button.Text = text
	button.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.6
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	button.Activated:Connect(onActivated)
	button.Parent = touchFrame
	return button
end

function Hud.init(callbacks: Callbacks)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	screen = Instance.new("ScreenGui")
	screen.Name = "EscaperHud"
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.Size = UDim2.fromOffset(8, 8)
	crosshair.BackgroundColor3 = Color3.new(1, 1, 1)
	crosshair.BorderSizePixel = 0
	crosshair.Visible = false
	local crosshairCorner = Instance.new("UICorner")
	crosshairCorner.CornerRadius = UDim.new(1, 0)
	crosshairCorner.Parent = crosshair
	local crosshairStroke = Instance.new("UIStroke")
	crosshairStroke.Thickness = 1.5
	crosshairStroke.Transparency = 0.3
	crosshairStroke.Parent = crosshair
	crosshair.Parent = screen

	hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -24)
	hint.Size = UDim2.new(0.9, 0, 0, 28)
	hint.BackgroundTransparency = 1
	hint.FontFace = font(Enum.FontWeight.Medium)
	hint.TextSize = 18
	hint.TextColor3 = Color3.new(1, 1, 1)
	hint.TextStrokeTransparency = 0.35
	hint.Text = ""
	hint.Parent = screen

	toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 16)
	toast.AutomaticSize = Enum.AutomaticSize.X
	toast.Size = UDim2.fromOffset(0, 40)
	toast.BackgroundColor3 = toastColors.info
	toast.BackgroundTransparency = 1
	toast.TextTransparency = 1
	toast.FontFace = font(Enum.FontWeight.Bold)
	toast.TextSize = 20
	toast.TextColor3 = Color3.new(1, 1, 1)
	toast.Text = ""
	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 10)
	toastCorner.Parent = toast
	local toastPadding = Instance.new("UIPadding")
	toastPadding.PaddingLeft = UDim.new(0, 18)
	toastPadding.PaddingRight = UDim.new(0, 18)
	toastPadding.Parent = toast
	toast.Parent = screen

	-- Touch buttons sit in a column above the jump button.
	touchFrame = Instance.new("Frame")
	touchFrame.Name = "TouchButtons"
	touchFrame.AnchorPoint = Vector2.new(1, 1)
	touchFrame.Position = UDim2.new(1, -24, 1, -150)
	touchFrame.Size = UDim2.fromOffset(72, 72 * 3 + 24)
	touchFrame.BackgroundTransparency = 1
	touchFrame.Visible = UserInputService.TouchEnabled
	touchFrame.Parent = screen
	grabButton = makeTouchButton("Grab", "Grab", 0, callbacks.onGrab)
	throwButton = makeTouchButton("Throw", "Throw", 1, callbacks.onThrow)
	rotateButton = makeTouchButton("Turn", "Turn", 2, callbacks.onRotate)
	throwButton.Visible = false
	rotateButton.Visible = false

	screen.Parent = playerGui
end

function Hud.setAimMode(centered: boolean)
	crosshair.Visible = centered
	touchFrame.Visible = UserInputService.TouchEnabled
end

function Hud.setHint(text: string?)
	if text == currentHint then
		return
	end
	currentHint = text
	hint.Text = text or ""
end

function Hud.setHolding(holding: boolean, canThrow: boolean)
	grabButton.Text = if holding then "Drop" else "Grab"
	throwButton.Visible = holding and canThrow
	rotateButton.Visible = holding
	crosshair.BackgroundColor3 = if holding then Color3.fromRGB(255, 210, 90) else Color3.new(1, 1, 1)
end

function Hud.toast(text: string, kind: string?)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	toast.BackgroundColor3 = toastColors[kind or "info"] or toastColors.info
	toast.BackgroundTransparency = 0.15
	toast.TextTransparency = 0
	task.delay(3, function()
		if toastToken ~= token then
			return
		end
		local fade = TweenInfo.new(0.6)
		TweenService:Create(toast, fade, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
	end)
end

return Hud
