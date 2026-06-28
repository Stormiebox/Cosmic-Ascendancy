package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local damageTracker = {}

function initialize()
    if onServer() then
        local entity = Entity()
        entity:registerCallback("onDamaged", "onDamaged")
    end
end

function onDamaged(objectIndex, amount, inflictor, damageType)
    local entity = Entity()
    if not entity then return end
    
    -- 8% Damage Gate Logic
    local maxTotalHealth = entity.maxDurability + entity.shieldMaxDurability
    local damageLimit = maxTotalHealth * 0.08
    
    if amount > damageLimit then
        local excess = amount - damageLimit
        
        -- Restore the excess damage to prevent one-shots
        if entity.shieldDurability and entity.shieldDurability > 0 then
            entity.shieldDurability = math.min(entity.shieldMaxDurability, entity.shieldDurability + excess)
        else
            entity.durability = math.min(entity.maxDurability, entity.durability + excess)
        end
        
        -- Update the amount actually processed for our tracker
        amount = damageLimit
    end
    
    -- Track incoming damage
    damageType = damageType or DamageType.Physical
    damageTracker[damageType] = (damageTracker[damageType] or 0) + amount
    
    -- Check if HP is below 5%
    if entity.durability / entity.maxDurability <= 0.05 then
        -- Find highest damage type
        local highestType = DamageType.Physical
        local highestDamage = 0
        for dtype, dmg in pairs(damageTracker) do
            if dmg > highestDamage then
                highestDamage = dmg
                highestType = dtype
            end
        end
        
        -- Save the nemesis resist to server globally
        Server():setValue("eclipse_nemesis_resist", highestType)
        
        -- Broadcast dramatic retreat
        local sector = Sector()
        sector:broadcastChatMessage(entity.title, 2, "CRITICAL DAMAGE DETECTED. ADAPTING SHIELDS. INITIATING TACTICAL RETREAT.")
        
        -- Remove the entity (Jump away)
        local jumpArgs = {
            effect = 1, -- Hyperspace effect
            x = 0, y = 0
        }
        sector:deleteEntityJumped(entity)
    end
end
