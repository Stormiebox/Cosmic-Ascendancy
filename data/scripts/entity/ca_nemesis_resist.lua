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
    if data then
        resistType = data.type
    end
end

-- The 8%-of-max-health damage gate lives solely in ca_nemesis_system.lua now, which is attached to
-- every Harbinger alongside this script and receives the exact same onDamaged/onShieldDamaged
-- callbacks independently. Both scripts used to apply their own separate 8% cap-and-refund pass on
-- top of each other -- on a hit above the cap, the excess got refunded twice, and on the ship's own
-- resisted damage type the 90% reduction below plus the second 8% refund could exceed the damage
-- actually dealt, healing the ship instead of hurting it. This script's job is only the type-specific
-- 90% reduction; ca_nemesis_system.lua enforces the shared cap on whatever damage remains.
function onDamaged(objectIndex, amount, inflictor, damageSource, damageType)
    if damageType ~= resistType then return end
    local entity = Entity()
    local resisted = amount * 0.90
    entity.durability = math.min(entity.durability + resisted, entity.maxDurability)
end

function onShieldDamaged(objectIndex, amount, damageType, inflictor)
    if damageType ~= resistType then return end
    local entity = Entity()
    local maxShield = entity.shieldMaxDurability
    if not maxShield or maxShield <= 0 then return end
    local resisted = amount * 0.90
    entity.shieldDurability = math.min(entity.shieldDurability + resisted, maxShield)
end
