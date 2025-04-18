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
	Abilities[2],
	Abilities[1],
	Abilities[3],
	Abilities[1],
	Abilities[6],
	Abilities[1],
	Abilities[2],
	Abilities[3],
	"talent",
	Abilities[3],
	Abilities[6],
	Abilities[3],
	Abilities[2],
	"talent",
	Abilities[2],
	"nil",
	Abilities[6],
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
		return Talents[6]
	end,
	function()
		return Talents[8]
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
local CanCast = { AbilityExtensions.NormalCanCastFunction, utility.NCanCast, function(t)
	return AbilityExtensions:StunCanCast(t, AbilitiesReal[3], false, true, true, false)
end, utility.NCanCast }
local enemyDisabled = utility.enemyDisabled

function GetComboDamage()
	return ability_item_usage_generic.GetComboDamage(AbilitiesReal)
end

function GetComboMana()
	return ability_item_usage_generic.GetComboMana(AbilitiesReal)
end

function GetMostDangerousEnemy(range, funNpcFilter)
	local npcMostDangerousEnemy = nil;
	local nMostDangerousDamage = 0;

	local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes(range, true, BOT_MODE_NONE);
	for _, npcEnemy in pairs(tableNearbyEnemyHeroes) do
		if (funNpcFilter(npcEnemy) and not npcEnemy:IsSilenced())
		then
			local Damage = npcEnemy:GetEstimatedDamageToTarget(false, npcBot, 3.0, DAMAGE_TYPE_ALL);
			if (Damage > nMostDangerousDamage)
			then
				nMostDangerousDamage = Damage;
				npcMostDangerousEnemy = npcEnemy;
			end
		end
	end

	return npcMostDangerousEnemy
end

