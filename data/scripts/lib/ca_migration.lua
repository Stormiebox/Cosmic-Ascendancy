local CAState = include("ca_state")
local CAMigration = {}

local missionByChapter = {
    [0] = "data/scripts/player/missions/ca_story0_meet_aegis.lua",
    [1] = "data/scripts/player/missions/ca_story1_awakening.lua",
    [2] = "data/scripts/player/missions/ca_story2_forge.lua",
    [3] = "data/scripts/player/missions/ca_story3_vanguard.lua",
    [4] = "data/scripts/player/missions/ca_story4_citadel.lua",
    [5] = "data/scripts/player/missions/ca_story5_worldeater.lua"
}

local debriefByChapter = {
    [0] = "ca_ready_for_debrief_intro",
    [1] = "ca_ready_for_debrief_1",
    [2] = "ca_ready_for_debrief_2",
    [3] = "ca_ready_for_debrief_3",
    [4] = "ca_ready_for_debrief_4",
    [5] = "ca_ready_for_debrief_5"
}

local function addSource(record, source)
    table.insert(record.migration.sources, source)
end

local function addWarning(record, warning)
    table.insert(record.migration.warnings, warning)
end

local function nonNegativeNumber(value)
    if type(value) ~= "number" then return nil end
    return math.max(0, value)
end

function CAMigration.ParseCoordinateSet(value)
    local result = {}
    local malformed = false
    if value == nil or value == "" then return result, false end
    if type(value) ~= "string" then return result, true end

    local consumed = ""
    for token in string.gmatch(value, "([^,]+)") do
        local x, y = string.match(token, "^(-?%d+)_(-?%d+)$")
        if x and y then
            x, y = tonumber(x), tonumber(y)
            local key = assert(CAState.CoordinateKey(x, y))
            result[key] = {x = x, y = y}
            consumed = consumed .. token .. ","
        else
            malformed = true
        end
    end
    if consumed ~= value then malformed = true end
    return result, malformed
end

