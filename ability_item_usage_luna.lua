----------------------------------------------------------------------------
--	Ranked Matchmaking AI v1.3 New Structure
--	Author: adamqqq		Email:adamqqq@163.com
----------------------------------------------------------------------------
--------------------------------------
-- General Initialization
--------------------------------------
local utility = require(GetScriptDirectory() .. "/utility")
local ability_item_usage_generic = require(GetScriptDirectory() .. "/ability_item_usage_generic")
local AbilityExtensions = require(GetScriptDirectory() .. "/util/AbilityAbstraction")
local A = require(GetScriptDirectory() .. "/util/MiraDota")

local debugmode = false
local npcBot = GetBot()
if npcBot == nil or npcBot:IsIllusion() then
	return
end

local Talents = {}
local Abilities = {}
local AbilitiesReal = {}

ability_item_usage_generic.InitAbility(Abilities, AbilitiesReal, Talents)

local AbilityToLevelUp =
{
	Abilities[1],
	Abilities[3],
	Abilities[1],
	Abilities[3],
	Abilities[1],
	Abilities[5],
	Abilities[1],
	Abilities[2],
	Abilities[2],
	"talent",
	Abilities[2],
	Abilities[5],
	Abilities[2],
	Abilities[3],
	"talent",
	Abilities[3],
	"nil",
	Abilities[5],
	"nil",
	"talent",
	"nil",
	"nil",
	"nil",
	"nil",
	"talent",
}
local TalentTree = {
	function()
		return Talents[1]
	end,
	function()
		return Talents[4]
	end,
	function()
		return Talents[5]
	end,
	function()
		return Talents[7]
	end
}

-- check skill build vs current level
utility.CheckAbilityBuild(AbilityToLevelUp)

function BuybackUsageThink()
	ability_item_usage_generic.BuybackUsageThink();
end

function CourierUsageThink()
	ability_item_usage_generic.CourierUsageThink();
end

function AbilityLevelUpThink()
	ability_item_usage_generic.AbilityLevelUpThink2(AbilityToLevelUp, TalentTree)
end

--------------------------------------
-- Ability Usage Thinking
--------------------------------------
local cast = {}
cast.Desire = {}
cast.Target = {}
cast.Type = {}
local Consider = {}
local CanCast = { function(t)
	return AbilityExtensions:NormalCanCast(t) and not AbilityExtensions:HasAbilityRetargetModifier(t)
end, utility.NCanCast, utility.NCanCast, AbilityExtensions.NormalCanCastFunction }
local enemyDisabled = utility.enemyDisabled

function GetComboDamage()
	return ability_item_usage_generic.GetComboDamage(AbilitiesReal)
end

function GetComboMana()
	return ability_item_usage_generic.GetComboMana(AbilitiesReal)
end

