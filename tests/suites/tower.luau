--!nonstrict
-- The tower map's rules, and the layout of every level, pad and connector in it.

local t = require("../harness")
local Geometry = require("../geometry")
local Loader = require("../loader")

local describe, it, expectEqual = t.describe, t.it, t.expectEqual

local Config = Loader.require("src/shared/Config.luau")
local TowerMap = Loader.require("src/shared/TowerMap.luau")
local Placement = Loader.require("src/server/Tower/Placement.luau")

describe("Tower map", function()
	it("follows every rule", function()
		local problems = TowerMap.validate()
		assert(#problems == 0, table.concat(problems, "\n      "))
	end)

	it("names levels by floor and staircase letter", function()
		for id, level in TowerMap.levels do
			local suffix = TowerMap.Staircases[level.staircase].suffix
			expectEqual(id, tostring(level.floor) .. suffix)
		end
	end)

	it("makes the main stair very hard after the tutorial", function()
		for _, level in TowerMap.ordered do
			if level.staircase == "Main" and level.floor > 1 then
				expectEqual(level.difficulty, "Very hard", level.id)
			end
		end
	end)

	it("has easy, medium and hard staircases beside the main stair", function()
		local counts = {}
		for _, level in TowerMap.ordered do
			counts[level.staircase] = (counts[level.staircase] or 0) + 1
		end
		expectEqual(counts.Main, TowerMap.TopFloor)
		for _, staircase in { "E", "M", "H" } do
			assert((counts[staircase] or 0) > 0, "no levels on staircase " .. staircase)
		end
	end)

	it("forks Level 2 onto the medium, main and hard staircases", function()
		local exits = TowerMap.levels["2"].exits
		expectEqual(table.concat(exits, ","), "3M,3,3H")
	end)

	it("brings every staircase back to the main stair before Level 100", function()
		local top = TowerMap.levels[tostring(TowerMap.TopFloor)]
		expectEqual(table.concat(top.incoming, ","), tostring(TowerMap.TopFloor - 1))
		for _, level in TowerMap.ordered do
			if level.floor >= TowerMap.TopFloor - 1 then
				expectEqual(level.staircase, "Main", level.id)
			end
		end
	end)

	it("forks and merges in every block of ten floors", function()
		for block = 0, 9 do
			local forks, merges = 0, 0
			for _, level in TowerMap.ordered do
				if level.floor > block * 10 and level.floor <= block * 10 + 10 then
					if #level.exits > 1 then
						forks += 1
					end
					if #level.incoming > 1 then
						merges += 1
					end
				end
			end
			assert(
				forks > 0 and merges > 0,
				string.format("floors %d-%d need a fork and a merge", block * 10 + 1, block * 10 + 10)
			)
		end
	end)
end)

describe("Tower layout", function()
	local tower = Config.Tower
	local boxes = {}
	local connectors = {}
	local function add(name: string, kind: string, min: any, max: any)
		table.insert(boxes, { name = name, kind = kind, min = min, max = max })
	end
	for _, level in TowerMap.ordered do
		local envelope = Placement.envelope(level.id)
		add(envelope.name, "level", envelope.min, envelope.max)
		if #level.incoming > 0 then
			local pad = Placement.pad(level.id)
			add(pad.name, "pad", pad.min, pad.max)
		end
		for _, targetId in level.exits do
			local connector = Placement.connector(level.id, targetId)
			table.insert(connectors, connector)
			local name = level.id .. " to " .. targetId
			for _, piece in { connector.corridor, connector.shaft, connector.bridge } do
				if piece then
					add(name .. " " .. piece.name, "connector", piece.min, piece.max)
				end
			end
		end
	end

	it("keeps every level, pad and connector out of each other (touching is fine)", function()
		-- Sweep in height order so only boxes that share heights are compared.
		table.sort(boxes, function(a, b)
			return a.min.Y < b.min.Y
		end)
		local problems = {}
		for i = 1, #boxes do
			local a = boxes[i]
			for j = i + 1, #boxes do
				local b = boxes[j]
				if b.min.Y >= a.max.Y then
					break
				end
				local depth = Geometry.overlap(a.min, a.max, b.min, b.max)
				if depth > 0.001 then
					table.insert(problems, string.format("%s overlaps %s by %.2f", a.name, b.name, depth))
					if #problems >= 10 then
						break
					end
				end
			end
		end
		assert(#problems == 0, table.concat(problems, "\n      "))
	end)

	it("starts every connector at its exit opening", function()
		for _, connector in connectors do
			local from = TowerMap.levels[connector.from]
			local frame = Placement.levelFrame(connector.from)
			for _, exit in Placement.exits(connector.from) do
				if exit.target == connector.to then
					local opening = Placement.exitOpening(exit)
					local centre = frame * ((opening.min + opening.max) / 2)
					t.expectNear(centre.X, connector.slotX, 1e-3, connector.from .. " exit x")
					t.expectNear(
						centre.Y,
						connector.exitY + tower.OpeningHeight / 2,
						1e-3,
						connector.from .. " exit y"
					)
					t.expectNear(
						centre.Z,
						connector.wallZ - connector.outward * 0.5,
						1e-3,
						connector.from .. " exit z"
					)
				end
			end
			expectEqual(connector.exitY, Placement.floorBase(from.floor) + tower.ExitHeight)
		end
	end)

	it("ends every connector at its target's pad, in front of the entrance", function()
		for _, connector in connectors do
			local pad = Placement.pad(connector.to)
			local top = if connector.bridge then connector.bridge else connector.shaft
			if connector.bridge then
				local edge = if connector.direction > 0 then top.max.X else top.min.X
				local padEdge = if connector.direction > 0 then pad.min.X else pad.max.X
				t.expectNear(edge, padEdge, 1e-6, connector.from .. " to " .. connector.to .. " bridge end")
				t.expectNear(top.min.Y, pad.min.Y, 1e-6, "bridge deck height")
			else
				t.expectNear(top.max.Y, pad.min.Y, 1e-6, "shaft top")
			end
			-- The target's entrance opening is in the wall the pad stands against.
			local frame = Placement.levelFrame(connector.to)
			local opening = Placement.entranceOpening()
			local centre = frame * ((opening.min + opening.max) / 2)
			t.expectNear(centre.X, connector.targetX, 1e-3, connector.to .. " entrance x")
			t.expectNear(
				centre.Y,
				connector.padY + tower.OpeningHeight / 2,
				1e-3,
				connector.to .. " entrance y"
			)
			t.expectNear(
				centre.Z,
				connector.wallZ - connector.outward * 0.5,
				1e-3,
				connector.to .. " entrance z"
			)
		end
	end)
end)
