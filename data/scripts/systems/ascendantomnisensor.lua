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
    
    local finalMultiplier = distMultiplier * warMultiplier
    
    -- Omni-Sensor gives Radar, Hidden Sector, Cargo, and Loot Range
    local k1 = entity:addAbsoluteBias(StatsBonuses.RadarReach, math.floor(20 * finalMultiplier))
    local k2 = entity:addAbsoluteBias(StatsBonuses.HiddenSectorRadarReach, math.floor(15 * finalMultiplier))
    local k3 = entity:addMultiplier(StatsBonuses.CargoHold, 10.0 * finalMultiplier)
    local k4 = entity:addMultiplier(StatsBonuses.LootCollectionRange, 5.0 * finalMultiplier)
    
    table.insert(dynamicKeys, {key=k1, type="absolute", stat=StatsBonuses.RadarReach})
    table.insert(dynamicKeys, {key=k2, type="absolute", stat=StatsBonuses.HiddenSectorRadarReach})
    table.insert(dynamicKeys, {key=k3, type="multiplier", stat=StatsBonuses.CargoHold})
    table.insert(dynamicKeys, {key=k4, type="multiplier", stat=StatsBonuses.LootCollectionRange})
end

function removeDynamicBuffs()
    local entity = Entity()
    if not entity then return end
    for _, kData in pairs(dynamicKeys) do
        if kData.type == "absolute" then
            entity:removeAbsoluteBias(kData.stat, kData.key)
        else
            entity:removeMultiplier(kData.stat, kData.key)
        end
    end
    dynamicKeys = {}
end

function onInstalled(seed, rarity, permanent)
    if onServer() then applyDynamicBuffs() end
end

function onUninstalled(seed, rarity, permanent)
    if onServer() then removeDynamicBuffs() end
end

-- ================= PERSISTENCE HOOKS =================
local base_secure = secure
function secure()
    local data = {}
    if base_secure then data = base_secure() or {} end
    data.dynamicKeys = dynamicKeys
    return data
end

local base_restore = restore
function restore(data)
    if base_restore then base_restore(data) end
    dynamicKeys = data.dynamicKeys or {}
end
-- =====================================================

function getName(seed, rarity)
    return "Ascendant Omni-Sensor"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/radar-sweep.png"
end

function getEnergy(seed, rarity)
    return 0
end

function getPrice(seed, rarity)
    return 1000000000
end

function getTooltipLines(seed, rarity, permanent)
    local texts = {}
    table.insert(texts, {ltext = "Base Radar Reach"%_t, rtext = "+20", icon = "data/textures/icons/radar-sweep.png", boosted = false})
    table.insert(texts, {ltext = "Base Hidden Sectors"%_t, rtext = "+15", icon = "data/textures/icons/radar-sweep.png", boosted = false})
    table.insert(texts, {ltext = "Base Cargo Hold"%_t, rtext = "+1000%", icon = "data/textures/icons/sell.png", boosted = false})
    table.insert(texts, {ltext = "Base Loot Range"%_t, rtext = "+500%", icon = "data/textures/icons/domino-mask.png", boosted = false})
    
    table.insert(texts, {ltext = "", rtext = "", icon = ""})
    table.insert(texts, {ltext = "\\c(e44)LIVING RELIC\\c()"%_t, rtext = "", icon = ""})
    table.insert(texts, {ltext = "Stats multiply based on"%_t, rtext = "", icon = ""})
    table.insert(texts, {ltext = "Core Proximity & War Heat!"%_t, rtext = "", icon = ""})
    
    return texts
end
