package.path = package.path .. ";data/scripts/lib/?.lua"
local cv_buffs = include("cosmicvaultbuffs")

-- The ship will keep this script attached permanently and grant stats based on Global Tier

function getUpdateInterval()
    return 30 -- Update every 30 seconds to force stat recalculation if tier changed
end

function initialize()
    if onServer() then
        applyBuffs()
    end
end

function updateServer(timeStep)
    if onServer() then
        applyBuffs()
    end
end

function applyBuffs()
    local entity = Entity()
    entity:removeScriptBonuses()
    
    if not cv_buffs or not cv_buffs.getGlobalTier then return end
    
    local faction = Faction(entity.factionIndex)
    if not faction then return end
    
    local tier = cv_buffs.getGlobalTier(faction.index)
    if tier > 0 then
        -- Tier 1: +15% Shields, +10% Hyperspace Cooldown Speed, +20% Shield Regen
        local shieldMult = tier * 0.15
        local hyperMult = tier * 0.10
        local regenMult = tier * 0.20
        
        -- Use negative for HyperspaceCooldown to make it FASTER
        entity:addBaseMultiplier(StatsBonuses.ShieldDurability, shieldMult)
        entity:addBaseMultiplier(StatsBonuses.ShieldRecharge, regenMult)
        entity:addBaseMultiplier(StatsBonuses.HyperspaceCooldown, -hyperMult)
    end
end
