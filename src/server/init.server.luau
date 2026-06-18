local replecs
local scheduler = require("@Shared/scheduler")
local replicator = require("@Shared/replicator").server

local systemsOrder = {
	require("@Server/Systems/healthSystem"),
}

scheduler:addSystems(systemsOrder)
