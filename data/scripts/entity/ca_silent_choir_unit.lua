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
SilentChoirUnit.encounterId = nil
SilentChoirUnit.entityId = nil

-- willEngage: passed true on the sighting that's meant to commit to a real fight instead of
-- vanishing (see ca_silent_choir_manager.lua, the only caller). Defaults false for any other/
-- legacy attachment.
function SilentChoirUnit.initialize(willEngage, encounterId, entityId)
    SilentChoirUnit.willEngage = willEngage or false
    SilentChoirUnit.encounterId = encounterId
    SilentChoirUnit.entityId = entityId
    if onServer() and SilentChoirUnit.willEngage then
        Entity():registerCallback("onDestroyed", "onDestroyed")
    end
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
        Galaxy():invokeFunction("data/scripts/galaxy/ca_silent_choir_manager.lua",
            "resolveSighting", SilentChoirUnit.encounterId, SilentChoirUnit.entityId, false)
        sector:deleteEntity(entity)
    end
end

function SilentChoirUnit.onDestroyed()
    Galaxy():invokeFunction("data/scripts/galaxy/ca_silent_choir_manager.lua",
        "resolveSighting", SilentChoirUnit.encounterId, SilentChoirUnit.entityId, true)
end

function SilentChoirUnit.secure()
    return {willEngage = SilentChoirUnit.willEngage, hasActed = SilentChoirUnit.hasActed,
        encounterId = SilentChoirUnit.encounterId, entityId = SilentChoirUnit.entityId}
end

function SilentChoirUnit.restore(data)
    if not data then return end
    SilentChoirUnit.willEngage = data.willEngage == true
    SilentChoirUnit.hasActed = data.hasActed == true
    SilentChoirUnit.encounterId = data.encounterId
    SilentChoirUnit.entityId = data.entityId
    if onServer() and SilentChoirUnit.willEngage then
        Entity():registerCallback("onDestroyed", "onDestroyed")
    end
end
