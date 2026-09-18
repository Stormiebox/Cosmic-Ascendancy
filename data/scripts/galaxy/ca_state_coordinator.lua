package.path = package.path .. ";data/scripts/lib/?.lua"

local CosmicVaultData = include("cosmicvaultdata")
local CosmicVaultTerritory = include("cosmicvaultterritory")
local CAState = include("ca_state")
local CAMigration = include("ca_migration")

-- namespace CAStateCoordinator
CAStateCoordinator = {}

local STATE_KEY = "ca_state_v2"
local ENCOUNTER_KEY = "ca_encounters_v1"
local RECEIPT_KEY = "ca_receipts_v1"
local REPAIR_KEY = "ca_repair_audit_v1"

local records = {}
local loadErrors = {}
local nextManagerCheck = 0

local managerPaths = {
    "data/scripts/galaxy/ascendancykeepalive.lua",
    "data/scripts/galaxy/eclipse_awakes.lua",
    "data/scripts/galaxy/ca_expansion_manager.lua",
    "data/scripts/galaxy/eclipse_conquest_manager.lua",
    "data/scripts/galaxy/ca_world_eater_manager.lua",
    "data/scripts/galaxy/ca_silent_choir_manager.lua"
}

local allowedOwners = {
    ["data/scripts/galaxy/ca_state_coordinator.lua"] = true,
    ["data/scripts/galaxy/ascendancykeepalive.lua"] = true,
    ["data/scripts/galaxy/eclipse_awakes.lua"] = true,
    ["data/scripts/galaxy/ca_expansion_manager.lua"] = true,
    ["data/scripts/galaxy/eclipse_conquest_manager.lua"] = true,
    ["data/scripts/galaxy/ca_world_eater_manager.lua"] = true,
    ["data/scripts/galaxy/ca_silent_choir_manager.lua"] = true,
    ["data/scripts/events/ca_world_eater_event.lua"] = true,
    ["data/scripts/sector/ca_raid_summoner.lua"] = true,
    ["data/scripts/entity/ca_worldeater_behavior.lua"] = true,
    ["data/scripts/entity/ca_nemesis_system.lua"] = true,
    ["data/scripts/entity/ca_citadel_loot.lua"] = true,
    ["data/scripts/entity/ascendancybeacon.lua"] = true,
    ["data/scripts/player/background/ca_campaign_controller.lua"] = true,
    ["data/scripts/player/background/ca_nemesis_hunt.lua"] = true,
    ["data/scripts/events/ascendancysiege.lua"] = true,
    ["data/scripts/sector/ca_delayed_annihilation.lua"] = true,
    ["data/scripts/player/background/ca_darksector_generator.lua"] = true,
    ["data/scripts/player/ascendancyplayer.lua"] = true,
    ["data/scripts/player/missions/ca_story0_meet_aegis.lua"] = true,
    ["data/scripts/player/missions/ca_story1_awakening.lua"] = true,
    ["data/scripts/player/missions/ca_story2_forge.lua"] = true,
    ["data/scripts/player/missions/ca_story3_vanguard.lua"] = true,
    ["data/scripts/player/missions/ca_story4_citadel.lua"] = true,
    ["data/scripts/player/missions/ca_story5_worldeater.lua"] = true
}

local function currentTime()
    return Server().unpausedRuntime
end

local function readLegacy(key)
    local ok, value = pcall(function() return Server():getValue(key) end)
    if ok then return value end
    return nil
end

local function writeRecord(key, record)
    CAState.Touch(record, currentTime())
    local saved, err = CosmicVaultData.SetRecord(Server(), key, record)
    if not saved then
        record.revision = math.max(0, record.revision - 1)
        return nil, err
    end
    records[key] = record
    loadErrors[key] = nil
    return true, nil
end

local function loadRecord(key, version, constructor, collectionName, validator)
    local record, err = CosmicVaultData.GetRecord(Server(), key, version)
    if record then
        local valid, validationError
        if validator then
            valid, validationError = validator(record)
        else
            valid, validationError = CAState.ValidateRecord(record, version, collectionName)
        end
        if not valid then
            loadErrors[key] = validationError
            records[key] = constructor(currentTime())
            return false
        end
        records[key] = record
        return false
    end

    if err ~= "missing" then
        loadErrors[key] = err
        records[key] = constructor(currentTime())
        return false
    end

    records[key] = constructor(currentTime())
    return true
end

local function onlineGuardianEvidence()
    for _, player in pairs({Server():getOnlinePlayers()}) do
        if player:getValue("wormhole_guardian_destroyed") then return true end
    end
    return false
end

local function collectGalaxyEvidence()
    local awakeningElapsed = 0
    local ok, elapsed = Galaxy():invokeFunction(
        "data/scripts/galaxy/eclipse_awakes.lua", "getAwakeningElapsed")
    if ok == 0 and type(elapsed) == "number" then awakeningElapsed = elapsed end

    return {
        eclipseFullyAwake = readLegacy("eclipse_fully_awake") == true,
        eclipseUnleashed = readLegacy("the_eclipse_unleashed") == true,
        warning1 = readLegacy("eclipse_warning_1") == true,
        warning2 = readLegacy("eclipse_warning_2") == true,
        awakeningElapsed = awakeningElapsed,
        guardianRespawnTime = readLegacy("guardian_respawn_time"),
        playerGuardian = onlineGuardianEvidence(),
        heldTerritory = readLegacy("eclipse_held_territory"),
        conqueredSectors = readLegacy("eclipse_conquered_sectors"),
        threat = readLegacy("eclipse_threat"),
        fallenEmpire = readLegacy("eclipse_fallen_empire"),
        citadelDestroyedAt = readLegacy("eclipse_citadel_destroyed_time"),
        worldEaterGraceUntil = readLegacy("eclipse_world_eater_grace_end"),
        worldEatersKilled = readLegacy("eclipse_world_eaters_killed"),
        citadelsKilled = readLegacy("eclipse_citadels_killed"),
        remnantTierAnnounced = readLegacy("eclipse_remnant_tier_announced"),
        lastCrusade = readLegacy("eclipse_last_crusade_target"),
        lastPlayerCrusadeTarget = readLegacy("eclipse_last_player_crusade_target"),
        lastPlayerCrusadeAt = readLegacy("eclipse_last_player_crusade_time")
    }
end

local function importLegacyQueue(key, kind)
    local value = readLegacy(key)
    local coordinates = CAMigration.ParseCoordinateSet(value)
    for _, coordinate in pairs(coordinates) do
        CosmicVaultTerritory.QueueMaterialization(kind, coordinate.x, coordinate.y, {
            source = key
        })
    end
end

local function migrateGalaxyState(preserveExisting)
    if loadErrors[STATE_KEY] then return nil, loadErrors[STATE_KEY] end
    local state = records[STATE_KEY]
    if state.migrationVersion == 2 then return true, nil end

    local migrated, findings
    if preserveExisting then
        migrated = CAState.DeepCopy(state)
        migrated.migrationVersion = 2
        migrated.migration = migrated.migration or {state = "pending", sources = {}, warnings = {}}
        migrated.migration.sources = migrated.migration.sources or {}
        migrated.migration.warnings = migrated.migration.warnings or {}
        table.insert(migrated.migration.sources, "existing_ca_state_v2")
        migrated.migration.state = "succeeded"
        findings = {}
    else
        migrated, findings = CAMigration.AnalyzeGalaxy(collectGalaxyEvidence(), currentTime())
    end
    if not migrated then return nil, "migration_failed" end
    if #findings > 0 and not migrated.repairRequired then
        migrated.migration.warnings = findings
    end
    local saved, saveError = writeRecord(STATE_KEY, migrated)
    if not saved then return nil, saveError end

    importLegacyQueue("eclipse_pending_annihilations", "annihilation")
    importLegacyQueue("eclipse_pending_sieges", "siege")
    return true, nil
end

local function saveManagerObservations()
    if loadErrors[STATE_KEY] then return end
    local state = CAState.DeepCopy(records[STATE_KEY])
    local changed = false
    for _, path in ipairs(managerPaths) do
        local attached = Galaxy():hasScript(path)
        local previous = state.managers[path]
        local status = attached and "active" or "failed_permanent"
        if not previous or previous.state ~= status then
            state.managers[path] = {
                schemaVersion = 1,
                revision = previous and (previous.revision or 0) + 1 or 1,
                state = status,
                observedAt = currentTime(),
                lastError = attached and nil or "script_attachment_failed",
                repairRequired = attached and nil or "manager_missing"
            }
            changed = true
        end
    end
    if changed then writeRecord(STATE_KEY, state) end
end

local function ensureManagers()
    for _, path in ipairs(managerPaths) do
        if not Galaxy():hasScript(path) then Galaxy():addScriptOnce(path) end
    end
    saveManagerObservations()
end

