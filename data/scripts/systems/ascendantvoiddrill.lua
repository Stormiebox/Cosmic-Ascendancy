package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("basesystem")
include ("utility")
local cv_buffs = include("cosmicvaultbuffs")

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
    
    local finalMultiplier = 1.0
    if cv_buffs and type(cv_buffs.getDynamicRelicMultiplier) == "function" then
        finalMultiplier = cv_buffs.getDynamicRelicMultiplier(entity.id)
    end
    
    entity:addAbsoluteBias(StatsBonuses.UnarmedTurrets, 15)
    
    -- Dynamically scaled capabilities
    entity:addAbsoluteBias(StatsBonuses.LootCollectionRange, 5000 * finalMultiplier)
    entity:addAbsoluteBias(StatsBonuses.TransporterRange, 5000 * finalMultiplier)
    entity:addMultiplyableBias(StatsBonuses.GeneratedEnergy, 5.0 * finalMultiplier)
end

function removeDynamicBuffs()
    local entity = Entity()
    if not entity then return end
    entity:removeScriptBonuses()
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
    return data
end

local base_restore = restore
function restore(data)
    if base_restore then base_restore(data) end
end

function getName(seed, rarity)
    return "Ascendant Void-Drill"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/mining-laser.png"
end

function getEnergy(seed, rarity)
    return 0
end

function getPrice(seed, rarity)
    return 1000000000
end

function getTooltipLines(seed, rarity, permanent)
    local texts = {}
    table.insert(texts, {ltext = "Civilian Turrets"%_t, rtext = "+15", icon = "data/textures/icons/turret.png", boosted = false})
    table.insert(texts, {ltext = "Base Loot Range"%_t, rtext = "+5000", icon = "data/textures/icons/magnet.png", boosted = false})
    table.insert(texts, {ltext = "Base Transporter Range"%_t, rtext = "+5000", icon = "data/textures/icons/processor.png", boosted = false})
    table.insert(texts, {ltext = "Base Energy Generation"%_t, rtext = "+500%", icon = "data/textures/icons/electric.png", boosted = false})
    
    table.insert(texts, {ltext = "", rtext = "", icon = ""})
    table.insert(texts, {ltext = "\\c(e44)LIVING RELIC\\c()"%_t, rtext = "", icon = ""})
    table.insert(texts, {ltext = "Utility scales dynamically with"%_t, rtext = "", icon = ""})
    table.insert(texts, {ltext = "Core Proximity & War Heat!"%_t, rtext = "", icon = ""})
    
    return texts
end
