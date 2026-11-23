--!strict
-- Pure maths for the counterweight lift, kept separate so it can be unit tested.
--
-- The lift has two platforms on one rope. `s` is how far the cargo platform (A) has
-- dropped, which is also how far the rider platform (B) has risen. 0 <= s <= travel.

local LiftMath = {}

-- +1: A is heavier, A goes down and B goes up.
-- -1: B is heavier, B goes down and A goes up.
--  0: within the deadband, the lift holds still.
function LiftMath.direction(loadA: number, loadB: number, deadband: number): number
	local difference = loadA - loadB
	if difference > deadband then
		return 1
	elseif difference < -deadband then
		return -1
	end
	return 0
end

-- A bigger imbalance moves the lift faster, within limits.
function LiftMath.speed(loadA: number, loadB: number, baseSpeed: number): number
	local imbalance = math.abs(loadA - loadB)
	return baseSpeed * math.clamp(imbalance / 20, 0.5, 1.5)
end

function LiftMath.step(s: number, direction: number, speed: number, dt: number, travel: number): number
	return math.clamp(s + direction * speed * dt, 0, travel)
end

return LiftMath
