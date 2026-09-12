package.path = package.path .. ";data/scripts/lib/?.lua"
include("randomext")
local EncounterBridge = include("ca_encounter_bridge")
local OWNER = "data/scripts/player/background/ca_nemesis_hunt.lua"

-- Nemesis Hunt Tracker
-- When an Eclipse Dread-Lord retreats near death (see ca_nemesis_system.lua), it relocates to a
-- nearby sector instead of vanishing outright. This script watches for a player entering that
-- sector and materializes the wounded Dread-Lord there, so the retreat is a lead to follow up on
-- rather than a dead end.

function initialize()
    if onServer() then
        Player():registerCallback("onSectorEntered", "onSectorEntered")
    end
end

function onSectorEntered(playerIndex, x, y, sectorChangeType)
    if onClient() then return end

    local hunt
    for _, candidate in ipairs(EncounterBridge.List("nemesis") or {}) do
        if candidate.x == x and candidate.y == y
                and (candidate.state == "prepared" or candidate.state == "retryable") then
            hunt = candidate
            break
        end
    end
    if not hunt then return end

    local sector = Sector()
    if not sector then return end

    if hunt.state == "retryable" then
        hunt = EncounterBridge.Transition(OWNER, hunt.encounterId, "prepared")
        if not hunt then return end
    end
    local materializing = EncounterBridge.Transition(OWNER, hunt.encounterId, "materializing")
    if not materializing then return end

    local EclipseGenerator = include("eclipsegenerator")
    local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local pos = MatrixLookUpPosition(-dir, vec3(0, 1, 0), dir * 1500)

    -- createShip() reads Server():getValue("eclipse_nemesis_resist") internally for the "ca_harbinger"
    -- plan type and attaches ca_nemesis_resist.lua/ca_nemesis_system.lua on its own, so this Dread-Lord
    -- picks up the same adaptive resistance it fled with without any extra work here.
    local nemesis = EclipseGenerator.createShip(pos, "ca_harbinger")
    if not nemesis then
        local latest = EncounterBridge.Get(hunt.encounterId)
        EncounterBridge.Transition(OWNER, hunt.encounterId,
            latest and (latest.attempt or 0) >= 4 and "repair_required" or "retryable",
            {lastError = "nemesis_spawn_failed"})
        return
    end

    nemesis.title = "Eclipse Dread-Lord (Wounded)"%_T
    nemesis:setValue("ca_nemesis_hunted", true)
    if hunt.resistanceType ~= nil then
        nemesis:addScriptOnce("data/scripts/entity/ca_nemesis_resist.lua", hunt.resistanceType)
    end
    local activated = EncounterBridge.TagAndActivate(OWNER, hunt.encounterId, nemesis, {
        targetPlayerIndex = playerIndex
    })
    if not activated then return end

    -- It fled at 5% HP; heal it partway so finding it is a real fight, not a single-hit kill,
    -- matching the WIKI's "it will return" framing rather than "it returns still dying."
    nemesis.durability = nemesis.maxDurability * 0.4

    sector:broadcastChatMessage("Sensors"%_T, 2, "Nemesis signature detected. The wounded Dread-Lord has been located."%_T)
    Player(playerIndex):sendChatMessage("Sensors"%_T, 0, "This is the Dread-Lord that escaped before. Finish it."%_T)
end
