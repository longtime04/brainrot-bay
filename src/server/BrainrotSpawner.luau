-- BrainrotSpawner.luau
-- The beach lane: rolls rarities and mutations, spawns brainrots on the
-- glowing pads, despawns the ignored ones, and runs everything about
-- carrying a brainrot on your head (grab, steal hand-off, tsunami drop).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))

local BrainrotSpawner = {}

local SPAWN_INTERVAL = 4
local DESPAWN_SECONDS = 25

local ctx -- set by init
local rng = Random.new()
local padOccupants = {} -- spawn pad Part -> record
local carriedBy = {} -- player -> record
-- record: { model, def, mutation, state = "beach" | "carried" | "placed", pad }

function BrainrotSpawner.init(context)
	ctx = context
end

function BrainrotSpawner.isCarrying(player)
	return carriedBy[player] ~= nil
end

function BrainrotSpawner.getCarriedRecord(player)
	return carriedBy[player]
end

----------------------------------------------------------------------
-- Carrying
----------------------------------------------------------------------

local function weldBrainrotToHead(model, character)
	local head = character and character:FindFirstChild("Head")
	local body = model.PrimaryPart
	if not head or not body then
		return false
	end
	body.Anchored = false
	body.CFrame = head.CFrame * CFrame.new(0, 3.4, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = body
	weld.Part1 = head
	weld.Parent = body
	return true
end

-- Pick a brainrot up and carry it home on your head: shared by the beach
-- Grab prompt and by stealing.
function BrainrotSpawner.carryBrainrotHome(player, model, def, mutation)
	if carriedBy[player] then
		return nil
	end
	local character = player.Character
	if not character then
		return nil
	end
	local record = { model = model, def = def, mutation = mutation, state = "carried" }
	if not weldBrainrotToHead(model, character) then
		return nil
	end
	model.Parent = workspace
	carriedBy[player] = record
	player:SetAttribute("CarryingName", BrainrotData.displayName(def, mutation))
	return record
end

-- Stop carrying without destroying: the caller decides where the model goes.
function BrainrotSpawner.detachCarriedBrainrot(player)
	local record = carriedBy[player]
	if not record then
		return nil
	end
	carriedBy[player] = nil
	player:SetAttribute("CarryingName", "")
	local weld = record.model.PrimaryPart:FindFirstChild("CarryWeld")
	if weld then
		weld:Destroy()
	end
	return record
end

-- After a respawn, re-weld the carried brainrot to the new head.
function BrainrotSpawner.reattachCarriedBrainrot(player)
	local record = carriedBy[player]
	if not record then
		return
	end
	local oldWeld = record.model.PrimaryPart:FindFirstChild("CarryWeld")
	if oldWeld then
		oldWeld:Destroy()
	end
	weldBrainrotToHead(record.model, player.Character)
end

-- Tsunami / leaving: the carried brainrot washes back to a free beach pad.
function BrainrotSpawner.dropCarriedBrainrot(player)
	local record = BrainrotSpawner.detachCarriedBrainrot(player)
	if not record then
		return
	end
	BrainrotSpawner.putBrainrotOnBeach(record, true)
end

function BrainrotSpawner.handlePlayerLeaving(player)
	local record = BrainrotSpawner.detachCarriedBrainrot(player)
	if record and record.model then
		record.model:Destroy()
	end
end

----------------------------------------------------------------------
-- The beach
----------------------------------------------------------------------

local function addGrabPrompt(record)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrabPrompt"
	prompt.ActionText = "Grab"
	prompt.ObjectText = BrainrotData.displayName(record.def, record.mutation)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = record.model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		BrainrotSpawner.grabBrainrotFromBeach(player, record)
	end)
end

-- Put a record's model on a free beach pad (or destroy it if the lane is full).
function BrainrotSpawner.putBrainrotOnBeach(record, withFreshTimer)
	for _, pad in ipairs(ctx.world.spawnPads) do
		if not padOccupants[pad] then
			padOccupants[pad] = record
			record.pad = pad
			record.state = "beach"
			local body = record.model.PrimaryPart
			body.Anchored = true
			record.model:PivotTo(CFrame.new(pad.Position.X, pad.Position.Y + 0.25, pad.Position.Z)
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
			record.model.Parent = workspace
			addGrabPrompt(record)
			if withFreshTimer then
				task.delay(DESPAWN_SECONDS, function()
					BrainrotSpawner.despawnBrainrot(record)
				end)
			end
			return true
		end
	end
	record.model:Destroy()
	return false
end

function BrainrotSpawner.despawnBrainrot(record)
	if record.state ~= "beach" then
		return
	end
	if record.pad and padOccupants[record.pad] == record then
		padOccupants[record.pad] = nil
	end
	record.state = "gone"
	record.model:Destroy()
end

function BrainrotSpawner.grabBrainrotFromBeach(player, record)
	if record.state ~= "beach" then
		return
	end
	if carriedBy[player] then
		ctx.remotes.Notify:FireClient(player, "Message", "You are already carrying a brainrot!")
		return
	end
	if record.pad and padOccupants[record.pad] == record then
		padOccupants[record.pad] = nil
	end
	record.pad = nil
	local grabPrompt = record.model.PrimaryPart:FindFirstChild("GrabPrompt")
	if grabPrompt then
		grabPrompt:Destroy()
	end
	local carried = BrainrotSpawner.carryBrainrotHome(player, record.model, record.def, record.mutation)
	if not carried then
		-- No character to carry it: put it back on the beach.
		BrainrotSpawner.putBrainrotOnBeach(record, false)
	end
end

local function spawnBrainrotOnPad()
	local freePads = {}
	for _, pad in ipairs(ctx.world.spawnPads) do
		if not padOccupants[pad] then
			table.insert(freePads, pad)
		end
	end
	if #freePads == 0 then
		return
	end
	local def = BrainrotData.rollBrainrot(rng)
	local mutation = BrainrotData.rollMutation(rng)
	local model = ctx.worldBuilder.buildBrainrotModel(def, mutation)
	local record = { model = model, def = def, mutation = mutation, state = "new" }
	BrainrotSpawner.putBrainrotOnBeach(record, true)

	-- Shout about the good ones.
	local rarityRank = table.find(BrainrotData.RarityOrder, def.rarity) or 1
	if rarityRank >= 3 then
		local text = "A " .. string.upper(def.rarity) .. " " .. BrainrotData.displayName(def, mutation)
			.. " appeared on the beach!"
		for _, player in ipairs(Players:GetPlayers()) do
			ctx.remotes.Notify:FireClient(player, "RareSpawn", text)
		end
	end
end

-- Rainbow brainrots cycle their glow colour while they exist.
local function startRainbowCycle()
	while true do
		task.wait(0.4)
		local hue = (os.clock() % 6) / 6
		for _, record in pairs(padOccupants) do
			local glow = record.model.PrimaryPart:FindFirstChild("RainbowGlow")
			if glow then
				glow.Color = Color3.fromHSV(hue, 0.7, 1)
			end
		end
	end
end

function BrainrotSpawner.startSpawnLoop()
	task.spawn(startRainbowCycle)
	while true do
		spawnBrainrotOnPad()
		task.wait(SPAWN_INTERVAL)
	end
end

return BrainrotSpawner
