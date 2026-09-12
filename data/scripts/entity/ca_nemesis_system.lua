package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local damageTracker = {}
local EncounterBridge = include("ca_encounter_bridge")
local OWNER = "data/scripts/entity/ca_nemesis_system.lua"

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
        local hunts = EncounterBridge.List("nemesis") or {}
        local lastRetreat = 0
        for _, hunt in ipairs(hunts) do
            lastRetreat = math.max(lastRetreat, hunt.createdAt or hunt.engagedAt or 0)
        end
        
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
        
        -- Hunt the Dread-Lord: relocate it to a nearby sector instead of just vanishing, so players
        -- can track it down and finish the fight instead of the retreat being a dead end (see
        -- ca_nemesis_hunt.lua, which materializes it there when a player arrives). The
        -- spawn-gating record stays a single shared Server() value -- there's only ever one
        -- wounded Dread-Lord in flight at a time (the 2-hour cooldown above prevents a second
        -- retreat from ever racing this one), and ca_nemesis_hunt.lua's spawned-once check needs
        -- exactly one shared record to guard against a double-spawn if two players reach the hunt
        -- sector in the same tick. What WAS broken is personal visibility: every player physically
        -- present for this retreat also gets their own copy for their own /eclipsestatus and the
        -- Command Interface, so a later, unrelated retreat overwriting the shared record doesn't
        -- silently erase what THIS retreat's witnesses already know.
        local x, y = Sector():getCoordinates()
        local MissionUT = include("missionutility")
        local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
        local hx, hy = MissionUT.getEmptySector(x, y, 5, 20, insideBarrier)
        if hx and hy then
            local encounterId = EncounterBridge.MakeId("nemesis", "galaxy", hx, hy, math.floor(now))
            local participants = {}
            for _, witness in pairs({Sector():getPlayers()}) do table.insert(participants, witness.index) end
            table.sort(participants)
            local prepared = EncounterBridge.Create(OWNER, {
                encounterId = encounterId,
                kind = "nemesis",
                concurrencyKey = "nemesis:galaxy",
                scope = "galaxy",
                x = hx, y = hy,
                resistanceType = highestType,
                participants = participants,
                createdAt = now,
                state = "prepared"
            })
            if not prepared then return end
        else
            return
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

    local encounterId = entity:getValue("ca_encounter_id")
    local hunt = encounterId and EncounterBridge.Get(encounterId)
    if not hunt or hunt.kind ~= "nemesis" or hunt.entityId ~= entity.id.string
            or hunt.state ~= "active" then return end

    local sector = Sector()
    local participants = {}
    for _, player in pairs({sector:getPlayers()}) do table.insert(participants, player.index) end
    table.sort(participants)
    local resolving = EncounterBridge.Transition(OWNER, encounterId, "resolving", {
        participants = participants, resolution = {reason = "verified_destroyed", entityId = entity.id.string}
    })
    if not resolving then return end

    sector:broadcastChatMessage("System"%_T, 0, "The hunted Dread-Lord has finally been destroyed!"%_T)
    for _, playerIndex in ipairs(participants) do
        local player = Player(playerIndex)
        local operationId = encounterId .. ":player:" .. playerIndex .. ":reward"
        local receipt = EncounterBridge.PrepareReceipt(OWNER, {
            operationId = operationId, kind = "nemesis_reward",
            encounterId = encounterId, recipient = {playerIndex = playerIndex},
            reissue = {mode = "coordinator_credit", credits = 10000000,
                reason = "Nemesis Bounty"}
        })
        if not receipt then
            EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
                lastError = "reward_receipt_prepare_failed:" .. operationId})
            return
        end
        local before = player.money or 0
        player:receive("Nemesis Bounty"%_T, 10000000)
        if (player.money or 0) < before + 10000000 then
            EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
                lastError = "reward_delivery_unverified:" .. operationId})
            return
        end
        if not EncounterBridge.CompleteReceipt(OWNER, operationId, {
                credits = 10000000, before = before, after = player.money}) then
            EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
                lastError = "reward_receipt_completion_ambiguous:" .. operationId})
            return
        end
    end
    local succeeded = EncounterBridge.Transition(OWNER, encounterId, "succeeded", {
        participants = participants, resolution = {reason = "verified_destroyed", entityId = entity.id.string}
    })
    if not succeeded then
        EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
            lastError = "nemesis_terminal_transition_failed"
        })
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
