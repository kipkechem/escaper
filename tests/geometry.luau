--!nonstrict
-- Box maths shared by the geometry tests.

local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3

local Geometry = {}

-- World-space bounding box of a part, allowing for its rotation.
function Geometry.aabb(cframe: any, size: any): (any, any)
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cframe:GetComponents()
	local half = size / 2
	local extent = Vector3.new(
		math.abs(r00) * half.X + math.abs(r01) * half.Y + math.abs(r02) * half.Z,
		math.abs(r10) * half.X + math.abs(r11) * half.Y + math.abs(r12) * half.Z,
		math.abs(r20) * half.X + math.abs(r21) * half.Y + math.abs(r22) * half.Z
	)
	return cframe.Position - extent, cframe.Position + extent
end

function Geometry.partBox(part: any): (any, any)
	return Geometry.aabb(part.CFrame, part.Size)
end

-- How deeply two boxes overlap: the smallest axis overlap. <= 0 means they are apart
-- (0 means touching).
function Geometry.overlap(minA: any, maxA: any, minB: any, maxB: any): number
	local x = math.min(maxA.X, maxB.X) - math.max(minA.X, minB.X)
	local y = math.min(maxA.Y, maxB.Y) - math.max(minA.Y, minB.Y)
	local z = math.min(maxA.Z, maxB.Z) - math.max(minA.Z, minB.Z)
	return math.min(x, y, z)
end

-- A box given in some frame's coordinates, as a world-space bounding box.
function Geometry.transformBox(frame: any, min: any, max: any): (any, any)
	local center = (min + max) / 2
	return Geometry.aabb(frame * roblox.CFrame.new(center), max - min)
end

function Geometry.inside(minA: any, maxA: any, minB: any, maxB: any, tolerance: number): boolean
	return minA.X >= minB.X - tolerance
		and minA.Y >= minB.Y - tolerance
		and minA.Z >= minB.Z - tolerance
		and maxA.X <= maxB.X + tolerance
		and maxA.Y <= maxB.Y + tolerance
		and maxA.Z <= maxB.Z + tolerance
end

function Geometry.describe(min: any, max: any): string
	return string.format("(%.1f, %.1f, %.1f)-(%.1f, %.1f, %.1f)", min.X, min.Y, min.Z, max.X, max.Y, max.Z)
end

return Geometry
