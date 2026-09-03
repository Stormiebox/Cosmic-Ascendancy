package.path = package.path .. ";data/scripts/lib/?.lua"

-- Single shared source of truth for "what is The Eclipse's current status" -- both the
-- /eclipsestatus chat command and the Eclipse Command Interface UI window call
-- EclipseStatus.getSnapshot() instead of each independently recomputing the same values from
-- Server():getValue(). Two surfaces computing the same status from scratch is exactly the shape
-- of bug this mod hit earlier (the conquest manager's own counter drifting from what
-- /eclipsestatus reported) -- one function, read from both places, closes that class of bug here
-- before it can happen.
local EclipseStatus = {}

-- Fields that don't depend on a specific player (galaxy-wide state only).
function EclipseStatus.getGalaxySnapshot()
    local server = Server()
    local snap = {}

    snap.unleashed = server:getValue("the_eclipse_unleashed") or false
    snap.fullyAwake = server:getValue("eclipse_fully_awake") or false
    snap.warning1 = server:getValue("eclipse_warning_1") or false
    snap.warning2 = server:getValue("eclipse_warning_2") or false

    local conqueredCount = server:getValue("eclipse_conquered_sectors") or 0
    snap.conqueredSectors = conqueredCount

    -- eclipse_citadel_destroyed_time only ever gets set by ca_citadel_loot.lua, on an actual
    -- Citadel kill -- must stay nil (not default to 0) so a galaxy that's never had a Citadel
    -- die doesn't get misread as "a Citadel died the instant the galaxy was created."
    local citadelDestroyed = server:getValue("eclipse_citadel_destroyed_time")
    local suppressionDuration = (6 + math.floor(conqueredCount / 10) * 2) * 3600
    if citadelDestroyed and (server.unpausedRuntime - citadelDestroyed) < suppressionDuration then
        snap.citadelSuppressed = true
        snap.citadelSuppressionRemaining = suppressionDuration - (server.unpausedRuntime - citadelDestroyed)
    else
        snap.citadelSuppressed = false
        snap.citadelSuppressionRemaining = nil
    end

    local graceEnd = server:getValue("eclipse_world_eater_grace_end") or 0
    if server.unpausedRuntime < graceEnd then
        snap.worldEaterGraceActive = true
        snap.worldEaterGraceRemaining = graceEnd - server.unpausedRuntime
    else
        snap.worldEaterGraceActive = false
        snap.worldEaterGraceRemaining = nil
    end

    local threat = server:getValue("eclipse_threat") or 0
    snap.threatPercent = math.floor(math.min(100, (threat / 10000) * 100))

    snap.fallenEmpire = server:getValue("eclipse_fallen_empire") or false
    local lastCrusade = server:getValue("eclipse_last_crusade_target")
    if lastCrusade then
        snap.lastCrusade = {
            x = lastCrusade.x,
            y = lastCrusade.y,
            kind = lastCrusade.kind,
            secondsAgo = server.unpausedRuntime - lastCrusade.time
        }
    else
        snap.lastCrusade = nil
    end

    local hunt = server:getValue("eclipse_nemesis_hunt")
    if hunt then
        snap.nemesisHunt = {x = hunt.x, y = hunt.y}
    else
        snap.nemesisHunt = nil
    end

    local EclipseGenerator = include("eclipsegenerator")
    snap.remnantTier = EclipseGenerator.getRemnantTier()
    snap.worldEatersKilled = server:getValue("eclipse_world_eaters_killed") or 0
    snap.citadelsKilled = server:getValue("eclipse_citadels_killed") or 0

    -- Silent Choir: galaxy-wide singleton tracker, not per-player.
    local choir = server:getValue("eclipse_silent_choir")
    if choir then
        snap.silentChoir = {
            targetPlayerIndex = choir.targetPlayerIndex,
            lastX = choir.lastX,
            lastY = choir.lastY,
            encounters = choir.encounters or 0
        }
    else
        snap.silentChoir = nil
    end

    return snap
end

-- Fields specific to one player (Eclipse Remembers kill score, active Ward). Pass the Player
-- object; returns nil fields gracefully if player is nil so callers don't need to branch.
function EclipseStatus.getPersonalSnapshot(player)
    local snap = {killScore = 0, wardActive = false, wardRemaining = nil}
    if not player then return snap end

    snap.killScore = player:getValue("eclipse_kill_score") or 0

    local wardUntil = player:getValue("eclipse_ward_until")
    if wardUntil and Server().unpausedRuntime < wardUntil then
        snap.wardActive = true
        snap.wardRemaining = wardUntil - Server().unpausedRuntime
    end

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
