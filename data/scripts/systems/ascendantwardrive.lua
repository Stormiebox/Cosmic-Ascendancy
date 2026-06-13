package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("basesystem")
include ("utility")
local cv_success, cv_war = pcall(require, "cosmicwarbridge")

local dynamicKeys = {}

function getUpdateInterval()
    return 15 -- Every 15 seconds
end

function updateServer(timeStep)
    applyDynamicBuffs()
end

function applyDynamicBuffs()
    removeDynamicBuffs()
    
    local entity = Entity()
    if not entity then return end
    
    -- Calculate Relic Multiplier
    local distMultiplier = 1.0
    local x, y = Sector():getCoordinates()
    if x and y then
        local dist = math.sqrt(x * x + y * y)
        distMultiplier = 1.0 + (math.max(0, 500 - dist) / 250) -- Up to 3x at core
    end
    
    local warMultiplier = 1.0
    if cv_success and cv_war.getFactionWarHeat then
        local heat = cv_war.getFactionWarHeat(entity.factionIndex) or 0
        warMultiplier = 1.0 + (heat * 1.5) -- Up to 2.5x during max war
    end
    
    local finalMultiplier = distMultiplier * warMultiplier -- Max ~7.5x
    
    -- Apply Base Stats multiplied by finalMultiplier
    -- War-Drive gives Armed/Arbitrary Turrets, Energy, and FireRate
    local k1 = entity:addAbsoluteBias(StatsBonuses.ArmedTurrets, math.floor(10 * finalMultiplier))
    local k2 = entity:addAbsoluteBias(StatsBonuses.ArbitraryTurrets, math.floor(5 * finalMultiplier))
    local k3 = entity:addMultiplier(StatsBonuses.GeneratedEnergy, 2.0 * finalMultiplier)
    local k4 = entity:addMultiplier(StatsBonuses.FireRate, 0.5 * finalMultiplier)
    
    table.insert(dynamicKeys, {key=k1, type="absolute", stat=StatsBonuses.ArmedTurrets})
    table.insert(dynamicKeys, {key=k2, type="absolute", stat=StatsBonuses.ArbitraryTurrets})
    table.insert(dynamicKeys, {key=k3, type="multiplier", stat=StatsBonuses.GeneratedEnergy})
    table.insert(dynamicKeys, {key=k4, type="multiplier", stat=StatsBonuses.FireRate})
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
    if onServer() then
        applyDynamicBuffs()
    end
end

function onUninstalled(seed, rarity, permanent)
    if onServer() then
        removeDynamicBuffs()
    end
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
    return "Ascendant War-Drive"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/power-generator.png"
end

function getEnergy(seed, rarity)
    return 0 -- Ascendant Relics cost no energy
end

function getPrice(seed, rarity)
    return 1000000000 -- 1 Billion Base Value
end

function getTooltipLines(seed, rarity, permanent)
    local texts = {}
    table.insert(texts, {ltext = "Base Armed Turrets"%_t, rtext = "+10", icon = "data/textures/icons/turret.png", boosted = false})
    table.insert(texts, {ltext = "Base Any Turrets"%_t, rtext = "+5", icon = "data/textures/icons/turret.png", boosted = false})
    table.insert(texts, {ltext = "Base Energy"%_t, rtext = "+200%", icon = "data/textures/icons/electric.png", boosted = false})
    table.insert(texts, {ltext = "Base Fire Rate"%_t, rtext = "+50%", icon = "data/textures/icons/bullets.png", boosted = false})
    
    table.insert(texts, {ltext = "", rtext = "", icon = ""})
    table.insert(texts, {ltext = "\\c(e44)LIVING RELIC\\c()"%_t, rtext = "", icon = ""})
    table.insert(texts, {ltext = "Stats multiply based on"%_t, rtext = "", icon = ""})
    table.insert(texts, {ltext = "Core Proximity & War Heat!"%_t, rtext = "", icon = ""})
    
    return texts
end
