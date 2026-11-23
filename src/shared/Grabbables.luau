--!strict
-- Helpers for finding the grabbable object a part belongs to. Used by server and client.

local CollectionService = game:GetService("CollectionService")

local Tags = require(script.Parent.Tags)

local Grabbables = {}

-- The tagged instance (part or model) that `part` belongs to, or nil if it is not grabbable.
function Grabbables.findRoot(part: Instance): Instance?
	local current: Instance? = part
	while current and current ~= workspace do
		if CollectionService:HasTag(current, Tags.Grabbable) then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- The physics root part of a grabbable (a part, or the main part of a model).
function Grabbables.rootPart(root: Instance): BasePart?
	local part: BasePart? = nil
	if root:IsA("BasePart") then
		part = root
	elseif root:IsA("Model") then
		part = root.PrimaryPart or root:FindFirstChildWhichIsA("BasePart", true)
	end
	if part then
		return part.AssemblyRootPart or part
	end
	return nil
end

function Grabbables.parts(root: Instance): { BasePart }
	local parts: { BasePart } = {}
	if root:IsA("BasePart") then
		table.insert(parts, root)
	end
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

function Grabbables.mass(root: Instance): number
	local part = Grabbables.rootPart(root)
	return if part then part.AssemblyMass else 0
end

-- Bounding box of a grabbable in world space.
function Grabbables.bounds(root: Instance): (CFrame, Vector3)
	if root:IsA("BasePart") then
		return root.CFrame, root.Size
	elseif root:IsA("Model") then
		return root:GetBoundingBox()
	end
	return CFrame.identity, Vector3.zero
end

-- Distance from `point` to the surface of the grabbable's bounding box (0 if inside).
function Grabbables.distanceTo(root: Instance, point: Vector3): number
	local cframe, size = Grabbables.bounds(root)
	local localPoint = cframe:PointToObjectSpace(point)
	local half = size / 2
	local outside = Vector3.new(
		math.max(math.abs(localPoint.X) - half.X, 0),
		math.max(math.abs(localPoint.Y) - half.Y, 0),
		math.max(math.abs(localPoint.Z) - half.Z, 0)
	)
	return outside.Magnitude
end

function Grabbables.heldBy(root: Instance): number?
	local value = root:GetAttribute("HeldBy")
	return if type(value) == "number" then value else nil
end

return Grabbables
