package.path = package.path .. ";data/scripts/lib/?.lua"
include("stringutility")
include("randomext")
include("data/scripts/lib/callable")

local CosmicVaultData = include("cosmicvaultdata")
local EncounterBridge = include("ca_encounter_bridge")

-- namespace SilentChoirManager
SilentChoirManager = {}

local OWNER = "data/scripts/galaxy/ca_silent_choir_manager.lua"
local SIGHTINGS_BEFORE_ENGAGE = 3
local MIN_SIGHTING_COOLDOWN = 300
local MAX_SIGHTING_COOLDOWN = 900
local IDLE_ROLL_CHANCE = 0.05

function SilentChoirManager.getUpdateInterval() return 30 end

local function activeTracker()
    for _, encounter in ipairs(EncounterBridge.List("silent_choir") or {}) do
        if encounter.state ~= "succeeded" and encounter.state ~= "abandoned"
                and encounter.state ~= "expired" and encounter.state ~= "failed_permanent" then
            return encounter
        end
    end
end

local function schedule(targetPlayerIndex, encounterCount, delay)
    local now = Server().unpausedRuntime
    local id = EncounterBridge.MakeId("silent_choir", "galaxy", 0, 0,
        tostring(math.floor(now)) .. ":" .. tostring(encounterCount))
    return EncounterBridge.Create(OWNER, {
        encounterId = id, kind = "silent_choir",
        concurrencyKey = "silent_choir:galaxy", scope = "galaxy",
        targetPlayerIndex = targetPlayerIndex, encounterCount = encounterCount,
        nextCheckTime = now + delay, state = "pending"
    })
end

