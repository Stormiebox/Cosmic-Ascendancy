package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("basesystem")
include ("utility")
local cv_war = include("cosmicwarbridge")

local dynamicKeys = {}

function getUpdateInterval()
    return 15
end

function updateServer(timeStep)
    applyDynamicBuffs()
end

function applyDynamicBuffs()
    removeDynamicBuffs()
    
    local entity = Entity()
    if not entity then return end
    
    local distMultiplier = 1.0
    local x, y = Sector():getCoordinates()
    if x and y then
        local dist = math.sqrt(x * x + y * y)
        distMultiplier = 1.0 + (math.max(0, 500 - dist) / 250)
    end
    
    local warMultiplier = 1.0
    if cv_war.getFactionWarHeat then
        local heat = cv_war.getFactionWarHeat(entity.factionIndex) or 0
        warMultiplier = 1.0 + (heat * 1.5)
    end
    
    local finalMultiplier = math.min(2.5, distMultiplier * warMultiplier)
    
    -- Slipstream Core gives massive Velocity, Jump Reach, and Cooldown reduction
    local k1 = entity:addMultiplier(StatsBonuses.Velocity, 1.5 * finalMultiplier)
    local k2 = entity:addAbsoluteBias(StatsBonuses.HyperspaceReach, math.floor(10 * finalMultiplier))
    local k3 = entity:addBaseMultiplier(StatsBonuses.HyperspaceCooldown, -0.8) -- Cap cooldown naturally, maybe not multiply to avoid negative infinity?
    -- Wait, removeBaseMultiplier is for Basesystem. Let's use removeMultiplier.
    
    table.insert(dynamicKeys, {key=k1, type="multiplier", stat=StatsBonuses.Velocity})
    table.insert(dynamicKeys, {key=k2, type="absolute", stat=StatsBonuses.HyperspaceReach})
    table.insert(dynamicKeys, {key=k3, type="base_multiplier", stat=StatsBonuses.HyperspaceCooldown})
end

function removeDynamicBuffs()
    local entity = Entity()
    if not entity then return end
    for _, kData in pairs(dynamicKeys) do
        entity:removeBonus(kData.key)
    end
    dynamicKeys = {}
end

function onInstalled(seed, rarity, permanent)
    if onServer() then applyDynamicBuffs() end
end

function onUninstalled(seed, rarity, permanent)
    if onServer() then removeDynamicBuffs() end
end

local base_secure = secure
function secure()
    local data = {}
    if base_secure then data = base_secure() or {} end
    -- Bonus handles from addMultiplier/addAbsoluteBias/addBaseMultiplier are volatile —
    -- they are reset on every server restart. Saving stale handles causes:
    --   1. removeBonus(staleKey) silently fails on next load
    --   2. The previously applied buffs remain permanently (because they were never removed)
    --   3. New buffs then stack on top — doubling/tripling velocity and jump range each restart
    -- Let restore() clear the table so the next update tick reapplies buffs cleanly.
    return data
end

local base_restore = restore
function restore(data)
    if base_restore then base_restore(data) end
    -- Clear handles — next updateServer() will call applyDynamicBuffs() with fresh keys
    dynamicKeys = {}
end

function getName(seed, rarity)
    return "Ascendant Slipstream Core"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/engine.png"
end

function getEnergy(seed, rarity)
    return 0
end

function getPrice(seed, rarity)
    return 1000000000
end

function getTooltipLines(seed, rarity, permanent)
    local texts = {}
    table.insert(texts, {ltext = "Base Velocity"%_t, rtext = "+500%", icon = "data/textures/icons/sprint.png", boosted = false})
    table.insert(texts, {ltext = "Base Jump Reach"%_t, rtext = "+25", icon = "data/textures/icons/radar-sweep.png", boosted = false})
    table.insert(texts, {ltext = "Hyperspace Cooldown"%_t, rtext = "-80%", icon = "data/textures/icons/hourglass.png", boosted = false})
    
    table.insert(texts, {ltext = "", rtext = "", icon = ""})
    table.insert(texts, {ltext = "\\c(e44)LIVING RELIC\\c()"%_t, rtext = "", icon = ""})
    table.insert(texts, {ltext = "Stats multiply based on"%_t, rtext = "", icon = ""})
    table.insert(texts, {ltext = "Core Proximity & War Heat!"%_t, rtext = "", icon = ""})
    
    return texts
end
