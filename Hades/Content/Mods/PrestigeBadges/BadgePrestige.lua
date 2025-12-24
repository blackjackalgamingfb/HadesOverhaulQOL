ModUtil.Mod.Register("PrestiegeMod")
print("Prestiege Mod Loaded")

ModUtil.DebugCall(function()
	print("Badge Tier Totals Initialized")

	BadgeTierTotals =
	{
		[1]  = { 2, 4, 6, 8, 10 },     -- Max HP (flat)

		-- Store as TENTHS of a percent to avoid floats in saved data:
		-- 0.8% -> 8, 1.6% -> 16, ... 4.0% -> 40
		[2]  = { 8, 16, 24, 32, 40 },  -- Damage dealt (tenths of %)
		[3]  = { 6, 12, 18, 24, 30 },  -- Damage reduction (tenths of %)

		[4]  = { 2, 4, 6, 8, 10 },     -- Move speed % (whole)
		[5]  = { 2, 4, 6, 8, 10 },     -- Attack speed % (whole)

		[6]  = { 1, 2, 3, 4, 5 },      -- Attack damage % (whole)
		[7]  = { 1, 2, 3, 4, 5 },      -- Special damage % (whole)

		[8]  = { 4, 8, 12, 16, 20 },   -- Cast damage (flat)

		[9]  = { 4, 8, 12, 16, 20 },   -- Crit damage % (whole)
		[10] = { 1, 2, 3, 4, 5 },      -- Crit chance % (whole)
	}

	print("Badge Tier Totals Defined")
end)


OnAnyLoad{
	print("Initializing Badge Buff Totals on Load"),
	function()
		GameState.BadgeBuffTotals = GameState.BadgeBuffTotals or
		{
			MaxHealth       = 0,
			DamageMult      = 0, -- tenths of a percent (0.8% -> 8)
			DamageReduction = 0, -- tenths of a percent (0.6% -> 6)
			MoveSpeed       = 0, -- whole percent
			AttackSpeed     = 0, -- whole percent
			AttackDamage    = 0, -- whole percent
			SpecialDamage   = 0, -- whole percent
			CastDamage      = 0, -- flat
			CritDamage      = 0, -- whole percent
			CritChance      = 0, -- whole percent
		}
	end,
	print("Badge Buff Totals Initialized on Load")
}


local function HasAnyBadgeTotals()
	print("Checking for any badge totals")
	local t = GameState.BadgeBuffTotals
	if not t then return false end
	for _, v in pairs(t) do
		if (tonumber(v) or 0) ~= 0 then
			return true
		end
	end
	return false
end
print("HasAnyBadgeTotals function defined")


OnRunStart{
	print("Checking Badge Ledger Trait on Run Start"),
	function()
		if HasAnyBadgeTotals() and not HeroHasTrait("BadgeLedgerTrait") then
			AddTraitToHero({ TraitName = "BadgeLedgerTrait" })
		end
	end,
	print("Badge Ledger Trait checked on Run Start")
}


TraitData.BadgeLedgerTrait =
{
	print("Defining BadgeLedgerTrait"),
	Hidden = true,

	OnApply = function( trait )
		local t = GameState.BadgeBuffTotals
		if not t then return end

		local moveSpeed   = math.min(tonumber(t.MoveSpeed) or 0, 20)
		local attackSpeed = math.min(tonumber(t.AttackSpeed) or 0, 20)

		AddTraitPropertyChange(trait, { Property = "MaxHealth", BaseValue = tonumber(t.MaxHealth) or 0, ChangeType = "Add" })

		-- DamageMult / DamageReduction are stored as tenths-of-% integers, so divide by 1000 here:
		-- 8 -> 0.008 -> +0.8%
		AddTraitPropertyChange(trait, { Property = "DamageMultiplier", BaseValue = (tonumber(t.DamageMult) or 0) / 1000, ChangeType = "Add" })
		AddTraitPropertyChange(trait, { Property = "DamageReduction", BaseValue = (tonumber(t.DamageReduction) or 0) / 1000, ChangeType = "Add" })

		AddTraitPropertyChange(trait, { Property = "MoveSpeed", BaseValue = moveSpeed / 100, ChangeType = "Add" })
		AddTraitPropertyChange(trait, { Property = "AttackSpeed", BaseValue = attackSpeed / 100, ChangeType = "Add" })

		AddTraitPropertyChange(trait, { Property = "AttackDamageMultiplier", BaseValue = (tonumber(t.AttackDamage) or 0) / 100, ChangeType = "Add" })
		AddTraitPropertyChange(trait, { Property = "SpecialDamageMultiplier", BaseValue = (tonumber(t.SpecialDamage) or 0) / 100, ChangeType = "Add" })

		AddTraitPropertyChange(trait, { Property = "CastDamage", BaseValue = tonumber(t.CastDamage) or 0, ChangeType = "Add" })

		AddTraitPropertyChange(trait, { Property = "CritDamage", BaseValue = (tonumber(t.CritDamage) or 0) / 100, ChangeType = "Add" })
		AddTraitPropertyChange(trait, { Property = "CritChance", BaseValue = (tonumber(t.CritChance) or 0) / 100, ChangeType = "Add" })
	end,
	print("BadgeLedgerTrait defined")
}


