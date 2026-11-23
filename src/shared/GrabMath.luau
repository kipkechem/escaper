--!strict
-- Pure maths for carrying and throwing, kept separate so it can be unit tested.

local Config = require(script.Parent.Config)

local GrabMath = {}

local grab = Config.Grab

function GrabMath.canLift(mass: number): boolean
	return mass <= grab.LiftCapacity
end

-- Fastest a held object may move.
function GrabMath.holdSpeed(mass: number): number
	return math.clamp(grab.SpeedBudget / math.max(mass, 0.1), grab.MinHoldSpeed, grab.MaxHoldSpeed)
end

-- Launch speed for a throw. Objects too heavy to lift cannot be thrown.
function GrabMath.throwSpeed(mass: number): number
	if not GrabMath.canLift(mass) then
		return 0
	end
	return math.min(grab.ThrowImpulse / math.max(mass, 0.1), grab.ThrowMaxSpeed)
end

-- Walk speed multiplier while carrying `mass`. Light objects barely slow you down.
function GrabMath.walkFactor(mass: number): number
	local load = mass / (grab.LiftCapacity * 1.5)
	return math.clamp(1 - load, grab.MinWalkFactor, 1)
end

-- Force limits for the hold constraint: lifting is capped, dragging is stronger.
function GrabMath.holdForces(gravity: number): (number, number)
	local vertical = grab.LiftCapacity * gravity * 1.1
	local horizontal = grab.LiftCapacity * gravity * grab.DragStrength
	return horizontal, vertical
end

-- How much of a held object's mass presses down through the holder's feet.
function GrabMath.carriedWeight(mass: number): number
	if GrabMath.canLift(mass) then
		return mass
	end
	-- A dragged object mostly rests on the floor; the holder bears none of it.
	return 0
end

return GrabMath
