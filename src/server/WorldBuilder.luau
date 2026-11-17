-- WorldBuilder.luau
-- Builds the whole island from code at server start: ocean, sand, the beach
-- spawn lane, 8 raised base plots, decorations, and the brainrot characters
-- themselves (buildBrainrotModel). Nothing is modelled by hand in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))

local WorldBuilder = {}

local function makePart(name, size, cframe, color, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function weldPartTo(part, root)
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	return weld
end

----------------------------------------------------------------------
-- Island
----------------------------------------------------------------------

local function buildOceanAndIsland(world)
	-- Ocean surface.
	makePart("Ocean", Vector3.new(720, 1, 720), CFrame.new(0, -1.5, 0),
		Color3.fromRGB(38, 116, 196), Enum.Material.SmoothPlastic, world).Transparency = 0.12
	-- The sand island itself.
	makePart("Island", Vector3.new(240, 6, 180), CFrame.new(0, 0, 0),
		Color3.fromRGB(237, 214, 152), Enum.Material.Sand, world)
	-- A grassy middle where players spawn.
	makePart("VillageGreen", Vector3.new(90, 0.4, 44), CFrame.new(0, 3.2, 8),
		Color3.fromRGB(116, 196, 96), Enum.Material.Grass, world)
end

local function buildBeachLane(world)
	local lane = Instance.new("Folder")
	lane.Name = "BeachLane"
	lane.Parent = world
	makePart("Lane", Vector3.new(196, 0.4, 24), CFrame.new(0, 3.2, 52),
		Color3.fromRGB(246, 228, 170), Enum.Material.Sand, lane)
	-- Fences along both edges of the lane.
	for _, z in ipairs({ 39, 65 }) do
		makePart("FenceRail", Vector3.new(196, 0.5, 0.5), CFrame.new(0, 4.6, z),
			Color3.fromRGB(146, 102, 62), Enum.Material.Wood, lane)
		for x = -96, 96, 12 do
			makePart("FencePost", Vector3.new(0.7, 2.4, 0.7), CFrame.new(x, 4.2, z),
				Color3.fromRGB(128, 88, 52), Enum.Material.Wood, lane)
		end
	end
	-- Six glowing spawn pads.
	local spawnPads = {}
	for i, x in ipairs({ -80, -48, -16, 16, 48, 80 }) do
		local pad = makePart("SpawnPad" .. i, Vector3.new(10, 0.5, 10), CFrame.new(x, 3.65, 52),
			Color3.fromRGB(255, 255, 255), Enum.Material.Neon, lane)
		table.insert(spawnPads, pad)
	end
	return spawnPads
end

local function buildBasePlots(world)
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "BasePlots"
	plotsFolder.Parent = world

	local plots = {}
	local xs = { -81, -27, 27, 81 }
	local zs = { -20, -62 }
	local index = 0
	for _, z in ipairs(zs) do
		for _, x in ipairs(xs) do
			index += 1
			local model = Instance.new("Model")
			model.Name = "BasePlot" .. index
			model.Parent = plotsFolder

			-- Raised platform: high enough that the tsunami cannot reach.
			local platform = makePart("Platform", Vector3.new(36, 3, 36), CFrame.new(x, 6.5, z),
				Color3.fromRGB(196, 164, 120), Enum.Material.WoodPlanks, model)
			makePart("PlatformSkirt", Vector3.new(38, 5.5, 38), CFrame.new(x, 2.75, z),
				Color3.fromRGB(120, 96, 70), Enum.Material.Wood, model)
			-- A coloured trim so each plot reads as its own little fort.
			makePart("Trim", Vector3.new(37, 0.5, 37), CFrame.new(x, 8.1, z),
				Color3.fromHSV(index / 8, 0.45, 0.95), Enum.Material.SmoothPlastic, model)

			-- Nine placement pads in a 3x3 grid.
			local pads = {}
			for row = -1, 1 do
				for col = -1, 1 do
					local pad = makePart("Pad", Vector3.new(7, 0.5, 7),
						CFrame.new(x + col * 10, 8.25, z + row * 10),
						Color3.fromRGB(240, 236, 226), Enum.Material.SmoothPlastic, model)
					table.insert(pads, pad)
				end
			end

			-- Owner sign at the lane-facing edge.
			makePart("SignPost", Vector3.new(0.8, 6, 0.8), CFrame.new(x, 11, z + 18.5),
				Color3.fromRGB(110, 78, 46), Enum.Material.Wood, model)
			local board = makePart("SignBoard", Vector3.new(16, 4.5, 0.6), CFrame.new(x, 14.5, z + 18.5),
				Color3.fromRGB(84, 58, 36), Enum.Material.Wood, model)
			local signGui = Instance.new("SurfaceGui")
			signGui.Face = Enum.NormalId.Front
			signGui.Parent = board
			local signLabel = Instance.new("TextLabel")
			signLabel.Name = "SignLabel"
			signLabel.Size = UDim2.fromScale(1, 1)
			signLabel.BackgroundTransparency = 1
			signLabel.Text = "Empty Base"
			signLabel.TextColor3 = Color3.fromRGB(255, 244, 214)
			signLabel.FontFace = FontFace.new("rbxasset://fonts/families/Fredoka.json", Enum.FontWeight.Bold)
			signLabel.TextScaled = true
			signLabel.Parent = signGui

			-- Shield bubble, invisible until the base is locked.
			local shield = makePart("ShieldBubble", Vector3.new(38, 13, 38), CFrame.new(x, 13.5, z),
				Color3.fromRGB(90, 220, 255), Enum.Material.Glass, model)
			shield.CanCollide = false
			shield.Transparency = 1

			table.insert(plots, {
				index = index,
				model = model,
				platform = platform,
				pads = pads,
				signLabel = signLabel,
				shieldPart = shield,
				center = Vector3.new(x, 8, z),
			})
		end
	end
	return plots
end

local function buildPalmTree(parent, x, z, lean)
	local palm = Instance.new("Model")
	palm.Name = "PalmTree"
	palm.Parent = parent
	local trunk = makePart("Trunk", Vector3.new(1.4, 11, 1.4),
		CFrame.new(x, 8.5, z) * CFrame.Angles(0, 0, lean),
		Color3.fromRGB(146, 108, 66), Enum.Material.Wood, palm)
	trunk.Shape = Enum.PartType.Cylinder
	local topX = x - math.sin(lean) * 5.5
	for i = 1, 5 do
		local angle = (i / 5) * math.pi * 2
		local leafCFrame = CFrame.new(topX, 14.4, z) * CFrame.Angles(0, angle, 0)
			* CFrame.new(3.4, -0.6, 0) * CFrame.Angles(0, 0, -0.45)
		makePart("Leaf", Vector3.new(9, 0.3, 2), leafCFrame,
			Color3.fromRGB(64, 168, 74), Enum.Material.Grass, palm)
	end
	makePart("Coconut", Vector3.new(1.1, 1.1, 1.1), CFrame.new(topX + 0.7, 13.4, z + 0.4),
		Color3.fromRGB(110, 80, 44), Enum.Material.Wood, palm).Shape = Enum.PartType.Ball
end

local function buildLighthouse(parent, x, z)
	local lighthouse = Instance.new("Model")
	lighthouse.Name = "Lighthouse"
	lighthouse.Parent = parent
	makePart("RockBase", Vector3.new(16, 5, 16), CFrame.new(x, 4, z),
		Color3.fromRGB(128, 128, 134), Enum.Material.Rock, lighthouse)
	local bands = { Color3.fromRGB(238, 238, 238), Color3.fromRGB(224, 64, 58),
		Color3.fromRGB(238, 238, 238), Color3.fromRGB(224, 64, 58) }
	for i, color in ipairs(bands) do
		local band = makePart("Band" .. i, Vector3.new(7, 5, 7), CFrame.new(x, 6.5 + i * 5, z),
			color, Enum.Material.SmoothPlastic, lighthouse)
		band.Shape = Enum.PartType.Cylinder
	end
	local lamp = makePart("Lamp", Vector3.new(4.4, 3.4, 4.4), CFrame.new(x, 29.5, z),
		Color3.fromRGB(255, 236, 150), Enum.Material.Neon, lighthouse)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 230, 160)
	light.Range = 40
	light.Brightness = 1.5
	light.Parent = lamp
	makePart("Roof", Vector3.new(8, 2.4, 8), CFrame.new(x, 32.4, z),
		Color3.fromRGB(60, 60, 70), Enum.Material.Slate, lighthouse)