function ApplyBadgeTierDelta( newBadgeRank )
	print("Applying Badge Tier Delta for new rank: " .. tostring(newBadgeRank))

	newBadgeRank = tonumber(newBadgeRank) or 0
	if newBadgeRank <= 0 then
		return
	end

	local rankIndex = math.ceil(newBadgeRank / 5)
	local tierIndex = ((newBadgeRank - 1) % 5) + 1

	local tierTotals = BadgeTierTotals and BadgeTierTotals[rankIndex]
	if not tierTotals then
		return
	end

	local previous = (tierIndex > 1 and tierTotals[tierIndex - 1]) or 0
	local current  = tierTotals[tierIndex] or 0
	local delta    = current - previous
	if delta <= 0 then
		return
	end

	print("Applying delta of " .. tostring(delta) .. " to rank index " .. tostring(rankIndex))

	local totals = GameState and GameState.BadgeBuffTotals
	if not totals then
		return
	end

	if rankIndex == 1 then
		totals.MaxHealth = (tonumber(totals.MaxHealth) or 0) + delta
	elseif rankIndex == 2 then
		totals.DamageMult = (tonumber(totals.DamageMult) or 0) + delta
	elseif rankIndex == 3 then
		totals.DamageReduction = (tonumber(totals.DamageReduction) or 0) + delta
	elseif rankIndex == 4 then
		totals.MoveSpeed = (tonumber(totals.MoveSpeed) or 0) + delta
	elseif rankIndex == 5 then
		totals.AttackSpeed = (tonumber(totals.AttackSpeed) or 0) + delta
	elseif rankIndex == 6 then
		totals.AttackDamage = (tonumber(totals.AttackDamage) or 0) + delta
	elseif rankIndex == 7 then
		totals.SpecialDamage = (tonumber(totals.SpecialDamage) or 0) + delta
	elseif rankIndex == 8 then
		totals.CastDamage = (tonumber(totals.CastDamage) or 0) + delta
	elseif rankIndex == 9 then
		totals.CritDamage = (tonumber(totals.CritDamage) or 0) + delta
	elseif rankIndex == 10 then
		totals.CritChance = (tonumber(totals.CritChance) or 0) + delta
	end

	print("Badge Tier Delta Applied")
end


ModUtil.Path.Wrap("UseBadgeSeller", function(base, usee, args)
	print("Using Badge Seller")
	local oldRank = tonumber(GameState.BadgeRank) or 0

	-- run vanilla purchase logic (spends resources, increments BadgeRank, plays presentation, etc.)
	base(usee, args)

	local newRank = tonumber(GameState.BadgeRank) or 0
	if newRank > oldRank then
		ApplyBadgeTierDelta(newRank)

		-- optional: if you want perks to kick in immediately without waiting for next run
		if CurrentRun and CurrentRun.Hero and HasAnyBadgeTotals() and not HeroHasTrait("BadgeLedgerTrait") then
			AddTraitToHero({ TraitName = "BadgeLedgerTrait" })
		end

		print("Badge Seller used and Badge Rank updated")
	else
		print("Badge Seller used but Badge Rank did not change")
	end

	print("Badge Seller use complete")
end)