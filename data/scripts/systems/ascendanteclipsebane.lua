package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("basesystem")


function getFixedStats()
    return {
        {stat = StatsBonuses.ShieldDurability, amount = 0.50},
        {stat = StatsBonuses.HullDurability, amount = 0.50},
        {stat = StatsBonuses.ArbitraryTurrets, amount = 5},
        {stat = StatsBonuses.HyperspaceReach, amount = 5},
        {stat = StatsBonuses.FireRate, amount = 0.25}
    }
end

function onInstalled(seed, rarity, permanent)
    for _, bonus in pairs(getFixedStats()) do
        if bonus.stat == StatsBonuses.ArbitraryTurrets or bonus.stat == StatsBonuses.HyperspaceReach then
            addAbsoluteBias(bonus.stat, bonus.amount)
        else
            addMultiplyableBias(bonus.stat, bonus.amount)
        end
    end
end

function onUninstalled(seed, rarity, permanent)
end

function getName(seed, rarity)
    return "The Eclipse Bane"
end

function getIcon(seed, rarity)
    return "data/textures/icons/EclipseBane.png"
end

function getPrice(seed, rarity)
    return 15000000
end

function getTooltipLines(seed, rarity, permanent)
    local texts = {}
    table.insert(texts, {ltext = "Forged from the remnants of the Vanguard. Tuned to destroy The Eclipse.", lcolor = ColorRGB(1, 0.5, 0)})
    table.insert(texts, {ltext = "Shield Durability", rtext = "+50%", icon = "data/textures/icons/shield.png"})
    table.insert(texts, {ltext = "Hull Durability", rtext = "+50%", icon = "data/textures/icons/health-normal.png"})
    table.insert(texts, {ltext = "Arbitrary Turret Slots", rtext = "+5", icon = "data/textures/icons/turret.png"})
    table.insert(texts, {ltext = "Jump Range", rtext = "+5", icon = "data/textures/icons/jump-range.png"})
    table.insert(texts, {ltext = "All Damage (Anti-Eclipse)", rtext = "+25%", icon = "data/textures/icons/explosion.png"})
    return texts
end
