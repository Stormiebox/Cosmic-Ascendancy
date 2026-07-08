package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("basesystem")
include ("utility")
local cv_buffs = include("cosmicvaultbuffs")


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
    local finalMultiplier = 1.0
    if cv_buffs and type(cv_buffs.getDynamicRelicMultiplier) == "function" then
        finalMultiplier = cv_buffs.getDynamicRelicMultiplier(entity.id)
    end
    
    -- Apply Base Stats multiplied by finalMultiplier
    -- War-Drive gives Armed/Arbitrary Turrets, Energy, and FireRate
    entity:addAbsoluteBias(StatsBonuses.ArmedTurrets, math.floor(3 * finalMultiplier))
    entity:addAbsoluteBias(StatsBonuses.ArbitraryTurrets, math.floor(2 * finalMultiplier))
    entity:addMultiplier(StatsBonuses.GeneratedEnergy, 2.0 * finalMultiplier)
    entity:addMultiplier(StatsBonuses.FireRate, 0.5 * finalMultiplier)
end

function removeDynamicBuffs()
    local entity = Entity()
    if not entity then return end
    entity:removeScriptBonuses()
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
    return data
end

local base_restore = restore
function restore(data)
    if base_restore then base_restore(data) end
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
