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
	Abilities[2],
	Abilities[1],
	Abilities[5],
	Abilities[1],
	Abilities[3],
	Abilities[3],
	"talent",
	Abilities[3],
	Abilities[5],
	Abilities[2],
	Abilities[2],
	"talent",
	Abilities[2],
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
		return Talents[2]
	end,
	function()
		return Talents[3]
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
local CanCast = { utility.NCanCast, AbilityExtensions.PhysicalCanCastFunction, utility.NCanCast, function(t)
	return AbilityExtensions:NormalCanCast(t, false, DAMAGE_TYPE_PURE, true, false) and not A.Unit.IsNotCreepHero(t)
end }
local enemyDisabled = utility.enemyDisabled

function GetComboDamage()
	return ability_item_usage_generic.GetComboDamage(AbilitiesReal)
end

function GetComboMana()
	return ability_item_usage_generic.GetComboMana(AbilitiesReal)
end

Consider[1] = function()

	local abilityNumber = 1
	--------------------------------------
	-- Generic Variable Setting
	--------------------------------------
	local ability = AbilitiesReal[abilityNumber];

	if not ability:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0;
	end

	local CastRange = ability:GetCastRange();
	local Damage = ability:GetSpecialValueInt("duration") * ability:GetSpecialValueInt("damage")
	local Radius = ability:GetAOERadius()


	local allys = npcBot:GetNearbyHeroes(1200, false, BOT_MODE_NONE);
	local enemys = npcBot:GetNearbyHeroes(CastRange + Radius, true, BOT_MODE_NONE)
	local WeakestEnemy, HeroHealth = utility.GetWeakestUnit(enemys)
	local creeps = npcBot:GetNearbyCreeps(CastRange + Radius, true)
	local WeakestCreep, CreepHealth = utility.GetWeakestUnit(creeps)

	--------------------------------------
	-- Global high-priorty usage
	--------------------------------------
	--try to kill enemy hero
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
					return BOT_ACTION_DESIRE_HIGH, utility.GetUnitsTowardsLocation(WeakestEnemy, npcBot, Radius / 2);
				end
			end
		end
	end
	--------------------------------------
	-- Mode based usage
	--------------------------------------
	-- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
	if (npcBot:GetActiveMode() == BOT_MODE_RETREAT and npcBot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH)
	then
		for _, npcEnemy in pairs(enemys) do
			if (npcBot:WasRecentlyDamagedByHero(npcEnemy, 2.0))
			then
				if (CanCast[abilityNumber](npcEnemy))
				then
					return BOT_ACTION_DESIRE_MODERATE, utility.GetUnitsTowardsLocation(npcEnemy, npcBot, Radius / 2);
				end
			end
		end
	end

	if (npcBot:GetActiveMode() == BOT_MODE_ATTACK or
		npcBot:GetActiveMode() == BOT_MODE_LANING)
	then
		if (ManaPercentage > 0.4 or npcBot:GetMana() > ComboMana)
		then
			local locationAoE = npcBot:FindAoELocation(true, true, npcBot:GetLocation(), CastRange, Radius, 0, 0);
			if (locationAoE.count >= 2) then
				return BOT_ACTION_DESIRE_MODERATE - 0.01, locationAoE.targetloc;
			end
		end
	end

	-- If we're pushing or defending a lane and can hit 4+ creeps, go for it
	if (npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_TOP or
		npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_MID or
		npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_BOT or
		npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_TOP or
		npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_MID or
		npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_BOT)
	then
		local locationAoE = npcBot:FindAoELocation(true, false, npcBot:GetLocation(), CastRange, Radius, 0, 0);

		if (locationAoE.count >= 4)
		then
			return BOT_ACTION_DESIRE_MODERATE - 0.02, locationAoE.targetloc;
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
			if (CanCast[abilityNumber](npcEnemy) and GetUnitToUnitDistance(npcBot, npcEnemy) <= CastRange + Radius)
			then
				return BOT_ACTION_DESIRE_MODERATE - 0.03, utility.GetUnitsTowardsLocation(npcEnemy, npcBot, Radius / 2);
			end
		end
	end

	if (npcBot:GetActiveMode() == BOT_MODE_LANING)
	then
		if ((ManaPercentage > 0.4 or npcBot:GetMana() > ComboMana) and ability:GetLevel() >= 2)
		then
			if (WeakestEnemy ~= nil)
			then
				if (CanCast[abilityNumber](WeakestEnemy))
				then
					return BOT_ACTION_DESIRE_LOW, utility.GetUnitsTowardsLocation(WeakestEnemy, npcBot, Radius / 2);
				end
			end
		end
	end

	-- If we're farming and can kill 3+ creeps
	if (npcBot:GetActiveMode() == BOT_MODE_FARM) then
		local locationAoE = npcBot:FindAoELocation(true, false, npcBot:GetLocation(), CastRange, Radius, 0, 0);

		if (locationAoE.count >= 3) then
			return BOT_ACTION_DESIRE_LOW, locationAoE.targetloc;
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0;

end


