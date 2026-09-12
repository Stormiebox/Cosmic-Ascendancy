local EncounterBridge = {}

local COORDINATOR = "data/scripts/galaxy/ca_state_coordinator.lua"

local function coordinator(functionName, ...)
    local resultCode, first, second = Galaxy():invokeFunction(COORDINATOR, functionName, ...)
    if resultCode ~= 0 then return nil, "coordinator_unavailable" end
    return first, second
end

local function revisions()
    local value, err = coordinator("getRegistryRevisions")
    if not value then return nil, err end
    return value
end

function EncounterBridge.MakeId(kind, scope, x, y, discriminator)
    return table.concat({kind, scope or "galaxy", tostring(x or 0), tostring(y or 0),
        tostring(discriminator or math.floor(Server().unpausedRuntime))}, ":")
end

function EncounterBridge.Get(encounterId)
    return coordinator("getEncounter", encounterId)
end

function EncounterBridge.List(kind)
    return coordinator("getEncounters", kind)
end

function EncounterBridge.Create(owner, payload)
    local current, err = revisions()
    if not current then return nil, err end
    local encounter, nextRevision = coordinator("requestEncounter", owner, current.encounters, "create", payload)
    if encounter then return encounter, nextRevision end
    if nextRevision ~= "revision_mismatch" then return nil, nextRevision end
    current, err = revisions()
    if not current then return nil, err end
    return coordinator("requestEncounter", owner, current.encounters, "create", payload)
end

function EncounterBridge.Transition(owner, encounterId, state, fields)
    local current, err = revisions()
    if not current then return nil, err end
    local payload = fields or {}
    payload.encounterId = encounterId
    payload.state = state
    local encounter, nextRevision = coordinator(
        "requestEncounter", owner, current.encounters, "transition", payload)
    if encounter then return encounter, nextRevision end
    if nextRevision ~= "revision_mismatch" then return nil, nextRevision end
    current, err = revisions()
    if not current then return nil, err end
    return coordinator("requestEncounter", owner, current.encounters, "transition", payload)
end

function EncounterBridge.TagAndActivate(owner, encounterId, entity, fields)
    if not entity or not valid(entity) then return nil, "missing_entity" end
    entity:setValue("ca_encounter_id", encounterId)
    if entity:getValue("ca_encounter_id") ~= encounterId then return nil, "tag_not_verified" end
    fields = fields or {}
    fields.entityId = entity.id.string
    return EncounterBridge.Transition(owner, encounterId, "active", fields)
end

function EncounterBridge.PrepareReceipt(owner, payload)
    local current, err = revisions()
    if not current then return nil, err end
    return coordinator("requestReceipt", owner, current.receipts, "prepare", payload)
end

function EncounterBridge.CompleteReceipt(owner, operationId, evidence)
    local current, err = revisions()
    if not current then return nil, err end
    return coordinator("requestReceipt", owner, current.receipts, "complete", {
        operationId = operationId,
        evidence = evidence
    })
end

return EncounterBridge
