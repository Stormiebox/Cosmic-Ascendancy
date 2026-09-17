package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
local CosmicVaultData = include("cosmicvaultdata")
local EclipseChoir = include("ca_eclipse_choir")

-- namespace EclipseAwakes
EclipseAwakes = {}

local OWNER = "data/scripts/galaxy/eclipse_awakes.lua"
local COORDINATOR = "data/scripts/galaxy/ca_state_coordinator.lua"
local AWAKENING_DURATION = 10 * 60
local announced = {unleashed = false, warning1 = false, warning2 = false, fullyAwake = false}

local function canonicalState()
    return CosmicVaultData.GetRecord(Server(), "ca_state_v2", 2)
end

local function coordinator(functionName, ...)
    local resultCode, first, second = Galaxy():invokeFunction(COORDINATOR, functionName, ...)
    if resultCode ~= 0 then return nil, "coordinator_unavailable" end
    return first, second
end

local function transition(phase, state)
    local revision, err = coordinator("requestEclipseAwakening", OWNER, state.revision, phase)
    if revision or err ~= "revision_mismatch" then return revision, err end
    state = canonicalState()
    if not state then return nil, "state_unavailable" end
    return coordinator("requestEclipseAwakening", OWNER, state.revision, phase)
end

local function cinematic(title)
    for _, player in pairs({Server():getOnlinePlayers()}) do
        player:addScriptOnce("data/scripts/player/ca_boss_audio_hook.lua")
        player:invokeFunction("data/scripts/player/ca_boss_audio_hook.lua",
            "triggerCinematicBanner", title, "data/sounds/siren.ogg")
    end
end

function EclipseAwakes.getUpdateInterval()
    return 5
end

function EclipseAwakes.getAwakeningElapsed()
    local state = canonicalState()
    if not state or not state.eclipse.unleashedAt then return 0 end
    return math.max(0, Server().unpausedRuntime - state.eclipse.unleashedAt)
end

function EclipseAwakes.initialize()
    EclipseChoir.registerChoirLines("awakening")
end

function EclipseAwakes.updateServer(timeStep)
    local state = canonicalState()
    if not state or state.guardian.state ~= "confirmed" then return end
    if state.eclipse.state == "dormant" then
        transition("awakening", state)
        return
    end

    if not announced.unleashed then
        announced.unleashed = true
        EclipseChoir.registerChoirLines("unleashed")
        Server():broadcastChatMessage("Server", 2,
            "An ominous shudder ripples through the fabric of subspace... The Guardian's death has broken an ancient seal."%_T)
        cinematic("THE ECLIPSE AWAKENS")
    end

    if state.eclipse.state == "awakening" then
        local elapsed = math.max(0, Server().unpausedRuntime - (state.eclipse.unleashedAt or Server().unpausedRuntime))
        if elapsed >= 3 * 60 and not state.eclipse.warning1At then
            local changed = transition("warning1", state)
            if changed then
                announced.warning1 = true
                Server():broadcastChatMessage("Server", 3,
                    "WARNING: Massive hyperspace anomalies detected across all sectors. Something ancient is waking up."%_T)
                cinematic("MASSIVE HYPERSPACE ANOMALY")
            end
            return
        end
        if elapsed >= 8 * 60 and not state.eclipse.warning2At then
            local changed = transition("warning2", state)
            if changed then
                announced.warning2 = true
                Server():broadcastChatMessage("Server", 3,
                    "CRITICAL WARNING: The anomalies are stabilizing into jump signatures. Black Avorion readings are off the charts!"%_T)
                cinematic("BLACK AVORION SIGNATURES DETECTED")
            end
            return
        end
        if elapsed >= AWAKENING_DURATION then
            local changed = transition("fully_awake", state)
            if changed then
                announced.fullyAwake = true
                EclipseChoir.registerChoirLines("fully_awake")
                Server():broadcastChatMessage("The Eclipse", 2,
                    "Your ignorance has doomed this galaxy. We are The Eclipse. You will be erased."%_T)
            end
        end
    end

    state = canonicalState() or state
    if state.eclipse.state == "fully_awake" then
        local EclipseGenerator = include("eclipsegenerator")
        EclipseGenerator.getFaction()
    end
end

function EclipseAwakes.secure()
    return {schemaVersion = 2, announced = announced}
end

function EclipseAwakes.restore(data)
    data = data or {}
    if data.schemaVersion == 2 then announced = data.announced or announced end
    if data.nextInvasionTime and data.nextInvasionTime > 0 then
        local state = canonicalState()
        if state and (state.territory.threat or 0) == 0 then
            local remaining = math.max(0, data.nextInvasionTime - Server().unpausedRuntime)
            local threat = math.max(0, math.min(10000, 10000 - (remaining * (10000 / 2700))))
            coordinator("requestTerritoryState", OWNER, state.revision,
                "add_threat", {amount = threat, source = "legacy_invasion_timer"})
        end
    end
end
