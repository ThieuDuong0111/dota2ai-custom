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
local ItemUsage = require(GetScriptDirectory() .. "/util/ItemUsage-New")

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
	Abilities[2],
	Abilities[1],
	Abilities[3],
	Abilities[1],
	Abilities[2],
	Abilities[5],
	Abilities[2],
	Abilities[2],
	Abilities[1],
	"talent",
	Abilities[1],
	Abilities[5],
	Abilities[3],
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
local CanCast = { utility.NCanCast, utility.NCanCast, utility.NCanCast, utility.UCanCast }
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
			if (
				HeroHealth <= WeakestEnemy:GetActualIncomingDamage(GetComboDamage(), DAMAGE_TYPE_PHYSICAL) and
					npcBot:GetMana() > ComboMana)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end

	--------------------------------------
	-- Mode based usage
	--------------------------------------
	--protect myself
	if (npcBot:WasRecentlyDamagedByAnyHero(2) or npcBot:GetActiveMode() == BOT_MODE_RETREAT)
	then
		return BOT_ACTION_DESIRE_HIGH
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
			return BOT_ACTION_DESIRE_MODERATE
		end
	end

	-- If we're farming
	if (npcBot:GetActiveMode() == BOT_MODE_FARM)
	then
		if (#creeps == 0)
		then
			return BOT_ACTION_DESIRE_LOW
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0;

end

Consider[2] = function()
	local abilityNumber = 2
	--------------------------------------
	-- Generic Variable Setting
	--------------------------------------
	local ability = AbilitiesReal[abilityNumber];

	if not ability:IsFullyCastable() or AbilityExtensions:CannotMove(npcBot) then
		return BOT_ACTION_DESIRE_NONE, 0;
	end

	local CastRange = ability:GetCastRange()
	local Damage = ability:GetAbilityDamage()
	local Radius = ability:GetAOERadius() - 50
	local CastPoint = ability:GetCastPoint()

	local blink = AbilityExtensions:GetAvailableBlink(npcBot)
	if (blink ~= nil and blink:IsFullyCastable())
	then
		CastRange = CastRange + 1200
		if (npcBot:GetActiveMode() == BOT_MODE_ATTACK)
		then
			local locationAoE = npcBot:FindAoELocation(true, true, npcBot:GetLocation(), CastRange, Radius, 0, 0);
			if (locationAoE.count >= 2)
			then
				ItemUsage.UseItemOnLocation(npcBot, blink, locationAoE.targetloc);
				return 0
			end
		end
	end


	local allys = npcBot:GetNearbyHeroes(1200, false, BOT_MODE_NONE);
	local enemys = npcBot:GetNearbyHeroes(Radius, true, BOT_MODE_NONE)
	local WeakestEnemy, HeroHealth = utility.GetWeakestUnit(enemys)
	local creeps = npcBot:GetNearbyCreeps(Radius + 300, true)
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
					HeroHealth <= WeakestEnemy:GetActualIncomingDamage(Damage, DAMAGE_TYPE_PHYSICAL) and
						GetUnitToUnitDistance(npcBot, WeakestEnemy) <= Radius - CastPoint * WeakestEnemy:GetCurrentMovementSpeed())
				then
					return BOT_ACTION_DESIRE_HIGH, WeakestEnemy
				end
			end
		end
	end
	--------------------------------------
	-- Mode based usage
	--------------------------------------
	--protect myself
	if ((npcBot:WasRecentlyDamagedByAnyHero(2) and #enemys >= 1) or #enemys >= 2)
	then
		for _, npcEnemy in pairs(enemys) do
			if (CanCast[abilityNumber](npcEnemy))
			then
				return BOT_ACTION_DESIRE_HIGH, "immediately"
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
					if (GetUnitToUnitDistance(npcBot, WeakestEnemy) < Radius - CastPoint * WeakestEnemy:GetCurrentMovementSpeed())
					then
						return BOT_ACTION_DESIRE_LOW, WeakestEnemy
					end
				end
			end
		end
	end

	-- If we're farming and can hit 2+ creeps
	if (npcBot:GetActiveMode() == BOT_MODE_FARM)
	then
		if (#creeps >= 2)
		then
			if (
				CreepHealth <= WeakestCreep:GetActualIncomingDamage(Damage, DAMAGE_TYPE_PHYSICAL) and npcBot:GetMana() > ComboMana
				)
			then
				return BOT_ACTION_DESIRE_LOW, WeakestCreep
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
			if (
				CanCast[abilityNumber](npcEnemy) and not enemyDisabled(npcEnemy) and
					GetUnitToUnitDistance(npcBot, npcEnemy) <= Radius - CastPoint * npcEnemy:GetCurrentMovementSpeed())
			then
				return BOT_ACTION_DESIRE_MODERATE, npcEnemy
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0
end

local function CorrosiveHazeRemainingDurationLessThan(target, time)
	return AbilityExtensions:GetMagicImmuneRemainingDuration(target, "modifier_slardar_amplify_damage") <= time
end

Consider[5] = function()
    local abilityNumber = 5
	--------------------------------------
	-- Generic Variable Setting
	--------------------------------------
    local ability = AbilitiesReal[abilityNumber]
    if not ability:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE
    end
    local CastRange = Clamp(ability:GetCastRange(), 0, 1599)
    local realEnemies = fun1:GetNearbyNonIllusionHeroes(npcBot, CastRange):Filter(function(it)
        return fun1:SpellCanCast(it) and it:IsHero() and fun1:MayNotBeIllusion(npcBot, it) and A.Unit.IsNotCreepHero(it)
    end):Map(function(it)
        return {
            it,
            it:GetHealth() * HasTrackModifierPenalty(it),
        }
    end):SortByMinFirst(function(it)
        return it[2]
    end)
    do
        local t = realEnemies:First()
        if t then
            local target = t[1]
            if fun1:IsFarmingOrPushing(npcBot) or npcBot:GetActiveMode() == BOT_MODE_LANING then
                if ManaPercentage >= 0.7 then
                    return BOT_ACTION_DESIRE_MODERATE, target
                end
                if fun1:GetHealthPercent(target) <= 0.5 then
                    return BOT_ACTION_DESIRE_HIGH, target
                end
            else
                return BOT_ACTION_DESIRE_HIGH, target
            end
        end
    end
    do
        local target = fun1:GetTargetIfGood(npcBot)
        if target and target:GetTeam() ~= npcBot:GetTeam() and A.Unit.IsNotCreepHero(target) then
            return BOT_ACTION_DESIRE_HIGH, target
        end
    end
    return BOT_ACTION_DESIRE_NONE
end

AbilityExtensions:AutoModifyConsiderFunction(npcBot, Consider, AbilitiesReal)

local crushLosingTarget

function AbilityUsageThink()

	-- Check if we're already using an ability
	if npcBot:IsUsingAbility() or npcBot:IsChanneling() or npcBot:IsSilenced() then
		if npcBot:IsCastingAbility() then
			if npcBot:GetCurrentActiveAbility() == AbilitiesReal[2] then
				if not AbilityExtensions:IsFarmingOrPushing(npcBot) then
					local nearbyEnemies = AbilityExtensions:GetNearbyEnemyUnits(npcBot, AbilitiesReal[2]:GetAOERadius() + 90)
					if AbilityExtensions:Count(nearbyEnemies, CanCast[1]) == 0 then
						if crushLosingTarget == nil then
							crushLosingTarget = DotaTime()
						elseif DotaTime() - crushLosingTarget > 0.15 then
							npcBot:Action_ClearActions(true)
						end
						return
					end
				end
			end
		end
		crushLosingTarget = nil
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