local function reconcileGuardianEvidence()
    if loadErrors[STATE_KEY] then return end
    local state = records[STATE_KEY]
    local working = CAState.DeepCopy(state)
    local changed = false

    if working.guardian.state ~= "confirmed" then
        local source
        local guardianRespawnTime = readLegacy("guardian_respawn_time")
        if type(guardianRespawnTime) == "number" and guardianRespawnTime > 0 then
            source = "guardian_respawn_time"
        elseif onlineGuardianEvidence() then
            source = "wormhole_guardian_destroyed"
        end

        if source then
            working.guardian.state = "confirmed"
            working.guardian.evidence = source
            working.guardian.confirmedAt = currentTime()
            if working.eclipse.state == "dormant" then
                working.eclipse.state = "awakening"
                working.eclipse.unleashedAt = currentTime()
            end
            changed = true
        end
    end

    if changed then
        local saved = writeRecord(STATE_KEY, working)
        if saved and working.guardian.state == "confirmed" and not readLegacy("the_eclipse_unleashed") then
            Server():setValue("the_eclipse_unleashed", true)
        end
    end
end

local function ownerAllowed(owner)
    return type(owner) == "string" and allowedOwners[owner] == true
end

local function revisionMatches(record, expectedRevision)
    return type(expectedRevision) == "number" and expectedRevision == record.revision
end

local function recordWritable(key)
    if loadErrors[key] then return nil, loadErrors[key] end
    if not records[key] then return nil, "not_initialized" end
    return true, nil
end

local function controllingFaction(x, y)
    local faction = Galaxy():getControllingFaction(x, y)
    if type(faction) == "number" then faction = Faction(faction) end
    return faction
end

local function migrateLegacyEncounters()
    if loadErrors[ENCOUNTER_KEY] then return end
    local registry = records[ENCOUNTER_KEY]
    if not registry then return end
    local changed = false
    local hunt = readLegacy("eclipse_nemesis_hunt")
    if hunt ~= nil then
        local id = "nemesis:galaxy:legacy"
        if not registry.encounters[id] then
            local readable = type(hunt) == "table" and type(hunt.x) == "number"
                and type(hunt.y) == "number"
            registry.encounters[id] = {
                schemaVersion = 1, revision = 0, encounterId = id, kind = "nemesis",
                concurrencyKey = "nemesis:galaxy", scope = "galaxy",
                x = readable and hunt.x or nil, y = readable and hunt.y or nil,
                resistanceType = readLegacy("eclipse_nemesis_resist"),
                participants = {}, attempt = 0,
                state = readable and not hunt.spawned and "prepared" or "repair_required",
                repairRequired = readable and not hunt.spawned and nil or "legacy_nemesis_unverified",
                lastError = readable and not hunt.spawned and nil or "legacy_nemesis_unverified"
            }
            changed = true
        end
    end
    local choir = readLegacy("eclipse_silent_choir")
    if choir ~= nil then
        local id = "silent_choir:galaxy:legacy"
        if not registry.encounters[id] then
            local readable = type(choir) == "table" and type(choir.targetPlayerIndex) == "number"
            registry.encounters[id] = {
                schemaVersion = 1, revision = 0, encounterId = id, kind = "silent_choir",
                concurrencyKey = "silent_choir:galaxy", scope = "galaxy",
                targetPlayerIndex = readable and choir.targetPlayerIndex or nil,
                encounterCount = readable and (choir.encounters or 0) or 0,
                nextCheckTime = readable and choir.nextCheckTime or nil,
                x = readable and choir.lastX or nil, y = readable and choir.lastY or nil,
                participants = {}, attempt = 0,
                state = readable and "pending" or "repair_required",
                repairRequired = readable and nil or "legacy_silent_choir_unreadable",
                lastError = readable and nil or "legacy_silent_choir_unreadable"
            }
            changed = true
        end
    end
    if changed then writeRecord(ENCOUNTER_KEY, registry) end
end

function CAStateCoordinator.initialize()
    if not onServer() then return end

    local stateMissing = loadRecord(STATE_KEY, 2, CAState.NewGalaxyState, nil,
        CAState.ValidateGalaxyState)
    local encounterMissing = loadRecord(ENCOUNTER_KEY, 1, CAState.NewEncounterRegistry,
        "encounters", function(record)
            return CAState.ValidateLifecycleRegistry(record, 1, "encounters")
        end)
    local receiptMissing = loadRecord(RECEIPT_KEY, 1, CAState.NewReceiptRegistry,
        "receipts", function(record)
            return CAState.ValidateLifecycleRegistry(record, 1, "receipts")
        end)
    local repairMissing = loadRecord(REPAIR_KEY, 1, CAState.NewRepairAudit, "repairs")

    migrateGalaxyState(not stateMissing)
    if encounterMissing then writeRecord(ENCOUNTER_KEY, records[ENCOUNTER_KEY]) end
    if receiptMissing then writeRecord(RECEIPT_KEY, records[RECEIPT_KEY]) end
    if repairMissing then writeRecord(REPAIR_KEY, records[REPAIR_KEY]) end
    migrateLegacyEncounters()

    ensureManagers()
    nextManagerCheck = currentTime() + 60
    reconcileGuardianEvidence()
    Server():registerCallback("onPlayerLogIn", "onPlayerLogIn")
end

function CAStateCoordinator.getUpdateInterval()
    return 5
end

function CAStateCoordinator.updateServer(timeStep)
    reconcileGuardianEvidence()
    if currentTime() >= nextManagerCheck then
        ensureManagers()
        nextManagerCheck = currentTime() + 60
    end
end

function CAStateCoordinator.onPlayerLogIn(playerIndex)
    local player = Player(playerIndex)
    if not player then return end
    player:addScriptOnce("data/scripts/player/ascendancyplayer.lua")
    player:addScriptOnce("data/scripts/player/background/ca_campaign_controller.lua")
end

function CAStateCoordinator.getCanonicalSnapshot(playerIndex)
    local state = records[STATE_KEY]
    if not state then return nil, "not_initialized" end
    local snapshot = CAState.Snapshot(state)
    snapshot.recordErrors = CAState.DeepCopy(loadErrors)

    if type(playerIndex) == "number" then
        local player = Player(playerIndex)
        if player then
            snapshot.player = {
                index = playerIndex,
                killScore = player:getValue("eclipse_kill_score") or 0,
                wardUntil = player:getValue("eclipse_ward_until"),
                campaign = CosmicVaultData.GetRecord(player, "ca_campaign_v2", 2)
            }
        end
    end
    return snapshot, nil
end

function CAStateCoordinator.getRegistryRevisions()
    return {
        state = records[STATE_KEY] and records[STATE_KEY].revision,
        encounters = records[ENCOUNTER_KEY] and records[ENCOUNTER_KEY].revision,
        receipts = records[RECEIPT_KEY] and records[RECEIPT_KEY].revision,
        repairs = records[REPAIR_KEY] and records[REPAIR_KEY].revision
    }
end

function CAStateCoordinator.getEncounter(encounterId)
    local encounter = records[ENCOUNTER_KEY]
        and records[ENCOUNTER_KEY].encounters[encounterId]
    if not encounter then return nil, "missing" end
    return CAState.DeepCopy(encounter), nil
end

function CAStateCoordinator.getEncounters(kind)
    local result = {}
    for _, encounter in pairs(records[ENCOUNTER_KEY] and records[ENCOUNTER_KEY].encounters or {}) do
        if kind == nil or encounter.kind == kind then table.insert(result, CAState.DeepCopy(encounter)) end
    end
    table.sort(result, function(left, right) return left.encounterId < right.encounterId end)
    return result, nil
end

function CAStateCoordinator.requestCampaignCompletion(owner, expectedRevision, playerIndex)
    if owner ~= "data/scripts/player/background/ca_campaign_controller.lua" then
        return nil, "unauthorized_owner"
    end
    local writable, writeError = recordWritable(STATE_KEY)
    if not writable then return nil, writeError end
    local state = records[STATE_KEY]
    if not state or not revisionMatches(state, expectedRevision) then return nil, "revision_mismatch" end
    if state.guardian.state ~= "confirmed" then return nil, "guardian_unconfirmed" end

    local working = CAState.DeepCopy(state)
    working.eclipse.state = working.eclipse.state == "dormant" and "awakening" or working.eclipse.state
    working.eclipse.unleashedAt = working.eclipse.unleashedAt or currentTime()
    working.history.lastCampaignCompletion = {playerIndex = playerIndex, at = currentTime()}
    local saved, err = writeRecord(STATE_KEY, working)
    if not saved then return nil, err end
    Server():setValue("the_eclipse_unleashed", true)
    ensureManagers()
    saveManagerObservations()
    for _, path in ipairs(managerPaths) do
        if not Galaxy():hasScript(path) then return nil, "manager_attachment_failed:" .. path end
    end
    return records[STATE_KEY].revision, nil
end

