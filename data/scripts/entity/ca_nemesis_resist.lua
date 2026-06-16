package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local resistType = nil

function initialize(damageType)
    resistType = damageType or DamageType.Physical
    
    if onServer() then
        local entity = Entity()
        
        -- Apply massive damage reduction to the specific element
        local modifier = 0.1 -- Takes only 10% damage from this element
        
        if resistType == DamageType.Physical then
            entity:addMultiplyableFactor(StatsBonuses.PhysicalDamageReceived, modifier)
        elseif resistType == DamageType.Plasma then
            entity:addMultiplyableFactor(StatsBonuses.PlasmaDamageReceived, modifier)
        elseif resistType == DamageType.Antimatter then
            entity:addMultiplyableFactor(StatsBonuses.AntimatterDamageReceived, modifier)
        elseif resistType == DamageType.Electric then
            entity:addMultiplyableFactor(StatsBonuses.ElectricDamageReceived, modifier)
        end
        
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
    local maxAllowedDamage = maxDurability * 0.08
    
    if amount > maxAllowedDamage then
        local excessDamage = amount - maxAllowedDamage
        entity.durability = math.min(entity.durability + excessDamage, maxDurability)
    end
end

function onShieldDamaged(objectIndex, amount, inflictor, damageSource, damageType)
    local entity = Entity()
    local maxShield = entity.shieldMaxDurability
    if not maxShield or maxShield <= 0 then return end
    
    local maxAllowedDamage = maxShield * 0.08
    
    if amount > maxAllowedDamage then
        local excessDamage = amount - maxAllowedDamage
        local newShield = math.min(entity.shieldDurability + excessDamage, maxShield)
        entity.shieldDurability = newShield
    end
end