end

local function buildDecorations(world)
	local decor = Instance.new("Folder")
	decor.Name = "Decorations"
	decor.Parent = world
	local palmSpots = {
		{ -108, 30, 0.12 }, { 108, 28, -0.1 }, { -104, -6, 0.06 }, { 104, -10, -0.14 },
		{ -60, 78, 0.1 }, { 62, 80, -0.08 }, { -112, 66, 0.16 }, { 112, 60, -0.05 },
		{ -34, -88, 0.08 }, { 40, -90, -0.12 },
	}
	for _, spot in ipairs(palmSpots) do
		buildPalmTree(decor, spot[1], spot[2], spot[3])
	end
	buildLighthouse(decor, -102, -72)
	local rockSpots = { { -96, 84, 3 }, { 92, -84, 4 }, { 118, -34, 2.4 }, { -118, -52, 3.4 }, { 70, 88, 2 }, { -72, 90, 2.6 } }
	for i, spot in ipairs(rockSpots) do
		local rock = makePart("Rock" .. i, Vector3.new(spot[3], spot[3] * 0.7, spot[3]),
			CFrame.new(spot[1], 3.4, spot[2]), Color3.fromRGB(134, 134, 140), Enum.Material.Rock, decor)
		rock.Shape = Enum.PartType.Ball
	end
