local replecs = require(script.Parent.Parent:FindFirstChild('Packages'):FindFirstChild('replecs'))
local world = require(script.Parent:FindFirstChild('world'))

return replecs.create(world)
