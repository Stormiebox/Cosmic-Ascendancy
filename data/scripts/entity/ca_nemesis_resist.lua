package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local resistType = nil

function initialize(damageType)
    resistType = damageType or DamageType.Physical

    if onServer() then
        local entity = Entity()

        -- We apply a 90% damage reduction for the specific element inside the onDamaged callbacks

        entity:registerCallback("onDamaged", "onDamaged")
        entity:registerCallback("onShieldDamaged", "onShieldDamaged")

        -- Alert players that it has adapted
        Sector():broadcastChatMessage(entity.title, 2, "ADAPTATION COMPLETE. NEMESIS PROTOCOLS ENGAGED.")
    end
end

function secure()
    return { type = resistType }
end

function restore(data)
    resistType = data.type
end

function onDamaged(objectIndex, amount, inflictor, damageSource, damageType)
    local entity = Entity()
    local maxDurability = entity.maxDurability

    local damageTaken = amount
    if damageType == resistType then
        local resisted = amount * 0.90
        entity.durability = math.min(entity.durability + resisted, maxDurability)
        damageTaken = amount - resisted
    end

    local maxAllowedDamage = maxDurability * 0.08

    if damageTaken > maxAllowedDamage then
        local excessDamage = damageTaken - maxAllowedDamage
        entity.durability = math.min(entity.durability + excessDamage, maxDurability)
    end
end

function onShieldDamaged(objectIndex, amount, inflictor, damageSource, damageType)
    local entity = Entity()
    local maxShield = entity.shieldMaxDurability
    if not maxShield or maxShield <= 0 then return end

    local damageTaken = amount
    if damageType == resistType then
        local resisted = amount * 0.90
        entity.shieldDurability = math.min(entity.shieldDurability + resisted, maxShield)
        damageTaken = amount - resisted
    end

    local maxAllowedDamage = maxShield * 0.08

    if damageTaken > maxAllowedDamage then
        local excessDamage = damageTaken - maxAllowedDamage
        entity.shieldDurability = math.min(entity.shieldDurability + excessDamage, maxShield)
    end
end
