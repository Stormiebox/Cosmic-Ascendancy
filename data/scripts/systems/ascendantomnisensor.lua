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

    -- Omni-Sensor gives Radar, Hidden Sector, Cargo, and Loot Range
    entity:addAbsoluteBias(StatsBonuses.RadarReach, math.floor(20 * finalMultiplier))
    entity:addAbsoluteBias(StatsBonuses.HiddenSectorRadarReach, math.floor(15 * finalMultiplier))
    entity:addBaseMultiplier(StatsBonuses.CargoHold, 10.0 * finalMultiplier)
    entity:addAbsoluteBias(StatsBonuses.LootCollectionRange, 2500 * finalMultiplier)
end

function removeDynamicBuffs()
    local entity = Entity()
    if not entity then return end
    entity:removeScriptBonuses()
end

function onInstalled(seed, rarity, permanent)
    if onServer() then 
        applyDynamicBuffs() 
        Entity():registerCallback("onSectorEntered", "onSectorEntered")
    end
end

function onUninstalled(seed, rarity, permanent)
    if onServer() then 
        removeDynamicBuffs() 
        Entity():unregisterCallback("onSectorEntered", "onSectorEntered")
    end
end

function onSectorEntered(playerIndex, x, y, sectorChangeType)
    if onServer() then
        local sector = Sector()
        local player = Player(playerIndex)
        if not player then return end

        local stashesFound = 0
        local asteroidsFound = 0

        local wreckages = {sector:getEntitiesByType(EntityType.Wreckage)}
        for _, w in pairs(wreckages) do
            if w.title == "Hidden Stash" or w.title == "Corrupted Databank Stash"%_t then
                stashesFound = stashesFound + 1
            end
        end

        local asteroids = {sector:getEntitiesByType(EntityType.Asteroid)}
        for _, a in pairs(asteroids) do
            if a:hasScript("claim.lua") then
                asteroidsFound = asteroidsFound + 1
            end
        end

        if stashesFound > 0 or asteroidsFound > 0 then
            local msg = "Omni-Sensor Deep Scan Complete. Detected: "
            if stashesFound > 0 then msg = msg .. stashesFound .. " Hidden Stash(es). " end
            if asteroidsFound > 0 then msg = msg .. asteroidsFound .. " Claimable Asteroid(s)." end
            player:sendChatMessage("Omni-Sensor", 3, msg)
        end
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
    return "Ascendant Omni-Sensor"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/AscendantOmniSensor.png"
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
    table.insert(texts, {ltext = "Base Loot Range"%_t, rtext = "+2500", icon = "data/textures/icons/domino-mask.png", boosted = false})

    table.insert(texts, {ltext = "", rtext = "", icon = ""})
    table.insert(texts, {ltext = "\\c(e44)LIVING RELIC\\c()"%_t, rtext = "", icon = ""})
    table.insert(texts, {ltext = "Stats multiply based on"%_t, rtext = "", icon = ""})
    table.insert(texts, {ltext = "Core Proximity & War Heat!"%_t, rtext = "", icon = ""})

    return texts
end
