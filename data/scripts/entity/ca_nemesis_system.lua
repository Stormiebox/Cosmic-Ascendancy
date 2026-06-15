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
