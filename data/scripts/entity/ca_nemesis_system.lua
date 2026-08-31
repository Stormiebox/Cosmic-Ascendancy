package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local damageTracker = {}

function initialize()
    if onServer() then
        local entity = Entity()
        entity:registerCallback("onDamaged", "onDamaged")
        entity:registerCallback("onShieldDamaged", "onShieldDamaged")
        -- Always registered (not gated on the "hunted" flag here) since ca_nemesis_hunt.lua sets
        -- that flag on this same entity only after createShip() returns, which is after this
        -- initialize() has already run -- checking the flag inside onDestroyed instead, once the
        -- entity has existed long enough for the flag to definitely be set, avoids that race.
        entity:registerCallback("onDestroyed", "onDestroyed")
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

        -- Hunt the Dread-Lord: relocate it to a nearby sector instead of just vanishing, so players
        -- can track it down and finish the fight instead of the retreat being a dead end (see
        -- ca_nemesis_hunt.lua, which materializes it there when a player arrives).
        local x, y = Sector():getCoordinates()
        local MissionUT = include("missionutility")
        local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
        local hx, hy = MissionUT.getEmptySector(x, y, 5, 20, insideBarrier)
        if hx and hy then
            Server():setValue("eclipse_nemesis_hunt", {x = hx, y = hy, time = now, spawned = false})
        end

        -- Broadcast dramatic retreat
        local sector = Sector()
        sector:broadcastChatMessage(entity.title, 2, "CRITICAL DAMAGE DETECTED. ADAPTING SHIELDS. INITIATING TACTICAL RETREAT.")

        -- Remove the entity (Jump away)
        sector:deleteEntityJumped(entity)
    end
end

function onDestroyed()
    if not onServer() then return end
    local entity = Entity()
    if not entity or not entity:getValue("ca_nemesis_hunted") then return end

    local hunt = Server():getValue("eclipse_nemesis_hunt")
    if not hunt then return end -- already cleared, or this wasn't actually the tracked one

    Server():setValue("eclipse_nemesis_hunt", nil)

    local sector = Sector()
    sector:broadcastChatMessage("System"%_T, 0, "The hunted Dread-Lord has finally been destroyed!"%_T)
    for _, player in pairs({sector:getPlayers()}) do
        player:receive("Nemesis Bounty"%_T, 10000000)
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
