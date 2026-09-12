local MissionEncounter = {}
local EncounterBridge = include("ca_encounter_bridge")

function MissionEncounter.Prepare(owner, chapter, kind, x, y)
    local playerIndex = Player().index
    local encounterId = "campaign:" .. tostring(playerIndex) .. ":" .. tostring(chapter)
    local existing = EncounterBridge.Get(encounterId)
    if existing then return existing, nil end
    return EncounterBridge.Create(owner, {
        encounterId = encounterId,
        kind = kind,
        concurrencyKey = "campaign:" .. tostring(playerIndex),
        scope = "player",
        ownerPlayerIndex = playerIndex,
        x = x,
        y = y,
        state = "prepared"
    })
end

function MissionEncounter.FindTagged(scriptValue, encounterId)
    local result = {}
    for _, entity in pairs({Sector():getEntitiesByScriptValue(scriptValue)}) do
        if entity:getValue("ca_encounter_id") == encounterId then
            table.insert(result, entity)
        end
    end
    return result
end

function MissionEncounter.BeginMaterialization(owner, encounterId)
    local encounter, err = EncounterBridge.Get(encounterId)
    if not encounter then return nil, err end
    if encounter.state == "retryable" then
        encounter, err = EncounterBridge.Transition(owner, encounterId, "prepared")
        if not encounter then return nil, err end
    end
    if encounter.state == "materializing" then
        EncounterBridge.Transition(owner, encounterId, "repair_required", {
            lastError = "restart_during_campaign_materialization"
        })
        return nil, "materialization_ambiguous"
    end
    if encounter.state ~= "prepared" then return nil, "invalid_encounter_state" end
    return EncounterBridge.Transition(owner, encounterId, "materializing")
end

function MissionEncounter.RecordMaterializationFailure(owner, encounterId, errorText)
    local encounter, err = EncounterBridge.Get(encounterId)
    if not encounter then return nil, err end
    if encounter.state ~= "materializing" then return nil, "invalid_encounter_state" end
    local attempt = (encounter.attempt or 0) + 1
    if attempt >= 5 then
        return EncounterBridge.Transition(owner, encounterId, "repair_required", {
            attempt = attempt,
            lastError = tostring(errorText or "campaign_spawn_failed") .. "_after_five_attempts"
        })
    end
    return EncounterBridge.Transition(owner, encounterId, "retryable", {
        attempt = attempt,
        lastError = errorText or "campaign_spawn_failed"
    })
end

function MissionEncounter.Activate(owner, encounterId, entities)
    local ids = {}
    for _, entity in ipairs(entities or {}) do
        if not entity or not valid(entity) then return nil, "missing_entity" end
        entity:setValue("ca_encounter_id", encounterId)
        if entity:getValue("ca_encounter_id") ~= encounterId then return nil, "tag_not_verified" end
        table.insert(ids, entity.id.string)
    end
    if #ids == 0 then return nil, "missing_entity" end
    local existing, existingError = EncounterBridge.Get(encounterId)
    if not existing then return nil, existingError end
    if existing.state == "active" then
        local registered = existing.entityIds or (existing.entityId and {existing.entityId}) or {}
        if #registered ~= #ids then return nil, "entity_set_mismatch" end
        local wanted = {}
        for _, id in ipairs(registered) do wanted[id] = true end
        for _, id in ipairs(ids) do
            if not wanted[id] then return nil, "entity_set_mismatch" end
        end
        return existing, nil
    end
    return EncounterBridge.Transition(owner, encounterId, "active", {
        entityId = #ids == 1 and ids[1] or nil,
        entityIds = ids,
        participants = {Player().index},
        engagedAt = Server().unpausedRuntime
    })
end

function MissionEncounter.Resolve(owner, encounterId, entityId)
    local encounter, err = EncounterBridge.Get(encounterId)
    if not encounter then return nil, err end
    if encounter.state == "succeeded" then return true, nil end
    if encounter.state ~= "active" then return nil, "encounter_not_active" end
    if entityId then
        if encounter.entityId and encounter.entityId ~= entityId then
            return nil, "encounter_mismatch"
        end
        if encounter.entityIds then
            local found = false
            for _, registeredId in ipairs(encounter.entityIds) do
                if registeredId == entityId then found = true; break end
            end
            if not found then return nil, "encounter_mismatch" end
        end
    end
    local resolving, resolveError = EncounterBridge.Transition(owner, encounterId, "resolving", {
        resolution = {reason = "verified_destroyed", entityId = entityId},
        participants = {Player().index}
    })
    if not resolving then return nil, resolveError end
    return EncounterBridge.Transition(owner, encounterId, "succeeded", {
        resolution = {reason = "verified_destroyed", entityId = entityId},
        participants = {Player().index}
    })
end

function MissionEncounter.MarkMissing(owner, encounterId, errorText)
    local encounter = EncounterBridge.Get(encounterId)
    if not encounter or encounter.state ~= "active" then return nil, "encounter_not_active" end
    return EncounterBridge.Transition(owner, encounterId, "repair_required", {
        lastError = errorText or "registered_entity_missing_without_destroy_callback"
    })
end

return MissionEncounter