function CAStateCoordinator.requestEclipseAwakening(owner, expectedRevision, phase)
    if owner ~= "data/scripts/galaxy/eclipse_awakes.lua" then return nil, "unauthorized_owner" end
    local writable, writeError = recordWritable(STATE_KEY)
    if not writable then return nil, writeError end
    local canonical = records[STATE_KEY]
    if not canonical or not revisionMatches(canonical, expectedRevision) then
        return nil, "revision_mismatch"
    end
    if canonical.guardian.state ~= "confirmed" then return nil, "guardian_unconfirmed" end
    local working = CAState.DeepCopy(canonical)
    if phase == "awakening" then
        if working.eclipse.state ~= "dormant" then return working.revision, nil end
        working.eclipse.state = "awakening"
        working.eclipse.unleashedAt = currentTime()
    elseif phase == "warning1" then
        if working.eclipse.state ~= "awakening" then return nil, "invalid_state" end
        working.eclipse.warning1At = working.eclipse.warning1At or currentTime()
    elseif phase == "warning2" then
        if working.eclipse.state ~= "awakening" or not working.eclipse.warning1At then
            return nil, "invalid_state"
        end
        working.eclipse.warning2At = working.eclipse.warning2At or currentTime()
    elseif phase == "fully_awake" then
        if working.eclipse.state == "fully_awake" then return working.revision, nil end
        if working.eclipse.state ~= "awakening" then return nil, "invalid_state" end
        working.eclipse.state = "fully_awake"
        working.eclipse.warning1At = working.eclipse.warning1At or currentTime()
        working.eclipse.warning2At = working.eclipse.warning2At or currentTime()
        working.eclipse.fullyAwakeAt = currentTime()
    else
        return nil, "invalid_phase"
    end
    local saved, err = writeRecord(STATE_KEY, working)
    if not saved then return nil, err end
    -- Compatibility mirrors are emitted from the canonical owner only.
    Server():setValue("the_eclipse_unleashed", true)
    if working.eclipse.warning1At then Server():setValue("eclipse_warning_1", true) end
    if working.eclipse.warning2At then Server():setValue("eclipse_warning_2", true) end
    if working.eclipse.state == "fully_awake" then Server():setValue("eclipse_fully_awake", true) end
    return working.revision, nil
end

function CAStateCoordinator.requestManagerState(owner, expectedRevision, managerPath, managerState, errorText)
    if not ownerAllowed(owner) or owner ~= managerPath then return nil, "unauthorized_owner" end
    if managerState ~= "active" and managerState ~= "retryable"
            and managerState ~= "failed_permanent" and managerState ~= "repair_required" then
        return nil, "invalid_state"
    end
    local writable, writeError = recordWritable(STATE_KEY)
    if not writable then return nil, writeError end
    local state = records[STATE_KEY]
    if not state or not revisionMatches(state, expectedRevision) then return nil, "revision_mismatch" end

    local working = CAState.DeepCopy(state)
    local previous = working.managers[managerPath]
    working.managers[managerPath] = {
        schemaVersion = 1,
        revision = previous and (previous.revision or 0) + 1 or 1,
        state = managerState,
        observedAt = currentTime(),
        lastError = errorText,
        repairRequired = managerState == "repair_required" and tostring(errorText or "manager_error") or nil
    }
    local saved, err = writeRecord(STATE_KEY, working)
    if not saved then return nil, err end
    return working.revision, nil
end

function CAStateCoordinator.requestEncounter(owner, expectedRevision, operation, payload)
    if not ownerAllowed(owner) then return nil, "unauthorized_owner" end
    if type(payload) ~= "table" or type(payload.encounterId) ~= "string"
            or payload.encounterId == "" then return nil, "invalid_payload" end
    local writable, writeError = recordWritable(ENCOUNTER_KEY)
    if not writable then return nil, writeError end
    local registry = records[ENCOUNTER_KEY]
    if not registry or not revisionMatches(registry, expectedRevision) then return nil, "revision_mismatch" end
    local working = CAState.DeepCopy(registry)
    local encounter = working.encounters[payload.encounterId]

    if operation == "create" then
        if encounter then return nil, "duplicate_encounter" end
        if not CAState.LifecycleStates[payload.state or "pending"] then return nil, "invalid_state" end
        if type(payload.kind) ~= "string" or payload.kind == "" then return nil, "missing_kind" end
        if type(payload.concurrencyKey) ~= "string" or payload.concurrencyKey == "" then
            return nil, "missing_concurrency_key"
        end
        if payload.participants ~= nil and type(payload.participants) ~= "table" then
            return nil, "invalid_participants"
        end
        for _, existing in pairs(working.encounters) do
            if existing.concurrencyKey == payload.concurrencyKey
                    and not CAState.TerminalStates[existing.state] then
                return nil, "concurrency_conflict"
            end
        end
        encounter = CAState.DeepCopy(payload)
        encounter.schemaVersion = 1
        encounter.revision = 0
        encounter.state = payload.state or "pending"
        encounter.attempt = payload.attempt or 0
        encounter.participants = payload.participants or {}
        encounter.lastError = nil
        encounter.repairRequired = nil
        working.encounters[payload.encounterId] = encounter
    elseif operation == "transition" then
        if not encounter then return nil, "missing" end
        if payload.participants ~= nil and type(payload.participants) ~= "table" then
            return nil, "invalid_participants"
        end
        if payload.resolution ~= nil and type(payload.resolution) ~= "table" then
            return nil, "invalid_resolution"
        end
        if (payload.state == "resolving" or payload.state == "succeeded") and encounter.entityId then
            local callbackEntityId = payload.resolution and payload.resolution.entityId
            if callbackEntityId ~= encounter.entityId then return nil, "entity_mismatch" end
        end
        local transitioned, transitionError = CAState.Transition(encounter, payload.state, currentTime())
        if not transitioned then return nil, transitionError end
        if payload.state == "retryable" then encounter.attempt = (encounter.attempt or 0) + 1 end
        if payload.resolution ~= nil then encounter.resolution = CAState.DeepCopy(payload.resolution) end
        if payload.participants ~= nil then encounter.participants = CAState.DeepCopy(payload.participants) end
        if payload.lastError ~= nil then encounter.lastError = tostring(payload.lastError) end
        for _, field in ipairs({"entityId", "entityIds", "engagedAt", "materializingAt", "expiresAt", "x", "y", "attempt",
                "targetPlayerIndex", "encounterCount", "nextCheckTime", "resistanceType"}) do
            if payload[field] ~= nil then encounter[field] = CAState.DeepCopy(payload[field]) end
        end
        if payload.state == "repair_required" then
            encounter.repairRequired = payload.repairRequired or payload.lastError or "repair_required"
        elseif payload.state ~= "retryable" then
            encounter.repairRequired = nil
        end
    else
        return nil, "invalid_operation"
    end

    local saved, err = writeRecord(ENCOUNTER_KEY, working)
    if not saved then return nil, err end
    return CAState.DeepCopy(encounter), working.revision
end

function CAStateCoordinator.requestEncounterOutcome(owner, expectedRevision, encounterId, outcome, data)
    if not ownerAllowed(owner) then return nil, "unauthorized_owner" end
    if outcome ~= "world_eater_succeeded" and outcome ~= "world_eater_abandoned"
            and outcome ~= "citadel_succeeded" then return nil, "invalid_outcome" end
    if data ~= nil and type(data) ~= "table" then return nil, "invalid_payload" end
    local stateWritable, stateError = recordWritable(STATE_KEY)
    if not stateWritable then return nil, stateError end
    local encounterWritable, encounterError = recordWritable(ENCOUNTER_KEY)
    if not encounterWritable then return nil, encounterError end
    local canonical = records[STATE_KEY]
    if not canonical or not revisionMatches(canonical, expectedRevision) then return nil, "revision_mismatch" end
    local encounter = records[ENCOUNTER_KEY] and records[ENCOUNTER_KEY].encounters[encounterId]
    local verifiedResolution = encounter and encounter.state == "resolving"
        and encounter.resolution
        and (encounter.resolution.reason == "boss_destroyed"
            or encounter.resolution.reason == "verified_destroyed")
    if not encounter or (encounter.state ~= "succeeded" and encounter.state ~= "abandoned"
            and not verifiedResolution) then
        return nil, "encounter_not_terminal"
    end

    local working = CAState.DeepCopy(canonical)
    working.history.processedEncounters = working.history.processedEncounters or {}
    if working.history.processedEncounters[encounterId] then return working.revision, nil end
    working.history.processedEncounters[encounterId] = {outcome = outcome, at = currentTime()}
    data = data or {}
    if outcome == "world_eater_succeeded" then
        working.territory.worldEatersKilled = (working.territory.worldEatersKilled or 0) + 1
    elseif outcome == "citadel_succeeded" then
        working.territory.citadelsKilled = (working.territory.citadelsKilled or 0) + 1
        working.timers.citadelSuppressionUntil = data.suppressionUntil
        if type(data.x) == "number" and type(data.y) == "number"
                and type(data.releaseRadius) == "number" then
            local liberated = 0
            for key, held in pairs(working.territory.held) do
                local hx = type(held) == "table" and held.x
                    or tonumber(string.match(key, "^(%-?%d+):"))
                local hy = type(held) == "table" and held.y
                    or tonumber(string.match(key, ":(%-?%d+)$"))
                if hx and hy then
                    local dx, dy = hx - data.x, hy - data.y
                    if math.sqrt(dx * dx + dy * dy) <= data.releaseRadius then
                        working.territory.held[key] = nil
                        liberated = liberated + 1
                    end
                end
            end
            local heldCount = 0
            for _ in pairs(working.territory.held) do heldCount = heldCount + 1 end
            working.territory.conqueredCount = heldCount
            working.history.lastLiberation = {
                x = data.x, y = data.y, radius = data.releaseRadius,
                count = liberated, at = currentTime(), source = encounterId
            }
        end
    end
    if string.find(outcome, "world_eater", 1, true) then
        working.timers.worldEaterGraceUntil = data.graceUntil
    end
    working.territory.remnantTier = math.min(5, math.floor(
        ((working.territory.worldEatersKilled or 0) * 3
            + (working.territory.citadelsKilled or 0)) / 10))
    local saved, err = writeRecord(STATE_KEY, working)
    if not saved then return nil, err end
    return working.revision, nil
