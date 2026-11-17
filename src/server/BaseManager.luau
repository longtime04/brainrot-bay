-- BaseManager.luau
-- Owns the 8 base plots: who claimed which plot, which brainrots sit on its
-- pads, the once-a-second income tick and the floating "+$N" earnings text.

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))

local BaseManager = {}

local ctx -- set by init
local plots = {} -- plot states: { visual, owner, placed = {padIndex -> record}, shieldUntil }
local plotByPlayer = {}
local padLookup = {} -- pad Part -> { plot = plotState, padIndex = n }

function BaseManager.init(context)
	ctx = context
	for _, visual in ipairs(ctx.world.plots) do
		local plot = { visual = visual, owner = nil, placed = {}, shieldUntil = 0 }
		table.insert(plots, plot)
		for padIndex, pad in ipairs(visual.pads) do
			padLookup[pad] = { plot = plot, padIndex = padIndex }
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "PlacePrompt"
			prompt.ActionText = "Place"
			prompt.ObjectText = "Place Brainrot"
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Parent = pad
			prompt.Triggered:Connect(function(player)
				BaseManager.placeCarriedBrainrotOnPad(player, pad)
			end)
		end
	end
end

----------------------------------------------------------------------
-- Claims
----------------------------------------------------------------------

function BaseManager.claimPlotForPlayer(player)
	if plotByPlayer[player] then
		return plotByPlayer[player]
	end
	for _, plot in ipairs(plots) do
		if not plot.owner then
			plot.owner = player
			plotByPlayer[player] = plot
			plot.visual.signLabel.Text = player.Name .. "'s Base"
			return plot
		end
	end
	return nil
end

