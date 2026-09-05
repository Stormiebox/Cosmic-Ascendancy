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
local squadsKey = nil
local pilotsKey = nil
local cargoPickupKey = nil
local productionKey = nil

function applyDynamicBuffs()
    removeDynamicBuffs()

    local entity = Entity()
    if not entity then return end

    local finalMultiplier = 1.0
    if cv_buffs and type(cv_buffs.getDynamicRelicMultiplier) == "function" then
        finalMultiplier = cv_buffs.getDynamicRelicMultiplier(entity.id)
    end

    -- In Avorion, fighter damage cannot be modified via StatsBonuses.
    -- Instead, this subsystem maxes out Carrier capabilities and production.
    squadsKey = entity:addAbsoluteBias(StatsBonuses.FighterSquads, 10)
    pilotsKey = entity:addAbsoluteBias(StatsBonuses.Pilots, 120)
    cargoPickupKey = entity:addAbsoluteBias(StatsBonuses.FighterCargoPickup, 1)

    -- Base capacity of 50,000 multiplied dynamically
    productionKey = entity:addAbsoluteBias(StatsBonuses.ProductionCapacity, 50000 * finalMultiplier)
end

function removeDynamicBuffs()
    local entity = Entity()
    if not entity then return end
    if squadsKey then entity:removeBonus(squadsKey); squadsKey = nil end
    if pilotsKey then entity:removeBonus(pilotsKey); pilotsKey = nil end
    if cargoPickupKey then entity:removeBonus(cargoPickupKey); cargoPickupKey = nil end
    if productionKey then entity:removeBonus(productionKey); productionKey = nil end
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
    return "Ascendant Swarm Nexus"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/AscendantSwarm.png"
end

function getEnergy(seed, rarity)
    return 0
end

function getPrice(seed, rarity)
    return 1000000000
end

function getTooltipLines(seed, rarity, permanent)
    local texts = {}
    table.insert(texts, {ltext = "Fighter Squadrons"%_t, rtext = "+10", icon = "data/textures/icons/fighter.png", boosted = false})
    table.insert(texts, {ltext = "Base Pilots"%_t, rtext = "+120", icon = "data/textures/icons/crew.png", boosted = false})
    table.insert(texts, {ltext = "Fighter Cargo Pickup"%_t, rtext = "Yes", icon = "data/textures/icons/fighter.png", boosted = false})
    table.insert(texts, {ltext = "Base Production Speed"%_t, rtext = "+50000", icon = "data/textures/icons/gears.png", boosted = false})

    table.insert(texts, {ltext = "", rtext = "", icon = ""})
    table.insert(texts, {ltext = "\\c(e44)LIVING RELIC\\c()"%_t, rtext = "", icon = ""})
    table.insert(texts, {ltext = "Production scales dynamically with"%_t, rtext = "", icon = ""})
    table.insert(texts, {ltext = "Core Proximity & War Heat!"%_t, rtext = "", icon = ""})

    return texts
end
