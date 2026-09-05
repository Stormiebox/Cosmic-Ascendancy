package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("basesystem")
include ("utility")
local cv_buffs = include("cosmicvaultbuffs")

-- Matches the vanilla convention (shieldbooster.lua, hyperspacebooster.lua, etc.): getEnergy()
-- returns a constant here, so this tells the engine it never needs to re-read it every frame.
FixedEnergyRequirement = true

function getUpdateInterval()
    return 15
end

function updateServer(timeStep)
    applyDynamicBuffs()
end

-- See ascendantomnisensor.lua's identical comment for why these keys are tracked and not persisted.
local velocityKey = nil
local jumpReachKey = nil
local cooldownKey = nil

function applyDynamicBuffs()
    removeDynamicBuffs()

    local entity = Entity()
    if not entity then return end

    local finalMultiplier = 1.0
    if cv_buffs and type(cv_buffs.getDynamicRelicMultiplier) == "function" then
        finalMultiplier = cv_buffs.getDynamicRelicMultiplier(entity.id)
    end

    -- Slipstream Core gives massive Velocity, Jump Reach, and Cooldown reduction
    velocityKey = entity:addBaseMultiplier(StatsBonuses.Velocity, 5.0 * finalMultiplier)
    jumpReachKey = entity:addAbsoluteBias(StatsBonuses.HyperspaceReach, math.floor(25 * finalMultiplier))
    cooldownKey = entity:addBaseMultiplier(StatsBonuses.HyperspaceCooldown, -0.8) -- Cap cooldown naturally, maybe not multiply to avoid negative infinity?
end

function removeDynamicBuffs()
    local entity = Entity()
    if not entity then return end
    if velocityKey then entity:removeBonus(velocityKey); velocityKey = nil end
    if jumpReachKey then entity:removeBonus(jumpReachKey); jumpReachKey = nil end
    if cooldownKey then entity:removeBonus(cooldownKey); cooldownKey = nil end
end

function onInstalled(seed, rarity, permanent)
    if onServer() then
        applyDynamicBuffs()
        -- Entity's onSectorEntered(entityId, x, y) has a different, 3-arg signature —
        -- this handler needs the 4-arg Player callback (playerIndex, x, y, sectorChangeType).
        Player():registerCallback("onSectorEntered", "onSectorEntered")
    end
end

function onUninstalled(seed, rarity, permanent)
    if onServer() then
        removeDynamicBuffs()
        Player():unregisterCallback("onSectorEntered", "onSectorEntered")
    end
end

function onSectorEntered(playerIndex, x, y, sectorChangeType)
    if onServer() then
        if sectorChangeType == SectorChangeType.Jump then
            local entity = Entity()
            if entity then
                entity:addScriptOnce("data/scripts/systems/slipstream_drift_buff.lua")
            end
        end
    end
end

local base_secure = secure
function secure()
    local data = {}
    if base_secure then data = base_secure() or {} end
    return data
end

local base_restore = restore
function restore(data)
    if base_restore then base_restore(data) end
end

function getName(seed, rarity)
    return "Ascendant Slipstream Core"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/AscendantSlipstreamCore.png"
end

function getEnergy(seed, rarity)
    return 0
end

function getPrice(seed, rarity)
    return 1000000000
end

function getTooltipLines(seed, rarity, permanent)
    local texts = {}
    table.insert(texts, {ltext = "Base Velocity"%_t, rtext = "+500%", icon = "data/textures/icons/acceleration.png", boosted = false})
    table.insert(texts, {ltext = "Base Jump Reach"%_t, rtext = "+25", icon = "data/textures/icons/vortex.png", boosted = false})
    table.insert(texts, {ltext = "Hyperspace Cooldown"%_t, rtext = "-80%", icon = "data/textures/icons/hourglass.png", boosted = false})

    table.insert(texts, {ltext = "", rtext = "", icon = ""})
    table.insert(texts, {ltext = "\\c(e44)LIVING RELIC\\c()"%_t, rtext = "", icon = ""})
    table.insert(texts, {ltext = "Stats multiply based on"%_t, rtext = "", icon = ""})
    table.insert(texts, {ltext = "Core Proximity & War Heat!"%_t, rtext = "", icon = ""})

    return texts
end
