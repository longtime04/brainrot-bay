-- TsunamiController.luau
-- Every 100 seconds a tsunami sweeps the island. Ten seconds of warning,
-- then a translucent wave wall crosses from the beach to the back plots
-- over 9 seconds. Anyone it catches outside a raised base plot is washed
-- away: their carried brainrot returns to the beach and they respawn.

local Players = game:GetService("Players")

local TsunamiController = {}

local WAVE_INTERVAL = 100
local WARNING_SECONDS = 10
local SWEEP_SECONDS = 9
local WAVE_START_Z = 135
local WAVE_END_Z = -150

local ctx -- set by init

function TsunamiController.init(context)
	ctx = context
end

local function washPlayerAway(player)
	if ctx.spawner then
		ctx.spawner.dropCarriedBrainrot(player)
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root then
		root.Velocity = Vector3.new(math.random(-18, 18), 58, -34)
	end
	ctx.remotes.Notify:FireClient(player, "Message", "The tsunami washed you away!")
	if humanoid then
		task.delay(0.7, function()
			if humanoid and humanoid.Parent then
				humanoid.Health = 0
			end
		end)
	end
end

local function sweepWaveAcrossIsland()
	local wave = Instance.new("Part")
	wave.Name = "TsunamiWave"
	wave.Size = Vector3.new(280, 38, 10)
	wave.Position = Vector3.new(0, 13, WAVE_START_Z)
	wave.Color = Color3.fromRGB(64, 148, 255)
	wave.Material = Enum.Material.Glass
	wave.Transparency = 0.35
	wave.Anchored = true
	wave.CanCollide = false
	wave.Parent = workspace
	local foam = Instance.new("Part")
	foam.Name = "Foam"
	foam.Size = Vector3.new(280, 5, 11)
	foam.Color = Color3.fromRGB(235, 250, 255)
	foam.Material = Enum.Material.SmoothPlastic
	foam.Transparency = 0.25
	foam.Anchored = true
	foam.CanCollide = false
	foam.Parent = wave

	local washed = {}
	local started = os.clock()
	while true do
		local elapsed = os.clock() - started
		if elapsed >= SWEEP_SECONDS then
			break
		end
		local z = WAVE_START_Z + (WAVE_END_Z - WAVE_START_Z) * (elapsed / SWEEP_SECONDS)
		wave.Position = Vector3.new(0, 13, z)
		foam.Position = Vector3.new(0, 30, z)
		for _, player in ipairs(Players:GetPlayers()) do
			if not washed[player] then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and root.Position.Z >= z - 5 then
					if not ctx.base.isPlayerOnSafePlot(player) then
						washed[player] = true
						washPlayerAway(player)
					else
						washed[player] = true
					end
				end
			end
		end
		task.wait(0.1)
	end
	wave:Destroy()
	for _, player in ipairs(Players:GetPlayers()) do
		ctx.remotes.Notify:FireClient(player, "TsunamiOver")
	end
end

local function startTsunamiWave()
	for _, player in ipairs(Players:GetPlayers()) do
		ctx.remotes.Notify:FireClient(player, "TsunamiWarning", WARNING_SECONDS)
	end
	task.wait(WARNING_SECONDS)
	sweepWaveAcrossIsland()
end

function TsunamiController.startTsunamiLoop()
	while true do
		task.wait(WAVE_INTERVAL)
		startTsunamiWave()
	end
end

return TsunamiController
