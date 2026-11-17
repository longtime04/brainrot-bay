-- BrainrotData.luau
-- The cast of Brainrot Bay: rarities, spawn odds, mutations and income math.
-- Shared by server and client (lives in ReplicatedStorage).

local BrainrotData = {}

-- Rarities from most to least common. income is cash per second for one placed
-- brainrot of that rarity (before mutation and rebirth multipliers).
BrainrotData.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

BrainrotData.Rarities = {
	Common = { income = 1, odds = 55, color = Color3.fromRGB(208, 213, 219) },
	Rare = { income = 4, odds = 27, color = Color3.fromRGB(82, 172, 255) },
	Epic = { income = 15, odds = 11, color = Color3.fromRGB(178, 96, 255) },
	Legendary = { income = 60, odds = 4.5, color = Color3.fromRGB(255, 191, 42) },
	Mythic = { income = 250, odds = 2, color = Color3.fromRGB(255, 84, 164) },
	Secret = { income = 1200, odds = 0.5, color = Color3.fromRGB(46, 48, 58) },
}

-- The cast. shape is one of "round", "tall", "flat", "box" and picks the body
-- proportions WorldBuilder uses; accessory names a silly hat or prop builder.
BrainrotData.Cast = {
	{ id = "noodle_newt", name = "Noodle Newt", rarity = "Common", accessory = "chefHat", shape = "tall",
		bodyColor = Color3.fromRGB(138, 219, 128), headColor = Color3.fromRGB(172, 240, 160) },
	{ id = "pigeon_toast", name = "Pigeon Toast", rarity = "Common", accessory = "cap", shape = "flat",
		bodyColor = Color3.fromRGB(224, 186, 118), headColor = Color3.fromRGB(148, 152, 168) },
	{ id = "barry_brick", name = "Barry the Brick", rarity = "Common", accessory = "bowTie", shape = "box",
		bodyColor = Color3.fromRGB(178, 84, 66), headColor = Color3.fromRGB(192, 98, 78) },
	{ id = "turbo_turnip", name = "Turbo Turnip", rarity = "Rare", accessory = "mohawk", shape = "round",
		bodyColor = Color3.fromRGB(246, 241, 226), headColor = Color3.fromRGB(118, 208, 108) },
	{ id = "captain_cucumber", name = "Captain Cucumber", rarity = "Rare", accessory = "topHat", shape = "tall",
		bodyColor = Color3.fromRGB(58, 168, 80), headColor = Color3.fromRGB(82, 196, 102) },
	{ id = "disco_dumpling", name = "Disco Dumpling", rarity = "Epic", accessory = "glasses", shape = "round",
		bodyColor = Color3.fromRGB(250, 224, 168), headColor = Color3.fromRGB(255, 236, 192) },
	{ id = "professor_pickle", name = "Professor Pickle", rarity = "Epic", accessory = "glasses", shape = "tall",
		bodyColor = Color3.fromRGB(88, 158, 68), headColor = Color3.fromRGB(112, 182, 92) },
	{ id = "sir_loin", name = "Sir Loin the Steak Knight", rarity = "Legendary", accessory = "crown", shape = "box",
		bodyColor = Color3.fromRGB(198, 88, 88), headColor = Color3.fromRGB(216, 122, 112) },
	{ id = "moonlight_muffin", name = "Moonlight Muffin", rarity = "Legendary", accessory = "halo", shape = "round",
		bodyColor = Color3.fromRGB(148, 138, 222), headColor = Color3.fromRGB(236, 222, 162) },
	{ id = "golden_gooseberry", name = "Golden Gooseberry", rarity = "Mythic", accessory = "crown", shape = "round",
		bodyColor = Color3.fromRGB(255, 204, 58), headColor = Color3.fromRGB(255, 222, 102) },
	{ id = "tax_auditor", name = "The Tax Auditor", rarity = "Mythic", accessory = "briefcase", shape = "tall",
		bodyColor = Color3.fromRGB(68, 72, 88), headColor = Color3.fromRGB(226, 200, 174) },
	{ id = "last_wifi_router", name = "The Last Wi-Fi Router", rarity = "Secret", accessory = "wifi", shape = "box",
		bodyColor = Color3.fromRGB(36, 38, 46), headColor = Color3.fromRGB(54, 58, 68) },
}

-- Mutations rolled once when a brainrot spawns. tint nil means "keep the cast
-- colours" (Rainbow instead glows and cycles, handled by the spawner).
BrainrotData.Mutations = {
	{ name = "Gold", multiplier = 2, chance = 0.08, tint = Color3.fromRGB(255, 214, 64) },
	{ name = "Diamond", multiplier = 4, chance = 0.025, tint = Color3.fromRGB(150, 236, 255) },
	{ name = "Rainbow", multiplier = 10, chance = 0.006, tint = nil },
}

local castById = {}
local castByRarity = {}
for _, def in ipairs(BrainrotData.Cast) do
	castById[def.id] = def
	if not castByRarity[def.rarity] then
		castByRarity[def.rarity] = {}
	end
	table.insert(castByRarity[def.rarity], def)
end

function BrainrotData.getBrainrotById(id)
	return castById[id]
end

function BrainrotData.getMutationByName(name)
	if not name or name == "" then
		return nil
	end
	for _, mutation in ipairs(BrainrotData.Mutations) do
		if mutation.name == name then
			return mutation
		end
	end
	return nil
end

-- Weighted rarity roll using the odds column (they sum to 100).
function BrainrotData.rollRarity(rng)
	local roll = rng:NextNumber(0, 100)
	local running = 0
	for _, rarityName in ipairs(BrainrotData.RarityOrder) do
		running += BrainrotData.Rarities[rarityName].odds
		if roll <= running then
			return rarityName
		end
	end
	return "Common"
end

-- Roll a full cast member: rarity first, then a random member of that rarity.
function BrainrotData.rollBrainrot(rng)
	local rarityName = BrainrotData.rollRarity(rng)
	local pool = castByRarity[rarityName]
	return pool[rng:NextInteger(1, #pool)]
end

-- Roll a mutation (or nil for a plain brainrot).
function BrainrotData.rollMutation(rng)
	for _, mutation in ipairs(BrainrotData.Mutations) do
		if rng:NextNumber() < mutation.chance then
			return mutation
		end
	end
	return nil
end

-- Cash per second one placed brainrot earns before the owner's rebirth multiplier.
function BrainrotData.incomePerSecond(def, mutation)
	local base = BrainrotData.Rarities[def.rarity].income
	if mutation then
		return base * mutation.multiplier
	end
	return base
end

-- "Rainbow Disco Dumpling" / "Disco Dumpling".
function BrainrotData.displayName(def, mutation)
	if mutation then
		return mutation.name .. " " .. def.name
	end
	return def.name
end

return BrainrotData
