-- components
local jecs = require("@Packages/jecs")
local world = require("@Shared/world")

local components = {
	player = world:component() :: jecs.Entity<Player>,
	client = world:entity(),
}
