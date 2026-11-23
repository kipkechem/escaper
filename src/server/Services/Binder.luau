--!strict
-- Gives behaviour to tagged instances. For each tag, every instance in the Workspace that
-- carries it gets an object from `class.new(instance)`; the object's `destroy()` runs
-- when the tag is removed or the instance leaves the Workspace.

local CollectionService = game:GetService("CollectionService")

local Signals = require(script.Parent.Signals)

export type Component = {
	instance: Instance,
	scope: Instance,
	destroy: (self: any) -> (),
	[any]: any,
}

type Class = {
	new: (instance: Instance) -> Component?,
}

local Binder = {}

local objectsByTag: { [string]: { [Instance]: Component } } = {}

local function create(tag: string, class: Class, instance: Instance)
	local objects = objectsByTag[tag]
	if objects[instance] or not instance:IsDescendantOf(workspace) then
		return
	end
	local ok, result = pcall(class.new, instance)
	if not ok then
		warn(
			string.format(
				"[Escaper] %s on %s failed to start: %s",
				tag,
				instance:GetFullName(),
				tostring(result)
			)
		)
		return
	end
	if result then
		objects[instance] = result
	end
end

local function remove(tag: string, instance: Instance)
	local objects = objectsByTag[tag]
	local object = objects[instance]
	if object then
		objects[instance] = nil
		local ok, err = pcall(object.destroy, object)
		if not ok then
			warn(
				string.format(
					"[Escaper] %s on %s failed to stop: %s",
					tag,
					instance:GetFullName(),
					tostring(err)
				)
			)
		end
	end
end

function Binder.bind(tag: string, class: Class)
	objectsByTag[tag] = objectsByTag[tag] or {}
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		create(tag, class, instance)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		remove(tag, instance)
	end)
	for _, instance in CollectionService:GetTagged(tag) do
		create(tag, class, instance)
	end
end

-- All live objects for a tag inside a room (or anywhere, if scope is nil).
function Binder.objects(tag: string, scope: Instance?): { Component }
	local list: { Component } = {}
	for _, object in objectsByTag[tag] or {} do
		if scope == nil or object.scope == scope then
			table.insert(list, object)
		end
	end
	return list
end

function Binder.get(tag: string, instance: Instance): Component?
	local objects = objectsByTag[tag]
	return if objects then objects[instance] else nil
end

Binder.scopeFor = Signals.scopeFor

return Binder
