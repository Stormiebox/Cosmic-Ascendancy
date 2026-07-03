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
    
    table.insert(dynamicKeys, entity:addMultiplyableBias(StatsBonuses.ShieldDurability, 2.0 * finalMultiplier))
    table.insert(dynamicKeys, entity:addMultiplyableBias(StatsBonuses.ShieldRecharge, 1.5 * finalMultiplier))
end

function removeDynamicBuffs()
    local entity = Entity()
    if not entity then return end
    for _, key in ipairs(dynamicKeys) do
        entity:removeBonus(key)
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
    -- These are integer handles returned by addMultiplyableBias and are volatile —
    -- they become invalid after a server restart. Storing and restoring them means
    -- removeBonus(staleKey) silently fails, and old buffs stack permanently each reload.
    -- The next updateServer() tick will reapply fresh keys automatically.
    return data
end

local base_restore = restore
function restore(data)
    if base_restore then base_restore(data) end
    -- The updateServer loop will re-register fresh keys on the next tick.
    dynamicKeys = {}
end

function getName(seed, rarity)
    return "Ascendant Aegis Matrix"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/shield.png"
end

function getEnergy(seed, rarity)
    return 0
end

function getPrice(seed, rarity)
    return 1000000000
end

function getTooltipLines(seed, rarity, permanent)
    local texts = {}
    table.insert(texts, {ltext = "Base Shield Durability"%_t, rtext = "+500%", icon = "data/textures/icons/health-normal.png", boosted = false})
    table.insert(texts, {ltext = "Base Shield Recharge"%_t, rtext = "+300%", icon = "data/textures/icons/health-normal.png", boosted = false})
    
    table.insert(texts, {ltext = "", rtext = "", icon = ""})
    table.insert(texts, {ltext = "\\c(e44)LIVING RELIC\\c()"%_t, rtext = "", icon = ""})
    table.insert(texts, {ltext = "Stats multiply based on"%_t, rtext = "", icon = ""})
    table.insert(texts, {ltext = "Core Proximity & War Heat!"%_t, rtext = "", icon = ""})
    
    return texts
end