end

-- Build the whole island. Returns { spawnPads = {...}, plots = {...} }.
function WorldBuilder.buildWorld()
	local world = Instance.new("Folder")
	world.Name = "BrainrotBayWorld"
	world.Parent = workspace

	buildOceanAndIsland(world)
	local spawnPads = buildBeachLane(world)
	local plots = buildBasePlots(world)
	buildDecorations(world)
	return { spawnPads = spawnPads, plots = plots }
end

----------------------------------------------------------------------
-- Brainrot characters
----------------------------------------------------------------------

local BODY_SIZES = {
	round = Vector3.new(2.7, 2.7, 2.7),
	tall = Vector3.new(1.9, 3.3, 1.5),
	flat = Vector3.new(3, 1.5, 2.2),
	box = Vector3.new(2.5, 2.5, 1.7),
}

local function buildAccessory(kind, model, body, head, headTop)
	local function add(name, size, cframe, color, material)
		local part = makePart(name, size, cframe, color, material or Enum.Material.SmoothPlastic, model)
		weldPartTo(part, body)
		return part
	end
	local hx, hy, hz = head.Position.X, head.Position.Y, head.Position.Z
	if kind == "chefHat" then
		add("HatBrim", Vector3.new(1.9, 0.25, 1.9), CFrame.new(hx, headTop, hz), Color3.fromRGB(250, 250, 250))
		add("HatTop", Vector3.new(1.5, 0.9, 1.5), CFrame.new(hx, headTop + 0.55, hz), Color3.fromRGB(250, 250, 250))
	elseif kind == "cap" then
		add("CapTop", Vector3.new(1.8, 0.5, 1.8), CFrame.new(hx, headTop - 0.1, hz), Color3.fromRGB(64, 110, 220))
		add("CapBrim", Vector3.new(1.6, 0.18, 1), CFrame.new(hx, headTop - 0.2, hz + 1.1), Color3.fromRGB(64, 110, 220))
	elseif kind == "bowTie" then
		add("BowLeft", Vector3.new(0.6, 0.5, 0.2), CFrame.new(hx - 0.4, hy - 0.9, hz + 0.95), Color3.fromRGB(220, 40, 60))
		add("BowRight", Vector3.new(0.6, 0.5, 0.2), CFrame.new(hx + 0.4, hy - 0.9, hz + 0.95), Color3.fromRGB(220, 40, 60))
		add("BowKnot", Vector3.new(0.35, 0.35, 0.22), CFrame.new(hx, hy - 0.9, hz + 0.95), Color3.fromRGB(180, 30, 50))
	elseif kind == "mohawk" then
		for i = -2, 2 do
			add("Spike", Vector3.new(0.34, 0.9, 0.5), CFrame.new(hx, headTop + 0.3, hz + i * 0.34),
				Color3.fromRGB(255, 84, 164))
		end
	elseif kind == "topHat" then
		add("HatBrim", Vector3.new(2.1, 0.2, 2.1), CFrame.new(hx, headTop, hz), Color3.fromRGB(30, 30, 36))
		add("HatTop", Vector3.new(1.4, 1.3, 1.4), CFrame.new(hx, headTop + 0.7, hz), Color3.fromRGB(30, 30, 36))
	elseif kind == "glasses" then
		add("LensL", Vector3.new(0.62, 0.62, 0.12), CFrame.new(hx - 0.45, hy + 0.1, hz + 0.82), Color3.fromRGB(24, 24, 30))
		add("LensR", Vector3.new(0.62, 0.62, 0.12), CFrame.new(hx + 0.45, hy + 0.1, hz + 0.82), Color3.fromRGB(24, 24, 30))
		add("Bridge", Vector3.new(0.4, 0.12, 0.12), CFrame.new(hx, hy + 0.16, hz + 0.82), Color3.fromRGB(24, 24, 30))
	elseif kind == "crown" then
		add("CrownBand", Vector3.new(1.8, 0.55, 1.8), CFrame.new(hx, headTop + 0.2, hz), Color3.fromRGB(255, 200, 40), Enum.Material.Metal)
		for i = -1, 1 do
			add("CrownPoint", Vector3.new(0.4, 0.6, 0.4), CFrame.new(hx + i * 0.6, headTop + 0.7, hz),
				Color3.fromRGB(255, 200, 40), Enum.Material.Metal)
		end
	elseif kind == "halo" then
		local halo = add("Halo", Vector3.new(1.7, 0.18, 1.7), CFrame.new(hx, headTop + 0.55, hz),
			Color3.fromRGB(255, 240, 160), Enum.Material.Neon)
		halo.Shape = Enum.PartType.Cylinder
	elseif kind == "briefcase" then
		add("Briefcase", Vector3.new(1.7, 1.2, 0.5), CFrame.new(hx + 1.7, hy - 1, hz + 0.3),
			Color3.fromRGB(96, 64, 36), Enum.Material.Leather)
		add("BriefcaseBand", Vector3.new(1.74, 0.24, 0.54), CFrame.new(hx + 1.7, hy - 1, hz + 0.3),
			Color3.fromRGB(200, 170, 60), Enum.Material.Metal)
	elseif kind == "wifi" then
		add("AntennaL", Vector3.new(0.16, 1.6, 0.16), CFrame.new(hx - 0.6, headTop + 0.7, hz), Color3.fromRGB(20, 20, 24))
		add("AntennaR", Vector3.new(0.16, 1.6, 0.16), CFrame.new(hx + 0.6, headTop + 0.7, hz), Color3.fromRGB(20, 20, 24))
		local dot = add("SignalDot", Vector3.new(0.4, 0.4, 0.14), CFrame.new(hx, hy, hz + 0.5),
			Color3.fromRGB(80, 255, 140), Enum.Material.Neon)
		dot.Shape = Enum.PartType.Ball
	end
