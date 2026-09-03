package.path = package.path .. ";data/scripts/lib/?.lua"
include("stringutility")
include("randomext")

-- The Silent Choir: attached alongside ca_eclipse_abilities.lua (which every
-- Eclipse ship already gets via EclipseGenerator.createShip) to a specially-spawned ca_phantom
-- reused for this encounter. This script owns ONLY the "appear, whisper, vanish" scripted beat --
-- it never calls into ca_eclipse_abilities.lua directly, since each script attached to the same
-- entity runs in its own isolated Lua state with no shared scope or cross-call between them.

-- namespace SilentChoirUnit
SilentChoirUnit = {}
SilentChoirUnit.willEngage = false
SilentChoirUnit.hasActed = false

-- willEngage: passed true on the sighting that's meant to commit to a real fight instead of
-- vanishing (see ca_silent_choir_manager.lua, the only caller). Defaults false for any other/
-- legacy attachment.
function SilentChoirUnit.initialize(willEngage)
    SilentChoirUnit.willEngage = willEngage or false
end

function SilentChoirUnit.getUpdateInterval()
    return 1.0
end

local whispers = {
    "...found you.",
    "...still counting.",
    "...soon.",
    "...we remember your name now."
}

function SilentChoirUnit.updateServer(timeStep)
    if SilentChoirUnit.hasActed then return end
    SilentChoirUnit.hasActed = true

    local sector = Sector()
    if not sector then return end

    sector:broadcastChatMessage("???"%_T, 2, whispers[random():getInt(1, #whispers)]%_T)

    if SilentChoirUnit.willEngage then
        -- Commits to a real fight this time -- no vanish, just this ship, hunting.
        local entity = Entity()
        if entity then entity:addScriptOnce("ai/patrol.lua") end
        return
    end

    deferredCallback(random():getFloat(4.0, 7.0), "vanish")
end

function SilentChoirUnit.vanish()
    local entity = Entity()
    if not valid(entity) then return end
    local sector = Sector()
    if sector then
        sector:broadcastChatMessage("???"%_T, 2, "...gone."%_T)
        sector:deleteEntity(entity)
    end
end
