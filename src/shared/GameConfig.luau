--!strict

export type Cost = {
	gold: number?,
	shards: number?,
}

export type EnemyConfig = {
	id: string,
	name: string,
	health: number,
	attack: number,
	rewardGold: number,
	rewardShards: number,
	rewardXp: number,
	color: Color3,
	accentColor: Color3,
}

export type FloorConfig = {
	id: number,
	name: string,
	rooms: number,
	recommendedPower: number,
	completionGold: number,
	completionShards: number,
	completionXp: number,
	enemyPacks: { { string } },
	wallColor: Color3,
	floorColor: Color3,
	accentColor: Color3,
}

export type SwordConfig = {
	id: string,
	name: string,
	price: Cost,
	requiredFloor: number,
	damage: number,
	cooldown: number,
	bladeColor: Color3,
	hiltColor: Color3,
	accentColor: Color3,
}

export type UpgradeConfig = {
	id: string,
	name: string,
	maxLevel: number,
	baseCost: Cost,
	costGrowth: number,
	effectPerLevel: number,
}

export type BaseConfig = {
	id: string,
	name: string,
	price: Cost,
	requiredFloor: number,
	goldBonusPercent: number,
	primaryColor: Color3,
	accentColor: Color3,
}

local config = {
	DataStoreName = "testrblx_dungeon_save_v1",

	Remotes = {
		DungeonCommand = "DungeonCommand",
		StateUpdate = "StateUpdate",
		Toast = "Toast",
	},

	Economy = {
		StartingGold = 250,
		StartingShards = 0,
		StartingXp = 0,
	},

	Player = {
		BaseHealth = 100,
		AttackRange = 18,
		StudioDataStoresEnabled = false,
	},

	World = {
		LobbySpawn = Vector3.new(0, 5, 22),
		DungeonOrigin = Vector3.new(-360, 6, -140),
		RunSlotSpacing = 190,
		MaxBasePlots = 6,
	},

	Enemies = {
		boneCrawler = {
			id = "boneCrawler",
			name = "Bone Crawler",
			health = 45,
			attack = 5,
			rewardGold = 18,
			rewardShards = 0,
			rewardXp = 12,
			color = Color3.fromRGB(204, 195, 168),
			accentColor = Color3.fromRGB(121, 105, 87),
		},
		cryptKnight = {
			id = "cryptKnight",
			name = "Crypt Knight",
			health = 85,
			attack = 9,
			rewardGold = 42,
			rewardShards = 1,
			rewardXp = 28,
			color = Color3.fromRGB(97, 107, 123),
			accentColor = Color3.fromRGB(195, 164, 84),
		},
		emberImp = {
			id = "emberImp",
			name = "Ember Imp",
			health = 95,
			attack = 12,
			rewardGold = 58,
			rewardShards = 1,
			rewardXp = 36,
			color = Color3.fromRGB(205, 87, 50),
			accentColor = Color3.fromRGB(255, 191, 96),
		},
		runeGolem = {
			id = "runeGolem",
			name = "Rune Golem",
			health = 165,
			attack = 18,
			rewardGold = 112,
			rewardShards = 2,
			rewardXp = 72,
			color = Color3.fromRGB(83, 118, 126),
			accentColor = Color3.fromRGB(93, 210, 206),
		},
		voidAcolyte = {
			id = "voidAcolyte",
			name = "Void Acolyte",
			health = 240,
			attack = 27,
			rewardGold = 185,
			rewardShards = 4,
			rewardXp = 120,
			color = Color3.fromRGB(70, 57, 100),
			accentColor = Color3.fromRGB(178, 126, 255),
		},
	} :: { [string]: EnemyConfig },

	FloorOrder = { 1, 2, 3, 4, 5 },

	Floors = {
		[1] = {
			id = 1,
			name = "Forgotten Crypt",
			rooms = 3,
			recommendedPower = 12,
			completionGold = 140,
			completionShards = 2,
			completionXp = 90,
			enemyPacks = {
				{ "boneCrawler", "boneCrawler" },
				{ "boneCrawler", "cryptKnight" },
				{ "cryptKnight", "cryptKnight" },
			},
			wallColor = Color3.fromRGB(80, 78, 86),
			floorColor = Color3.fromRGB(49, 48, 55),
			accentColor = Color3.fromRGB(98, 184, 160),
		},
		[2] = {
			id = 2,
			name = "Ember Warrens",
			rooms = 4,
			recommendedPower = 24,
			completionGold = 360,
			completionShards = 5,
			completionXp = 220,
			enemyPacks = {
				{ "boneCrawler", "emberImp" },
				{ "emberImp", "emberImp" },
				{ "cryptKnight", "emberImp", "emberImp" },
				{ "cryptKnight", "emberImp", "runeGolem" },
			},
			wallColor = Color3.fromRGB(93, 62, 55),
			floorColor = Color3.fromRGB(56, 42, 39),
			accentColor = Color3.fromRGB(255, 142, 78),
		},
		[3] = {
			id = 3,
			name = "Sapphire Reliquary",
			rooms = 4,
			recommendedPower = 38,
			completionGold = 780,
			completionShards = 9,
			completionXp = 430,
			enemyPacks = {
				{ "cryptKnight", "runeGolem" },
				{ "runeGolem", "runeGolem" },
				{ "emberImp", "runeGolem", "cryptKnight" },
				{ "runeGolem", "runeGolem", "voidAcolyte" },
			},
			wallColor = Color3.fromRGB(50, 78, 91),
			floorColor = Color3.fromRGB(37, 51, 62),
			accentColor = Color3.fromRGB(95, 210, 229),
		},
		[4] = {
			id = 4,
			name = "Moonlit Bastion",
			rooms = 5,
			recommendedPower = 54,
			completionGold = 1450,
			completionShards = 15,
			completionXp = 760,
			enemyPacks = {
				{ "runeGolem", "runeGolem" },
				{ "cryptKnight", "voidAcolyte", "voidAcolyte" },
				{ "runeGolem", "voidAcolyte" },
				{ "emberImp", "runeGolem", "voidAcolyte" },
				{ "voidAcolyte", "voidAcolyte", "runeGolem" },
			},
			wallColor = Color3.fromRGB(72, 66, 94),
			floorColor = Color3.fromRGB(44, 41, 58),
			accentColor = Color3.fromRGB(202, 176, 255),
		},
		[5] = {
			id = 5,
			name = "Void Crown Depths",
			rooms = 5,
			recommendedPower = 76,
			completionGold = 2600,
			completionShards = 28,
			completionXp = 1320,
			enemyPacks = {
				{ "voidAcolyte", "runeGolem" },
				{ "voidAcolyte", "voidAcolyte" },
				{ "runeGolem", "voidAcolyte", "voidAcolyte" },
				{ "emberImp", "runeGolem", "voidAcolyte", "voidAcolyte" },
				{ "voidAcolyte", "voidAcolyte", "runeGolem", "runeGolem" },
			},
			wallColor = Color3.fromRGB(41, 42, 55),
			floorColor = Color3.fromRGB(27, 28, 38),
			accentColor = Color3.fromRGB(226, 95, 212),
		},
	} :: { [number]: FloorConfig },

	SwordOrder = { "rustbite", "emberFang", "frostbrand", "moonCleaver", "voidCrown" },

	Swords = {
		rustbite = {
			id = "rustbite",
			name = "Rustbite",
			price = { gold = 0 },
			requiredFloor = 0,
			damage = 14,
			cooldown = 0.95,
			bladeColor = Color3.fromRGB(176, 161, 132),
			hiltColor = Color3.fromRGB(91, 72, 55),
			accentColor = Color3.fromRGB(124, 184, 141),
		},
		emberFang = {
			id = "emberFang",
			name = "Ember Fang",
			price = { gold = 320 },
			requiredFloor = 1,
			damage = 25,
			cooldown = 0.85,
			bladeColor = Color3.fromRGB(255, 115, 65),
			hiltColor = Color3.fromRGB(87, 55, 41),
			accentColor = Color3.fromRGB(255, 207, 105),
		},
		frostbrand = {
			id = "frostbrand",
			name = "Frostbrand",
			price = { gold = 880, shards = 5 },
			requiredFloor = 2,
			damage = 38,
			cooldown = 0.78,
			bladeColor = Color3.fromRGB(141, 221, 240),
			hiltColor = Color3.fromRGB(61, 79, 112),
			accentColor = Color3.fromRGB(233, 249, 255),
		},
		moonCleaver = {
			id = "moonCleaver",
			name = "Moon Cleaver",
			price = { gold = 1800, shards = 14 },
			requiredFloor = 4,
			damage = 58,
			cooldown = 0.7,
			bladeColor = Color3.fromRGB(209, 194, 255),
			hiltColor = Color3.fromRGB(62, 54, 87),
			accentColor = Color3.fromRGB(255, 232, 149),
		},
		voidCrown = {
			id = "voidCrown",
			name = "Void Crown",
			price = { gold = 4200, shards = 34 },
			requiredFloor = 5,
			damage = 88,
			cooldown = 0.62,
			bladeColor = Color3.fromRGB(225, 81, 221),
			hiltColor = Color3.fromRGB(44, 40, 64),
			accentColor = Color3.fromRGB(120, 255, 232),
		},
	} :: { [string]: SwordConfig },

	UpgradeOrder = { "power", "vitality", "fortune", "haste" },

	Upgrades = {
		power = {
			id = "power",
			name = "Power Core",
			maxLevel = 12,
			baseCost = { gold = 180 },
			costGrowth = 1.42,
			effectPerLevel = 4,
		},
		vitality = {
			id = "vitality",
			name = "Vitality Ward",
			maxLevel = 10,
			baseCost = { gold = 160 },
			costGrowth = 1.38,
			effectPerLevel = 16,
		},
		fortune = {
			id = "fortune",
			name = "Treasure Sense",
			maxLevel = 8,
			baseCost = { gold = 240, shards = 1 },
			costGrowth = 1.48,
			effectPerLevel = 0.08,
		},
		haste = {
			id = "haste",
			name = "Blade Tempo",
			maxLevel = 8,
			baseCost = { gold = 280, shards = 1 },
			costGrowth = 1.5,
			effectPerLevel = 0.04,
		},
	} :: { [string]: UpgradeConfig },

	BaseOrder = { "camp", "forgehold", "crystalKeep", "skyCitadel" },

	Bases = {
		camp = {
			id = "camp",
			name = "Starter Camp",
			price = { gold = 0 },
			requiredFloor = 0,
			goldBonusPercent = 0,
			primaryColor = Color3.fromRGB(99, 117, 89),
			accentColor = Color3.fromRGB(211, 178, 111),
		},
		forgehold = {
			id = "forgehold",
			name = "Forgehold",
			price = { gold = 650, shards = 3 },
			requiredFloor = 2,
			goldBonusPercent = 0.08,
			primaryColor = Color3.fromRGB(122, 75, 54),
			accentColor = Color3.fromRGB(255, 148, 78),
		},
		crystalKeep = {
			id = "crystalKeep",
			name = "Crystal Keep",
			price = { gold = 1550, shards = 12 },
			requiredFloor = 3,
			goldBonusPercent = 0.16,
			primaryColor = Color3.fromRGB(64, 104, 128),
			accentColor = Color3.fromRGB(118, 231, 235),
		},
		skyCitadel = {
			id = "skyCitadel",
			name = "Sky Citadel",
			price = { gold = 3600, shards = 30 },
			requiredFloor = 5,
			goldBonusPercent = 0.27,
			primaryColor = Color3.fromRGB(84, 76, 122),
			accentColor = Color3.fromRGB(236, 216, 140),
		},
	} :: { [string]: BaseConfig },

	AssetSlots = {
		GoblinMesh = "",
		GolemMesh = "",
		DungeonWallTexture = "",
		SwordBladeTexture = "",
		BaseBannerTexture = "",
	},
}

local function deepFreeze(value: any): any
	if type(value) == "table" then
		for _, child in value do
			deepFreeze(child)
		end

		table.freeze(value)
	end

	return value
end

return deepFreeze(config)