end

-- Build one brainrot character model at the origin, facing +Z.
-- The Body is the PrimaryPart and starts Anchored; every other part is welded
-- to it, so callers can anchor/unanchor or weld the Body to move the model.
function WorldBuilder.buildBrainrotModel(def, mutation)
	local model = Instance.new("Model")
	model.Name = def.id
	model:SetAttribute("BrainrotId", def.id)
	model:SetAttribute("Mutation", mutation and mutation.name or "")

	local bodyColor = def.bodyColor
	local headColor = def.headColor
	if mutation and mutation.tint then
		bodyColor = mutation.tint
		headColor = mutation.tint:Lerp(Color3.fromRGB(255, 255, 255), 0.25)
	end

	local bodySize = BODY_SIZES[def.shape] or BODY_SIZES.box
	local body = makePart("Body", bodySize, CFrame.new(0, bodySize.Y / 2, 0), bodyColor,
		Enum.Material.SmoothPlastic, model)
	if def.shape == "round" then
		body.Shape = Enum.PartType.Ball
	end

	local headSize = 1.7
	local headY = bodySize.Y + headSize / 2 - 0.15
	local head = makePart("Head", Vector3.new(headSize, headSize, headSize),
		CFrame.new(0, headY, 0), headColor, Enum.Material.SmoothPlastic, model)
	head.Shape = Enum.PartType.Ball
	weldPartTo(head, body)

	-- Big cartoon eyes on the +Z face.
	for _, side in ipairs({ -0.42, 0.42 }) do
		local white = makePart("EyeWhite", Vector3.new(0.46, 0.56, 0.2),
			CFrame.new(side, headY + 0.12, 0.78), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, model)
		white.Shape = Enum.PartType.Ball
		weldPartTo(white, body)
		local pupil = makePart("Pupil", Vector3.new(0.2, 0.26, 0.1),
			CFrame.new(side, headY + 0.12, 0.9), Color3.fromRGB(16, 16, 20), Enum.Material.SmoothPlastic, model)
		pupil.Shape = Enum.PartType.Ball
		weldPartTo(pupil, body)
	end
	-- A simple smile line.
	local mouth = makePart("Mouth", Vector3.new(0.7, 0.12, 0.08),
		CFrame.new(0, headY - 0.42, 0.84), Color3.fromRGB(60, 30, 30), Enum.Material.SmoothPlastic, model)
	weldPartTo(mouth, body)

	buildAccessory(def.accessory, model, body, head, headY + headSize / 2 - 0.05)

	if mutation and not mutation.tint then
		-- Rainbow: a soft cycling glow (the spawner cycles the colour).
		local glow = Instance.new("PointLight")
		glow.Name = "RainbowGlow"
		glow.Range = 9
		glow.Brightness = 1.2
		glow.Parent = body
	end

	-- Floating label: name, rarity and income, big and readable.
	local rarity = BrainrotData.Rarities[def.rarity]
	local label = Instance.new("BillboardGui")
	label.Name = "BrainrotLabel"
	label.Size = UDim2.fromOffset(240, 96)
	label.StudsOffset = Vector3.new(0, headY + 1.6, 0)
	label.AlwaysOnTop = true
	label.Adornee = body
	label.Parent = model

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 40)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = BrainrotData.displayName(def, mutation)
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.25
	nameLabel.FontFace = FontFace.new("rbxasset://fonts/families/Fredoka.json", Enum.FontWeight.Bold)
	nameLabel.TextSize = 24
	nameLabel.Parent = label

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "InfoLabel"
	infoLabel.Position = UDim2.new(0, 0, 0, 42)
	infoLabel.Size = UDim2.new(1, 0, 0, 34)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Text = string.format("%s  •  $%d/s", def.rarity, BrainrotData.incomePerSecond(def, mutation))
	infoLabel.TextColor3 = rarity.color
	infoLabel.TextStrokeTransparency = 0.25
	infoLabel.FontFace = FontFace.new("rbxasset://fonts/families/Fredoka.json", Enum.FontWeight.Bold)
	infoLabel.TextSize = 21
	infoLabel.Parent = label

	model.PrimaryPart = body
	return model
end

return WorldBuilder
