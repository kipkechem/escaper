--!nonstrict
-- All the tests. Run from the repository root with:
--   lune run tests/run.luau

local process = require("@lune/process")

local t = require("./harness")

require("./suites/logic")
require("./suites/tower")
require("./suites/level1")
require("./suites/level2")

if not t.summary() then
	process.exit(1)
end