Consider[2] = function()
	local abilityNumber = 2
	--------------------------------------
	-- Generic Variable Setting
	--------------------------------------
	local ability = AbilitiesReal[abilityNumber]

	if not ability:IsFullyCastable() or AbilityExtensions:IsPhysicalOutputDisabled(npcBot) then
		return 0
	end

	local CastRange = ability:GetCastRange()
	local enemys = npcBot:GetNearbyHeroes(CastRange + 100, true, BOT_MODE_NONE)
	local WeakestEnemy, HeroHealth = utility.GetWeakestUnit(enemys)

	local function UseAt(target)
		if not CanCast[abilityNumber](target) then
			return false
		end
		if AbilityExtensions:IsAttackingEnemies(npcBot) and npcBot:WasRecentlyDamagedByAnyHero(1) then
			return false
		end
		if target:IsHero() then
			if AbilityExtensions:MustBeIllusion(npcBot, target) then
				return AbilityExtensions:GetManaPercent(npcBot) >= 0.8 or AbilityExtensions:GetHealthPercent(target) <= 0.4
			else
				return true
			end
		elseif target:IsBuilding() then
			return false
		else
			return AbilityExtensions:GetManaPercent(npcBot) >= 0.8
		end
	end

	local attackRange = npcBot:GetAttackRange()
	if AbilityExtensions:NotRetreating(npcBot) then
		if npcBot:GetActiveMode() == BOT_MODE_LANING then
			local creeps = npcBot:GetNearbyLaneCreeps(attackRange + 120, true)
			local allyCreeps = npcBot:GetNearbyLaneCreeps(attackRange + 120, false)
			if creeps and #creeps > 0 or allyCreeps and #allyCreeps > 0 then
				return false
			end
		end

		local target = npcBot:GetAttackTarget() or npcBot:GetTarget()
		if target == nil then
			if WeakestEnemy ~= nil then
				local b = UseAt(WeakestEnemy)
				if b then
					return BOT_ACTION_DESIRE_HIGH, WeakestEnemy
				else
					return false
				end
			end
		else
			return UseAt(target)
		end
	end
	return false
end
Consider[2] = AbilityExtensions:ToggleFunctionToAutoCast(npcBot, AbilitiesReal[2], Consider[2])

Consider[3] = function()
	local abilityNumber = 3
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

	-- If we're in a teamfight, use it on the scariest enemy
	local tableNearbyAttackingAlliedHeroes = npcBot:GetNearbyHeroes(1000, false, BOT_MODE_ATTACK);
	if (#tableNearbyAttackingAlliedHeroes >= 2)
	then

		local npcMostDangerousEnemy = nil;
		local nMostDangerousDamage = 0;

		for _, npcEnemy in pairs(enemys) do
			if (CanCast[abilityNumber](npcEnemy))
			then
				local Damage2 = npcEnemy:GetEstimatedDamageToTarget(false, npcBot, 3.0, DAMAGE_TYPE_ALL);
				if (Damage2 > nMostDangerousDamage)
				then
					nMostDangerousDamage = Damage2;
					npcMostDangerousEnemy = npcEnemy;
				end
			end
		end

		if (npcMostDangerousEnemy ~= nil)
		then
			return BOT_ACTION_DESIRE_HIGH, npcMostDangerousEnemy;
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
				if (CanCast[abilityNumber](npcEnemy))
				then
					return BOT_ACTION_DESIRE_HIGH, npcEnemy;
				end
			end
		end
	end

	-- If my mana is enough,use it at enemy
	if (npcBot:GetActiveMode() == BOT_MODE_LANING)
	then
		if ((ManaPercentage > 0.4 or npcBot:GetMana() > ComboMana) and ability:GetLevel() >= 2)
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

	-- If we're pushing or defending a lane
	if (npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_TOP or
		npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_MID or
		npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_BOT or
		npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_TOP or
		npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_MID or
		npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_BOT)
	then
		if (#enemys >= 1)
		then
			if (ManaPercentage > 0.5 or npcBot:GetMana() > ComboMana)
			then
				if (WeakestEnemy ~= nil)
				then
					if (CanCast[abilityNumber](WeakestEnemy) and GetUnitToUnitDistance(npcBot, WeakestEnemy) < CastRange + 75 * #allys)
					then
						return BOT_ACTION_DESIRE_LOW, WeakestEnemy;
					end
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

	local CastRange = ability:GetCastRange();
	local Damage = 0
	local Radius = ability:GetAOERadius()


	local allys = npcBot:GetNearbyHeroes(1200, false, BOT_MODE_NONE);
	local enemys = AbilityExtensions:GetNearbyNonIllusionHeroes(npcBot, 1200, true, BOT_MODE_NONE)
	local WeakestEnemy, HeroHealth = utility.GetWeakestUnit(enemys)

	-- Check for a channeling enemy
	for _, npcEnemy in pairs(enemys) do
		if AbilityExtensions:IsChannelingBreakWorthAbility(npcEnemy, "moderate") and CanCast[abilityNumber](npcEnemy) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end

	-- If we're in a teamfight, use it on the scariest enemy
	if (npcBot:GetActiveMode() == BOT_MODE_ROAM or
		npcBot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
		npcBot:GetActiveMode() == BOT_MODE_DEFEND_ALLY or
		npcBot:GetActiveMode() == BOT_MODE_ATTACK)
	then
		if (#allys + #enemys >= 5)
		then
			local npcMostDangerousEnemy = nil;
			local nMostDangerousDamage = 0;

			for _, npcEnemy in pairs(enemys) do
				local Damage = npcEnemy:GetEstimatedDamageToTarget(false, npcBot, 3.0, DAMAGE_TYPE_ALL);
				if (Damage > nMostDangerousDamage)
				then
					nMostDangerousDamage = Damage;
					npcMostDangerousEnemy = npcEnemy;
				end
			end

			if (npcMostDangerousEnemy ~= nil)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0;
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