Consider[1] = function() --Target Ability Example
	local abilityNumber = 1
	--------------------------------------
	-- Generic Variable Setting
	--------------------------------------
	local ability = AbilitiesReal[abilityNumber];

	if not ability:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0;
	end

	local CastRange = ability:GetCastRange();
	local Damage = ability:GetAbilityDamage();


	local allys = npcBot:GetNearbyHeroes(1200, false, BOT_MODE_NONE);
	local enemys = npcBot:GetNearbyHeroes(CastRange + 300, true, BOT_MODE_NONE)
	local WeakestEnemy, HeroHealth = utility.GetWeakestUnit(enemys)
	local creeps = npcBot:GetNearbyCreeps(CastRange + 300, true)
	local WeakestCreep, CreepHealth = utility.GetWeakestUnit(creeps)
	--------------------------------------
	-- Global high-priorty usage
	--------------------------------------
	-- Check for a channeling enemy
	for _, npcEnemy in pairs(enemys) do
		if (npcEnemy:IsChanneling() and CanCast[abilityNumber](npcEnemy))
		then
			return BOT_ACTION_DESIRE_HIGH, npcEnemy
		end
	end

	--Try to kill enemy hero
	if (npcBot:GetActiveMode() ~= BOT_MODE_RETREAT)
	then
		if (WeakestEnemy ~= nil)
		then
			if (CanCast[abilityNumber](WeakestEnemy))
			then
				if (
					HeroHealth <= WeakestEnemy:GetActualIncomingDamage(Damage, DAMAGE_TYPE_MAGICAL) or
						(
						HeroHealth <= WeakestEnemy:GetActualIncomingDamage(GetComboDamage(), DAMAGE_TYPE_MAGICAL) and
							npcBot:GetMana() > ComboMana))
				then
					return BOT_ACTION_DESIRE_HIGH, WeakestEnemy;
				end
			end
		end
	end

	--------------------------------------
	-- Mode based usage
	--------------------------------------
	--protect myself
	local enemys2 = npcBot:GetNearbyHeroes(500, true, BOT_MODE_NONE);
	if (npcBot:WasRecentlyDamagedByAnyHero(5))
	then
		for _, npcEnemy in pairs(enemys2) do
			if (CanCast[abilityNumber](npcEnemy))
			then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy
			end
		end
	end

	-- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
	if (npcBot:GetActiveMode() == BOT_MODE_RETREAT and npcBot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH)
	then
		for _, npcEnemy in pairs(enemys) do
			if (npcBot:WasRecentlyDamagedByHero(npcEnemy, 2.0))
			then
				if (CanCast[abilityNumber](npcEnemy) and not enemyDisabled(npcEnemy))
				then
					return BOT_ACTION_DESIRE_LOW, npcEnemy;
				end
			end
		end
	end

	-- If my mana is enough,use it at enemy
	if (npcBot:GetActiveMode() ~= BOT_MODE_RETREAT)
	then
		if ((ManaPercentage > 0.65 and npcBot:GetMana() > ComboMana) and ability:GetLevel() >= 2)
		then
			if (WeakestEnemy ~= nil)
			then
				if (CanCast[abilityNumber](WeakestEnemy))
				then
					return BOT_ACTION_DESIRE_LOW, WeakestEnemy;
				end
			end
		end
	end

	-- If we're going after someone
	if (npcBot:GetActiveMode() == BOT_MODE_ROAM or
		npcBot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
		npcBot:GetActiveMode() == BOT_MODE_DEFEND_ALLY or
		npcBot:GetActiveMode() == BOT_MODE_ATTACK)
	then
		local npcEnemy = npcBot:GetTarget();

		if (npcEnemy ~= nil)
		then
			if (CanCast[abilityNumber](npcEnemy) and GetUnitToUnitDistance(npcBot, npcEnemy) < CastRange + 75 * #allys)
			then
				return BOT_ACTION_DESIRE_MODERATE, npcEnemy
			end
		end
	end


	return BOT_ACTION_DESIRE_NONE, 0;

end

Consider[5] = function()
	local abilityNumber = 5
	--------------------------------------
	-- Generic Variable Setting
	--------------------------------------
	local ability = AbilitiesReal[abilityNumber];

	if not ability:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0;
	end

	local CastRange = ability:GetCastRange() - 150;
	local singleShotDamage = AbilitiesReal[1]:GetAbilityDamage()
	local compoundDamage = singleShotDamage * (1 + ability:GetSpecialValueInt("beams"))
	local Radius = ability:GetAOERadius()

	local allys = npcBot:GetNearbyHeroes(1600, false, BOT_MODE_NONE);
	local enemys = npcBot:GetNearbyHeroes(Radius, true, BOT_MODE_NONE)
	local WeakestEnemy, HeroHealth = utility.GetWeakestUnit(enemys)
	local creeps = npcBot:GetNearbyCreeps(Radius, true)
	local WeakestCreep, CreepHealth = utility.GetWeakestUnit(creeps)

	local function IsStealing(target)
		if AbilityExtensions:ShouldNotBeAttacked(target) or A.Hero.IsTeleporting(target) then
			return false
		end
		if target:GetActualIncomingDamage(singleShotDamage * (#allys + 1), DAMAGE_TYPE_MAGICAL) >= target:GetHealth() then
			return true
		end
		return false
	end

	--------------------------------------
	-- Global high-priorty usage
	--------------------------------------
	local disabledheronum = 0
	for _, temphero in pairs(enemys) do
		if (enemyDisabled(temphero) or temphero:GetCurrentMovementSpeed() <= 200)
		then
			disabledheronum = disabledheronum + 1
		end
	end

	if (npcBot:HasScepter() or npcBot:HasModifier("modifier_item_ultimate_scepter"))
	then
		local locationAoE = npcBot:FindAoELocation(true, true, npcBot:GetLocation(), CastRange, Radius, 0, 0);
		if (locationAoE.count - #creeps >= 2)
		then
			return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc, "Location"
		end

		if (npcBot:GetActiveMode() == BOT_MODE_ATTACK)
		then
			table.insert(allys, npcBot)
			for _, npcAlly in pairs(allys) do
				local enemys2 = npcAlly:GetNearbyHeroes(Radius, false, BOT_MODE_NONE)
				local creeps2 = npcAlly:GetNearbyCreeps(Radius, true)
				if (#enemys2 + disabledheronum - #creeps >= 2)
				then
					return BOT_ACTION_DESIRE_HIGH, npcAlly, "Target"
				end
			end
		end

		-- If we're going after someone
		if (npcBot:GetActiveMode() == BOT_MODE_ROAM or
			npcBot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
			npcBot:GetActiveMode() == BOT_MODE_DEFEND_ALLY or
			npcBot:GetActiveMode() == BOT_MODE_ATTACK)
		then
			local npcEnemy = npcBot:GetTarget();
			local creeps2 = npcBot:GetNearbyCreeps(Radius, true)
			local incomingDamage = npcEnemy:GetActualIncomingDamage(compoundDamage, DAMAGE_TYPE_MAGICAL)
			if (npcEnemy ~= nil and #creeps2 <= 1)
			then
				if not (npcEnemy:GetHealth() <= incomingDamage * 0.4 and #allys >= 2) and CanCast[abilityNumber](npcEnemy) and
					(
					npcEnemy:GetHealth() <= npcEnemy:GetActualIncomingDamage(compoundDamage, DAMAGE_TYPE_MAGICAL) or
						npcEnemy:GetHealth() <= Damage) and GetUnitToUnitDistance(npcEnemy, npcBot) <= CastRange and
					not IsStealing(npcEnemy)
				then
					return BOT_ACTION_DESIRE_MODERATE, npcEnemy:GetExtrapolatedLocation(0.5), "Location"
				end
			end
		end

	else
		-- npcMostDangerousEnemy is never assigned
		-- if ( npcBot:GetActiveMode() == BOT_MODE_ATTACK )
		-- then
		-- 	if ( #enemys+disabledheronum-#creeps>=2)
		-- 	then
		-- 		if ( npcMostDangerousEnemy ~= nil )
		-- 		then
		-- 			return BOT_ACTION_DESIRE_HIGH
		-- 		end
		-- 	end
		-- end

		-- If we're going after someone

		if (npcBot:GetActiveMode() == BOT_MODE_ROAM or
			npcBot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
			npcBot:GetActiveMode() == BOT_MODE_DEFEND_ALLY or
			npcBot:GetActiveMode() == BOT_MODE_ATTACK)
		then
			local npcEnemy = AbilityExtensions:GetTargetIfGood(npcBot)

			if (npcEnemy ~= nil and #creeps <= 1)
			then
				if (
					CanCast[abilityNumber](npcEnemy) and
						(
						npcEnemy:GetHealth() <= npcEnemy:GetActualIncomingDamage(npcBot:GetOffensivePower(), DAMAGE_TYPE_MAGICAL) or
							npcEnemy:GetHealth() <= compoundDamage) and GetUnitToUnitDistance(npcEnemy, npcBot) <= Radius) and
					not IsStealing(npcEnemy)
				then
					return BOT_ACTION_DESIRE_MODERATE
				end
			end
		end

	end

	return BOT_ACTION_DESIRE_NONE;
end

AbilityExtensions:AutoModifyConsiderFunction(npcBot, Consider, AbilitiesReal)

function AbilityUsageThink()

	-- Check if we're already using an ability
	if (npcBot:IsUsingAbility() or npcBot:IsChanneling() or npcBot:IsSilenced())
	then
		return
	end

	ComboMana = GetComboMana()
	AttackRange = npcBot:GetAttackRange()
	ManaPercentage = npcBot:GetMana() / npcBot:GetMaxMana()
	HealthPercentage = npcBot:GetHealth() / npcBot:GetMaxHealth()

	cast = ability_item_usage_generic.ConsiderAbility(AbilitiesReal, Consider)
	---------------------------------debug--------------------------------------------
	if (debugmode == true)
	then
		ability_item_usage_generic.PrintDebugInfo(AbilitiesReal, cast)
	end
	ability_item_usage_generic.UseAbility(AbilitiesReal, cast)
end

function CourierUsageThink()
	ability_item_usage_generic.CourierUsageThink()
end