end

function CAStateCoordinator.requestRemnantAnnouncement(owner, expectedRevision, tier)
    if owner ~= "data/scripts/lib/eclipsegenerator.lua" then return nil, "unauthorized_owner" end
    local writable, writeError = recordWritable(STATE_KEY)
    if not writable then return nil, writeError end
    local canonical = records[STATE_KEY]
    if not canonical or not revisionMatches(canonical, expectedRevision) then
        return nil, "revision_mismatch"
    end
    if type(tier) ~= "number" or tier < 1 or tier > (canonical.territory.remnantTier or 0) then
        return nil, "invalid_tier"
    end
    local announced = canonical.history.remnantTierAnnounced or 0
    if tier <= announced then return nil, "already_announced" end
    local working = CAState.DeepCopy(canonical)
    working.history.remnantTierAnnounced = tier
    local saved, err = writeRecord(STATE_KEY, working)
    if not saved then return nil, err end
    return working.revision, nil
end

function CAStateCoordinator.requestTerritoryState(owner, expectedRevision, action, payload)
    if not ownerAllowed(owner) then return nil, "unauthorized_owner" end
    local writable, writeError = recordWritable(STATE_KEY)
    if not writable then return nil, writeError end
    local canonical = records[STATE_KEY]
    if not canonical or not revisionMatches(canonical, expectedRevision) then return nil, "revision_mismatch" end
    payload = payload or {}
    local working = CAState.DeepCopy(canonical)

    if action == "add_threat" then
        if type(payload.amount) ~= "number" then return nil, "invalid_amount" end
        working.territory.threat = math.max(0, math.min(10000,
            (working.territory.threat or 0) + payload.amount))
    elseif action == "consume_threat" then
        if (working.territory.threat or 0) < 10000 then return nil, "insufficient_threat" end
        working.territory.threat = working.territory.threat - 10000
    elseif action == "claim" or action == "release" then
        local key, keyError = CAState.CoordinateKey(payload.x, payload.y)
        if not key then return nil, keyError end
        if action == "claim" then
            local controlling = controllingFaction(payload.x, payload.y)
            if not controlling or controlling.index ~= payload.eclipseFactionIndex then
                return nil, "controlling_faction_unverified"
            end
            working.territory.held[key] = {
                x = payload.x, y = payload.y, factionIndex = controlling.index,
                verifiedAt = currentTime(), source = payload.source
            }
        else
            working.territory.held[key] = nil
        end
        local count = 0
        for _ in pairs(working.territory.held) do count = count + 1 end
        working.territory.conqueredCount = count
        working.territory.fallenEmpire = working.territory.fallenEmpire or count >= 75
    elseif action == "release_radius" then
        if type(payload.x) ~= "number" or type(payload.y) ~= "number"
                or type(payload.radius) ~= "number" then return nil, "invalid_radius" end
        local liberated = 0
        for key, held in pairs(working.territory.held) do
            local hx = type(held) == "table" and held.x or tonumber(string.match(key, "^(%-?%d+):"))
            local hy = type(held) == "table" and held.y or tonumber(string.match(key, ":(%-?%d+)$"))
            if hx and hy then
                local dx, dy = hx - payload.x, hy - payload.y
                if math.sqrt(dx * dx + dy * dy) <= payload.radius then
                    working.territory.held[key] = nil
                    liberated = liberated + 1
                end
            end
        end
        local count = 0
        for _ in pairs(working.territory.held) do count = count + 1 end
        working.territory.conqueredCount = count
        working.history.lastLiberation = {x = payload.x, y = payload.y,
            radius = payload.radius, count = liberated, at = currentTime()}
    elseif action == "set_fallen" then
        working.territory.fallenEmpire = payload.value == true
    elseif action == "record_crusade" then
        if type(payload.x) ~= "number" or type(payload.y) ~= "number" then return nil, "invalid_coordinate" end
        working.history.lastCrusade = {
            x = payload.x, y = payload.y, kind = payload.kind, time = currentTime()
        }
        working.timers.lastCrusadeAt = currentTime()
        if payload.targetFactionIndex then
            working.history.lastPlayerCrusadeTarget = payload.targetFactionIndex
            working.history.lastPlayerCrusadeAt = currentTime()
        end
    else
        return nil, "invalid_action"
    end

    local saved, err = writeRecord(STATE_KEY, working)
    if not saved then return nil, err end
    return working.revision, nil
end

function CAStateCoordinator.requestReceipt(owner, expectedRevision, operation, payload)
    if not ownerAllowed(owner) then return nil, "unauthorized_owner" end
    if type(payload) ~= "table" or type(payload.operationId) ~= "string" then return nil, "invalid_payload" end
    local writable, writeError = recordWritable(RECEIPT_KEY)
    if not writable then return nil, writeError end
    local registry = records[RECEIPT_KEY]
    if not registry or not revisionMatches(registry, expectedRevision) then return nil, "revision_mismatch" end
    local working = CAState.DeepCopy(registry)
    local receipt = working.receipts[payload.operationId]

    if operation == "prepare" then
        if receipt then return nil, receipt.state == "succeeded" and "terminal_state" or "duplicate_receipt" end
        if type(payload.kind) ~= "string" or payload.kind == ""
                or type(payload.recipient) ~= "table"
                or type(payload.reissue) ~= "table" then
            return nil, "invalid_payload"
        end
        receipt = {
            schemaVersion = 1,
            revision = 0,
            operationId = payload.operationId,
            kind = payload.kind,
            recipient = CAState.DeepCopy(payload.recipient),
            encounterId = payload.encounterId,
            reissue = CAState.DeepCopy(payload.reissue),
            state = "prepared",
            preparedAt = currentTime(),
            completedAt = nil,
            evidence = nil,
            lastError = nil,
            repairRequired = nil
        }
        working.receipts[payload.operationId] = receipt
    elseif operation == "complete" then
        if not receipt then return nil, "missing" end
        if payload.evidence ~= nil and type(payload.evidence) ~= "table" then
            return nil, "invalid_evidence"
        end
        if receipt.state == "succeeded" then return nil, "terminal_state" end
        if receipt.state ~= "prepared" then return nil, "invalid_transition" end
        receipt.state = "succeeded"
        receipt.completedAt = currentTime()
        receipt.evidence = CAState.DeepCopy(payload.evidence or {})
        receipt.revision = receipt.revision + 1
    else
        return nil, "invalid_operation"
    end

    local saved, err = writeRecord(RECEIPT_KEY, working)
    if not saved then return nil, err end
    return CAState.DeepCopy(receipt), working.revision
end

function CAStateCoordinator.requestBeaconClaim(owner, expectedRevision, operation, claim)
    if owner ~= "data/scripts/entity/ascendancybeacon.lua" then return nil, "unauthorized_owner" end
    if type(claim) ~= "table" or type(claim.beaconId) ~= "string" then return nil, "invalid_payload" end
    local writable, writeError = recordWritable(STATE_KEY)
    if not writable then return nil, writeError end
    local state = records[STATE_KEY]
    if not state or not revisionMatches(state, expectedRevision) then return nil, "revision_mismatch" end
    local working = CAState.DeepCopy(state)

    if operation == "reserve" or operation == "upsert" then
        if type(claim.ownerFactionIndex) ~= "number" or type(claim.x) ~= "number"
                or type(claim.y) ~= "number" or type(claim.tier) ~= "number"
                or claim.tier < 1 or claim.tier > 5 then
            return nil, "invalid_payload"
        end
        local coordinateKey = CAState.CoordinateKey(claim.x, claim.y)
        if not coordinateKey then return nil, "invalid_coordinate" end
        local slots = 0
        for beaconId, stored in pairs(working.beacons.claims) do
            if beaconId ~= claim.beaconId and stored.ownerFactionIndex == claim.ownerFactionIndex
                    and (stored.state == "active" or stored.state == "prepared") then
                slots = slots + 1
            end
        end
        if slots >= 3 then return nil, "limit_reached" end

        local stored = CAState.DeepCopy(claim)
        stored.state = operation == "reserve" and "prepared" or "active"
        stored.coordinateKey = coordinateKey
        stored.updatedAt = currentTime()
        working.beacons.claims[claim.beaconId] = stored
    elseif operation == "suspend" then
        local stored = working.beacons.claims[claim.beaconId]
        if not stored then return nil, "missing" end
        stored.state = "suspended"
        stored.suspensionReason = claim.suspensionReason or "reconciliation_failed"
        stored.updatedAt = currentTime()
    elseif operation == "remove" then
        working.beacons.claims[claim.beaconId] = nil
    else
        return nil, "invalid_operation"
    end

    working.beacons.byFaction = {}
    for beaconId, stored in pairs(working.beacons.claims) do
        local key = tostring(stored.ownerFactionIndex)
        local summary = working.beacons.byFaction[key]
        if not summary then
            summary = {activeIds = {}, activeCount = 0, maxTier = 0, sanctuaryFields = {}}
            working.beacons.byFaction[key] = summary
        end
        if stored.state == "active" then
            table.insert(summary.activeIds, beaconId)
            summary.activeCount = summary.activeCount + 1
            summary.maxTier = math.max(summary.maxTier, stored.tier or 1)
            if stored.sanctuaryRadius and stored.sanctuaryRadius > 0 then
                table.insert(summary.sanctuaryFields, {
                    beaconId = beaconId, x = stored.x, y = stored.y,
                    radius = stored.sanctuaryRadius
                })
            end
        end
    end
    local saved, err = writeRecord(STATE_KEY, working)
    if not saved then return nil, err end
    return working.revision, CAState.DeepCopy(working.beacons.byFaction[tostring(claim.ownerFactionIndex)])
