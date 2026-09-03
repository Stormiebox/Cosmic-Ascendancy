package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

function getUpdateInterval()
    return 1.0
end


mission._Name = "The World-Eater"

abandon = nil -- this mission is not abandonable
mission.data.brief = mission._Name
mission.data.icon = "data/textures/icons/story-mission.png"
mission._Debug = 0

mission.data.description = "The destruction of the Citadel has triggered a massive response. An Eclipse World-Eater—a ship designed to consume entire stars—has breached our dimension."
mission.data.title = "The World-Eater"

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBeginServer = function()
    local x, y = Sector():getCoordinates()
    local targetX, targetY = getTargetSector(x, y)
    mission.data.custom.targetX = targetX
    mission.data.custom.targetY = targetY
    mission.data.description = "Aegis has locked onto the World-Eater's dimensional wake. Jump to (" .. targetX .. ":" .. targetY .. ") and destroy it before it reaches the core systems!"
end

mission.phases[1].onSectorEntered = function(x, y)
    if x == mission.data.custom.targetX and y == mission.data.custom.targetY then
        Player():sendChatMessage("Aegis"%_T, 0, "It is here. The scale is... unprecedented. Focus all Ascendancy weapons on its core!"%_T)
        nextPhase()
    end
end

mission.phases[2] = {}
mission.phases[2].onBeginServer = function()
    mission.data.description = "Destroy the Eclipse World-Eater!"
    
    local EclipseGenerator = include("eclipsegenerator")

    local existingBoss = {Sector():getEntitiesByScriptValue("ca_eclipse_worldeater")}
    if #existingBoss == 0 then
        -- Spawn World Eater
        local dir = normalize(vec3(random():getFloat(-1, 1), random():getFloat(-1, 1), random():getFloat(-1, 1)))
        local pos = dir * 2500
        -- Assuming createWorldEater exists or we use Juggernaut
        local boss = nil
        if EclipseGenerator.createWorldEater then
            boss = EclipseGenerator.createWorldEater(MatrixLookUpPosition(-dir, vec3(0,1,0), pos))
            -- EclipseGenerator.applyWorldEaterMultiplayerScaling's own comment requires this be called
            -- from every createWorldEater() spawn path (ca_world_eater_event.lua and ca_raid_summoner.lua
            -- both do) -- without it, this fight stays tuned for a single defender regardless of how many
            -- players/alliance members show up for the campaign's final boss. Guarded on boss being
            -- non-nil: Sector():createShip() (which createWorldEater wraps) can return nil, and
            -- applyWorldEaterMultiplayerScaling indexes the ship unconditionally, so calling it with a
            -- failed spawn would throw here -- before the phase even reaches its own nil-guard below.
            if boss then
                EclipseGenerator.applyWorldEaterMultiplayerScaling(boss)
            end
        else
            boss = EclipseGenerator.createJuggernaut(MatrixLookUpPosition(-dir, vec3(0,1,0), pos))
        end

        -- Sector():createShip() (which EclipseGenerator.createWorldEater/createJuggernaut/
        -- createInterceptor wrap) can return nil; indexing it unguarded would throw here and skip
        -- the mission.data.custom.bossSpawned = true line below, permanently soft-locking this
        -- phase's updateServer guard. Mirrors the existing if-ship-then pattern already used for
        -- the Aegis rendezvous spawn later in this file.
        if boss then
            boss.title = "Eclipse World-Eater"
            boss:setValue("ca_eclipse_worldeater", true)
        end

        -- Add heavy escorts
        for i = 1, 8 do
            local escortPos = MatrixLookUpPosition(-dir, vec3(0,1,0), pos + vec3(random():getFloat(-600, 600), random():getFloat(-600, 600), random():getFloat(-600, 600)))
            local escort = EclipseGenerator.createInterceptor(escortPos)
            if escort then
                escort:setValue("ca_eclipse_ambush", true)
            end
        end

        Player():sendChatMessage("The Eclipse"%_T, 2, "Absolute zero. Absolute silence. Absolute order."%_T)
    end
    mission.data.custom.bossSpawned = true
end

mission.phases[2].updateServer = function()
    local x, y = Sector():getCoordinates()
    if x ~= mission.data.custom.targetX or y ~= mission.data.custom.targetY then return end
    if not mission.data.custom.bossSpawned then return end
    
    local boss = {Sector():getEntitiesByScriptValue("ca_eclipse_worldeater")}
    if #boss == 0 then
        Player():sendChatMessage("Aegis"%_T, 0, "The World-Eater is destroyed! Commander, you have proven yourself worthy. We must meet one final time."%_T)
        Player():setValue("ca_campaign_completed", true)
        
        local rx, ry = getTargetSector(x, y)
        mission.data.custom.aegisX = rx
        mission.data.custom.aegisY = ry
        nextPhase()
    end
end

mission.phases[3] = {}
mission.phases[3].showUpdateOnEnd = true
mission.phases[3].onBeginServer = function()
    mission.data.description = "Rendezvous with Aegis at (" .. mission.data.custom.aegisX .. ":" .. mission.data.custom.aegisY .. ") for your final briefing."
end

mission.phases[3].onSectorEntered = function(x, y)
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
        if aegisExists then
            Player():setValue("ca_ready_for_debrief_5", true)
            mission.data.custom.debriefReady = true
        end
    end
end

mission.phases[3].updateServer = function()
    local player = Player()
    if mission.data.custom.aegisX and mission.data.custom.aegisY then
        local x, y = player:getSectorCoordinates()
        if x == mission.data.custom.aegisX and y == mission.data.custom.aegisY then
            -- Gated on debriefReady (only set once Aegis was actually confirmed present) so a
            -- pending/failed spawn retry doesn't get misread as a completed debrief.
            if mission.data.custom.debriefReady and player:getValue("ca_ready_for_debrief_5") == nil then
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
