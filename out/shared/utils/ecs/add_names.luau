local jecs = require(game:GetService('ReplicatedStorage'):FindFirstChild('Packages'):FindFirstChild('jecs'))
local world = require(script.Parent.Parent.Parent:FindFirstChild('world'))

function add_names<T>(entities: T): T
	for name, entity in pairs(entities :: any) do
		world:set(entity, jecs.Name, name)
	end
	return entities
end

return add_names