end

function CAStateCoordinator.requestBeaconReconciliation(owner, beaconId, operation, payload)
    if owner ~= "data/scripts/galaxy/ascendancykeepalive.lua" then return nil, "unauthorized_owner" end
    local writable, writeError = recordWritable(STATE_KEY)
    if not writable then return nil, writeError end
    local state = records[STATE_KEY]
    if not state then return nil, "not_initialized" end
    local working = CAState.DeepCopy(state)
    if operation == "remove_stale" then
        if type(beaconId) ~= "string" or not working.beacons.claims[beaconId] then return nil, "missing" end
        working.beacons.claims[beaconId] = nil
        working.beacons.leaseMetrics.reconciliationFailures =
            (working.beacons.leaseMetrics.reconciliationFailures or 0) + 1
    elseif operation == "metrics" then
        payload = payload or {}
        working.beacons.leaseMetrics.activeLeases = math.max(0, tonumber(payload.activeLeases) or 0)
        working.beacons.leaseMetrics.renewals = math.max(0, tonumber(payload.renewals) or 0)
        working.beacons.leaseMetrics.reconciliationFailures = math.max(0,
            tonumber(payload.reconciliationFailures)
                or working.beacons.leaseMetrics.reconciliationFailures or 0)
        working.beacons.leaseMetrics.reconciliationDuration = math.max(0,
            tonumber(payload.reconciliationDuration) or 0)
        working.beacons.leaseMetrics.renewalCost = math.max(0, tonumber(payload.renewalCost) or 0)
    else
        return nil, "invalid_operation"
    end

    working.beacons.byFaction = {}
    for id, stored in pairs(working.beacons.claims) do
        local key = tostring(stored.ownerFactionIndex)
        local summary = working.beacons.byFaction[key]
        if not summary then
            summary = {activeIds = {}, activeCount = 0, maxTier = 0, sanctuaryFields = {}}
            working.beacons.byFaction[key] = summary
        end
        if stored.state == "active" then
            table.insert(summary.activeIds, id)
            summary.activeCount = summary.activeCount + 1
            summary.maxTier = math.max(summary.maxTier, stored.tier or 1)
            if stored.sanctuaryRadius and stored.sanctuaryRadius > 0 then
                table.insert(summary.sanctuaryFields, {
                    beaconId = id, x = stored.x, y = stored.y,
                    radius = stored.sanctuaryRadius
                })
            end
        end
    end
    local saved, err = writeRecord(STATE_KEY, working)
    if not saved then return nil, err end
    return CAState.DeepCopy(working.beacons), nil
end

local function permittedActionsFor(finding)
    if finding.permittedActions then return finding.permittedActions end
    if finding.kind == "prepared_receipt" then
        if finding.reissueMode == "none" then return {"mark-complete", "abandon"} end
        return {"mark-complete", "reissue", "abandon"}
    end
    if finding.kind == "encounter" then
        local evidence = tostring(finding.evidence or "")
        if string.find(evidence, "reward", 1, true)
                and not string.find(evidence, "prepare", 1, true) then
            return {"retry", "reissue", "mark-complete", "abandon"}
        end
        return {"retry", "mark-complete", "abandon"}
    end
    if finding.kind == "queue" then return {"retry", "mark-complete", "abandon"} end
    if finding.kind == "record" then
        if finding.recordKey == STATE_KEY then return {"mark-complete", "abandon"} end
        return {"abandon"}
    end
    return {"resume", "mark-complete", "abandon"}
end

function CAStateCoordinator.requestEntityRepair(owner, operation, payload)
    if owner ~= "data/scripts/entity/ascendancyforge.lua"
            and owner ~= "data/scripts/entity/ascendancybeacon.lua" then
        return nil, "unauthorized_owner"
    end
    if type(payload) ~= "table" or type(payload.entityId) ~= "string" then
        return nil, "invalid_payload"
    end
    local writable, writeError = recordWritable(STATE_KEY)
    if not writable then return nil, writeError end
    local canonical = records[STATE_KEY]
    if not canonical then return nil, "not_initialized" end
    local working = CAState.DeepCopy(canonical)
    working.entityRepairs = working.entityRepairs or {}
    local existing = working.entityRepairs[payload.entityId]
    if operation == "upsert" then
        if type(payload.recordRevision) ~= "number" or type(payload.kind) ~= "string" then
            return nil, "invalid_payload"
        end
        if existing and (existing.recordRevision or 0) > payload.recordRevision then
            return nil, "stale_entity_revision"
        end
        local preserveRequest = existing and existing.recordRevision == payload.recordRevision
        working.entityRepairs[payload.entityId] = {
            entityId = payload.entityId,
            kind = payload.kind,
            ownerScript = owner,
            ownerFactionIndex = payload.ownerFactionIndex,
            x = payload.x,
            y = payload.y,
            recordRevision = payload.recordRevision,
            reason = payload.reason,
            reportedAt = currentTime(),
            requestedAction = preserveRequest and existing.requestedAction or nil,
            requestedForRevision = preserveRequest and existing.requestedForRevision or nil,
            requestedBy = preserveRequest and existing.requestedBy or nil
        }
    elseif operation == "resolve" then
        if not existing then return true, nil end
        if payload.recordRevision and existing.recordRevision > payload.recordRevision then
            return nil, "stale_entity_revision"
        end
        working.entityRepairs[payload.entityId] = nil
    else
        return nil, "invalid_operation"
    end
    local saved, err = writeRecord(STATE_KEY, working)
    if not saved then return nil, err end
    return true, nil
end

function CAStateCoordinator.getEntityRepairAction(owner, entityId, recordRevision)
    local canonical = records[STATE_KEY]
    local finding = canonical and canonical.entityRepairs and canonical.entityRepairs[entityId]
    if not finding then return nil, "missing" end
    if finding.ownerScript ~= owner then return nil, "unauthorized_owner" end
    if finding.recordRevision ~= recordRevision then return nil, "revision_mismatch" end
    return finding.requestedAction, nil
end