function BaseManager.releasePlot(player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	for padIndex, record in pairs(plot.placed) do
		if record.model then
			record.model:Destroy()
		end
		plot.placed[padIndex] = nil
	end
	plot.owner = nil
	plot.shieldUntil = 0
	plot.visual.signLabel.Text = "Empty Base"
	plotByPlayer[player] = nil
end

function BaseManager.getPlayerPlot(player)
	return plotByPlayer[player]
end

function BaseManager.getPlots()
	return plots
end

-- Tsunami safety: standing on any raised plot platform counts as safe.
function BaseManager.isPlayerOnSafePlot(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	if root.Position.Y < 6.5 then
		return false
	end
	for _, plot in ipairs(plots) do
		local center = plot.visual.center
		if math.abs(root.Position.X - center.X) <= 20 and math.abs(root.Position.Z - center.Z) <= 20 then
			return true
		end
	end
	return false
end

----------------------------------------------------------------------
-- Placement
----------------------------------------------------------------------

-- Put a model on a pad and start it earning. Shared by placing a carried
-- brainrot and by restoring saved brainrots when a player rejoins.
function BaseManager.placeModelOnPad(plot, padIndex, model, def, mutation)
	local pad = plot.visual.pads[padIndex]
	local body = model.PrimaryPart
	body.Anchored = true
	model:PivotTo(CFrame.new(pad.Position.X, pad.Position.Y + 0.25, pad.Position.Z))
	model.Parent = workspace
	local record = { model = model, def = def, mutation = mutation, padIndex = padIndex }
	plot.placed[padIndex] = record
	if ctx.steal then
		ctx.steal.onBrainrotPlaced(ctx, plot, record)
	end
	return record
end

-- The pad prompt path: the player must own this plot and be carrying.
function BaseManager.placeCarriedBrainrotOnPad(player, pad)
	local info = padLookup[pad]
	if not info then
		return
	end
	local plot = info.plot
	if plot.owner ~= player then
		return
	end
	if plot.placed[info.padIndex] then
		return
	end
	if not ctx.spawner or not ctx.spawner.isCarrying(player) then
		return
	end
	local record = ctx.spawner.detachCarriedBrainrot(player)
	if not record then
		return
	end
	BaseManager.placeModelOnPad(plot, info.padIndex, record.model, record.def, record.mutation)
end

-- The pad prompt path above, under the name the game design uses.
BaseManager.placeBrainrotOnBase = BaseManager.placeCarriedBrainrotOnPad

-- Take a placed brainrot off a plot (stealing). Returns the record or nil.
function BaseManager.removePlacedBrainrot(plot, padIndex)
	local record = plot.placed[padIndex]
	if not record then
		return nil
	end
	plot.placed[padIndex] = nil
	local stealPrompt = record.model.PrimaryPart:FindFirstChild("StealPrompt")
	if stealPrompt then
		stealPrompt:Destroy()
	end
	record.model.PrimaryPart.Anchored = false
	return record
end

-- Rebirth / release cleanup: destroy every placed brainrot of a player.
function BaseManager.clearPlacedBrainrots(player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	for padIndex, record in pairs(plot.placed) do
		if record.model then
			record.model:Destroy()
		end
		plot.placed[padIndex] = nil
	end
end

-- Save shape: a list of { id = ..., mutation = ... } in pad order.
function BaseManager.getPlacedSaveData(player)
	local plot = plotByPlayer[player]
	local saved = {}
	if not plot then
		return saved
	end
	for padIndex = 1, 9 do
		local record = plot.placed[padIndex]
		if record then
			table.insert(saved, {
				id = record.def.id,
				mutation = record.mutation and record.mutation.name or "",
			})
		end
	end
	return saved
end

function BaseManager.restorePlacedBrainrots(player, savedList)
	local plot = plotByPlayer[player]
	if not plot or not savedList then
		return
	end
	local padIndex = 0
	for _, entry in ipairs(savedList) do
		padIndex += 1
		if padIndex > 9 then
			break
		end
		local def = BrainrotData.getBrainrotById(entry.id)
		if def then
			local mutation = BrainrotData.getMutationByName(entry.mutation)
			local model = ctx.worldBuilder.buildBrainrotModel(def, mutation)
			BaseManager.placeModelOnPad(plot, padIndex, model, def, mutation)
		end
	end
end

----------------------------------------------------------------------
-- Income
----------------------------------------------------------------------

local function spawnFloatingEarningsText(plot, amount)
	local anchor = Instance.new("Part")
	anchor.Name = "EarningsFloater"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.Anchored = true
	local signPos = plot.visual.pads[5].Position
	anchor.Position = Vector3.new(signPos.X, 13, signPos.Z)
	anchor.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(180, 50)
	gui.AlwaysOnTop = true
	gui.Adornee = anchor
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "+$" .. amount
	label.TextColor3 = Color3.fromRGB(110, 255, 130)
	label.TextStrokeTransparency = 0.3
	label.FontFace = FontFace.new("rbxasset://fonts/families/Fredoka.json", Enum.FontWeight.Bold)
	label.TextSize = 30
	label.Parent = gui

	local tween = TweenService:Create(anchor, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = anchor.Position + Vector3.new(0, 4.5, 0) })
	tween:Play()
	TweenService:Create(label, TweenInfo.new(1.8), { TextTransparency = 1 }):Play()
	Debris:AddItem(anchor, 1.9)
end

-- Every second: pay each owner the sum of their placed brainrots' rates
-- times their rebirth multiplier, tell their HUD, and float the total over
-- their base every five seconds.
function BaseManager.startIncomeTicker()
	local seconds = 0
	local accumulated = {} -- player -> cash earned since the last floater
	while true do
		task.wait(1)
		seconds += 1
		for _, plot in ipairs(plots) do
			local owner = plot.owner
			if owner and ctx.data then
				local rate = 0
				for _, record in pairs(plot.placed) do
					rate += BrainrotData.incomePerSecond(record.def, record.mutation)
				end
				if rate > 0 then
					local amount = rate * ctx.data.getMultiplier(owner)
					ctx.data.addCash(owner, amount)
					accumulated[owner] = (accumulated[owner] or 0) + amount
					ctx.remotes.Notify:FireClient(owner, "Earnings", amount, rate * ctx.data.getMultiplier(owner))
				end
			end
		end
		if seconds % 5 == 0 then
			for player, total in pairs(accumulated) do
				local plot = plotByPlayer[player]
				if plot and total > 0 then
					spawnFloatingEarningsText(plot, math.floor(total))
				end
				accumulated[player] = nil
			end
		end
	end
end

return BaseManager
