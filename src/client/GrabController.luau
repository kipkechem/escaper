--!strict
-- Client side of grabbing: picks a target, asks the server, then carries the object with
-- AlignPosition / AlignOrientation constraints that this client simulates (the server gives
-- it physics ownership while held).
--
-- Controls
--   Keyboard and mouse: click or Q to grab / drop, F to throw, R to turn
--   Gamepad:            R2 to grab / drop, R1 to throw, Y to turn
--   Touch:              Grab / Throw / Turn buttons
-- Mouse aims where the pointer is; touch, gamepad and shift-lock aim at the screen centre.
-- If nothing grabbable is under the aim, the nearest one in front of you within reach is used.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local GrabMath = require(ReplicatedStorage.Shared.GrabMath)
local Grabbables = require(ReplicatedStorage.Shared.Grabbables)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Hud = require(script.Parent.Hud)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestGrab = remotes:WaitForChild("RequestGrab") :: RemoteFunction
local releaseGrab = remotes:WaitForChild("ReleaseGrab") :: RemoteEvent

local player = Players.LocalPlayer
local grab = Config.Grab

local AIM_DISTANCE = 80
local ASSIST_COSINE = 0.75
local STUCK_DISTANCE = 9
local STUCK_TIME = 0.8

type Hold = {
	root: Instance,
	rootPart: BasePart,
	mass: number,
	halfExtent: number,
	canLift: boolean,
	attachment: Attachment,
	align: AlignPosition,
	orient: AlignOrientation,
	relative: CFrame,
	turn: number,
	stuckFor: number,
	attributeConnection: RBXScriptConnection,
}

local GrabController = {}

local holding: Hold? = nil
local target: Instance? = nil
local pending = false
local highlight: Highlight

local function getCharacter(): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not rootPart then
		return nil, nil, nil
	end
	return character, humanoid, rootPart
end

local function inputFamily(): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "touch"
	elseif string.find(last.Name, "Gamepad") then
		return "gamepad"
	end
	return "keyboard"
end

local function aimsAtCentre(): boolean
	return inputFamily() ~= "keyboard" or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
end

local function aimRay(camera: Camera): Ray
	if aimsAtCentre() then
		local size = camera.ViewportSize
		return camera:ViewportPointToRay(size.X / 2, size.Y / 2)
	end
	local mouse = UserInputService:GetMouseLocation()
	return camera:ViewportPointToRay(mouse.X, mouse.Y)
end

local function heldBySomeoneElse(root: Instance): boolean
	local holder = Grabbables.heldBy(root)
	return holder ~= nil and holder ~= player.UserId
end

local function displayMass(root: Instance): number
	local mass = root:GetAttribute("Mass")
	if type(mass) == "number" then
		return mass
	end
	return math.floor(Grabbables.mass(root) + 0.5)
end

local function displayName(root: Instance): string
	local name = root:GetAttribute("DisplayName")
	return if type(name) == "string" then string.lower(name) else "object"
end

local function findTarget(character: Model, characterRoot: BasePart): Instance?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = aimRay(camera)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local result = workspace:Raycast(ray.Origin, ray.Direction.Unit * AIM_DISTANCE, params)
	if result then
		local root = Grabbables.findRoot(result.Instance)
		if
			root
			and not heldBySomeoneElse(root)
			and Grabbables.distanceTo(root, characterRoot.Position) <= grab.Reach
		then
			return root
		end
	end

	-- Aim assist: the best-aligned grabbable within reach that is in plain view.
	local best: Instance? = nil
	local bestScore = ASSIST_COSINE
	local direction = ray.Direction.Unit
	for _, root in CollectionService:GetTagged(Tags.Grabbable) do
		if not root:IsDescendantOf(workspace) or heldBySomeoneElse(root) then
			continue
		end
		if Grabbables.distanceTo(root, characterRoot.Position) > grab.Reach then
			continue
		end
		local center = (Grabbables.bounds(root)).Position
		local toCenter = center - ray.Origin
		local score = toCenter.Unit:Dot(direction)
		if score > bestScore then
			local sight = workspace:Raycast(ray.Origin, toCenter, params)
			if not sight or Grabbables.findRoot(sight.Instance) == root then
				best = root
				bestScore = score
			end
		end
	end
	return best
end

local function cameraYaw(camera: Camera): CFrame
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		-- Looking straight down: the camera's up vector points the way you face.
		local up = camera.CFrame.UpVector
		flat = Vector3.new(up.X, 0, up.Z)
	end
	if flat.Magnitude < 1e-3 then
		return CFrame.identity
	end
	return CFrame.lookAt(Vector3.zero, flat)
end