function CAStateCoordinator.scanRepair(scope, playerIndex)
    scope = scope or "all"
    local audit = records[REPAIR_KEY]
    if not audit then return nil, "not_initialized" end
    local findings = {}

    if scope == "all" or scope == "galaxy" then
        for key, err in pairs(loadErrors) do
            table.insert(findings, {kind = "record", recordKey = key, evidence = err})
        end
    end
    local state = records[STATE_KEY]
    if (scope == "all" or scope == "galaxy") and state and state.repairRequired then
        table.insert(findings, {kind = "galaxy", recordKey = STATE_KEY, evidence = state.repairRequired})
    end
    if scope == "all" or scope == "encounters" then
        for encounterId, encounter in pairs(records[ENCOUNTER_KEY].encounters) do
            if encounter.state == "repair_required" or encounter.state == "failed_permanent" then
                table.insert(findings, {kind = "encounter", recordKey = ENCOUNTER_KEY,
                    itemId = encounterId, evidence = encounter.repairRequired or encounter.lastError})
            end
        end
    end
    if scope == "all" or scope == "queues" then
        for _, kind in ipairs({"flip", "expansion", "annihilation", "siege"}) do
            local queue = CosmicVaultTerritory.ListMaterializations(kind, {
                repair_required = true,
                failed_permanent = true
            }) or {}
            for _, item in ipairs(queue) do
                table.insert(findings, {kind = "queue", recordKey = "cv_materialization_v1_" .. kind,
                    itemId = item.id, observedItemRevision = item.revision,
                    evidence = item.repairRequired or item.lastError})
            end
        end
    end
    if scope == "all" or scope == "beacons" or scope == "forges" then
        for entityId, entityRepair in pairs(state and state.entityRepairs or {}) do
            local wanted = scope == "all"
                or (scope == "beacons" and entityRepair.kind == "beacon")
                or (scope == "forges" and entityRepair.kind == "forge")
            if wanted then
                local actions
                if entityRepair.kind == "forge" then
                    local reason = tostring(entityRepair.reason)
                    -- These two reasons mean it's unknown, or confirmed, that the crafted item
                    -- already reached the player's inventory before the interruption. Offering
                    -- "reissue" here would let claimWeapon() generate and insert a second copy.
                    local deliveryAmbiguousOrConfirmed = reason == "claim_prepared_restart_ambiguity"
                        or reason == "forge_claim_completion_persistence_failed"
                        or reason == "contradictory_legacy_forge_state"
                    if deliveryAmbiguousOrConfirmed then
                        actions = {"mark-complete", "abandon"}
                    elseif string.find(reason, "claim", 1, true) then
                        actions = {"mark-complete", "reissue", "abandon"}
                    else
                        actions = {"resume", "reissue", "abandon"}
                    end
                else
                    actions = {"resume", "mark-complete", "abandon"}
                end
                table.insert(findings, {
                    kind = entityRepair.kind,
                    recordKey = STATE_KEY,
                    itemId = entityId,
                    observedItemRevision = entityRepair.recordRevision,
                    evidence = entityRepair.reason,
                    permittedActions = actions
                })
            end
        end
    end
    if scope == "player" then
        local player = Player(playerIndex)
        if not player then
            table.insert(findings, {kind = "player", recordKey = "ca_campaign_v2",
                itemId = tostring(playerIndex), evidence = "player_unavailable",
                permittedActions = {"abandon"}})
        else
            local campaign, campaignError = CosmicVaultData.GetRecord(player, "ca_campaign_v2", 2)
            if campaign then
                local valid, validationError = CAState.ValidateCampaignState(campaign)
                if not valid then campaign, campaignError = nil, validationError end
            end
            if not campaign then
                table.insert(findings, {kind = "player", recordKey = "ca_campaign_v2",
                    itemId = tostring(playerIndex), evidence = campaignError,
                    permittedActions = {"abandon"}})
            elseif campaign.phase == "repair_required" or campaign.repairRequired then
                local reason = campaign.repairRequired or campaign.lastError
                local actions = campaign.pendingReward and campaign.pendingReward.operationId
                    and {"mark-complete", "reissue", "abandon"}
                    or (reason == "corrupt_campaign_record"
                        and {"mark-complete", "abandon"}
                        or {"resume", "mark-complete", "abandon"})
                table.insert(findings, {kind = "player", recordKey = "ca_campaign_v2",
                    itemId = tostring(playerIndex), observedItemRevision = campaign.revision,
                    chapter = campaign.chapter, pendingReward = CAState.DeepCopy(campaign.pendingReward),
                    evidence = reason, permittedActions = actions})
            end
        end
    elseif scope == "all" and type(Server().getPlayers) == "function" then
        for _, player in pairs({Server():getPlayers()}) do
            local campaign, campaignError = CosmicVaultData.GetRecord(player, "ca_campaign_v2", 2)
            if campaign then
                local valid, validationError = CAState.ValidateCampaignState(campaign)
                if not valid then campaign, campaignError = nil, validationError end
            end
            if campaign and (campaign.phase == "repair_required" or campaign.repairRequired) then
                local reason = campaign.repairRequired or campaign.lastError
                local actions = campaign.pendingReward and campaign.pendingReward.operationId
                    and {"mark-complete", "reissue", "abandon"}
                    or (reason == "corrupt_campaign_record"
                        and {"mark-complete", "abandon"}
                        or {"resume", "mark-complete", "abandon"})
                table.insert(findings, {kind = "player", recordKey = "ca_campaign_v2",
                    itemId = tostring(player.index), observedItemRevision = campaign.revision,
                    chapter = campaign.chapter, pendingReward = CAState.DeepCopy(campaign.pendingReward),
                    evidence = reason, permittedActions = actions})
            elseif not campaign and campaignError ~= "missing" then
                table.insert(findings, {kind = "player", recordKey = "ca_campaign_v2",
                    itemId = tostring(player.index), evidence = campaignError,
                    permittedActions = {"abandon"}})
            end
        end
    end
    if scope == "all" or scope == "galaxy" then
        for operationId, receipt in pairs(records[RECEIPT_KEY].receipts) do
            if receipt.state == "prepared" or receipt.state == "repair_required" then
                table.insert(findings, {kind = "prepared_receipt", recordKey = RECEIPT_KEY,
                    itemId = operationId, observedItemRevision = receipt.revision,
                    reissueMode = receipt.reissue and receipt.reissue.mode or "none",
                    evidence = receipt.repairRequired or receipt.lastError or "delivery_unconfirmed"})
            end
        end
    end

    for _, finding in ipairs(findings) do finding.permittedActions = permittedActionsFor(finding) end
    local repairId = string.format("repair:%d:%d", math.floor(currentTime()), audit.revision + 1)
    local working = CAState.DeepCopy(audit)
    working.repairs[repairId] = {
        schemaVersion = 1,
        revision = 0,
        repairId = repairId,
        scope = scope,
        playerIndex = playerIndex,
        state = "scanned",
        createdAt = currentTime(),
        observedRevisions = {
            [STATE_KEY] = records[STATE_KEY] and records[STATE_KEY].revision,
            [ENCOUNTER_KEY] = records[ENCOUNTER_KEY] and records[ENCOUNTER_KEY].revision,
            [RECEIPT_KEY] = records[RECEIPT_KEY] and records[RECEIPT_KEY].revision
        },
        findings = findings,
        history = {{at = currentTime(), action = "scan", result = "dry_run"}}
    }
    local saved, err = writeRecord(REPAIR_KEY, working)
    if not saved then return nil, err end
    return CAState.DeepCopy(working.repairs[repairId]), nil
end

function CAStateCoordinator.getRepairStatus(repairId)
    if repairId == nil or repairId == "" then
        local latest
        for _, candidate in pairs(records[REPAIR_KEY] and records[REPAIR_KEY].repairs or {}) do
            if not latest or (candidate.createdAt or 0) > (latest.createdAt or 0) then latest = candidate end
        end
        if not latest then return nil, "missing" end
        return CAState.DeepCopy(latest), nil
    end
    local repair = records[REPAIR_KEY] and records[REPAIR_KEY].repairs[repairId]
    if not repair then return nil, "missing" end
    return CAState.DeepCopy(repair), nil
end

function CAStateCoordinator.getRepairHistory(repairId)
    local repair, err = CAStateCoordinator.getRepairStatus(repairId)
    if not repair then return nil, err end
    return repair.history or {}, nil
end

local function actionPermitted(repair, action)
    if #(repair.findings or {}) == 0 then return false end
    for _, finding in ipairs(repair.findings or {}) do
        local permitted = false
        for _, candidate in ipairs(finding.permittedActions or {}) do
            if candidate == action then permitted = true; break end
        end
        if not permitted then return false end
    end
    return true
end

local function applyEncounterFinding(finding, action)
    local registry = records[ENCOUNTER_KEY]
    local encounter = registry.encounters[finding.itemId]
    if not encounter then return nil, "missing_encounter" end
    local working = CAState.DeepCopy(registry)
    encounter = working.encounters[finding.itemId]
    if action == "retry" or action == "reissue" then
        if encounter.resolution and encounter.resolution.reason == "boss_destroyed" then
            encounter.state = "resolving"
        elseif action == "reissue" then
            encounter.state = "resolving"
        else
            encounter.state = "retryable"
            encounter.attempt = 0
        end
        encounter.lastError = nil
        encounter.repairRequired = nil
    elseif action == "mark-complete" then
        local doomsdayRepair = encounter.kind == "natural_world_eater"
            and string.find(tostring(encounter.lastError), "doomsday", 1, true) ~= nil
        encounter.state = doomsdayRepair and "abandoned" or "succeeded"
        encounter.resolvedAt = currentTime()
        encounter.resolution = {source = "administrator_repair",
            reason = doomsdayRepair and "deadline_elapsed" or "administrator_mark_complete"}
        encounter.lastError = nil
        encounter.repairRequired = nil
    elseif action == "abandon" then
        encounter.state = "abandoned"
        encounter.resolvedAt = currentTime()
        encounter.lastError = nil
        encounter.repairRequired = nil
    else
        return nil, "action_not_permitted"
    end
    encounter.revision = (encounter.revision or 0) + 1
    return writeRecord(ENCOUNTER_KEY, working)
end

local function settleCreditReceiptEncounter(receipt, action)
    if not receipt.encounterId then return true, nil end
    local registry = records[ENCOUNTER_KEY]
    local encounter = registry and registry.encounters[receipt.encounterId]
    if not encounter or CAState.TerminalStates[encounter.state] then return true, nil end
    if encounter.state ~= "resolving" and encounter.state ~= "repair_required" then return true, nil end
    if receipt.kind == "nemesis_reward" then
        for _, playerIndex in ipairs(encounter.participants or {}) do
            local operationId = receipt.encounterId .. ":player:" .. tostring(playerIndex) .. ":reward"
            local participantReceipt = records[RECEIPT_KEY].receipts[operationId]
            if not participantReceipt or (participantReceipt.state ~= "succeeded"
                    and participantReceipt.state ~= "abandoned") then
                return true, nil
            end
        end
    end

    local working = CAState.DeepCopy(registry)
    encounter = working.encounters[receipt.encounterId]
    if receipt.kind == "natural_world_eater_reward" then
        encounter.state = "resolving"
    else
        -- Abandoning an ambiguous payout skips that payout; it does not undo a
        -- separately verified encounter victory.
        encounter.state = "succeeded"
        encounter.resolvedAt = currentTime()
    end
    encounter.repairRequired = nil
    encounter.lastError = nil
    encounter.revision = (encounter.revision or 0) + 1
    return writeRecord(ENCOUNTER_KEY, working)
