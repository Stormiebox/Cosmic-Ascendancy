package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"


function getFixedStats()
    return {
        {stat = StatsBonuses.ShieldDurability, amount = 0.50},
        {stat = StatsBonuses.ArmedTurrets, amount = 5},
        {stat = StatsBonuses.HyperspaceReach, amount = 5},
        {stat = StatsBonuses.EnergyDamage, amount = 0.25},
        {stat = StatsBonuses.ElectricDamage, amount = 0.25},
        {stat = StatsBonuses.PlasmaDamage, amount = 0.25},
        {stat = StatsBonuses.AntiMatterDamage, amount = 0.25},
        {stat = StatsBonuses.FragmentsDamage, amount = 0.25},
        {stat = StatsBonuses.PhysicalDamage, amount = 0.25}
    }
end

function onInstalled(seed, rarity, permanent)
    if not permanent then return end
    for _, bonus in pairs(getFixedStats()) do
        if bonus.stat == StatsBonuses.ArmedTurrets or bonus.stat == StatsBonuses.HyperspaceReach then
            addBaseMultiplier(bonus.stat, bonus.amount)
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
    return "data/textures/icons/circuitry.png"
end

function getPrice(seed, rarity)
    return 15000000
end

function getTooltipLines(seed, rarity, tooltip)
    table.insert(tooltip, {ltext = "Forged from the remnants of the Vanguard. Tuned to destroy The Eclipse.", lcolor = ColorRGB(1, 0.5, 0)})
    table.insert(tooltip, {ltext = "Shield Durability", rtext = "+50%", icon = "data/textures/icons/shield.png"})
    table.insert(tooltip, {ltext = "Hull Durability", rtext = "+50%", icon = "data/textures/icons/health-normal.png"})
    table.insert(tooltip, {ltext = "Arbitrary Turret Slots", rtext = "+5", icon = "data/textures/icons/turret.png"})
    table.insert(tooltip, {ltext = "Jump Range", rtext = "+5", icon = "data/textures/icons/jump-range.png"})
    table.insert(tooltip, {ltext = "All Damage (Anti-Eclipse)", rtext = "+25%", icon = "data/textures/icons/explosion.png"})
end
