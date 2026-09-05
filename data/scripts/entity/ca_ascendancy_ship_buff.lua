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

-- Keys returned by addBaseMultiplier below, so removeBuffs() can strip exactly these three bonuses
-- via removeBonus(key) instead of entity:removeScriptBonuses(). This script is attached
-- unconditionally to every player/alliance-owned ship on every sector entry (ascendancyplayer.lua),
-- so the blanket-clear version of this bug had the largest blast radius in the mod: it silently
-- erased any other mod's stat bonus (Cosmic Overhaul's captain traits, Cosmic Starfall's Bastion
-- System, this mod's own Aegis Reactor) on that same ship every 30 seconds. Not persisted via
-- secure()/restore() -- these locals start nil on every fresh script load, which is exactly what a
-- volatile bonus key needs.
local shieldKey = nil
local regenKey = nil
local hyperKey = nil

function removeBuffs()
    local entity = Entity()
    if not entity then return end
    if shieldKey then entity:removeBonus(shieldKey); shieldKey = nil end
    if regenKey then entity:removeBonus(regenKey); regenKey = nil end
    if hyperKey then entity:removeBonus(hyperKey); hyperKey = nil end
end

function applyBuffs()
    local entity = Entity()
    removeBuffs()

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
        shieldKey = entity:addBaseMultiplier(StatsBonuses.ShieldDurability, shieldMult)
        regenKey = entity:addBaseMultiplier(StatsBonuses.ShieldRecharge, regenMult)
        hyperKey = entity:addBaseMultiplier(StatsBonuses.HyperspaceCooldown, -hyperMult)
    end
end