function SilentChoirManager.updateServer(timeStep)
    local state = CosmicVaultData.GetRecord(Server(), "ca_state_v2", 2)
    if not state or state.eclipse.state ~= "fully_awake" then return end
    local players = {Server():getOnlinePlayers()}
    if #players == 0 then return end

    local tracker = activeTracker()
    if not tracker then
        if random():getFloat() >= IDLE_ROLL_CHANCE then return end
        local candidates = {}
        for _, player in ipairs(players) do
            local wardUntil = player:getValue("eclipse_ward_until")
            if not wardUntil or Server().unpausedRuntime >= wardUntil then
                table.insert(candidates, player)
            end
        end
        if #candidates == 0 then return end
        local target = candidates[random():getInt(1, #candidates)]
        schedule(target.index, 0, random():getInt(MIN_SIGHTING_COOLDOWN, MAX_SIGHTING_COOLDOWN))
        return
    end

    if tracker.state == "materializing" then
        if Server().unpausedRuntime - (tracker.materializingAt or 0) > 60 then
            SilentChoirManager.reportMaterializationFailure(
                tracker.encounterId, "choir_materialization_confirmation_timeout")
        end
        return
    end
    if tracker.state == "repair_required" or tracker.state == "active"
            or tracker.state == "resolving" then return end
    if Server().unpausedRuntime < (tracker.nextCheckTime or 0) then return end
    local target = Player(tracker.targetPlayerIndex)
    if not target or not Server():isOnline(tracker.targetPlayerIndex) then
        EncounterBridge.Transition(OWNER, tracker.encounterId, "abandoned", {
            resolution = {reason = "target_offline"}})
        return
    end
    local wardUntil = target:getValue("eclipse_ward_until")
    if wardUntil and Server().unpausedRuntime < wardUntil then return end
    local tx, ty = target:getSectorCoordinates()
    if not tx or not ty or not Galaxy():sectorLoaded(tx, ty) then return end

    if tracker.state == "retryable" then
        tracker = EncounterBridge.Transition(OWNER, tracker.encounterId, "prepared")
    elseif tracker.state == "pending" then
        tracker = EncounterBridge.Transition(OWNER, tracker.encounterId, "prepared", {x = tx, y = ty})
    end
    if not tracker then return end
    local materializing = EncounterBridge.Transition(OWNER, tracker.encounterId, "materializing", {
        x = tx, y = ty, materializingAt = Server().unpausedRuntime})
    if not materializing then return end

    local willEngage = ((tracker.encounterCount or 0) + 1) >= SIGHTINGS_BEFORE_ENGAGE
    local code = [[
        function run(willEngage, encounterId)
            local EclipseGenerator = include("eclipsegenerator")
            local dir = normalize(vec3(random():getFloat(-1,1), random():getFloat(-1,1), random():getFloat(-1,1)))
            local pos = MatrixLookUpPosition(-dir, vec3(0,1,0), dir * 2500)
            local unit = EclipseGenerator.createAssassin(pos)
            if not unit then
                Galaxy():invokeFunction("data/scripts/galaxy/ca_silent_choir_manager.lua",
                    "reportMaterializationFailure", encounterId, "choir_spawn_failed")
                return
            end
            unit:setValue("ca_encounter_id", encounterId)
            unit:addScriptOnce("data/scripts/entity/ca_silent_choir_unit.lua",
                willEngage, encounterId, unit.id.string)
            if unit:getValue("ca_encounter_id") ~= encounterId
                    or not unit:hasScript("data/scripts/entity/ca_silent_choir_unit.lua") then
                Sector():deleteEntity(unit)
                Galaxy():invokeFunction("data/scripts/galaxy/ca_silent_choir_manager.lua",
                    "reportMaterializationFailure", encounterId,
                    "choir_tag_or_script_verification_failed")
                return
            end
            Galaxy():invokeFunction("data/scripts/galaxy/ca_silent_choir_manager.lua",
                "confirmMaterialized", encounterId, unit.id.string)
        end
    ]]
    runSectorCode(tx, ty, true, code, "run", willEngage, tracker.encounterId)
end

function SilentChoirManager.confirmMaterialized(encounterId, entityId)
    local tracker = EncounterBridge.Get(encounterId)
    if not tracker or tracker.state ~= "materializing" then return nil, "encounter_mismatch" end
    return EncounterBridge.Transition(OWNER, encounterId, "active", {
        entityId = entityId, engagedAt = Server().unpausedRuntime})
end

function SilentChoirManager.reportMaterializationFailure(encounterId, errorText)
    local tracker = EncounterBridge.Get(encounterId)
    if not tracker or tracker.state ~= "materializing" then return nil, "encounter_mismatch" end
    local nextState = (tracker.attempt or 0) >= 4 and "repair_required" or "retryable"
    return EncounterBridge.Transition(OWNER, encounterId, nextState, {lastError = errorText})
end

function SilentChoirManager.resolveSighting(encounterId, entityId, destroyed)
    local tracker = EncounterBridge.Get(encounterId)
    if not tracker or tracker.state ~= "active" or tracker.entityId ~= entityId then
        return nil, "encounter_mismatch"
    end
    local count = (tracker.encounterCount or 0) + 1
    if not EncounterBridge.Transition(OWNER, encounterId, "resolving", {
            resolution = {reason = destroyed and "verified_destroyed" or "scripted_vanish", entityId = entityId}}) then
        return nil, "resolve_failed"
    end
    if not EncounterBridge.Transition(OWNER, encounterId, "succeeded", {
            encounterCount = count,
            resolution = {reason = destroyed and "verified_destroyed" or "scripted_vanish", entityId = entityId}}) then
        return nil, "completion_failed"
    end
    if count < SIGHTINGS_BEFORE_ENGAGE then
        schedule(tracker.targetPlayerIndex, count,
            random():getInt(MIN_SIGHTING_COOLDOWN, MAX_SIGHTING_COOLDOWN))
    end
    return true, nil
end

callable(SilentChoirManager, "confirmMaterialized")
callable(SilentChoirManager, "reportMaterializationFailure")
callable(SilentChoirManager, "resolveSighting")
