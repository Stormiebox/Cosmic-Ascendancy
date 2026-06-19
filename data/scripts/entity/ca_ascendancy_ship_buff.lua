package.path = package.path .. ";data/scripts/lib/?.lua"
local cv_buffs = include("cosmicvaultbuffs")

-- The ship will keep this script attached permanently and grant stats based on Global Tier

function getUpdateInterval()
    return 30 -- Update every 30 seconds to force stat recalculation if tier changed
end

function updateServer(timeStep)
    local entity = Entity()
    -- Force Avorion engine to recalculate stats (onBaseMultiplierCalculated will fire)
    entity:addMultiplyableFactor(StatsBonuses.ShieldDurability, 0)
    entity:removeMultiplyableFactor(StatsBonuses.ShieldDurability)
end

function onBaseMultiplierCalculated(entity, statModifier)
    if not cv_buffs_success or not cv_buffs.getGlobalTier then return end
    
    local faction = Faction(entity.factionIndex)
    if not faction then return end
    
    local tier = cv_buffs.getGlobalTier(faction.index)
    if tier > 0 then
        -- Tier 1: +10% Shields, +10% Damage (represented by Armed Turrets multiplier or Base Damage multiplier)
        -- Avorion has StatsBonuses.BaseDamageMultiplier ? No, let's use ShieldDurability and Velocity to be safe,
        -- as modifying raw damage via base multipliers isn't always reliable.
        -- Actually we can boost ShieldDurability and HyperspaceCooldown!
        
        local shieldMult = 1.0 + (tier * 0.15) -- +15% per tier
        local hyperMult = 1.0 + (tier * 0.10) -- +10% faster cooldown per tier
        local regenMult = 1.0 + (tier * 0.20) -- +20% shield regen per tier
        
        statModifier:modifyBaseMultiplier(StatsBonuses.ShieldDurability, shieldMult)
        statModifier:modifyBaseMultiplier(StatsBonuses.ShieldRecharge, regenMult)
        statModifier:modifyBaseMultiplier(StatsBonuses.HyperspaceCooldown, hyperMult)
    end
end
