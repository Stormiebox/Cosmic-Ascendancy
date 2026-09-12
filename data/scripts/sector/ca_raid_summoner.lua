package.path = package.path .. ";data/scripts/lib/?.lua"

local EclipseGenerator = include("eclipsegenerator")
local EncounterBridge = include("ca_encounter_bridge")
local OWNER = "data/scripts/sector/ca_raid_summoner.lua"
local spawnedRaid = false
local encounterId
local bossId
local pendingRaid

local function materializePendingRaid()
    if not pendingRaid or spawnedRaid then return end
    local lootEntity = Entity(Uuid(pendingRaid.lootEntityId))
    if not valid(lootEntity) then
        EncounterBridge.Transition(OWNER, pendingRaid.encounterId, "repair_required", {
            lastError = "summoning_datacore_missing_before_materialization"
        })
        pendingRaid = nil
        return
    end
    local encounter = EncounterBridge.Get(pendingRaid.encounterId)
    if encounter and encounter.state == "retryable" then
        if not EncounterBridge.Transition(OWNER, pendingRaid.encounterId, "prepared") then return end
    end
    if not EncounterBridge.Transition(OWNER, pendingRaid.encounterId, "materializing", {
            attempts = pendingRaid.attempts or 0}) then return end
    pendingRaid.attempts = (pendingRaid.attempts or 0) + 1
    local pos = MatrixLookUpPosition(vec3(0,0,1), vec3(0,1,0), vec3(0, 0, 0))
    local boss = EclipseGenerator.createWorldEater(pos)
    if not boss then
        if pendingRaid.attempts < 5 then
            pendingRaid.nextAttemptAt = Server().unpausedRuntime + (pendingRaid.attempts * 10)
            EncounterBridge.Transition(OWNER, pendingRaid.encounterId, "retryable", {
                attempts = pendingRaid.attempts,
                nextAttemptAt = pendingRaid.nextAttemptAt,
                lastError = "summoned_boss_spawn_failed"
            })
        else
            EncounterBridge.Transition(OWNER, pendingRaid.encounterId, "repair_required", {
                attempts = pendingRaid.attempts,
                lastError = "summoned_boss_spawn_failed_after_five_attempts"
            })
            pendingRaid = nil
        end
        return
    end
    EclipseGenerator.applyWorldEaterMultiplayerScaling(boss)
    local activated = EncounterBridge.TagAndActivate(OWNER, pendingRaid.encounterId, boss, {
        attempts = pendingRaid.attempts
    })
    if not activated then
        boss:setValue("ca_encounter_id", pendingRaid.encounterId)
        EncounterBridge.Transition(OWNER, pendingRaid.encounterId, "repair_required", {
            entityId = boss.id.string,
            lastError = "summoned_boss_registration_failed"
        })
        pendingRaid = nil
        return
    end
    boss:registerCallback("onDestroyed", "onRaidBossDestroyed")
    encounterId = pendingRaid.encounterId
    bossId = boss.id.string
    spawnedRaid = true
    Sector():deleteEntity(lootEntity)
    Sector():broadcastChatMessage("System", 0,
        "WARNING: Quantum Datacore rupture detected. Massive spatial anomaly opening!")
    Sector():broadcastChatMessage(boss.title, 2, "WHO DARES DISTURB THE VOID.")
    pendingRaid = nil
end

function initialize()
    if onServer() then
        Sector():registerCallback("onEntityCreated", "onEntityCreated")
    end
end

function onEntityCreated(entityId)
    if not onServer() then return end
    if spawnedRaid or pendingRaid then return end

    local entity = Entity(entityId)
    if not entity then return end

    if entity:hasComponent(ComponentType.CargoLoot) then
        local loot = CargoLoot(entity)
        if loot and loot:matches("Eclipse Datacore") then
            -- We must ensure the player dropped this, and it didn't just drop from a dying Juggernaut.
            -- Juggernauts belong to the Eclipse faction. So if there are no Eclipse ships currently here,
            -- the player must have brought this Datacore here manually.
            local faction = EclipseGenerator.getFaction()
            if not faction then return end
            
            local sector = Sector()
            local eclipseEntities = {sector:getEntitiesByFaction(faction.index)}
            
            if #eclipseEntities == 0 then
                local x, y = sector:getCoordinates()
                local preparedId = EncounterBridge.MakeId(
                    "summoned_world_eater", "sector", x, y, math.floor(Server().unpausedRuntime))
                local prepared = EncounterBridge.Create(OWNER, {
                    encounterId = preparedId,
                    kind = "summoned_world_eater",
                    concurrencyKey = "summoned_world_eater:" .. x .. ":" .. y,
                    scope = "sector", x = x, y = y, state = "prepared"
                })
                if not prepared then return end
                pendingRaid = {encounterId = preparedId, lootEntityId = entity.id.string,
                    attempts = 0, nextAttemptAt = Server().unpausedRuntime}
                materializePendingRaid()
            end
        end
    end
end

function getUpdateInterval()
    return 5
end

function updateServer(timeStep)
    if pendingRaid and Server().unpausedRuntime >= (pendingRaid.nextAttemptAt or 0) then
        materializePendingRaid()
    end
end

function onRaidBossDestroyed()
    if not encounterId or not bossId then return end
    local encounter = EncounterBridge.Get(encounterId)
    if not encounter or encounter.entityId ~= bossId or encounter.state ~= "active" then return end
    local participants = {}
    for _, player in pairs({Sector():getPlayers()}) do table.insert(participants, player.index) end
    table.sort(participants)
    local resolving = EncounterBridge.Transition(OWNER, encounterId, "resolving", {
        participants = participants, resolution = {reason = "verified_destroyed", entityId = bossId}
    })
    if resolving then
        local succeeded = EncounterBridge.Transition(OWNER, encounterId, "succeeded", {
            participants = participants, resolution = {reason = "verified_destroyed", entityId = bossId}
        })
        if succeeded then
            spawnedRaid = false
            encounterId = nil
            bossId = nil
        end
    end
end

function secure()
    return {spawnedRaid = spawnedRaid, encounterId = encounterId,
        bossId = bossId, pendingRaid = pendingRaid}
end

function restore(data)
    if data then
        spawnedRaid = data.spawnedRaid or false
        encounterId = data.encounterId
        bossId = data.bossId
        pendingRaid = data.pendingRaid
        if spawnedRaid and encounterId and bossId then
            local boss = Entity(Uuid(bossId))
            if valid(boss) and boss:getValue("ca_encounter_id") == encounterId then
                boss:registerCallback("onDestroyed", "onRaidBossDestroyed")
            else
                EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
                    lastError = "loaded_sector_missing_summoned_boss"
                })
            end
        elseif pendingRaid then
            local encounter = EncounterBridge.Get(pendingRaid.encounterId)
            if encounter and (encounter.state == "prepared" or encounter.state == "retryable") then
                pendingRaid.nextAttemptAt = Server().unpausedRuntime + 5
            elseif encounter and encounter.state == "materializing" then
                EncounterBridge.Transition(OWNER, pendingRaid.encounterId, "repair_required", {
                    lastError = "restart_during_summoned_boss_materialization"
                })
                pendingRaid = nil
            else
                pendingRaid = nil
            end
        end
    end
end
