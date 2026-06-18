local net = require(script:FindFirstChild('Networking'):FindFirstChild('client'))
local scheduler = require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('scheduler'))
local replicator = require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('replicator')).client
local players = require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('players'))
local world = require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('world'))
local jabby = require(game:GetService('ReplicatedStorage'):FindFirstChild('Packages'):FindFirstChild('jabby'))
local userInputService = game:GetService("UserInputService")

-- Replecs: start replication and request the initial full state
replicator:init()
local buf, variants = net.ReceiveFull.Invoke(nil)

-- Planck: schedule systems
local systemsOrder = {
	require(script:FindFirstChild('Systems'):FindFirstChild('replecsClient')),
	require(script:FindFirstChild('Systems'):FindFirstChild('testingSystem')),
}

scheduler:addSystems(systemsOrder)

-- Jabby: expose the client world and open the debugger with F4
local client = jabby.obtain_client()

jabby.register({
	name = "Client",
	applet = jabby.applets.world,
	configuration = { world = world :: any },
})

userInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F4 then
		client.spawn_app(client.apps.home)
	end
end)

-- Bootstrap players, then apply the initial replicated snapshot
players.start_current_players()
players.listen_for_players()

if buf then
	replicator:apply_full(buf, variants)
end
