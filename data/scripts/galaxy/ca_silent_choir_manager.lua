package.path = package.path .. ";data/scripts/lib/?.lua"
include("stringutility")
include("randomext")

-- The Silent Choir: a single galaxy-wide named horror unit that tracks one
-- target player, periodically "sights" them (a whisper-then-vanish beat, ca_silent_choir_unit.lua)
-- while they're in a loaded sector, then finally commits to a real fight after enough sightings.
-- Same cadence class as the existing Nemesis Hunt system, but proactive/roaming instead of
-- reactive to a specific sector.

-- namespace SilentChoirManager
SilentChoirManager = {}

function SilentChoirManager.getUpdateInterval()
    return 30.0
end

local SIGHTINGS_BEFORE_ENGAGE = 3
local MIN_SIGHTING_COOLDOWN = 300 -- 5 minutes
local MAX_SIGHTING_COOLDOWN = 900 -- 15 minutes
local IDLE_ROLL_CHANCE = 0.05 -- per 30s tick once no target is tracked, ~1 in 20 rolls

function SilentChoirManager.updateServer(timeStep)
    if not Server():getValue("eclipse_fully_awake") then return end

    local players = {Server():getOnlinePlayers()}
    if #players == 0 then return end

    local choir = Server():getValue("eclipse_silent_choir")

    if not choir then
        if random():getFloat() < IDLE_ROLL_CHANCE then
            -- An active Ascendant Ward suppresses the Choir picking that player as a target too --
            -- filter warded players out of the candidate pool before rolling.
            local candidates = {}
            for _, p in pairs(players) do
                local wardUntil = p:getValue("eclipse_ward_until")
                if not (wardUntil and Server().unpausedRuntime < wardUntil) then
                    table.insert(candidates, p)
                end
            end
            if #candidates == 0 then return end

            local target = candidates[random():getInt(1, #candidates)]
            Server():setValue("eclipse_silent_choir", {
                targetPlayerIndex = target.index,
                encounters = 0,
                lastX = nil,
                lastY = nil,
                nextCheckTime = Server().unpausedRuntime + random():getInt(MIN_SIGHTING_COOLDOWN, MAX_SIGHTING_COOLDOWN)
            })
        end
        return
    end

    if Server().unpausedRuntime < (choir.nextCheckTime or 0) then return end

    local target = Player(choir.targetPlayerIndex)
    if not target or not Server():isOnline(choir.targetPlayerIndex) then
        -- Target went offline/invalid -- drop the tracker rather than keep polling a ghost; the
        -- idle roll above will pick a fresh target once someone's online again.
        Server():setValue("eclipse_silent_choir", nil)
        return
    end

    local wardUntil = target:getValue("eclipse_ward_until")
    if wardUntil and Server().unpausedRuntime < wardUntil then
        -- Warded right now -- defer this sighting rather than cancel the hunt outright; try again
        -- after the Ward's own 30-minute duration would plausibly have run out.
        choir.nextCheckTime = Server().unpausedRuntime + 1800
        Server():setValue("eclipse_silent_choir", choir)
        return
    end

    local tx, ty = target:getSectorCoordinates()
    if not tx or not ty then return end
    if not Galaxy():sectorLoaded(tx, ty) then return end

    local willEngage = (choir.encounters + 1) >= SIGHTINGS_BEFORE_ENGAGE

    -- Spawn the unit via runSectorCode into the target's current, already-confirmed-loaded
    -- sector -- the same established pattern ca_world_eater_manager.lua's injectSectorScript
    -- already uses for "materialize something in a specific player's live sector."
    local code = [[
        function run(willEngage)
            local EclipseGenerator = include("eclipsegenerator")
            local dir = normalize(vec3(random():getFloat(-1,1), random():getFloat(-1,1), random():getFloat(-1,1)))
            local pos = MatrixLookUpPosition(-dir, vec3(0,1,0), dir * 2500)
            local unit = EclipseGenerator.createAssassin(pos)
            if unit then
                unit:addScriptOnce("data/scripts/entity/ca_silent_choir_unit.lua", willEngage)
            end
        end
    ]]
    runSectorCode(tx, ty, true, code, "run", willEngage)

    if willEngage then
        -- Resolved -- the next idle roll starts a fresh Choir target from scratch.
        Server():setValue("eclipse_silent_choir", nil)
    else
        choir.encounters = choir.encounters + 1
        choir.lastX = tx
        choir.lastY = ty
        choir.nextCheckTime = Server().unpausedRuntime + random():getInt(MIN_SIGHTING_COOLDOWN, MAX_SIGHTING_COOLDOWN)
        Server():setValue("eclipse_silent_choir", choir)
    end
end

-- No secure()/restore() needed: all state lives in Server():setValue("eclipse_silent_choir", ...),
-- which already survives a reload independently of this script's own lifecycle hooks.
