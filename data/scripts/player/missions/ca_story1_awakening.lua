package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")
local CampaignBridge = include("ca_campaign_bridge")
local MissionEncounter = include("ca_mission_encounter")
local EncounterBridge = include("ca_encounter_bridge")
local OWNER = "data/scripts/player/missions/ca_story1_awakening.lua"

function getUpdateInterval()
    return 1.0
end


mission._Name = "The Eclipse Awakening"

abandon = nil -- this mission is not abandonable
mission.data.brief = mission._Name
mission.data.icon = "data/textures/icons/story-mission.png"
mission.data.autoTrackMission = true
mission._Debug = 0

mission.data.description = "Aegis, an Ascendant AI, revealed that the Wormhole Guardian was a keystone holding back the algorithmic plague known as The Eclipse. Now that the seal is broken, you must investigate the first detected subspace anomaly."
mission.data.title = "The Eclipse Awakening"

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBeginServer = function()
    local targetX, targetY = CampaignBridge.GetTarget(1)
    if not targetX or not targetY then return end
    mission.data.custom.targetX = targetX
    mission.data.custom.targetY = targetY
    mission.data.description = "Jump to the anomaly coordinates Aegis provided: (" .. targetX .. ":" .. targetY .. ")\n\nAegis warned that The Eclipse does not conquer—it sanitizes. Be prepared for anything."
end

mission.phases[1].onSectorEntered = function(x, y)
    if x == mission.data.custom.targetX and y == mission.data.custom.targetY then
        Player():sendChatMessage("Ship Sensors"%_T, 3, "WARNING: Massive subspace rupture detected. Energy signatures match nothing in our database. It's... purely dark energy."%_T)
        nextPhase()
    end
end

mission.phases[2] = {}
mission.phases[2].onBeginServer = function()
    mission.data.description = "Investigate the anomaly at (" .. mission.data.custom.targetX .. ":" .. mission.data.custom.targetY .. ")."

    local sector = Sector()
    -- Spawn a monolith to investigate
    local generator = include("SectorGenerator")(Sector():getCoordinates())
    local pos = generator:getPositionInSector(5000)

    local plan = LoadPlanFromFile("data/plans/ascendant/ascendancy_anomaly.xml")
    -- valid(), not a plain nil check -- see eclipsegenerator.lua's createShip for the writeup.
    if not valid(plan) then
        plan = generator:getBasicWreckagePlan()
    end

    local wreck = generator:createWreckage(nil, plan, 10, pos)
    if wreck then mission.data.custom.wreckId = wreck.index.string end
end

