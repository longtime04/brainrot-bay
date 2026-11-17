-- Brainrot Bay: Grab & Dash — server bootstrap.
-- Builds the island, then wires the services together through one context
-- table and starts their loops. Each service lives in its own module beside
-- this script; this file only connects them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldBuilder = require(script:WaitForChild("WorldBuilder"))
local BaseManager = require(script:WaitForChild("BaseManager"))
local PlayerDataService = require(script:WaitForChild("PlayerDataService"))
local BrainrotSpawner = require(script:WaitForChild("BrainrotSpawner"))
local StealService = require(script:WaitForChild("StealService"))
local TsunamiController = require(script:WaitForChild("TsunamiController"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local ctx = {
	remotes = {
		Notify = remotes:WaitForChild("Notify"),
		RebirthRequest = remotes:WaitForChild("RebirthRequest"),
		LockBaseRequest = remotes:WaitForChild("LockBaseRequest"),
		BuyBootsRequest = remotes:WaitForChild("BuyBootsRequest"),
	},
	worldBuilder = WorldBuilder,
	base = BaseManager,
	data = PlayerDataService,
	spawner = BrainrotSpawner,
	steal = StealService,
	tsunami = TsunamiController,
}

ctx.world = WorldBuilder.buildWorld()

BaseManager.init(ctx)
PlayerDataService.init(ctx)
BrainrotSpawner.init(ctx)
StealService.init(ctx)
TsunamiController.init(ctx)

task.spawn(BrainrotSpawner.startSpawnLoop)
task.spawn(BaseManager.startIncomeTicker)
task.spawn(TsunamiController.startTsunamiLoop)
task.spawn(PlayerDataService.startAutosaveLoop)

print(string.format("[Brainrot Bay] Grab & Dash server is up: %d base plots, %d beach pads, brainrots incoming.",
	#ctx.world.plots, #ctx.world.spawnPads))