function CAMigration.AnalyzeGalaxy(evidence, now)
    evidence = evidence or {}
    now = now or 0

    if evidence.existingState then
        local valid, validationError = CAState.ValidateGalaxyState(evidence.existingState)
        if not valid then return nil, validationError end
        return CAState.DeepCopy(evidence.existingState), {}
    end

    local state = CAState.NewGalaxyState(now)
    local findings = {}
    local guardianEvidence

    if evidence.eclipseFullyAwake == true then
        guardianEvidence = "eclipse_fully_awake"
        state.eclipse.state = "fully_awake"
        state.eclipse.unleashedAt = now
        state.eclipse.warning1At = now
        state.eclipse.warning2At = now
        state.eclipse.fullyAwakeAt = now
        addSource(state, guardianEvidence)
    elseif evidence.eclipseUnleashed == true or evidence.warning1 == true or evidence.warning2 == true then
        guardianEvidence = evidence.eclipseUnleashed == true and "the_eclipse_unleashed" or "eclipse_warning"
        state.eclipse.state = "awakening"
        state.eclipse.unleashedAt = now - math.max(0, tonumber(evidence.awakeningElapsed) or 0)
        if evidence.warning1 then state.eclipse.warning1At = now end
        if evidence.warning2 then
            state.eclipse.warning1At = state.eclipse.warning1At or now
            state.eclipse.warning2At = now
        end
        if evidence.eclipseUnleashed ~= true then
            addWarning(state, "warning_without_unleashed")
            table.insert(findings, "warning_without_unleashed")
        end
        addSource(state, guardianEvidence)
    elseif type(evidence.guardianRespawnTime) == "number" and evidence.guardianRespawnTime > 0 then
        guardianEvidence = "guardian_respawn_time"
        state.eclipse.state = "awakening"
        state.eclipse.unleashedAt = now
        addSource(state, guardianEvidence)
    elseif evidence.playerGuardian == true then
        guardianEvidence = "wormhole_guardian_destroyed"
        state.eclipse.state = "awakening"
        state.eclipse.unleashedAt = now
        addSource(state, guardianEvidence)
    end

    if guardianEvidence then
        state.guardian.state = "confirmed"
        state.guardian.evidence = guardianEvidence
        state.guardian.confirmedAt = now
    end

    local held, malformedHeld = CAMigration.ParseCoordinateSet(evidence.heldTerritory)
    state.territory.held = held
    if evidence.heldTerritory ~= nil then addSource(state, "eclipse_held_territory") end
    if malformedHeld then
        addWarning(state, "malformed_held_territory")
        table.insert(findings, "malformed_held_territory")
    end

    local heldCount = 0
    for _ in pairs(held) do heldCount = heldCount + 1 end
    local legacyCount = nonNegativeNumber(evidence.conqueredSectors) or 0
    state.territory.conqueredCount = math.max(heldCount, legacyCount)
    if heldCount ~= legacyCount and evidence.conqueredSectors ~= nil then
        addWarning(state, "territory_count_mismatch")
        table.insert(findings, "territory_count_mismatch")
    end

    if evidence.threat == nil then
        state.territory.threat = 0
    elseif type(evidence.threat) == "number" then
        state.territory.threat = math.max(0, math.min(10000, evidence.threat))
    else
        state.repairRequired = "invalid_legacy_threat"
        state.lastError = "eclipse_threat was not numeric"
        addWarning(state, "invalid_legacy_threat")
        table.insert(findings, "invalid_legacy_threat")
    end

    state.territory.fallenEmpire = evidence.fallenEmpire == true
        or state.territory.conqueredCount >= 75
    state.territory.worldEatersKilled = nonNegativeNumber(evidence.worldEatersKilled) or 0
    state.territory.citadelsKilled = nonNegativeNumber(evidence.citadelsKilled) or 0
    local computedTier = math.min(5, math.floor(
        (state.territory.worldEatersKilled * 3 + state.territory.citadelsKilled) / 10))
    state.territory.remnantTier = math.max(computedTier,
        math.min(5, nonNegativeNumber(evidence.remnantTierAnnounced) or 0))
    state.history.remnantTierAnnounced = math.min(5,
        nonNegativeNumber(evidence.remnantTierAnnounced) or 0)

    if type(evidence.citadelDestroyedAt) == "number" then
        local duration = (6 + math.floor(state.territory.conqueredCount / 10) * 2) * 3600
        state.timers.citadelSuppressionUntil = evidence.citadelDestroyedAt + duration
    end
    if type(evidence.worldEaterGraceUntil) == "number" then
        state.timers.worldEaterGraceUntil = evidence.worldEaterGraceUntil
    end
    if type(evidence.lastPlayerCrusadeAt) == "number" then
        state.timers.lastCrusadeAt = evidence.lastPlayerCrusadeAt
        state.history.lastPlayerCrusadeAt = evidence.lastPlayerCrusadeAt
    end
    if type(evidence.lastPlayerCrusadeTarget) == "number" then
        state.history.lastPlayerCrusadeTarget = evidence.lastPlayerCrusadeTarget
    end
    if type(evidence.lastCrusade) == "table"
            and type(evidence.lastCrusade.x) == "number"
            and type(evidence.lastCrusade.y) == "number" then
        state.history.lastCrusade = CAState.DeepCopy(evidence.lastCrusade)
        state.timers.lastCrusadeAt = evidence.lastCrusade.time or state.timers.lastCrusadeAt
    elseif evidence.lastCrusade ~= nil then
        addWarning(state, "invalid_last_crusade")
        table.insert(findings, "invalid_last_crusade")
    end

    state.migrationVersion = 2
    state.migration.state = state.repairRequired and "repair_required" or "succeeded"
    CAState.Touch(state, now)
    return state, findings
end