-- skywrath_mage_arcane_bolt
Consider[1] = function()

	local ability = AbilitiesReal[1];

	if not ability:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0;
	end

	local CastRange = ability:GetCastRange();
	local Damage = ability:GetAbilityDamage();
	local castPoint = ability:GetCastPoint()

	local allys = npcBot:GetNearbyHeroes(1200, false, BOT_MODE_NONE);
	local enemys = npcBot:GetNearbyHeroes(CastRange + 300, true, BOT_MODE_NONE)
	local WeakestEnemy, HeroHealth = utility.GetWeakestUnit(enemys)
	local creeps = npcBot:GetNearbyCreeps(CastRange + 300, true)
	local WeakestCreep, CreepHealth = utility.GetWeakestUnit(creeps)

	--try to kill enemy hero
	if (npcBot:GetActiveMode() ~= BOT_MODE_RETREAT)
	then
		if (WeakestEnemy ~= nil)
		then
			if (CanCast[1](WeakestEnemy))
			then
				if (
					HeroHealth <= WeakestEnemy:GetActualIncomingDamage(Damage, DAMAGE_TYPE_MAGICAL) * 3 or
						(
						HeroHealth <= WeakestEnemy:GetActualIncomingDamage(GetComboDamage(), DAMAGE_TYPE_MAGICAL) and
							npcBot:GetMana() > ComboMana))
				then
					npcBot:SetTarget(WeakestEnemy)
					return BOT_ACTION_DESIRE_HIGH, WeakestEnemy;
				end
			end
		end
	end

	--protect myself
	if A.Unit.IsAttackingEnemies(npcBot) or A.Unit.IsRetreating(npcBot) then
		local enemyAttackingMe = A.Dota.GetNearbyHeroes(npcBot, CastRange - castPoint * 300)
			:First(function(t) return t:GetActualIncomingDamage(Damage, DAMAGE_TYPE_MAGICAL) * 6 <= t:GetHealth() and
					CanCast[1](t)
			end)
		if enemyAttackingMe then
			return BOT_ACTION_DESIRE_MODERATE + 0.15, enemyAttackingMe
		end
	end

	--消耗
	--if ( npcBot:GetActiveMode() == BOT_MODE_LANING )
	--then
	if ((ManaPercentage > 0.4 or npcBot:GetMana() > ComboMana) and ability:GetLevel() >= 1)
	then
		if (WeakestEnemy ~= nil)
		then
			if (CanCast[1](WeakestEnemy))
			then
				return BOT_ACTION_DESIRE_LOW, WeakestEnemy
			end
		end
	end
	--end

	-- If we're pushing or defending a lane
	if (npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_TOP or
		npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_MID or
		npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_BOT or
		npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_TOP or
		npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_MID or
		npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_BOT)
	then
		if (WeakestEnemy ~= nil)
		then
			if (CanCast[1](WeakestEnemy) and GetUnitToUnitDistance(npcBot, WeakestEnemy) < CastRange + 75 * #allys)
			then
				return BOT_ACTION_DESIRE_LOW, WeakestEnemy
			end
		end
	end

	-- If we're going after someone
	if (npcBot:GetActiveMode() == BOT_MODE_ROAM or
		npcBot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
		npcBot:GetActiveMode() == BOT_MODE_DEFEND_ALLY or
		npcBot:GetActiveMode() == BOT_MODE_ATTACK)
	then
		local npcTarget = npcBot:GetTarget();

		if (npcTarget ~= nil)
		then
			if (CanCast[1](npcTarget) and GetUnitToUnitDistance(npcBot, npcTarget) < CastRange + 75 * #allys)
			then
				return BOT_ACTION_DESIRE_MODERATE, npcTarget
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0
end

-- skywrath_mage_concussive_shot
Consider[2] = function()

	local ability = AbilitiesReal[2];

	if not ability:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0;
	end

	local CastRange = ability:GetCastRange();
	local Damage = ability:GetAbilityDamage();


	local allys = npcBot:GetNearbyHeroes(1200, false, BOT_MODE_NONE);
	local enemys = npcBot:GetNearbyHeroes(CastRange + 0, true, BOT_MODE_NONE)
	local WeakestEnemy, HeroHealth = utility.GetWeakestUnit(enemys)

	--try to kill enemy hero
	if (npcBot:GetActiveMode() ~= BOT_MODE_RETREAT)
	then
		if (WeakestEnemy ~= nil)
		then
			if (CanCast[2](WeakestEnemy))
			then
				if (
					HeroHealth <= WeakestEnemy:GetActualIncomingDamage(Damage, DAMAGE_TYPE_MAGICAL) or
						(
						HeroHealth <= WeakestEnemy:GetActualIncomingDamage(GetComboDamage(), DAMAGE_TYPE_MAGICAL) and
							npcBot:GetMana() > ComboMana))
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end

	-- If a mode has set a target, and we can kill them, do it
	local npcTarget = npcBot:GetTarget();
	if (npcTarget ~= nil and CanCast[2](npcTarget))
	then
		if (GetComboDamage() > npcTarget:GetHealth())
		then
			return BOT_ACTION_DESIRE_HIGH;
		end
	end

	--protect myself
	if (npcBot:WasRecentlyDamagedByAnyHero(5) and npcBot:GetActiveMode() == BOT_MODE_RETREAT)
	then
		for _, enemy in pairs(enemys) do
			if (CanCast[2](enemy))
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end

	-- If we're going after someone
	if (npcBot:GetActiveMode() == BOT_MODE_ROAM or
		npcBot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
		npcBot:GetActiveMode() == BOT_MODE_DEFEND_ALLY or
		npcBot:GetActiveMode() == BOT_MODE_ATTACK)
	then
		local npcTarget = npcBot:GetTarget();

		if (npcTarget ~= nil)
		then
			if (CanCast[2](npcTarget) and GetUnitToUnitDistance(npcBot, npcTarget) < CastRange)
			then
				return BOT_ACTION_DESIRE_MODERATE
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE

end



-- skywrath_mage_ancient_seal
Consider[3] = function()

	local ability = AbilitiesReal[3];

	if not ability:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0;
	end

	local CastRange = ability:GetCastRange();
	local Damage = ability:GetAbilityDamage();


	local allys = npcBot:GetNearbyHeroes(1200, false, BOT_MODE_NONE);
	local enemys = npcBot:GetNearbyHeroes(CastRange + 300, true, BOT_MODE_NONE)
	local WeakestEnemy, HeroHealth = utility.GetWeakestUnit(enemys)

	-- Check for a channeling enemy
	for _, enemy in pairs(enemys) do
		if (enemy:IsChanneling() and CanCast[3](enemy) and not enemy:IsSilenced())
		then
			return BOT_ACTION_DESIRE_HIGH, enemy
		end
	end

	--try to kill enemy hero
	if (npcBot:GetActiveMode() ~= BOT_MODE_RETREAT)
	then
		if (WeakestEnemy ~= nil)
		then
			if (CanCast[3](WeakestEnemy))
			then
				if (
					(
						HeroHealth <= WeakestEnemy:GetActualIncomingDamage(GetComboDamage(), DAMAGE_TYPE_MAGICAL) and
							npcBot:GetMana() > ComboMana))
				then
					return BOT_ACTION_DESIRE_HIGH, WeakestEnemy;
				end
			end
		end
	end

	-- If running, try to silence an attacker
	if (npcBot:WasRecentlyDamagedByAnyHero(2.5) and A.Unit.IsRetreating(npcBot))
	then
		-- lower cast range a bit to make sure we don't chase
		local adjustedRange = CastRange - 100
		local npcMostDangerousEnemy = GetMostDangerousEnemy(adjustedRange, CanCast[3])
		if npcMostDangerousEnemy ~= nil then
			return BOT_ACTION_DESIRE_HIGH, npcMostDangerousEnemy
		end
	end

	-- If a mode has set a target, and we can kill them, do it
	local npcTarget = A.Unit.GetHeroTarget(npcBot)
	if npcTarget and (CanCast[3](npcTarget)) then
		if GetUnitToUnitDistance(npcTarget, npcBot) < (CastRange + 200)
		then
			return BOT_ACTION_DESIRE_MODERATE - 0.05, npcTarget
		end
	end

	-- If we're in a teamfight, use it on the scariest enemy
	local tableNearbyAttackingAlliedHeroes = npcBot:GetNearbyHeroes(1000, false, BOT_MODE_ATTACK);
	if (#tableNearbyAttackingAlliedHeroes >= 1)
	then
		local npcMostDangerousEnemy = GetMostDangerousEnemy(CastRange, CanCast[3])
		if (npcMostDangerousEnemy ~= nil)
		then
			return BOT_ACTION_DESIRE_HIGH, npcMostDangerousEnemy;
		end
	end


	return BOT_ACTION_DESIRE_NONE, 0
end

-- 7.30 new ability shield of the scion (passive)

-- skywrath_mage_mystic_flare
Consider[6] = function()

	local ability = AbilitiesReal[6]

	if not ability:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0;
	end

	local CastRange = ability:GetCastRange();
	local Damage = ability:GetAbilityDamage();


	local allys = npcBot:GetNearbyHeroes(1200, false, BOT_MODE_NONE);
	local enemys = npcBot:GetNearbyHeroes(CastRange + 300, true, BOT_MODE_NONE)
	local WeakestEnemy, HeroHealth = utility.GetWeakestUnit(enemys)


	-- If a mode has set a target, and we can kill them, do it
	local npcTarget = AbilityExtensions:GetTargetIfGood(npcBot)
	if (npcTarget ~= nil and CanCast[4](npcTarget))
	then
		if (
			GetComboDamage() > npcTarget:GetHealth() and GetUnitToUnitDistance(npcTarget, npcBot) < (CastRange + 200) and
				(
				enemyDisabled(npcTarget) or
					(npcTarget:IsSilenced() and npcTarget:HasModifier("modifier_skywrath_mage_concussive_shot_slow"))))
		then
			return BOT_ACTION_DESIRE_HIGH, npcTarget:GetExtrapolatedLocation(0.5)
		end
	end

	-- If we're in a teamfight, use it on the scariest enemy
	local tableNearbyAttackingAlliedHeroes = npcBot:GetNearbyHeroes(1000, false, BOT_MODE_ATTACK);
	if (#tableNearbyAttackingAlliedHeroes >= 2)
	then

		local npcMostDangerousEnemy = nil;
		local nMostDangerousDamage = 0;

		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes(CastRange, true, BOT_MODE_NONE);
		for _, npcEnemy in pairs(tableNearbyEnemyHeroes) do
			if (
				CanCast[4](npcEnemy) and
					(
					enemyDisabled(npcEnemy) or
						(npcEnemy:IsSilenced() and npcEnemy:HasModifier("modifier_skywrath_mage_concussive_shot_slow"))))
			then
				local Damage = npcEnemy:GetEstimatedDamageToTarget(false, npcBot, 3.0, DAMAGE_TYPE_ALL);
				if (Damage > nMostDangerousDamage)
				then
					nMostDangerousDamage = Damage;
					npcMostDangerousEnemy = npcEnemy;
				end
			end
		end

		if (npcMostDangerousEnemy ~= nil)
		then
			return BOT_ACTION_DESIRE_HIGH, npcMostDangerousEnemy:GetExtrapolatedLocation(0.5)
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0

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
