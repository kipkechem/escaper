--!strict
-- Watches an "Input" expression (see Shared/Expression) and calls back when its value
-- changes. Shared by doors, lights and lifts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Expression = require(ReplicatedStorage.Shared.Expression)
local Signals = require(script.Parent.Signals)

local Wiring = {}

export type Watcher = {
	value: boolean,
	disconnect: () -> (),
}

-- Returns nil (and warns) if `source` is not a valid expression.
function Wiring.watch(owner: Instance, source: string, onChange: (value: boolean) -> ()): Watcher?
	local compiled, err = Expression.compile(source)
	if not compiled then
		warn(string.format("[Escaper] Bad Input %q on %s: %s", source, owner:GetFullName(), tostring(err)))
		return nil
	end
	local scope = Signals.scopeFor(owner)
	local function evaluate(): boolean
		return compiled.evaluate(function(name: string): boolean
			return Signals.get(scope, name)
		end)
	end

	local disconnects: { () -> () } = {}
	local watcher: Watcher = {
		value = evaluate(),
		disconnect = function()
			for _, disconnect in disconnects do
				disconnect()
			end
		end,
	}
	for _, name in compiled.names do
		table.insert(
			disconnects,
			Signals.onChanged(scope, name, function()
				local value = evaluate()
				if value ~= watcher.value then
					watcher.value = value
					onChange(value)
				end
			end)
		)
	end
	return watcher
end

return Wiring
