-- StealService.luau
-- Base shields and stealing. A base locks for 60 s after a brainrot is
-- placed or when its owner presses Lock (90 s cooldown on the button).
-- While the shield is down, a rival can grab a placed brainrot and run it
-- home — at the price of their own shield dropping.

local Players = game:GetService("Players")

local StealService = {}

local SHIELD_SECONDS = 60
local LOCK_COOLDOWN_SECONDS = 90

local ctx -- set by init
local lockCooldownUntil = {} -- player -> os.clock() timestamp

local function isShieldUp(plot)
	return os.clock() < (plot.shieldUntil or 0)
end
StealService.isShieldUp = isShieldUp

local function refreshShieldVisual(plot)
	plot.visual.shieldPart.Transparency = isShieldUp(plot) and 0.72 or 1
end

-- Called by BaseManager whenever a brainrot is placed on a plot.
function StealService.onBrainrotPlaced(context, plot, record)
	ctx = context or ctx
	plot.shieldUntil = math.max(plot.shieldUntil or 0, os.clock() + SHIELD_SECONDS)
	refreshShieldVisual(plot)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Steal"
	prompt.ObjectText = record.def.name
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = record.model.PrimaryPart
	prompt.Triggered:Connect(function(rival)
		StealService.stealBrainrotFromBase(rival, plot, record.padIndex)
	end)
end

function StealService.stealBrainrotFromBase(rival, plot, padIndex)
	local owner = plot.owner
	if not owner or owner == rival then
		return
	end
	if isShieldUp(plot) then
		ctx.remotes.Notify:FireClient(rival, "Message", "That base is shielded! Wait for the bubble to drop.")
		return
	end
	if ctx.spawner.isCarrying(rival) then
		ctx.remotes.Notify:FireClient(rival, "Message", "Your hands are full — place your brainrot first!")
		return
	end
	local record = ctx.base.removePlacedBrainrot(plot, padIndex)
	if not record then
		return
	end
	local carried = ctx.spawner.carryBrainrotHome(rival, record.model, record.def, record.mutation)
	if not carried then
		-- Could not pick it up (no character): put it back where it was.
		ctx.base.placeModelOnPad(plot, padIndex, record.model, record.def, record.mutation)
		return
	end
	-- The thief's own base is exposed while they run.
	local rivalPlot = ctx.base.getPlayerPlot(rival)
	if rivalPlot then
		rivalPlot.shieldUntil = 0
		refreshShieldVisual(rivalPlot)
	end
	ctx.remotes.Notify:FireClient(owner, "Message", rival.Name .. " stole your " .. record.def.name .. "!")
	ctx.remotes.Notify:FireClient(rival, "Message", "You stole a " .. record.def.name .. "! Get it home!")
end

local function lockBase(player)
	local plot = ctx.base.getPlayerPlot(player)
	if not plot then
		return
	end
	local now = os.clock()
	if lockCooldownUntil[player] and now < lockCooldownUntil[player] then
		local left = math.ceil(lockCooldownUntil[player] - now)
		ctx.remotes.Notify:FireClient(player, "Message", "Lock is recharging (" .. left .. "s)")
		return
	end
	plot.shieldUntil = now + SHIELD_SECONDS
	lockCooldownUntil[player] = now + LOCK_COOLDOWN_SECONDS
	refreshShieldVisual(plot)
	ctx.remotes.Notify:FireClient(player, "Message", "Base locked for " .. SHIELD_SECONDS .. " seconds!")
end

function StealService.init(context)
	ctx = context
	ctx.remotes.LockBaseRequest.OnServerEvent:Connect(lockBase)
	Players.PlayerRemoving:Connect(function(player)
		lockCooldownUntil[player] = nil
	end)
	-- Keep shield bubbles honest as timers run out.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, plot in ipairs(ctx.base.getPlots()) do
				refreshShieldVisual(plot)
			end
		end
	end)
end

return StealService
