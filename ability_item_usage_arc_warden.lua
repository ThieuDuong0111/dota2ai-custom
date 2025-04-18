----------------------------------------------------------------------------
--  Ranked Matchmaking AI v1.1 NewStructure
--  Author: adamqqq		Email:adamqqq@163.com
----------------------------------------------------------------------------
--------------------------------------
-- General Initialization
--------------------------------------
if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or
    GetBot():IsIllusion() then
    return
end
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
local AbilityToLevelUp = {
    Abilities[3],
    Abilities[1],
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
        return Talents[1]
    end,
    function()
        return Talents[3]
    end,
    function()
        return Talents[6]
    end,
    function()
        return Talents[7]
    end,
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
function CanCast1(npcTarget)
    if npcTarget == nil or npcTarget:CanBeSeen() == false then
        return utility.NCanCast(npcTarget)
    end
    local enemys = npcTarget:GetNearbyCreeps(150, false)
    local enemys2 = npcTarget:GetNearbyHeroes(150, false, BOT_MODE_NONE)
    if enemys ~= nil and enemys2 ~= nil and #enemys == 0 and #enemys2 == 0 then
        return utility.NCanCast(npcTarget)
    end
    return utility.NCanCast(npcTarget)
end

local cast = {}
cast.Desire = {}
cast.Target = {}
cast.Type = {}
local Consider = {}
local CanCast = {
    CanCast1,
    utility.NCanCast,
    utility.NCanCast,
    utility.UCanCast,
}
local enemyDisabled = utility.enemyDisabled
function GetComboDamage()
    return ability_item_usage_generic.GetComboDamage(AbilitiesReal)
end

function GetComboMana()
    return ability_item_usage_generic.GetComboMana(AbilitiesReal)
end

local health
local maxHealth
local healthPercent
local mana
local maxMana
local manaPercent
Consider[1] = function()
    local abilityNumber = 1
    --------------------------------------
    -- Generic Variable Setting
    --------------------------------------
    local ability = AbilitiesReal[abilityNumber]
    if not ability:IsFullyCastable() or npcBot:GetMana() < ability:GetManaCost() or not ability:IsCooldownReady() then
        return BOT_ACTION_DESIRE_NONE, 0
    end
    local CastRange = ability:GetCastRange()
    local Damage = ability:GetAbilityDamage()
    local CastPoint = ability:GetCastPoint()
    local allys = npcBot:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
    local enemys = A.Dota.GetNearbyHeroes(npcBot, CastRange + 300, true)
    local WeakestEnemy, HeroHealth = utility.GetWeakestUnit(enemys)
    local creeps = npcBot:GetNearbyCreeps(CastRange + 300, true)
    local WeakestCreep, CreepHealth = utility.GetWeakestUnit(creeps)
    --------------------------------------
    -- Global high-priorty usage
    --------------------------------------
    if npcBot:GetActiveMode() ~= BOT_MODE_RETREAT then
        if WeakestEnemy ~= nil then
            if HeroHealth <= WeakestEnemy:GetActualIncomingDamage(Damage, DAMAGE_TYPE_MAGICAL) or
                (
                HeroHealth <= WeakestEnemy:GetActualIncomingDamage(GetComboDamage(), DAMAGE_TYPE_MAGICAL) and
                    npcBot:GetMana() > ComboMana) then
                if CanCast[abilityNumber](WeakestEnemy) then
                    return BOT_ACTION_DESIRE_HIGH, WeakestEnemy
                end
            end
        end
    end
    --------------------------------------
    -- Mode based usage
    --------------------------------------
    local enemys2 = npcBot:GetNearbyHeroes(400, true, BOT_MODE_NONE)

    -- If my mana is enough,use it at enemy
    if npcBot:GetActiveMode() == BOT_MODE_LANING then
        if HealthPercentage > 0.6 and (ManaPercentage > 0.6 or npcBot:GetMana() > ComboMana) then
            if WeakestEnemy ~= nil then
                if CanCast[abilityNumber](WeakestEnemy) then
                    return BOT_ACTION_DESIRE_LOW, WeakestEnemy
                end
            end
        end
    end
    -- If we're farming and can hit 2+ creeps and kill 1+ 
    if npcBot:GetActiveMode() == BOT_MODE_FARM then
        if #creeps >= 1 then
            if npcBot:GetMana() > ComboMana * 2 and CanCast[abilityNumber](WeakestCreep) then
                return BOT_ACTION_DESIRE_LOW, WeakestCreep
            end
        end
    end

    -- If we're pushing or defending a lane
    if npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_TOP or npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_MID or
        npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_BOT or npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_TOP or
        npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_MID or npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_BOT then
        if #enemys >= 1 then
            if ManaPercentage > 0.5 or npcBot:GetMana() > ComboMana then
                if WeakestEnemy ~= nil then
                    if CanCast[abilityNumber](WeakestEnemy) and
                        GetUnitToUnitDistance(npcBot, WeakestEnemy) < CastRange + 75 * #allys then
                        return BOT_ACTION_DESIRE_LOW, WeakestEnemy
                    end
                end
            end
        end
    end
    
    -- If we're going after someone
    if npcBot:GetActiveMode() == BOT_MODE_ROAM or npcBot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
        npcBot:GetActiveMode() == BOT_MODE_DEFEND_ALLY or npcBot:GetActiveMode() == BOT_MODE_ATTACK then
        local npcEnemy = npcBot:GetTarget()
        if npcEnemy ~= nil then
            if CanCast[abilityNumber](npcEnemy) and GetUnitToUnitDistance(npcBot, npcEnemy) < CastRange + 75 * #allys then
                return BOT_ACTION_DESIRE_MODERATE, npcEnemy
            end
        end
    end
    return BOT_ACTION_DESIRE_NONE, 0
end
Consider[2] = function()
    local abilityNumber = 2
    --------------------------------------
    -- Generic Variable Setting
    --------------------------------------
    local ability = AbilitiesReal[abilityNumber]
    if not ability:IsFullyCastable() or npcBot:GetMana() < ability:GetManaCost() or not ability:IsCooldownReady() then
        return BOT_ACTION_DESIRE_NONE, 0
    end
    local CastRange = ability:GetCastRange()
    local Damage = ability:GetAbilityDamage()
    local Radius = ability:GetAOERadius()
    local CastPoint = ability:GetCastPoint()
    local allys = npcBot:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
    local enemys = npcBot:GetNearbyHeroes(CastRange + 300, true, BOT_MODE_NONE)
    local WeakestEnemy, HeroHealth = utility.GetWeakestUnit(enemys)
    local creeps = npcBot:GetNearbyCreeps(CastRange + 300, true)
    local WeakestCreep, CreepHealth = utility.GetWeakestUnit(creeps)
    local towers = npcBot:GetNearbyTowers(CastRange + 300, false)

    --------------------------------------
    -- Mode based usage
    --------------------------------------

    --protect myself
    local enemys2 = npcBot:GetNearbyHeroes(400, true, BOT_MODE_NONE)
    -- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently    
    if npcBot:GetActiveMode() == BOT_MODE_RETREAT and npcBot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH or
        #enemys2 > 0 then
        for _, npcEnemy in pairs(enemys) do
            if npcBot:WasRecentlyDamagedByHero(npcEnemy, 2.0) and CanCast[abilityNumber](npcEnemy) or
                GetUnitToUnitDistance(npcBot, npcEnemy) < 400 then
                return BOT_ACTION_DESIRE_HIGH, utility.GetUnitsTowardsLocation(npcEnemy, npcBot, Radius)
            end
        end
    end

    -- If we're going after someone
    if npcBot:GetActiveMode() == BOT_MODE_ROAM or npcBot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
        npcBot:GetActiveMode() == BOT_MODE_DEFEND_ALLY or npcBot:GetActiveMode() == BOT_MODE_ATTACK then
        local locationAoE = npcBot:FindAoELocation(false, true, npcBot:GetLocation(), CastRange, Radius, 0, 0)
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_LOW, locationAoE.targetloc
        end
        local npcEnemy = npcBot:GetTarget()
        if npcEnemy ~= nil then
            if CanCast[abilityNumber](npcEnemy) then
                return BOT_ACTION_DESIRE_HIGH, utility.GetUnitsTowardsLocation(npcBot, npcEnemy, Radius)
            end
        end
    end
    return BOT_ACTION_DESIRE_NONE, 0
end
Consider[3] = function()
    local abilityNumber = 3
    --------------------------------------
    -- Generic Variable Setting
    --------------------------------------
    local ability = AbilitiesReal[abilityNumber]
    if not ability:IsFullyCastable() or npcBot:GetMana() < ability:GetManaCost() or not ability:IsCooldownReady() then
        return BOT_ACTION_DESIRE_NONE, 0
    end
    local CastRange = ability:GetCastRange()
    local Damage = ability:GetAbilityDamage()
    local Radius = ability:GetAOERadius()
    local CastPoint = ability:GetCastPoint()
    local Delay = ability:GetSpecialValueFloat("activation_delay")
    local searchRadius = ability:GetSpecialValueInt "search_radius" or 375
    local allys = npcBot:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
    local enemys = npcBot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
    local vulnerableEnemy = A.Linq.Filter(enemys, A.Hero.MayNotBeIllusion):First(CanCast[abilityNumber])
    local WeakestEnemy, HeroHealth = utility.GetWeakestUnit(enemys)
    local creeps = npcBot:GetNearbyCreeps(1600, true)
    local WeakestCreep, CreepHealth = utility.GetWeakestUnit(creeps)
    --------------------------------------
    -- Global high-priorty usage
    --------------------------------------
    --Try to kill enemy hero
    if npcBot:GetActiveMode() ~= BOT_MODE_RETREAT then
        if WeakestEnemy ~= nil then
            if CanCast[abilityNumber](WeakestEnemy) then
                if HeroHealth <= WeakestEnemy:GetActualIncomingDamage(Damage, DAMAGE_TYPE_MAGICAL) or
                    (
                    HeroHealth <= WeakestEnemy:GetActualIncomingDamage(GetComboDamage(), DAMAGE_TYPE_MAGICAL) and
                        npcBot:GetMana() > ComboMana) then
                    return BOT_ACTION_DESIRE_HIGH, WeakestEnemy:GetExtrapolatedLocation(CastPoint + Delay)
                end
            end
        end
    end
    
    --------------------------------------
    -- Mode based usage
    --------------------------------------
    local enemys2 = npcBot:GetNearbyHeroes(400, true, BOT_MODE_NONE)
    if npcBot:GetActiveMode() == BOT_MODE_LANING then
        if ManaPercentage > 0.7 or ManaPercentage >= 0.55 and ability:GetLevel() >= 3 then
            if WeakestEnemy ~= nil then
                if CanCast[abilityNumber](WeakestEnemy) then
                    return BOT_ACTION_DESIRE_LOW,
                        utility.GetUnitsTowardsLocation(npcBot, WeakestEnemy,
                            GetUnitToUnitDistance(npcBot, WeakestEnemy) + 300)
                end
            end
        end
    end
    local manaLeft = mana - ability:GetManaCost()
    if npcBot:GetActiveMode() == BOT_MODE_LANING then
        if manaLeft >= 0.7 * maxMana or manaLeft >= 0.55 * maxMana then
            if vulnerableEnemy then
                local enemyFriends = vulnerableEnemy:GetNearbyCreeps(searchRadius + vulnerableEnemy + GetBoundingRadius()
                    + 128):Count(function(t)
                    return A.Unit.GetHealthPercent(t) >= 0.3
                end)
                if enemyFriends == 1 then
                    return BOT_ACTION_DESIRE_LOW, vulnerableEnemy:GetExtrapolatedLocation(CastPoint + Delay)
                elseif enemyFriends == 0 then
                    return BOT_ACTION_DESIRE_MODERATE + 0.15, vulnerableEnemy:GetExtrapolatedLocation(CastPoint + Delay)
                end
            end
        end
    end
    
    -- If we're farming and can hit 2+ creeps and kill 1+ 
    if npcBot:GetActiveMode() == BOT_MODE_FARM then
        if #creeps >= 2 and ability:GetLevel() >= 3 then
            if CreepHealth <= WeakestCreep:GetActualIncomingDamage(Damage, DAMAGE_TYPE_MAGICAL) and
                manaLeft >= 0.75 * maxMana then
                return BOT_ACTION_DESIRE_LOW, WeakestCreep:GetExtrapolatedLocation(CastPoint + Delay)
            end
        end
    end

    -- If we're pushing or defending a lane
    if npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_TOP or npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_MID or
        npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_BOT or npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_TOP or
        npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_MID or npcBot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_BOT then
        if #enemys >= 1 then
            if manaLeft >= 0.65 * maxMana and npcBot:GetMana() > ComboMana and ability:GetLevel() >= 4 then
                if WeakestEnemy ~= nil then
                    if CanCast[abilityNumber](WeakestEnemy) and
                        GetUnitToUnitDistance(npcBot, WeakestEnemy) < CastRange + 75 * #allys then
                        return BOT_ACTION_DESIRE_LOW, WeakestEnemy:GetExtrapolatedLocation(CastPoint + Delay)
                    end
                end
            end
        end
    end
    
    -- If we're going after someone
    if npcBot:GetActiveMode() == BOT_MODE_ROAM or npcBot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
        npcBot:GetActiveMode() == BOT_MODE_DEFEND_ALLY or npcBot:GetActiveMode() == BOT_MODE_ATTACK then
        local locationAoE = npcBot:FindAoELocation(true, true, npcBot:GetLocation(), CastRange, Radius, CastPoint + Delay
            , 0)
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_LOW, locationAoE.targetloc
        end
        local npcEnemy = npcBot:GetTarget()
        if npcEnemy ~= nil then
            if CanCast[abilityNumber](npcEnemy) and not enemyDisabled(npcEnemy) and
                GetUnitToUnitDistance(npcBot, npcEnemy) < CastRange + 75 * #allys then
                return BOT_ACTION_DESIRE_MODERATE, npcEnemy:GetExtrapolatedLocation(CastPoint + Delay)
            end
        end
    end
    return BOT_ACTION_DESIRE_NONE, 0
end
Consider[5] = function()
    local abilityNumber = 5
    --------------------------------------
    -- Generic Variable Setting
    --------------------------------------
    local ability = AbilitiesReal[abilityNumber]
    if not ability:IsFullyCastable() or AbilityExtensions:CannotTeleport(npcBot) or
        AbilityExtensions:IsTempestDouble(npcBot) then
        return BOT_ACTION_DESIRE_NONE, 0
    end
    local CastRange = 0
    local Damage = 0
    local CastPoint = ability:GetCastPoint()
    local allys = npcBot:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
    local enemys = npcBot:GetNearbyHeroes(800, true, BOT_MODE_NONE)
    local WeakestEnemy, HeroHealth = utility.GetWeakestUnit(enemys)
    local creeps = npcBot:GetNearbyCreeps(800, true)
    local WeakestCreep, CreepHealth = utility.GetWeakestUnit(creeps)
    --------------------------------------
    -- Global high-priorty usage
    --------------------------------------

    -- Stop making a huge bounty for the enemy
    if (npcBot:GetHealth() <= 450 or HealthPercentage <= 0.3) and
        (
        npcBot:WasRecentlyDamagedByAnyHero(1.5) or AbilityExtensions:CanHardlyMove(npcBot) or
            AbilityExtensions:CannotTeleport(npcBot)) and not AbilityExtensions:Outnumber(npcBot, allys, enemys) then
        return 0
    end
    -- If we're in a teamfight, use it on the scariest enemy
    local tableNearbyAttackingAlliedHeroes = npcBot:GetNearbyHeroes(1000, false, BOT_MODE_ATTACK)
    if #tableNearbyAttackingAlliedHeroes >= 2 then
        return BOT_ACTION_DESIRE_HIGH
    end
    --------------------------------------
    -- Mode based usage
    --------------------------------------
    local enemys2 = npcBot:GetNearbyHeroes(400, true, BOT_MODE_NONE)
    -- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
    if npcBot:GetActiveMode() == BOT_MODE_RETREAT and npcBot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH or
        #enemys2 > 0 then
        for _, npcEnemy in pairs(enemys) do
            if npcBot:WasRecentlyDamagedByHero(npcEnemy, 2.0) and CanCast[abilityNumber](npcEnemy) or
                GetUnitToUnitDistance(npcBot, npcEnemy) < 400 then
                return BOT_ACTION_DESIRE_HIGH
            end
        end
    end
    
    -- If we're going after someone
    if npcBot:GetActiveMode() == BOT_MODE_ROAM or npcBot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
        npcBot:GetActiveMode() == BOT_MODE_DEFEND_ALLY or npcBot:GetActiveMode() == BOT_MODE_ATTACK then
        local npcEnemy = npcBot:GetTarget()
        if npcEnemy ~= nil then
            if CanCast[abilityNumber](npcEnemy) and GetUnitToUnitDistance(npcBot, npcEnemy) < CastRange + 75 * #allys then
                return BOT_ACTION_DESIRE_MODERATE
            end
        end
    end
    return BOT_ACTION_DESIRE_NONE, 0
end
AbilityExtensions:AutoModifyConsiderFunction(npcBot, Consider, AbilitiesReal)
function AbilityUsageThink()
    if npcBot == nil then
        npcBot = GetBot()
    end
    health = npcBot:GetHealth()
    maxHealth = npcBot:GetMaxHealth()
    healthPercent = AbilityExtensions:GetHealthPercent(npcBot)
    mana = npcBot:GetMana()
    maxMana = npcBot:GetMaxMana()
    manaPercent = AbilityExtensions:GetManaPercent(npcBot)

    -- Check if we're already using an ability
    if npcBot:IsUsingAbility() or npcBot:IsChanneling() or npcBot:IsSilenced() then
        return
    end
    ComboMana = GetComboMana()
    AttackRange = npcBot:GetAttackRange()
    ManaPercentage = npcBot:GetMana() / npcBot:GetMaxMana()
    HealthPercentage = npcBot:GetHealth() / npcBot:GetMaxHealth()
    cast = ability_item_usage_generic.ConsiderAbility(AbilitiesReal, Consider)
    ---------------------------------debug--------------------------------------------
    if debugmode == true then
        ability_item_usage_generic.PrintDebugInfo(AbilitiesReal, cast)
    end
    ability_item_usage_generic.UseAbility(AbilitiesReal, cast)
end

function CourierUsageThink()
    ability_item_usage_generic.CourierUsageThink()
end