end

local function settleSharedLootEncounter(receipt, action)
    if receipt.kind ~= "citadel_shared_loot" or not receipt.encounterId then return true, nil end
    for _, candidate in pairs(records[RECEIPT_KEY].receipts) do
        if candidate.kind == receipt.kind and candidate.encounterId == receipt.encounterId
                and candidate.state ~= "succeeded" and candidate.state ~= "abandoned" then
            return true, nil
        end
    end

    local registry = records[ENCOUNTER_KEY]
    local encounter = registry and registry.encounters[receipt.encounterId]
    if not encounter or CAState.TerminalStates[encounter.state] then return true, nil end
    if encounter.state ~= "resolving" and encounter.state ~= "repair_required" then return true, nil end

    local working = CAState.DeepCopy(registry)
    encounter = working.encounters[receipt.encounterId]
    encounter.state = "succeeded"
    encounter.resolvedAt = currentTime()
    encounter.repairRequired = nil
    encounter.lastError = nil
    encounter.resolution = {source = "administrator_shared_loot_repair"}
    encounter.revision = (encounter.revision or 0) + 1
    local state = CAState.DeepCopy(records[STATE_KEY])
    state.history.processedEncounters = state.history.processedEncounters or {}
    if not state.history.processedEncounters[receipt.encounterId] then
        state.history.processedEncounters[receipt.encounterId] = {
            outcome = "citadel_succeeded", at = currentTime()
        }
        state.territory.citadelsKilled = (state.territory.citadelsKilled or 0) + 1
    end
    state.timers.citadelSuppressionUntil = currentTime()
        + (6 + math.floor((state.territory.conqueredCount or 0) / 10) * 2) * 3600

    local liberated = 0
    for key, held in pairs(state.territory.held) do
        local hx = type(held) == "table" and held.x or tonumber(string.match(key, "^(%-?%d+):"))
        local hy = type(held) == "table" and held.y or tonumber(string.match(key, ":(%-?%d+)$"))
        if hx and hy then
            local dx, dy = hx - encounter.x, hy - encounter.y
            if math.sqrt(dx * dx + dy * dy) <= 15 then
                state.territory.held[key] = nil
                liberated = liberated + 1
            end
        end
    end
    local heldCount = 0
    for _ in pairs(state.territory.held) do heldCount = heldCount + 1 end
    state.territory.conqueredCount = heldCount
    state.territory.remnantTier = math.min(5, math.floor(
        ((state.territory.worldEatersKilled or 0) * 3
            + (state.territory.citadelsKilled or 0)) / 10))
    state.history.lastLiberation = {
        x = encounter.x, y = encounter.y, radius = 15,
        count = liberated, at = currentTime(), source = "administrator_shared_loot_repair"
    }
    local stateSaved, stateError = writeRecord(STATE_KEY, state)
    if not stateSaved then return nil, stateError end
    return writeRecord(ENCOUNTER_KEY, working)
end

local function queueCampaignReceiptRepair(receipt, action, administratorPlayerIndex)
    local playerIndex = receipt.recipient and receipt.recipient.playerIndex
    local player = playerIndex and Player(playerIndex)
    if not player then return nil, "player_unavailable" end
    local campaign, campaignError = CosmicVaultData.GetRecord(player, "ca_campaign_v2", 2)
    if campaign then
        local valid, validationError = CAState.ValidateCampaignState(campaign)
        if not valid then campaign, campaignError = nil, validationError end
    end
    if not campaign then return nil, campaignError end
    local working = CAState.DeepCopy(records[STATE_KEY])
    working.campaignRepairRequests = working.campaignRepairRequests or {}
    working.campaignRepairRequests[tostring(playerIndex)] = {
        playerIndex = playerIndex,
        expectedRevision = campaign.revision,
        action = action,
        requestedAt = currentTime(),
        requestedBy = administratorPlayerIndex
    }
    return writeRecord(STATE_KEY, working)
end

local function applyReceiptFinding(finding, action, administratorPlayerIndex)
    local registry = records[RECEIPT_KEY]
    local receipt = registry.receipts[finding.itemId]
    if not receipt then return nil, "missing_receipt" end
    if receipt.revision ~= finding.observedItemRevision then return nil, "revision_mismatch" end
    local reissue = receipt.reissue or {mode = "none"}

    if action == "reissue" and reissue.mode == "coordinator_credit" then
        local recipient
        if receipt.recipient and receipt.recipient.playerIndex then
            recipient = Player(receipt.recipient.playerIndex)
        elseif receipt.recipient and receipt.recipient.factionIndex then
            recipient = Faction(receipt.recipient.factionIndex)
        end
        if not recipient then return nil, "recipient_unavailable" end
        if type(reissue.credits) ~= "number" or reissue.credits < 0 then
            return nil, "invalid_reissue_payload"
        end

        local preparedRegistry = CAState.DeepCopy(registry)
        local preparedReceipt = preparedRegistry.receipts[finding.itemId]
        preparedReceipt.state = "prepared"
        preparedReceipt.reissueAuthorized = true
        preparedReceipt.reissuePreparedAt = currentTime()
        preparedReceipt.revision = (preparedReceipt.revision or 0) + 1
        local preparedSaved, preparedError = writeRecord(RECEIPT_KEY, preparedRegistry)
        if not preparedSaved then return nil, preparedError end

        local before = recipient.money or 0
        recipient:receive(tostring(reissue.reason or "Ascendancy Repair Reissue"), reissue.credits)
        local after = recipient.money or 0
        if after < before + reissue.credits then
            local failedRegistry = CAState.DeepCopy(records[RECEIPT_KEY])
            local failedReceipt = failedRegistry.receipts[finding.itemId]
            failedReceipt.state = "repair_required"
            failedReceipt.repairRequired = "administrator_reissue_delivery_unverified"
            failedReceipt.lastError = "credit_balance_not_increased"
            failedReceipt.revision = (failedReceipt.revision or 0) + 1
            writeRecord(RECEIPT_KEY, failedRegistry)
            return nil, "reissue_delivery_unverified"
        end

        local completedRegistry = CAState.DeepCopy(records[RECEIPT_KEY])
        local completedReceipt = completedRegistry.receipts[finding.itemId]
        completedReceipt.state = "succeeded"
        completedReceipt.completedAt = currentTime()
        completedReceipt.repairRequired = nil
        completedReceipt.lastError = nil
        completedReceipt.evidence = {source = "administrator_reissue",
            duplicateRiskAccepted = true, credits = reissue.credits,
            before = before, after = after}
        completedReceipt.revision = (completedReceipt.revision or 0) + 1
        local completedSaved, completedError = writeRecord(RECEIPT_KEY, completedRegistry)
        if not completedSaved then return nil, completedError end
        return settleCreditReceiptEncounter(completedReceipt, action)
    end

    local working = CAState.DeepCopy(registry)
    receipt = working.receipts[finding.itemId]
    if action == "mark-complete" then
        receipt.state = "succeeded"
        receipt.completedAt = currentTime()
        receipt.evidence = {source = "administrator_repair"}
    elseif action == "reissue" then
        if reissue.mode == "none" then return nil, "action_not_permitted" end
        receipt.state = "prepared"
        receipt.reissueAuthorized = true
        receipt.evidence = {source = "administrator_reissue", duplicateRiskAccepted = true}
    elseif action == "abandon" then
        receipt.state = "abandoned"
        receipt.completedAt = currentTime()
        receipt.evidence = {source = "administrator_repair"}
    else
        return nil, "action_not_permitted"
    end
    receipt.revision = (receipt.revision or 0) + 1
    local saved, saveError = writeRecord(RECEIPT_KEY, working)
    if not saved then return nil, saveError end
    if reissue.mode == "campaign_controller" then
        return queueCampaignReceiptRepair(receipt, action, administratorPlayerIndex)
    end
    if reissue.mode == "coordinator_credit" then
        return settleCreditReceiptEncounter(receipt, action)
    end
    if reissue.mode == "none" then
        return settleSharedLootEncounter(receipt, action)
    end
    return true, nil
end

local function applyQueueFinding(finding, action)
    local kind, x, y = string.match(finding.itemId or "", "^([^:]+):(-?%d+):(-?%d+)$")
    if not kind then return nil, "invalid_queue_id" end
    local current, currentError = CosmicVaultTerritory.GetMaterialization(kind, tonumber(x), tonumber(y))
    if not current then return nil, currentError end
    if current.revision ~= finding.observedItemRevision then return nil, "revision_mismatch" end
    local result = action == "mark-complete" and {
        source = "administrator_repair",
        verifiedByAdministrator = true
    } or nil
    return CosmicVaultTerritory.ResolveMaterializationRepair(kind, tonumber(x), tonumber(y), action, result)
end

