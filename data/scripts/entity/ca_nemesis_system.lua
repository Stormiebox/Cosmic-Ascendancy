package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local damageTracker = {}

function initialize()
    if onServer() then
        local entity = Entity()
        entity:registerCallback("onDamaged", "onDamaged")
        entity:registerCallback("onShieldDamaged", "onShieldDamaged")
    end
end

function secure()
    return { damageTracker = damageTracker }
end

function restore(data)
    data = data or {}
    damageTracker = data.damageTracker or {}
end

function trackAndCheckRetreat(entity, amount, damageType)
    -- Track incoming damage
    damageType = damageType or DamageType.Physical
    damageTracker[damageType] = (damageTracker[damageType] or 0) + amount
    
    -- Check if HP is below 5%
    if entity.durability / entity.maxDurability <= 0.05 then
        local now = Server().unpausedRuntime
        local lastRetreat = Server():getValue("eclipse_nemesis_last_retreat") or 0
        
        -- 2-Hour Global Cooldown (7200 seconds)
        if now - lastRetreat < 7200 then
            -- Cooldown is active. The Eclipse cannot adapt right now. Fight to the death!
            return
        end
        
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
        Server():setValue("eclipse_nemesis_last_retreat", now)
        
        -- Broadcast dramatic retreat
        local sector = Sector()
        sector:broadcastChatMessage(entity.title, 2, "CRITICAL DAMAGE DETECTED. ADAPTING SHIELDS. INITIATING TACTICAL RETREAT.")
        
        -- Remove the entity (Jump away)
        sector:deleteEntityJumped(entity)
    end
end

function onDamaged(objectIndex, amount, inflictor, damageSource, damageType)
    local entity = Entity()
    if not entity then return end
    
    -- 8% Damage Gate Logic
    local maxTotalHealth = entity.maxDurability + (entity.shieldMaxDurability or 0)
    local damageLimit = maxTotalHealth * 0.08
    
    if amount > damageLimit then
        local excess = amount - damageLimit
        entity.durability = math.min(entity.maxDurability, entity.durability + excess)
        amount = damageLimit
    end
    
    trackAndCheckRetreat(entity, amount, damageType)
end

function onShieldDamaged(objectIndex, amount, damageType, inflictor)
    local entity = Entity()
    if not entity then return end
    
    -- 8% Damage Gate Logic
    local maxTotalHealth = entity.maxDurability + (entity.shieldMaxDurability or 0)
    local damageLimit = maxTotalHealth * 0.08
    
    if amount > damageLimit then
        local excess = amount - damageLimit
        entity.shieldDurability = math.min(entity.shieldMaxDurability, entity.shieldDurability + excess)
        amount = damageLimit
    end
    
    trackAndCheckRetreat(entity, amount, damageType)
end