mission.phases[2].updateServer = function(timeStep)
    local player = Player()
    local craft = player.craft
    if not craft then return end

    local x, y = Sector():getCoordinates()
    if x ~= mission.data.custom.targetX or y ~= mission.data.custom.targetY then return end

    local wreck = Sector():getEntity(Uuid(mission.data.custom.wreckId))
    if not wreck then
        -- Player destroyed it or it despawned
        nextPhase()
        return
    end

    if distance(craft.translationf, wreck.translationf) < 500 then
        Player():sendChatMessage("Aegis"%_T, 0, "The anomaly is a subspace beacon. It's activating... Commander, prepare yourself. A Vanguard fleet has locked onto your position."%_T)
        -- "entity/delete.lua" does not exist anywhere in vanilla; deletejumped.lua is vanilla's real
        -- entity-removal script (see delayeddelete.lua's own Entity():addScript("deletejumped.lua", ...)).
        wreck:addScriptOnce("data/scripts/entity/deletejumped.lua") -- Delete the wreck
        nextPhase()
    end
end

mission.phases[3] = {}
mission.phases[3].onBeginServer = function()
    mission.data.description = "An Eclipse Vanguard ambush! Survive the attack."
    -- Spawn Eclipse enemies
    local EclipseGenerator = include("eclipsegenerator")
    local prepared = MissionEncounter.Prepare(OWNER, 1, "campaign_scout_ambush",
        mission.data.custom.targetX, mission.data.custom.targetY)
    if not prepared then return end
    mission.data.custom.encounterId = prepared.encounterId

    if prepared.state == "succeeded" then
        mission.data.custom.bossDestroyedVerified = true
        mission.data.custom.bossSpawned = true
        return
    elseif prepared.state == "active" then
        mission.data.custom.bossIds = prepared.entityIds or {}
        for _, id in ipairs(mission.data.custom.bossIds) do
            local ship = Entity(Uuid(id))
            if valid(ship) and ship:getValue("ca_encounter_id") == prepared.encounterId then
                ship:registerCallback("onDestroyed", "onCampaignScoutDestroyed")
            end
        end
        mission.data.custom.bossSpawned = true
        return
    end

    local existing = MissionEncounter.FindTagged("ca_eclipse_ambush", prepared.encounterId)
    if #existing == 0 then
        if not MissionEncounter.BeginMaterialization(OWNER, prepared.encounterId) then return end
        Player():sendChatMessage("Unknown Transmission"%_T, 2, "Chaotic biological variables detected. Sanitation protocol initiated. We are The Eclipse."%_T)

        local spawned = {}
        for i = 1, 3 do
            local ship = EclipseGenerator.createInterceptor(Matrix())
            -- Sector():createShip() (which EclipseGenerator.createInterceptor wraps) can return nil;
            -- indexing it unguarded would throw mid-loop and skip the mission.data.custom.bossSpawned =
            -- true line below, permanently soft-locking this phase's updateServer guard. Mirrors the
            -- existing if-ship-then pattern already used for the wreck/Aegis spawns elsewhere in this file.
            if ship then
                ship.title = "Eclipse Vanguard Scout"
                ship:setValue("ca_eclipse_ambush", true)
                ship:setValue("ca_encounter_id", prepared.encounterId)
                ship:registerCallback("onDestroyed", "onCampaignScoutDestroyed")
                table.insert(spawned, ship)
            end
        end
        if #spawned ~= 3 then
            for _, ship in ipairs(spawned) do Sector():deleteEntity(ship) end
            MissionEncounter.RecordMaterializationFailure(
                OWNER, prepared.encounterId, "campaign_scout_spawn_failed")
            return
        end
        local activated = MissionEncounter.Activate(OWNER, prepared.encounterId, spawned)
        if not activated then return end
        mission.data.custom.bossIds = {}
        for _, ship in ipairs(spawned) do table.insert(mission.data.custom.bossIds, ship.id.string) end
    else
        if #existing ~= 3 then
            EncounterBridge.Transition(OWNER, prepared.encounterId, "repair_required",
                {lastError = "partial_campaign_scout_spawn"})
            return
        end
        local activated = MissionEncounter.Activate(OWNER, prepared.encounterId, existing)
        if activated then
            mission.data.custom.bossIds = {}
            for _, ship in ipairs(existing) do
                ship:registerCallback("onDestroyed", "onCampaignScoutDestroyed")
                table.insert(mission.data.custom.bossIds, ship.id.string)
            end
        end
    end
    mission.data.custom.bossSpawned = mission.data.custom.bossIds ~= nil
end

function onCampaignScoutDestroyed()
    if not mission.data.custom.bossIds then return end
    for _, id in ipairs(mission.data.custom.bossIds) do
        if valid(Entity(Uuid(id))) then return end
    end
    local resolved = MissionEncounter.Resolve(OWNER, mission.data.custom.encounterId)
    if resolved then mission.data.custom.bossDestroyedVerified = true end
end

mission.phases[3].updateServer = function(timeStep)
    local x, y = Sector():getCoordinates()
    if x ~= mission.data.custom.targetX or y ~= mission.data.custom.targetY then return end
    if not mission.data.custom.bossSpawned then
        mission.phases[3].onBeginServer()
        return
    end
    local encounter = EncounterBridge.Get(mission.data.custom.encounterId)
    if encounter and encounter.state == "succeeded" then
        mission.data.custom.bossDestroyedVerified = true
    end
    if mission.data.custom.bossDestroyedVerified then
        Player():sendChatMessage("Aegis"%_T, 0, "Hostiles eliminated. More will come. We must meet. I am transmitting secure rendezvous coordinates."%_T)
        local rx, ry = getTargetSector(x, y)
        mission.data.custom.aegisX = rx
        mission.data.custom.aegisY = ry
        nextPhase()
    else
        local anyValid = false
        for _, id in ipairs(mission.data.custom.bossIds or {}) do
            if valid(Entity(Uuid(id))) then anyValid = true; break end
        end
        if not anyValid and not mission.data.custom.missingReported then
            mission.data.custom.missingReported = true
            MissionEncounter.MarkMissing(OWNER, mission.data.custom.encounterId,
                "campaign_scouts_missing_without_destroy_callback")
        end
    end
end

mission.phases[4] = {}
mission.phases[4].showUpdateOnEnd = true
mission.phases[4].onBeginServer = function()
    mission.data.description = "Rendezvous with Aegis at (" .. mission.data.custom.aegisX .. ":" .. mission.data.custom.aegisY .. ")."
end

mission.phases[4].onSectorEntered = function(x, y)
    if x == mission.data.custom.aegisX and y == mission.data.custom.aegisY then
        local aegisExists = false
        local entities = {Sector():getEntitiesByScript("entity/story/ca_ascendant_envoy.lua")}
        if #entities > 0 then
            aegisExists = true
        end
        if not aegisExists then
            local faction = Galaxy():getNearestFaction(0, 0)
            local plan = LoadPlanFromFile("data/plans/ascendant/ca_aegis.xml")
            -- valid(), not a plain nil check -- see eclipsegenerator.lua's createShip for the writeup.
            if not valid(plan) then
                plan = BlockPlan()
                plan:addBlock(vec3(0,0,0), vec3(2,2,2), BlockDefaults.GetHullBlockIndex(), -1, ColorRGB(1,1,1), Material(0), Matrix(), BlockType.Hull)
            end
            
            local ship = Sector():createShip(faction, "", plan, Matrix())
            if ship then
                ship.name = "Aegis, The Ascendant Envoy"%_T
                ship.title = "Ascendant AI Construct"%_T
                ship.invincible = true
                ship.dockable = false
                ship.crew = ship.minCrew
                
                local ShipUtility = include("shiputility")
                ShipUtility.addTurretsToCraft(ship, nil, 0, 0)
                ship:addScriptOnce("data/scripts/entity/ca_envoy_despawn.lua")
                ship:addScriptOnce("data/scripts/entity/story/ca_ascendant_envoy.lua")

                Player():sendChatMessage(ship.name, 0, "Commander. Approach my projection and initiate contact."%_T)
                aegisExists = true -- mark success so the debrief flag below reflects reality
            end
        end
        -- Only mark the player "ready for debrief" once Aegis is actually confirmed present (see
        -- ca_story0_meet_aegis.lua for the full rationale) -- otherwise a failed createShip() would
        -- tell the player to approach a ship that doesn't exist, with no way to recover.
        -- Only request the debrief while it hasn't already been confirmed once -- see
        -- ca_story0_meet_aegis.lua for why re-requesting on a redundant re-entry into this sector
        -- would stomp a true debriefReady back to false and permanently block finish() below.
        if aegisExists and not mission.data.custom.debriefReady then
            local revision = CampaignBridge.RequestDebrief(1, mission.data.custom.aegisX, mission.data.custom.aegisY)
            mission.data.custom.debriefReady = revision ~= nil
        end
    end
end

mission.phases[4].updateServer = function()
    local player = Player()
    if mission.data.custom.aegisX and mission.data.custom.aegisY then
        local x, y = player:getSectorCoordinates()
        if x == mission.data.custom.aegisX and y == mission.data.custom.aegisY then
            -- Gated on debriefReady (only set once Aegis was actually confirmed present) so a
            -- pending/failed spawn retry doesn't get misread as a completed debrief.
            if mission.data.custom.debriefReady and CampaignBridge.IsDebriefComplete(1) then
                finish()
            end
        end
    end
end

function getTargetSector(x, y)
    local MissionUT = include("missionutility")
    local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    local targetX, targetY = MissionUT.getEmptySector(x, y, 5, 30, insideBarrier)

    if not targetX or not targetY then
        local random = Random()
        -- Guarantee a genuine sector change: a (0,0) offset would return the player's CURRENT
        -- sector as the "target". structuredmission's onSectorEntered only fires on an actual
        -- sector-crossing event (Mission_onSectorEntered, registered against the player's
        -- onSectorEntered engine callback) -- it is never invoked just because a phase begins
        -- while the player already happens to be standing in the target sector. Without this,
        -- a same-sector roll would permanently soft-lock this phase: the player can never
        -- "arrive" at a sector they never left.
        local offsetX, offsetY
        repeat
            offsetX = random:getInt(-30, 30)
            offsetY = random:getInt(-30, 30)
        until offsetX ~= 0 or offsetY ~= 0
        return x + offsetX, y + offsetY
    end

    return targetX, targetY
end

function getCampaignMigrationTarget()
    if mission.data.custom.debriefReady then
        return mission.data.custom.aegisX, mission.data.custom.aegisY
    end
    return mission.data.custom.targetX, mission.data.custom.targetY
end
