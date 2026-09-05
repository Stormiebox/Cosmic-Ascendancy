package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("basesystem")
include ("utility")

-- Matches the vanilla convention (shieldbooster.lua, hyperspacebooster.lua, etc.): getEnergy()
-- returns a constant here, so this tells the engine it never needs to re-read it every frame.
FixedEnergyRequirement = true

-- Ascendant Neural Implant
-- An equippable subsystem that massive augments the ship's captain,
-- providing massive bonuses to fleet control, turrets, and engine output.

function getBonuses(seed, rarity, permanent)
    -- As an Ascendant item, its stats are fixed and absurd.
    local armed = 10
    local unarmed = 10
    local squads = 3
    local energy = 0.50 -- +50% generated energy
    local speed = 0.30 -- +30% velocity
    local jump = 15 -- +15 sector reach

    if permanent then
        armed = armed * 2
        unarmed = unarmed * 2
        squads = squads * 2
        energy = energy * 1.5
        speed = speed * 1.5
        jump = jump * 2
    end

    return armed, unarmed, squads, energy, speed, jump
end

function onInstalled(seed, rarity, permanent)
    local armed, unarmed, squads, energy, speed, jump = getBonuses(seed, rarity, permanent)

    addAbsoluteBias(StatsBonuses.ArmedTurrets, armed)
    addAbsoluteBias(StatsBonuses.UnarmedTurrets, unarmed)
    addAbsoluteBias(StatsBonuses.FighterSquads, squads)
    addBaseMultiplier(StatsBonuses.GeneratedEnergy, energy)
    addBaseMultiplier(StatsBonuses.Velocity, speed)
    addAbsoluteBias(StatsBonuses.HyperspaceReach, jump)
end

function onUninstalled(seed, rarity, permanent)
    -- Handled automatically by Avorion engine
end

function getName(seed, rarity)
    return "Ascendant Neural Implant"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/AscendantImplant.png"
end

function getPrice(seed, rarity)
    return 150000000
end

function getTooltipLines(seed, rarity, permanent)
    local texts = {}
    local armed, unarmed, squads, energy, speed, jump = getBonuses(seed, rarity, permanent)

    table.insert(texts, {ltext = "Armed Turrets"%_t, rtext = string.format("%+d", armed), icon = "data/textures/icons/turret.png"})
    table.insert(texts, {ltext = "Unarmed Turrets"%_t, rtext = string.format("%+d", unarmed), icon = "data/textures/icons/turret.png"})
    table.insert(texts, {ltext = "Fighter Squadrons"%_t, rtext = string.format("%+d", squads), icon = "data/textures/icons/fighter.png"})
    table.insert(texts, {ltext = "Generated Energy"%_t, rtext = string.format("%+d%%", math.floor(energy * 100)), icon = "data/textures/icons/electric.png"})
    table.insert(texts, {ltext = "Max Velocity"%_t, rtext = string.format("%+d%%", math.floor(speed * 100)), icon = "data/textures/icons/acceleration.png"})
    table.insert(texts, {ltext = "Jump Reach"%_t, rtext = string.format("%+d", jump), icon = "data/textures/icons/stars-stack.png"})

    if not permanent then
        table.insert(texts, {ltext = "Permanent Installation:"%_t, rtext = "", icon = ""})
        table.insert(texts, {ltext = "Massively boosts all bonuses."%_t, rtext = "", icon = ""})
    end

    return texts
end

function getDescriptionLines(seed, rarity, permanent)
    return
    {
        {ltext = "A terrifying fusion of Eclipse technology and human neuro-links."%_t, rtext = "", icon = ""},
        {ltext = "Grants the captain supernatural reflexes and processing power."%_t, rtext = "", icon = ""}
    }
end