-- Snaps a rotation to the nearest of the 24 square orientations, so a crate you pick up
-- straightens itself and sits flat when you put it down.
local function snapRotation(rotation: CFrame): CFrame
	local axes =
		{ Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis, -Vector3.yAxis, Vector3.zAxis, -Vector3.zAxis }
	local function nearest(vector: Vector3, avoid: Vector3?): Vector3
		local bestAxis = Vector3.yAxis
		local bestDot = -math.huge
		for _, axis in axes do
			if avoid and math.abs(axis:Dot(avoid)) > 0.5 then
				continue
			end
			local dot = axis:Dot(vector)
			if dot > bestDot then
				bestDot = dot
				bestAxis = axis
			end
		end
		return bestAxis
	end
	local up = nearest(rotation.UpVector)
	local right = nearest(rotation.RightVector, up)
	return CFrame.fromMatrix(Vector3.zero, right, up, right:Cross(up))
end

local function setWalkFactor(factor: number)
	local _, humanoid = getCharacter()
	if humanoid then
		humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed * factor
	end
end

local function refreshHint()
	local family = inputFamily()
	local hold = holding
	if hold then
		local weight = displayMass(hold.root)
		if family == "touch" then
			Hud.setHint(string.format("Carrying %d KG", weight))
		elseif family == "gamepad" then
			Hud.setHint(
				if hold.canLift
					then "R2 drop   ·   R1 throw   ·   Y turn"
					else "R2 let go   ·   too heavy to lift, drag it"
			)
		else
			Hud.setHint(
				if hold.canLift
					then "Q / click drop   ·   F throw   ·   R turn"
					else "Q / click let go   ·   too heavy to lift, drag it"
			)
		end
		return
	end
	local root = target
	if not root then
		Hud.setHint(nil)
		return
	end
	local weight = displayMass(root)
	local verb = if GrabMath.canLift(weight) then "Grab" else "Drag"
	local key = if family == "touch" then "Tap Grab" elseif family == "gamepad" then "R2" else "Click / Q"
	local note = if GrabMath.canLift(weight) then "" else ", too heavy to lift"
	Hud.setHint(string.format("%s   ·   %s %s (%d KG%s)", key, verb, displayName(root), weight, note))
end

local function endHold(throw: boolean)
	local hold = holding
	if not hold then
		return
	end
	holding = nil
	hold.attributeConnection:Disconnect()
	hold.align:Destroy()
	hold.orient:Destroy()
	hold.attachment:Destroy()
	setWalkFactor(1)
	Hud.setHolding(false, false)

	local rootPart = hold.rootPart
	local _, _, characterRoot = getCharacter()
	local camera = workspace.CurrentCamera
	if throw and camera and rootPart:IsDescendantOf(workspace) then
		local speed = GrabMath.throwSpeed(hold.mass)
		local direction = (camera.CFrame.LookVector + Vector3.new(0, 0.2, 0)).Unit
		local carry = if characterRoot then characterRoot.AssemblyLinearVelocity * 0.5 else Vector3.zero
		rootPart.AssemblyLinearVelocity = direction * speed + carry
	elseif rootPart:IsDescendantOf(workspace) then
		-- Let go gently: keep the drift, but no flinging.
		local velocity = rootPart.AssemblyLinearVelocity
		if velocity.Magnitude > 12 then
			rootPart.AssemblyLinearVelocity = velocity.Unit * 12
		end
	end
	releaseGrab:FireServer()
	refreshHint()
end

