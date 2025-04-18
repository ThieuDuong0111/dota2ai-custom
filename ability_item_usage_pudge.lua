
-- v1.7 template

local utility = require(GetScriptDirectory() .. "/utility")
local ability_item_usage_generic = require(GetScriptDirectory() .. "/ability_item_usage_generic")
local AbilityExtensions = require(GetScriptDirectory() .. "/util/AbilityAbstraction")
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
    Abilities[2],
    Abilities[1],
    Abilities[1],
    Abilities[2],
    Abilities[1],
    Abilities[5],
    Abilities[1],
    Abilities[3],
    Abilities[2],
    "talent",
    Abilities[2],
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
        return Talents[2]
    end,
    function()
        return Talents[3]
    end,
    function()
        return Talents[5]
    end,
    function()
        return Talents[8]
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
local cast = {}
cast.Desire = {}
cast.Target = {}
cast.Type = {}
local Consider = {}
local CanCast = {
    function(t)
        return AbilityExtensions:NormalCanCast(t, false, DAMAGE_TYPE_PURE, true, false)
    end,
    AbilityExtensions.NormalCanCastFunction,
    utility.NCanCast,
    utility.CanCastNoTarget,
    function(t)
        return AbilityExtensions:NormalCanCast(t, false, DAMAGE_TYPE_MAGICAL, true, true) and
            not AbilityExtensions:HasAbilityRetargetModifier(t)
    end,
}

-- pudge_meat_hook
Consider[1] = function()
    local ability = AbilitiesReal[1]
    if not ability:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, 0;
    end

    local CastRange = ability:GetCastRange();  -- Lấy phạm vi của skill
    local Radius = ability:GetAOERadius();     -- Lấy bán kính của skill
    local Damage = ability:GetAbilityDamage(); -- Lấy sát thương của skill

    -- Lấy các hero địch trong phạm vi
    local enemies = npcBot:GetNearbyHeroes(CastRange, true, BOT_MODE_NONE);
    local target = nil;
    
    -- Tìm kiếm mục tiêu để hook (lựa chọn hero gần nhất)
    for _, enemy in pairs(enemies) do
        if enemy:IsAlive() and GetUnitToUnitDistance(npcBot, enemy) <= CastRange then
            target = enemy;
            break;
        end
    end

    -- Nếu tìm thấy mục tiêu và có thể dùng skill
    if target ~= nil then
        -- Kiểm tra liệu có đủ mana và cooldown
        if npcBot:GetMana() >= ability:GetManaCost() then
            -- Sử dụng skill để kéo mục tiêu
            return BOT_ACTION_DESIRE_HIGH, target:GetLocation();  -- Tương tác với skill tại vị trí của mục tiêu
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, 0;
end

-- pudge_rot
Consider[2] = function()
    local ability = AbilitiesReal[2]
    local radius = ability:GetAOERadius()
    if not ability:IsFullyCastable() then
        return 0
    end
    if AbilityExtensions:IsAttackingEnemies(npcBot) or AbilityExtensions:IsRetreating(npcBot) then
        do
            local nearbyEnemies = AbilityExtensions:GetNearbyHeroes(npcBot, radius, true)
            if nearbyEnemies:Any(CanCast[2]) then
                return true
            end
        end
    end
    do
        local target = npcBot:GetTarget()
        if target and GetUnitToUnitDistance(target, npcBot) <= radius and CanCast[2](target) then
            if not AbilityExtensions:IsHero(target) or AbilityExtensions:MustBeIllusion(npcBot, target) then
                if npcBot:GetHealth() <= 270 or
                    AbilityExtensions:GetHealthPercent(npcBot) <= 0.3 and npcBot:WasRecentlyDamagedByHero(target, 1.5) then
                    return false
                end
            end
            return true
        end
    end
    return false
end
Consider[2] = AbilityExtensions:ToggleFunctionToAction(npcBot, Consider[2], AbilitiesReal[2])
local swallowingSomething
local swallowTimer

-- pudge_eject
Consider[4] = function()
    local ability = AbilitiesReal[4]
    if not ability:IsFullyCastable() or npcBot:IsChanneling() then
        return 0
    end
    swallowingSomething = npcBot:HasModifier("modifier_pudge_swallow") or
        npcBot:HasModifier("modifier_pudge_swallow_effect") or npcBot:HasModifier("modifier_pudge_swallow_hide")
    if swallowingSomething then
        if swallowTimer ~= nil then
            if DotaTime() >= swallowTimer + 3 then
                return BOT_MODE_DESIRE_VERYHIGH
            end
        else
            swallowTimer = DotaTime()
        end
    end
    return 0
end

-- pudge_dismember
Consider[5] = function()
    local ability = AbilitiesReal[5]
    if not ability:IsFullyCastable() or npcBot:IsChanneling() then
        return nil
    end
    local range = ability:GetCastRange() + 100
    local hookedEnemy = AbilityExtensions:First(AbilityExtensions:GetNearbyNonIllusionHeroes(npcBot, range, true,
        BOT_MODE_NONE), function(t)
        return t:IsHero() and AbilityExtensions:MayNotBeIllusion(npcBot, t) and t:HasModifier("modifier_pudge_meat_hook")
    end)
    if hookedEnemy then
        return BOT_MODE_DESIRE_VERYHIGH, hookedEnemy
    end
    do
        local target = AbilityExtensions:GetTargetIfGood(npcBot)
        if target and CanCast[5](target) and GetUnitToUnitDistance(npcBot, target) <= range then
            return BOT_MODE_DESIRE_HIGH, target
        end
    end
    local nearbyEnemies = AbilityExtensions:GetNearbyNonIllusionHeroes(npcBot, 900, true, BOT_MODE_NONE)
    if AbilityExtensions:IsAttackingEnemies(npcBot) then
        do
            local u = utility.GetWeakestUnit(nearbyEnemies)
            if u and CanCast[5](u) then
                return BOT_MODE_DESIRE_HIGH, u
            end
        end
    end
    if AbilityExtensions:IsRetreating(npcBot) and #nearbyEnemies == 1 then
        do
            local loneEnemy = nearbyEnemies[1]
            if loneEnemy and not AbilityExtensions:HasAbilityRetargetModifier(loneEnemy) and CanCast[5](loneEnemy) then
                return BOT_MODE_DESIRE_MODERATE, loneEnemy
            end
        end
    end
    return 0
end
function CourierUsageThink()
    ability_item_usage_generic.CourierUsageThink()
end

function AbilityUsageThink()
    if npcBot:IsUsingAbility() or npcBot:IsSilenced() then
        return
    end
    cast = ability_item_usage_generic.ConsiderAbility(AbilitiesReal, Consider)
    ability_item_usage_generic.UseAbility(AbilitiesReal, cast)
end
