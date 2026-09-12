local CAState = {}

CAState.LifecycleStates = {
    pending = true,
    prepared = true,
    materializing = true,
    active = true,
    resolving = true,
    succeeded = true,
    retryable = true,
    abandoned = true,
    expired = true,
    failed_permanent = true,
    repair_required = true
}

CAState.TerminalStates = {
    succeeded = true,
    abandoned = true,
    expired = true,
    failed_permanent = true
}

local transitions = {
    pending = {prepared = true, materializing = true, abandoned = true, repair_required = true},
    prepared = {materializing = true, active = true, retryable = true, abandoned = true, repair_required = true},
    materializing = {active = true, resolving = true, retryable = true, abandoned = true, failed_permanent = true, repair_required = true},
    active = {resolving = true, abandoned = true, expired = true, retryable = true, repair_required = true},
    resolving = {succeeded = true, retryable = true, failed_permanent = true, repair_required = true},
    retryable = {prepared = true, materializing = true, abandoned = true, failed_permanent = true, repair_required = true},
    repair_required = {pending = true, prepared = true, retryable = true, succeeded = true, abandoned = true}
}

function CAState.DeepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end

    local result = {}
    seen[value] = result
    for key, item in pairs(value) do
        result[CAState.DeepCopy(key, seen)] = CAState.DeepCopy(item, seen)
    end
    return result
end

function CAState.DeepEqual(left, right, seen)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    seen = seen or {}
    if seen[left] == right then return true end
    seen[left] = right
    for key, value in pairs(left) do
        if not CAState.DeepEqual(value, right[key], seen) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

function CAState.CoordinateKey(x, y)
    if type(x) ~= "number" or type(y) ~= "number"
            or x ~= math.floor(x) or y ~= math.floor(y) then
        return nil, "invalid_coordinate"
    end
    return tostring(x) .. ":" .. tostring(y), nil
end

function CAState.NewGalaxyState(now)
    return {
        schemaVersion = 2,
        revision = 0,
        migrationVersion = 0,
        updatedAt = now or 0,
        migration = {state = "pending", sources = {}, warnings = {}, lastError = nil},
        guardian = {state = "unknown", evidence = nil, confirmedAt = nil},
        eclipse = {
            state = "dormant",
            unleashedAt = nil,
            warning1At = nil,
            warning2At = nil,
            fullyAwakeAt = nil
        },
        territory = {
            held = {},
            conqueredCount = 0,
            threat = 0,
            fallenEmpire = false,
            remnantTier = 0,
            worldEatersKilled = 0,
            citadelsKilled = 0
        },
        timers = {
            citadelSuppressionUntil = nil,
            worldEaterGraceUntil = nil,
            lastCrusadeAt = nil
        },
        history = {
            lastCrusade = nil,
            lastPlayerCrusadeTarget = nil,
            lastPlayerCrusadeAt = nil,
            remnantTierAnnounced = 0,
            processedEncounters = {}
        },
        managers = {},
        beacons = {
            claims = {},
            byFaction = {},
            leaseMetrics = {activeLeases = 0, reconciliationFailures = 0, renewalCost = 0}
        },
        entityRepairs = {},
        campaignRepairRequests = {},
        repairRequired = nil,
        lastError = nil
    }
end

function CAState.NewCampaignState(now)
    return {
        schemaVersion = 2,
        revision = 0,
        migrationVersion = 0,
        updatedAt = now or 0,
        chapter = 0,
        phase = "locked",
        target = nil,
        mail = {id = nil, state = "none"},
        mission = {script = nil, state = "none"},
        aegis = {state = "unknown", encounterId = nil},
        pendingReward = nil,
        completedAt = nil,
        migration = {sources = {}, assumptions = {}, warnings = {}},
        repairRequired = nil,
        lastError = nil
    }
end

function CAState.NewEncounterRegistry(now)
    return {schemaVersion = 1, revision = 0, updatedAt = now or 0, encounters = {}}
end

function CAState.NewReceiptRegistry(now)
    return {schemaVersion = 1, revision = 0, updatedAt = now or 0, receipts = {}}
end

function CAState.NewRepairAudit(now)
    return {schemaVersion = 1, revision = 0, updatedAt = now or 0, repairs = {}}
end

function CAState.Touch(record, now)
    if type(record) ~= "table" then return nil, "invalid_record" end
    record.revision = (record.revision or 0) + 1
    record.updatedAt = now or record.updatedAt or 0
    return record.revision, nil
end

function CAState.CanTransition(fromState, toState)
    if not CAState.LifecycleStates[fromState] or not CAState.LifecycleStates[toState] then return false end
    return transitions[fromState] and transitions[fromState][toState] == true or false
end