local function beginHold(root: Instance)
	local rootPart = Grabbables.rootPart(root)
	local camera = workspace.CurrentCamera
	if not rootPart or not camera then
		return
	end
	local mass = rootPart.AssemblyMass
	local canLift = GrabMath.canLift(mass)
	local _, size = Grabbables.bounds(root)
	local halfExtent = math.max(size.X, size.Y, size.Z) / 2

	local attachment = Instance.new("Attachment")
	attachment.Name = "EscaperGrab"
	attachment.Position = rootPart.CFrame:PointToObjectSpace(rootPart.AssemblyCenterOfMass)
	attachment.Parent = rootPart

	local horizontal, vertical = GrabMath.holdForces(workspace.Gravity)
	local align = Instance.new("AlignPosition")
	align.Name = "EscaperHold"
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	align.ForceRelativeTo = Enum.ActuatorRelativeTo.World
	align.MaxAxesForce = Vector3.new(horizontal, vertical, horizontal)
	align.MaxVelocity = GrabMath.holdSpeed(mass)
	align.Responsiveness = grab.Responsiveness
	align.Position = rootPart.AssemblyCenterOfMass
	align.Parent = rootPart

	local yaw = cameraYaw(camera)
	local orient = Instance.new("AlignOrientation")
	orient.Name = "EscaperTurn"
	orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orient.Attachment0 = attachment
	orient.MaxTorque = 1e7
	orient.MaxAngularVelocity = 8
	orient.Responsiveness = 25
	orient.Enabled = canLift
	orient.Parent = rootPart

	local hold: Hold = {
		root = root,
		rootPart = rootPart,
		mass = mass,
		halfExtent = halfExtent,
		canLift = canLift,
		attachment = attachment,
		align = align,
		orient = orient,
		relative = snapRotation(yaw:Inverse() * rootPart.CFrame.Rotation),
		turn = 0,
		stuckFor = 0,
		attributeConnection = root:GetAttributeChangedSignal("HeldBy"):Connect(function()
			-- The server let go (reset, too far away, someone else's turn).
			if root:GetAttribute("HeldBy") ~= player.UserId and holding and holding.root == root then
				endHold(false)
			end
		end),
	}
	orient.CFrame = yaw * hold.relative
	holding = hold
	setWalkFactor(GrabMath.walkFactor(mass))
	Hud.setHolding(true, canLift)
	highlight.Adornee = nil
	highlight.Parent = nil
	refreshHint()
end

local function tryGrab()
	if pending or holding then
		return
	end
	local root = target
	if not root then
		return
	end
	local part = Grabbables.rootPart(root)
	if not part then
		return
	end
	pending = true
	local ok, okOrError, reason = pcall(function()
		return requestGrab:InvokeServer(part)
	end)
	pending = false
	if ok and okOrError == true then
		if getCharacter() and root:IsDescendantOf(workspace) then
			beginHold(root)
		else
			releaseGrab:FireServer()
		end
	elseif ok and type(reason) == "string" then
		Hud.toast(reason, "warning")
	end
end

local function toggleGrab()
	if holding then
		endHold(false)
	else
		-- The request waits for the server; input callbacks must not yield.
		task.spawn(tryGrab)
	end
end

local function throw()
	local hold = holding
	if hold and hold.canLift then
		endHold(true)
	end
end

local function rotate()
	local hold = holding
	if hold then
		hold.turn += math.rad(grab.RotateStep)
	end
end

local function updateHold(hold: Hold, dt: number, character: Model, characterRoot: BasePart, camera: Camera)
	local look = camera.CFrame.LookVector
	local origin = characterRoot.Position + Vector3.new(0, 1.5, 0)
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = characterRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	flat = flat.Unit
	local pitch = math.asin(math.clamp(look.Y, -1, 1))
	local distance = grab.HoldGap + hold.halfExtent * 1.2
	-- Keep the object in front of you even when looking straight down.
	local forward = math.max(distance * math.cos(pitch), hold.halfExtent + 1)
	local goal = origin + flat * forward + Vector3.new(0, distance * math.sin(pitch), 0)

	-- Do not try to push it through walls.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, hold.root }
	local offset = goal - origin
	local hit = workspace:Raycast(origin, offset, params)
	if hit then
		goal = origin + offset.Unit * math.max(hit.Distance - hold.halfExtent, 0.5)
	end
	hold.align.Position = goal
	hold.orient.CFrame = cameraYaw(camera) * CFrame.Angles(0, hold.turn, 0) * hold.relative

	-- Drop it if it is snagged far from where it should be.
	if (hold.rootPart.AssemblyCenterOfMass - goal).Magnitude > STUCK_DISTANCE then
		hold.stuckFor += dt
		if hold.stuckFor > STUCK_TIME then
			endHold(false)
		end
	else
		hold.stuckFor = 0
	end
end

local function onRenderStep(dt: number)
	local character, _, characterRoot = getCharacter()
	local camera = workspace.CurrentCamera
	Hud.setAimMode(aimsAtCentre())

	local hold = holding
	if hold then
		if
			not character
			or not characterRoot
			or not camera
			or not hold.rootPart:IsDescendantOf(workspace)
		then
			endHold(false)
		else
			updateHold(hold, dt, character, characterRoot, camera)
		end
		refreshHint()
		return
	end

	if pending then
		return
	end
	local newTarget = if character and characterRoot then findTarget(character, characterRoot) else nil
	if newTarget ~= target then
		target = newTarget
		if newTarget then
			highlight.OutlineColor = if GrabMath.canLift(displayMass(newTarget))
				then Config.Colors.Highlight
				else Config.Colors.TooHeavy
			highlight.Adornee = newTarget
			highlight.Parent = newTarget
		else
			highlight.Adornee = nil
			highlight.Parent = nil
		end
	end
	refreshHint()
end

function GrabController.start()
	highlight = Instance.new("Highlight")
	highlight.Name = "EscaperTarget"
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded

	Hud.init({ onGrab = toggleGrab, onThrow = throw, onRotate = rotate })

	local function bind(name: string, callback: () -> (), onlyWhileHolding: boolean, ...: Enum.KeyCode)
		ContextActionService:BindAction(name, function(_, state)
			if state ~= Enum.UserInputState.Begin then
				return Enum.ContextActionResult.Pass
			end
			if onlyWhileHolding and not holding then
				return Enum.ContextActionResult.Pass
			end
			callback()
			return Enum.ContextActionResult.Sink
		end, false, ...)
	end
	bind("EscaperGrab", toggleGrab, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonR2)
	bind("EscaperThrow", throw, true, Enum.KeyCode.F, Enum.KeyCode.ButtonR1)
	bind("EscaperRotate", rotate, true, Enum.KeyCode.R, Enum.KeyCode.ButtonY)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			toggleGrab()
		end
	end)

	player.CharacterRemoving:Connect(function()
		endHold(false)
	end)

	RunService:BindToRenderStep("EscaperGrab", Enum.RenderPriority.Camera.Value + 1, onRenderStep)
end

return GrabController
