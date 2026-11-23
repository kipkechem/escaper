--!nonstrict
-- The pure logic: the wiring expression language, lift maths and carrying maths.

local t = require("../harness")
local Loader = require("../loader")

local describe, it, expectEqual, expectNear = t.describe, t.it, t.expectEqual, t.expectNear

local shared = "src/shared"
local Expression = Loader.require(shared .. "/Expression.luau")
local LiftMath = Loader.require(shared .. "/LiftMath.luau")
local GrabMath = Loader.require(shared .. "/GrabMath.luau")
local Config = Loader.require(shared .. "/Config.luau")

local function lookupFrom(values: { [string]: boolean })
	return function(name: string): boolean
		return values[name] == true
	end
end

describe("Expression", function()
	local function eval(source: string, values: { [string]: boolean }): boolean
		local compiled, err = Expression.compile(source)
		assert(compiled, err)
		return compiled.evaluate(lookupFrom(values))
	end

	it("reads a single name", function()
		expectEqual(eval("Plate", { Plate = true }), true)
		expectEqual(eval("Plate", {}), false)
	end)

	it("supports and / or / not with symbols and words", function()
		expectEqual(eval("A & B", { A = true, B = true }), true)
		expectEqual(eval("A & B", { A = true }), false)
		expectEqual(eval("A | B", { B = true }), true)
		expectEqual(eval("!A", {}), true)
		expectEqual(eval("A and not B", { A = true }), true)
		expectEqual(eval("A && B || C", { C = true }), true)
	end)

	it("gives and higher precedence than or", function()
		expectEqual(eval("A | B & C", { A = true }), true)
		expectEqual(eval("A | B & C", { B = true }), false)
		expectEqual(eval("(A | B) & C", { A = true }), false)
		expectEqual(eval("(A | B) & C", { A = true, C = true }), true)
	end)

	it("handles double negation and constants", function()
		expectEqual(eval("!!A", { A = true }), true)
		expectEqual(eval("true", {}), true)
		expectEqual(eval("false | A", { A = true }), true)
	end)

	it("lists each referenced name once", function()
		local compiled = Expression.compile("(A & B) | !A | Room.C")
		assert(compiled, "did not compile")
		expectEqual(#compiled.names, 3)
		expectEqual(compiled.names[1], "A")
		expectEqual(compiled.names[2], "B")
		expectEqual(compiled.names[3], "Room.C")
	end)

	it("rejects broken expressions with a message", function()
		for _, source in { "", "A &", "(A", "A B", "A $ B", ")" } do
			local compiled, err = Expression.compile(source)
			expectEqual(compiled, nil, source)
			assert(type(err) == "string" and #err > 0, "missing message for " .. source)
		end
	end)
end)

describe("LiftMath", function()
	it("holds still inside the deadband", function()
		expectEqual(LiftMath.direction(37, 35, 2), 0)
		expectEqual(LiftMath.direction(33, 35, 2), 0)
	end)

	it("moves towards the heavier side", function()
		expectEqual(LiftMath.direction(40, 35, 2), 1)
		expectEqual(LiftMath.direction(0, 10, 2), -1)
	end)

	it("speeds up with imbalance, within limits", function()
		local base = 5
		expectNear(LiftMath.speed(21, 20, base), base * 0.5, 1e-6, "small imbalance")
		expectNear(LiftMath.speed(40, 20, base), base, 1e-6, "imbalance of 20")
		expectNear(LiftMath.speed(200, 0, base), base * 1.5, 1e-6, "huge imbalance")
	end)

	it("clamps travel to the ends", function()
		expectEqual(LiftMath.step(15.9, 1, 5, 1, 16), 16)
		expectEqual(LiftMath.step(0.1, -1, 5, 1, 16), 0)
		expectNear(LiftMath.step(4, 1, 5, 0.1, 16), 4.5, 1e-6)
	end)
end)

describe("GrabMath", function()
	local capacity = Config.Grab.LiftCapacity

	it("lets players lift crates but only drag the pallet", function()
		expectEqual(GrabMath.canLift(10), true)
		expectEqual(GrabMath.canLift(20), true)
		expectEqual(GrabMath.canLift(capacity), true)
		expectEqual(GrabMath.canLift(60), false)
	end)

	it("throws light things fast and heavy things slowly", function()
		expectEqual(GrabMath.throwSpeed(10), Config.Grab.ThrowMaxSpeed)
		expectNear(GrabMath.throwSpeed(20), 45, 1e-6)
		expectEqual(GrabMath.throwSpeed(60), 0)
	end)

	it("slows walking more for heavier loads", function()
		assert(GrabMath.walkFactor(10) > GrabMath.walkFactor(20), "10 KG should be easier than 20 KG")
		assert(GrabMath.walkFactor(20) > GrabMath.walkFactor(60), "20 KG should be easier than 60 KG")
		expectEqual(GrabMath.walkFactor(1000), Config.Grab.MinWalkFactor)
	end)

	it("lifts liftable masses against the game's gravity", function()
		local gravity = 196.2
		local horizontal, vertical = GrabMath.holdForces(gravity)
		assert(vertical > capacity * gravity, "cannot lift the capacity mass")
		assert(vertical < 60 * gravity, "would lift the 60 KG pallet")
		assert(horizontal > vertical, "drag should be stronger than lift")
	end)
end)

-- The Loading Dock's numbers, checked against the same rules the game uses.
