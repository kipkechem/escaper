--!strict
-- Named on/off signals that connect puzzle parts. A plate or lever writes a signal; doors
-- and lights read it. Names are scoped to the nearest ancestor tagged "Room", so a room can
-- be copied without its signals clashing with another copy. Outside any room, the
-- Workspace is the scope.
--
-- Several sources may write the same name; the signal is on while any of them is on.
-- Live values are mirrored as attributes on the room ("Signal_<name>") for debugging.

local CollectionService = game:GetService("CollectionService")

local Tags = require(game:GetService("ReplicatedStorage").Shared.Tags)

type Listener = (value: boolean) -> ()

type Scope = {
	sources: { [string]: { [any]: boolean } },
	values: { [string]: boolean },
	listeners: { [string]: { [Listener]: boolean } },
}

local Signals = {}

local scopes: { [Instance]: Scope } = {}

local function getScope(scopeInstance: Instance): Scope
	local scope = scopes[scopeInstance]
	if not scope then
		scope = { sources = {}, values = {}, listeners = {} }
		scopes[scopeInstance] = scope
	end
	return scope
end

local function attributeName(name: string): string
	return "Signal_" .. string.gsub(name, "[^%w_]", "_")
end

function Signals.scopeFor(instance: Instance): Instance
	local current: Instance? = instance
	while current and current ~= workspace do
		if CollectionService:HasTag(current, Tags.Room) then
			return current
		end
		current = current.Parent
	end
	return workspace
end

function Signals.get(scopeInstance: Instance, name: string): boolean
	return getScope(scopeInstance).values[name] == true
end

-- `source` identifies the writer (usually the component object), so that two plates
-- writing the same name do not cancel each other out.
function Signals.set(scopeInstance: Instance, name: string, source: any, value: boolean)
	if name == "" then
		return
	end
	local scope = getScope(scopeInstance)
	local sources = scope.sources[name]
	if not sources then
		sources = {}
		scope.sources[name] = sources
	end
	sources[source] = if value then true else nil

	local combined = next(sources) ~= nil
	if scope.values[name] == combined then
		return
	end
	scope.values[name] = combined
	if scopeInstance ~= workspace then
		scopeInstance:SetAttribute(attributeName(name), combined)
	end
	local listeners = scope.listeners[name]
	if listeners then
		for listener in listeners do
			task.spawn(listener, combined)
		end
	end
end

-- Calls `listener(value)` whenever the signal changes. Returns a function that disconnects.
function Signals.onChanged(scopeInstance: Instance, name: string, listener: Listener): () -> ()
	local scope = getScope(scopeInstance)
	local listeners = scope.listeners[name]
	if not listeners then
		listeners = {}
		scope.listeners[name] = listeners
	end
	listeners[listener] = true
	return function()
		listeners[listener] = nil
	end
end

return Signals