function CAMigration.AnalyzeCampaign(evidence, guardianConfirmed, now)
    evidence = evidence or {}
    local state = CAState.NewCampaignState(now)
    local findings = {}
    local attached = evidence.attachedMissions or {}

    if evidence.completed == true then
        state.chapter = 5
        state.phase = "campaign_complete"
        state.completedAt = now
        table.insert(state.migration.sources, "ca_campaign_completed")
    else
        local highestMission
        local missionCount = 0
        for chapter = 0, 5 do
            if attached[missionByChapter[chapter]] then
                highestMission = chapter
                missionCount = missionCount + 1
            end
        end

        local highestDebrief
        for chapter = 0, 5 do
            if evidence.values and evidence.values[debriefByChapter[chapter]] == true then
                highestDebrief = chapter
            end
        end

        if highestMission ~= nil and (highestDebrief == nil or highestMission > highestDebrief) then
            state.chapter = highestMission
            state.phase = "active"
            state.target = CAState.DeepCopy(evidence.missionTargets and evidence.missionTargets[highestMission])
            state.mission = {script = missionByChapter[highestMission], state = "attached"}
            table.insert(state.migration.sources, missionByChapter[highestMission])
            if missionCount > 1 then
                state.migration.resumePhase = "active"
                state.phase = "repair_required"
                state.repairRequired = "multiple_campaign_missions"
                table.insert(findings, "multiple_campaign_missions")
            end
        elseif highestDebrief ~= nil then
            state.chapter = highestDebrief
            state.phase = "debrief_pending"
            state.target = CAState.DeepCopy(evidence.missionTargets and evidence.missionTargets[highestDebrief])
            table.insert(state.migration.sources, debriefByChapter[highestDebrief])
        elseif guardianConfirmed then
            state.chapter = 0
            state.phase = "contact_pending"
            table.insert(state.migration.sources, "guardian_confirmed")
        end
    end

    state.migrationVersion = 2
    CAState.Touch(state, now)
    return state, findings
end

function CAMigration.AnalyzeLegacyEncounter(evidence, now)
    if type(evidence) ~= "table" then return nil, "missing_evidence" end
    local record = {
        schemaVersion = 1,
        revision = 0,
        kind = evidence.kind,
        scope = evidence.scope,
        ownerPlayerIndex = evidence.ownerPlayerIndex,
        coordinate = CAState.DeepCopy(evidence.coordinate),
        state = evidence.verifiedActive and "active" or "repair_required",
        attempt = 0,
        entityTag = evidence.encounterId,
        participants = {},
        resolution = nil,
        migratedAt = now,
        lastError = evidence.verifiedActive and nil or "legacy_encounter_unverified",
        repairRequired = evidence.verifiedActive and nil or "legacy_encounter_unverified"
    }
    return record, nil
end

function CAMigration.AnalyzeLegacyForge(evidence, now)
    evidence = evidence or {}
    if not evidence.isForging and not evidence.hasCompletedItem then return nil, nil end
    if evidence.selectedType == nil or type(evidence.finishTime) ~= "number" then
        return {state = "repair_required", repairRequired = "legacy_forge_incomplete", migratedAt = now}, nil
    end
    return {
        schemaVersion = 1,
        revision = 0,
        state = evidence.hasCompletedItem and "ready_to_claim" or "running",
        recipeId = evidence.selectedType,
        requesterPlayerIndex = nil,
        completionTime = evidence.finishTime,
        intendedSuccess = evidence.willSucceed == true,
        migrationProvenance = "legacy_secure",
        migratedAt = now
    }, nil
end

function CAMigration.AnalyzeLegacyBeacon(evidence, now)
    evidence = evidence or {}
    if evidence.active ~= true then return nil, nil end
    if type(evidence.ownerFactionIndex) ~= "number"
            or type(evidence.x) ~= "number" or type(evidence.y) ~= "number" then
        return {state = "repair_required", repairRequired = "legacy_beacon_incomplete", migratedAt = now}, nil
    end
    return {
        schemaVersion = 1,
        revision = 0,
        state = "active",
        ownerFactionIndex = evidence.ownerFactionIndex,
        coordinate = {x = evidence.x, y = evidence.y},
        tier = math.max(1, math.min(5, tonumber(evidence.tier) or 1)),
        migrationProvenance = "legacy_secure",
        migratedAt = now
    }, nil
end

CAMigration.MissionByChapter = missionByChapter
CAMigration.DebriefByChapter = debriefByChapter

return CAMigration
