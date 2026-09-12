package.path = package.path .. ";data/scripts/lib/?.lua"

-- Single shared source of truth for "what is The Eclipse's current status" -- both the
-- /eclipsestatus chat command and the Eclipse Command Interface UI window call
-- EclipseStatus.getSnapshot() instead of each independently recomputing the same values from
-- Server():getValue(). Two surfaces computing the same status from scratch is exactly the shape
-- of bug this mod hit earlier (the conquest manager's own counter drifting from what
-- /eclipsestatus reported) -- one function, read from both places, closes that class of bug here
-- before it can happen.
local EclipseStatus = {}
local CosmicVaultData = include("cosmicvaultdata")
local CAState = include("ca_state")

-- Fields that don't depend on a specific player (galaxy-wide state only).
function EclipseStatus.getGalaxySnapshot()
    local server = Server()
    local state = CosmicVaultData.GetRecord(server, "ca_state_v2", 2)
        or CAState.NewGalaxyState(server.unpausedRuntime)
    local encounters = CosmicVaultData.GetRecord(server, "ca_encounters_v1", 1)
    local snap = {}

    snap.unleashed = state.eclipse.state ~= "dormant"
    snap.fullyAwake = state.eclipse.state == "fully_awake"
    snap.warning1 = state.eclipse.warning1At ~= nil
    snap.warning2 = state.eclipse.warning2At ~= nil
    snap.repairRequired = state.repairRequired

    local conqueredCount = state.territory.conqueredCount or 0
    snap.conqueredSectors = conqueredCount

    local suppressionUntil = state.timers.citadelSuppressionUntil
    if suppressionUntil and server.unpausedRuntime < suppressionUntil then
        snap.citadelSuppressed = true
        snap.citadelSuppressionRemaining = suppressionUntil - server.unpausedRuntime
    else
        snap.citadelSuppressed = false
        snap.citadelSuppressionRemaining = nil
    end

    local graceEnd = state.timers.worldEaterGraceUntil or 0
    if server.unpausedRuntime < graceEnd then
        snap.worldEaterGraceActive = true
        snap.worldEaterGraceRemaining = graceEnd - server.unpausedRuntime
    else
        snap.worldEaterGraceActive = false
        snap.worldEaterGraceRemaining = nil
    end

    local threat = state.territory.threat or 0
    snap.threatPercent = math.floor(math.min(100, (threat / 10000) * 100))

    snap.fallenEmpire = state.territory.fallenEmpire or false
    local lastCrusade = state.history.lastCrusade
    if lastCrusade then
        snap.lastCrusade = {
            x = lastCrusade.x,
            y = lastCrusade.y,
            kind = lastCrusade.kind,
            secondsAgo = math.max(0, server.unpausedRuntime - (lastCrusade.time or state.timers.lastCrusadeAt or server.unpausedRuntime))
        }
    else
        snap.lastCrusade = nil
    end

    -- Nemesis Signature is a per-player lead, not galaxy-wide state -- see getPersonalSnapshot()
    -- below. A single galaxy-wide record here would silently reassign to whichever Harbinger
    -- retreated most recently, showing every player someone else's lead instead of their own.

    snap.remnantTier = state.territory.remnantTier or 0
    snap.worldEatersKilled = state.territory.worldEatersKilled or 0
    snap.citadelsKilled = state.territory.citadelsKilled or 0

    -- Silent Choir: galaxy-wide singleton tracker, not per-player.
    snap.silentChoir = nil
    if encounters then
        for _, encounter in pairs(encounters.encounters) do
            if encounter.kind == "silent_choir" and encounter.state ~= "succeeded"
                    and encounter.state ~= "abandoned" and encounter.state ~= "expired"
                    and encounter.state ~= "failed_permanent" then
                snap.silentChoir = {
                    targetPlayerIndex = encounter.targetPlayerIndex,
                    lastX = encounter.x or encounter.lastX,
                    lastY = encounter.y or encounter.lastY,
                    encounters = encounter.encounterCount or encounter.encounters or 0
                }
                break
            end
        end
    end

    return snap
end

-- Fields specific to one player (Eclipse Remembers kill score, active Ward). Pass the Player
-- object; returns nil fields gracefully if player is nil so callers don't need to branch.
function EclipseStatus.getPersonalSnapshot(player)
    local snap = {killScore = 0, wardActive = false, wardRemaining = nil, nemesisHunt = nil, campaign = nil}
    if not player then return snap end

    snap.killScore = player:getValue("eclipse_kill_score") or 0

    local wardUntil = player:getValue("eclipse_ward_until")
    if wardUntil and Server().unpausedRuntime < wardUntil then
        snap.wardActive = true
        snap.wardRemaining = wardUntil - Server().unpausedRuntime
    end

    -- Set for every player physically present when a Dread-Lord retreated (ca_nemesis_system.lua),
    -- so a later, unrelated retreat overwriting the shared spawn-gating record doesn't erase what
    -- this player specifically already knows.
    local registry = CosmicVaultData.GetRecord(Server(), "ca_encounters_v1", 1)
    for _, hunt in pairs(registry and registry.encounters or {}) do
        if hunt.kind == "nemesis" and (hunt.state == "prepared" or hunt.state == "retryable"
                or hunt.state == "materializing" or hunt.state == "active") then
            for _, participant in ipairs(hunt.participants or {}) do
                if participant == player.index then snap.nemesisHunt = {x = hunt.x, y = hunt.y} end
            end
        end
    end

    snap.campaign = CosmicVaultData.GetRecord(player, "ca_campaign_v2", 2)

    return snap
end

-- Convenience: both halves merged into one table. player may be nil (galaxy-only snapshot).
function EclipseStatus.getSnapshot(player)
    local snap = EclipseStatus.getGalaxySnapshot()
    local personal = EclipseStatus.getPersonalSnapshot(player)
    for k, v in pairs(personal) do
        snap[k] = v
    end
    return snap
end

-- Shared duration formatter (hours, minutes) so every consumer displays countdowns identically.
function EclipseStatus.formatDuration(seconds)
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    return hours, mins
end

return EclipseStatus