function CAState.Transition(record, toState, now)
    if type(record) ~= "table" or type(record.state) ~= "string" then return nil, "invalid_record" end
    if not CAState.LifecycleStates[toState] then return nil, "invalid_state" end
    if record.state == toState then return nil, "repeated_transition" end
    if CAState.TerminalStates[record.state] then return nil, "terminal_state" end
    if not CAState.CanTransition(record.state, toState) then return nil, "invalid_transition" end

    record.state = toState
    CAState.Touch(record, now)
    return true, nil
end

function CAState.ValidateRecord(record, schemaVersion, collectionName)
    if type(record) ~= "table" then return nil, "corrupt" end
    if record.schemaVersion ~= schemaVersion then return nil, "unsupported_version" end
    if type(record.revision) ~= "number" then return nil, "corrupt" end
    if collectionName ~= nil and type(record[collectionName]) ~= "table" then return nil, "corrupt" end
    return true, nil
end

function CAState.ValidateGalaxyState(record)
    local valid, err = CAState.ValidateRecord(record, 2)
    if not valid then return nil, err end
    for _, field in ipairs({"migration", "guardian", "eclipse", "territory", "timers",
            "history", "managers", "beacons", "entityRepairs", "campaignRepairRequests"}) do
        if type(record[field]) ~= "table" then return nil, "corrupt" end
    end
    if type(record.territory.held) ~= "table"
            or type(record.beacons.claims) ~= "table"
            or type(record.beacons.byFaction) ~= "table"
            or type(record.beacons.leaseMetrics) ~= "table" then
        return nil, "corrupt"
    end
    if (record.guardian.state ~= "unknown" and record.guardian.state ~= "confirmed")
            or (record.eclipse.state ~= "dormant" and record.eclipse.state ~= "awakening"
                and record.eclipse.state ~= "fully_awake") then
        return nil, "corrupt"
    end
    for _, field in ipairs({"conqueredCount", "threat", "remnantTier",
            "worldEatersKilled", "citadelsKilled"}) do
        if type(record.territory[field]) ~= "number" then return nil, "corrupt" end
    end
    if type(record.territory.fallenEmpire) ~= "boolean"
            or type(record.history.processedEncounters) ~= "table" then
        return nil, "corrupt"
    end
    for _, field in ipairs({"citadelSuppressionUntil", "worldEaterGraceUntil", "lastCrusadeAt"}) do
        if record.timers[field] ~= nil and type(record.timers[field]) ~= "number" then
            return nil, "corrupt"
        end
    end
    for key, held in pairs(record.territory.held) do
        if type(key) ~= "string" or type(held) ~= "table"
                or type(held.x) ~= "number" or type(held.y) ~= "number" then
            return nil, "corrupt"
        end
    end
    return true, nil
end

local campaignPhases = {
    locked = true,
    contact_pending = true,
    contact_prepared = true,
    active = true,
    debrief_pending = true,
    reward_prepared = true,
    reward_reissue_prepared = true,
    chapter_complete = true,
    campaign_complete = true,
    repair_required = true,
    repair_abandoned = true
}

function CAState.ValidateCampaignState(record)
    local valid, err = CAState.ValidateRecord(record, 2)
    if not valid then return nil, err end
    if type(record.chapter) ~= "number" or record.chapter ~= math.floor(record.chapter)
            or record.chapter < 0 or record.chapter > 5 then
        return nil, "corrupt"
    end
    if not campaignPhases[record.phase] then return nil, "corrupt" end
    for _, field in ipairs({"mail", "mission", "aegis", "migration"}) do
        if type(record[field]) ~= "table" then return nil, "corrupt" end
    end
    if record.target ~= nil and (type(record.target) ~= "table"
            or type(record.target.x) ~= "number" or type(record.target.y) ~= "number") then
        return nil, "corrupt"
    end
    if record.pendingReward ~= nil and (type(record.pendingReward) ~= "table"
            or type(record.pendingReward.operationId) ~= "string") then
        return nil, "corrupt"
    end
    return true, nil
end

function CAState.ValidateLifecycleRegistry(record, schemaVersion, collectionName)
    local valid, err = CAState.ValidateRecord(record, schemaVersion, collectionName)
    if not valid then return nil, err end
    for key, item in pairs(record[collectionName]) do
        if type(key) ~= "string" or type(item) ~= "table"
                or type(item.revision) ~= "number" or not CAState.LifecycleStates[item.state] then
            return nil, "corrupt"
        end
        if collectionName == "encounters" then
            if item.encounterId ~= key or type(item.kind) ~= "string"
                    or type(item.participants) ~= "table" then
                return nil, "corrupt"
            end
        elseif collectionName == "receipts" then
            if item.operationId ~= key or type(item.kind) ~= "string" then
                return nil, "corrupt"
            end
        end
    end
    return true, nil
end

function CAState.Snapshot(record)
    return CAState.DeepCopy(record)
end

return CAState
