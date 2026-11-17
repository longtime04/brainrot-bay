-- PlayerDataService.luau
-- Per-player state: leaderstats, cash, rebirths, boots, the income
-- multiplier, DataStore saving/loading, and the Rebirth / Boots shops
-- (driven by the client's RemoteEvents).

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local PlayerDataService = {}

local STORE_NAME = "BrainrotBay_v1"
local STARTING_CASH = 100
local REBIRTH_BASE_COST = 25000
local MAX_BOOTS_LEVEL = 5

local ctx -- set by init
local store = nil
local records = {} -- player -> { cash, rebirths, boots, loaded }

local function bootsCostForLevel(level)
	return 300 * (2 ^ level)
end
PlayerDataService.bootsCostForLevel = bootsCostForLevel

function PlayerDataService.rebirthCostFor(player)
	local record = records[player]
	local rebirths = record and record.rebirths or 0
	return REBIRTH_BASE_COST * (rebirths + 1)
end

local function syncLeaderstats(player)
	local record = records[player]
	local leaderstats = player:FindFirstChild("leaderstats")
	if not record or not leaderstats then
		return
	end
	leaderstats.Cash.Value = math.floor(record.cash)
	leaderstats.Rebirths.Value = record.rebirths
end

function PlayerDataService.getMultiplier(player)
	local record = records[player]
	if not record then
		return 1
	end
	return 1 + 0.5 * record.rebirths
end

function PlayerDataService.addCash(player, amount)
	local record = records[player]
	if not record then
		return
	end
	record.cash += amount
	syncLeaderstats(player)
end

function PlayerDataService.getRecord(player)
	return records[player]
end

local function applyWalkSpeed(player)
	local record = records[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if record and humanoid then
		humanoid.WalkSpeed = 16 + 2 * record.boots
	end
end

local function notifyBootsState(player)
	local record = records[player]
	if not record then
		return
	end
	if record.boots >= MAX_BOOTS_LEVEL then
		ctx.remotes.Notify:FireClient(player, "Boots", record.boots, nil)
	else
		ctx.remotes.Notify:FireClient(player, "Boots", record.boots, bootsCostForLevel(record.boots))
	end
end

----------------------------------------------------------------------
-- Saving / loading
----------------------------------------------------------------------

local function savePlayerData(player)
	local record = records[player]
	if not record or not record.loaded or not store then
		return
	end
	local payload = {
		cash = math.floor(record.cash),
		rebirths = record.rebirths,
		boots = record.boots,
		placed = ctx.base.getPlacedSaveData(player),
	}
	local ok, err = pcall(function()
		store:SetAsync("player_" .. player.UserId, payload)
	end)
	if not ok then
		warn("[Brainrot Bay] save failed for " .. player.Name .. ": " .. tostring(err))
	end
end
PlayerDataService.savePlayerData = savePlayerData

local function loadPlayerData(player)
	local record = records[player]
	if not store then
		record.loaded = true
		return
	end
	local ok, payload = pcall(function()
		return store:GetAsync("player_" .. player.UserId)
	end)
	if ok and type(payload) == "table" then
		record.cash = payload.cash or STARTING_CASH
		record.rebirths = payload.rebirths or 0
		record.boots = payload.boots or 0
		record.loaded = true
		syncLeaderstats(player)
		applyWalkSpeed(player)
		notifyBootsState(player)
		if payload.placed then
			ctx.base.restorePlacedBrainrots(player, payload.placed)
		end
	else
		record.loaded = true
		if not ok then
			warn("[Brainrot Bay] load failed for " .. player.Name .. ": " .. tostring(payload))
		end
	end
end

----------------------------------------------------------------------
-- Join / leave
----------------------------------------------------------------------

local function onPlayerAdded(player)
	records[player] = { cash = STARTING_CASH, rebirths = 0, boots = 0, loaded = false }

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = STARTING_CASH
	cash.Parent = leaderstats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = 0
	rebirths.Parent = leaderstats
	leaderstats.Parent = player

	ctx.base.claimPlotForPlayer(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		applyWalkSpeed(player)
		if ctx.spawner then
			ctx.spawner.reattachCarriedBrainrot(player)
		end
	end)
	task.spawn(function()
		loadPlayerData(player)
		notifyBootsState(player)
	end)
end

local function onPlayerRemoving(player)
	savePlayerData(player)
	if ctx.spawner then
		ctx.spawner.handlePlayerLeaving(player)
	end
	ctx.base.releasePlot(player)
	records[player] = nil
end

----------------------------------------------------------------------
-- Shops
----------------------------------------------------------------------

-- Trade every coin and placed brainrot for a permanent income multiplier.
function PlayerDataService.rebirthPlayer(player)
	local record = records[player]
	if not record then
		return
	end
	local cost = PlayerDataService.rebirthCostFor(player)
	if record.cash < cost then
		ctx.remotes.Notify:FireClient(player, "Message", "Rebirth needs $" .. cost .. " — keep farming!")
		return
	end
	record.rebirths += 1
	record.cash = 0
	ctx.base.clearPlacedBrainrots(player)
	syncLeaderstats(player)
	ctx.remotes.Notify:FireClient(player, "Message",
		"Rebirth " .. record.rebirths .. "! All income is now x" .. PlayerDataService.getMultiplier(player))
	savePlayerData(player)
end

function PlayerDataService.buyBootsForPlayer(player)
	local record = records[player]
	if not record then
		return
	end
	if record.boots >= MAX_BOOTS_LEVEL then
		ctx.remotes.Notify:FireClient(player, "Message", "Your boots are already max level!")
		return
	end
	local cost = bootsCostForLevel(record.boots)
	if record.cash < cost then
		ctx.remotes.Notify:FireClient(player, "Message", "Boots level " .. (record.boots + 1) .. " costs $" .. cost)
		return
	end
	record.cash -= cost
	record.boots += 1
	syncLeaderstats(player)
	applyWalkSpeed(player)
	notifyBootsState(player)
	ctx.remotes.Notify:FireClient(player, "Message", "Boots level " .. record.boots .. "! You run faster now.")
end

----------------------------------------------------------------------
-- Init
----------------------------------------------------------------------

function PlayerDataService.init(context)
	ctx = context
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Brainrot Bay] DataStore unavailable, playing session-only: " .. tostring(result))
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	ctx.remotes.RebirthRequest.OnServerEvent:Connect(PlayerDataService.rebirthPlayer)
	ctx.remotes.BuyBootsRequest.OnServerEvent:Connect(PlayerDataService.buyBootsForPlayer)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			savePlayerData(player)
		end
	end)
end

function PlayerDataService.startAutosaveLoop()
	while true do
		task.wait(60)
		for player in pairs(records) do
			savePlayerData(player)
		end
	end
end

return PlayerDataService