local function applyEntityFinding(finding, action, administratorPlayerIndex)
    local canonical = records[STATE_KEY]
    local entityRepair = canonical.entityRepairs and canonical.entityRepairs[finding.itemId]
    if not entityRepair then return nil, "missing_entity_repair" end
    if entityRepair.recordRevision ~= finding.observedItemRevision then return nil, "revision_mismatch" end
    local working = CAState.DeepCopy(canonical)
    entityRepair = working.entityRepairs[finding.itemId]
    entityRepair.requestedAction = action
    entityRepair.requestedForRevision = entityRepair.recordRevision
    entityRepair.requestedAt = currentTime()
    entityRepair.requestedBy = administratorPlayerIndex
    return writeRecord(STATE_KEY, working)
end

local function applyCampaignFinding(finding, action, administratorPlayerIndex)
    local writable, writeError = recordWritable(STATE_KEY)
    if not writable then return nil, writeError end
    local canonical = records[STATE_KEY]
    local playerIndex = tonumber(finding.itemId)
    local player = playerIndex and Player(playerIndex)
    if not player then return nil, "player_unavailable" end
    local campaign, campaignError = CosmicVaultData.GetRecord(player, "ca_campaign_v2", 2)
    if not campaign then
        if action ~= "abandon" or finding.observedItemRevision ~= nil then
            return nil, campaignError
        end
        local working = CAState.DeepCopy(records[STATE_KEY])
        working.campaignRepairRequests = working.campaignRepairRequests or {}
        working.campaignRepairRequests[tostring(playerIndex)] = {
            playerIndex = playerIndex,
            expectedRevision = -1,
            action = "abandon",
            unreadableRecord = true,
            evidence = campaignError,
            requestedAt = currentTime(),
            requestedBy = administratorPlayerIndex
        }
        return writeRecord(STATE_KEY, working)
    end
    if campaign.revision ~= finding.observedItemRevision then return nil, "revision_mismatch" end

    if finding.pendingReward and finding.pendingReward.operationId
            and (action == "reissue" or action == "mark-complete" or action == "abandon") then
        local receiptRegistry = CAState.DeepCopy(records[RECEIPT_KEY])
        local receipt = receiptRegistry.receipts[finding.pendingReward.operationId]
        if not receipt then return nil, "missing_receipt" end
        if action == "reissue" then
            receipt.state = "prepared"
            receipt.evidence = {source = "administrator_reissue", duplicateRiskAccepted = true}
        elseif action == "mark-complete" then
            receipt.state = "succeeded"
            receipt.completedAt = currentTime()
            receipt.evidence = {source = "administrator_mark_complete", deliveryAsserted = true}
        else
            receipt.state = "abandoned"
            receipt.completedAt = currentTime()
            receipt.evidence = {source = "administrator_abandon"}
        end
        receipt.revision = (receipt.revision or 0) + 1
        local savedReceipt, receiptError = writeRecord(RECEIPT_KEY, receiptRegistry)
        if not savedReceipt then return nil, receiptError end
    end

    local working = CAState.DeepCopy(records[STATE_KEY])
    working.campaignRepairRequests = working.campaignRepairRequests or {}
    working.campaignRepairRequests[tostring(playerIndex)] = {
        playerIndex = playerIndex,
        expectedRevision = campaign.revision,
        action = action,
        requestedAt = currentTime(),
        requestedBy = administratorPlayerIndex
    }
    return writeRecord(STATE_KEY, working)
end

local function applyRecordFinding(finding, action)
    local key = finding.recordKey
    if key == REPAIR_KEY then
        -- scanRepair already replaced an unreadable audit with the record that
        -- contains this scan; abandoning the old bytes requires no second write.
        return action == "abandon" and true or nil,
            action == "abandon" and nil or "action_not_permitted"
    end
    if key == STATE_KEY then
        local state = CAState.DeepCopy(records[STATE_KEY])
        if action == "mark-complete" then
            state.guardian.state = "confirmed"
            state.guardian.evidence = "administrator"
            state.guardian.confirmedAt = currentTime()
            if state.eclipse.state == "dormant" then
                state.eclipse.state = "awakening"
                state.eclipse.unleashedAt = currentTime()
            end
        elseif action == "abandon" then
            state = CAState.NewGalaxyState(currentTime())
            state.migrationVersion = 2
            state.migration.state = "succeeded"
            state.migration.sources = {"administrator_abandoned_unreadable_ca_state_v2"}
        else
            return nil, "action_not_permitted"
        end
        state.repairRequired = nil
        state.lastError = nil
        local saved, saveError = writeRecord(STATE_KEY, state)
        if saved and action == "mark-complete" then
            Server():setValue("the_eclipse_unleashed", true)
        end
        return saved, saveError
    end
    if action ~= "abandon" then return nil, "action_not_permitted" end
    if key == ENCOUNTER_KEY then
        return writeRecord(ENCOUNTER_KEY, CAState.NewEncounterRegistry(currentTime()))
    end
    if key == RECEIPT_KEY then
        return writeRecord(RECEIPT_KEY, CAState.NewReceiptRegistry(currentTime()))
    end
    return nil, "unknown_record_key"
end

function CAStateCoordinator.getCampaignRepairAction(owner, playerIndex, campaignRevision)
    if owner ~= "data/scripts/player/background/ca_campaign_controller.lua" then
        return nil, "unauthorized_owner"
    end
    if loadErrors[STATE_KEY] then return nil, loadErrors[STATE_KEY] end
    local canonical = records[STATE_KEY]
    local request = canonical and canonical.campaignRepairRequests
        and canonical.campaignRepairRequests[tostring(playerIndex)]
    if not request then return nil, "missing" end
    if request.expectedRevision ~= campaignRevision then return nil, "revision_mismatch" end
    return CAState.DeepCopy(request), nil
end

function CAStateCoordinator.acknowledgeCampaignRepair(owner, playerIndex, expectedRevision)
    if owner ~= "data/scripts/player/background/ca_campaign_controller.lua" then
        return nil, "unauthorized_owner"
    end
    local writable, writeError = recordWritable(STATE_KEY)
    if not writable then return nil, writeError end
    local canonical = records[STATE_KEY]
    local request = canonical and canonical.campaignRepairRequests
        and canonical.campaignRepairRequests[tostring(playerIndex)]
    if not request then return true, nil end
    if request.expectedRevision ~= expectedRevision then return nil, "revision_mismatch" end
    local working = CAState.DeepCopy(canonical)
    working.campaignRepairRequests[tostring(playerIndex)] = nil
    return writeRecord(STATE_KEY, working)
end

function CAStateCoordinator.applyRepair(repairId, action, administratorPlayerIndex)
    local administrator = Player(administratorPlayerIndex)
    if not administrator or not Server():hasAdminPrivileges(administrator) then return nil, "admin_required" end
    local audit = records[REPAIR_KEY]
    local repair = audit and audit.repairs[repairId]
    if not repair then return nil, "missing" end
    if repair.state ~= "scanned" then return nil, "terminal_state" end
    if not actionPermitted(repair, action) then return nil, "action_not_permitted" end

    for key, observedRevision in pairs(repair.observedRevisions or {}) do
        if records[key] and records[key].revision ~= observedRevision then return nil, "revision_mismatch" end
    end

    local appliedCount = 0
    local orderedFindings = CAState.DeepCopy(repair.findings or {})
    table.sort(orderedFindings, function(left, right)
        local receiptPriority = action == "reissue" and 2 or 1
        local encounterPriority = action == "reissue" and 1 or 2
        local leftPriority = left.kind == "record" and 0
            or (left.kind == "prepared_receipt" and receiptPriority
                or (left.kind == "encounter" and encounterPriority or 3))
        local rightPriority = right.kind == "record" and 0
            or (right.kind == "prepared_receipt" and receiptPriority
                or (right.kind == "encounter" and encounterPriority or 3))
        return leftPriority < rightPriority
    end)
    for _, finding in ipairs(orderedFindings) do
        local applied, applyError
        if finding.kind == "encounter" then
            applied, applyError = applyEncounterFinding(finding, action)
        elseif finding.kind == "prepared_receipt" then
            applied, applyError = applyReceiptFinding(finding, action, administratorPlayerIndex)
        elseif finding.kind == "queue" then
            applied, applyError = applyQueueFinding(finding, action)
        elseif finding.kind == "forge" or finding.kind == "beacon" then
            applied, applyError = applyEntityFinding(finding, action, administratorPlayerIndex)
        elseif finding.kind == "player" then
            applied, applyError = applyCampaignFinding(finding, action, administratorPlayerIndex)
        elseif finding.kind == "record" then
            applied, applyError = applyRecordFinding(finding, action)
        else
            applyError = "action_not_implemented_for_finding"
        end
        if not applied then return nil, applyError end
        appliedCount = appliedCount + 1
    end

    local result = "applied_" .. tostring(appliedCount)

    local working = CAState.DeepCopy(records[REPAIR_KEY])
    repair = working.repairs[repairId]
    repair.state = "applied"
    repair.selectedAction = action
    repair.administratorPlayerIndex = administratorPlayerIndex
    repair.appliedAt = currentTime()
    repair.result = result
    repair.revision = (repair.revision or 0) + 1
    table.insert(repair.history, {at = currentTime(), action = action, result = result,
        administratorPlayerIndex = administratorPlayerIndex})
    local saved, err = writeRecord(REPAIR_KEY, working)
    if not saved then return nil, err end
    return CAState.DeepCopy(repair), nil
end
