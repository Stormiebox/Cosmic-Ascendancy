package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

function getUpdateInterval()
    return 1.0
end


mission._Name = "Forging the Defense"

abandon = nil -- this mission is not abandonable
mission.data.brief = mission._Name
mission.data.icon = "data/textures/icons/story-mission.png"
mission._Debug = 0

mission.data.description = "The Eclipse are real, and they possess shielding technology that adapts to our weapons. Aegis mentioned an ancient, planet-sized failsafe built by the Ascendants: the 'Ascendancy Forge'."
mission.data.title = "Forging the Defense"

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBeginServer = function()
    local x, y = Sector():getCoordinates()
    local targetX, targetY = getTargetSector(x, y)
    mission.data.custom.targetX = targetX
    mission.data.custom.targetY = targetY
    mission.data.description = "Aegis uploaded a set of ancient encrypted coordinates. Jump to (" .. targetX .. ":" .. targetY .. ") to investigate."
end

mission.phases[1].onSectorEntered = function(x, y)
    if x == mission.data.custom.targetX and y == mission.data.custom.targetY then
        Player():sendChatMessage("Ship Sensors", 3, "Scans indicate massive subterranean ruins on the largest asteroid in this sector. Sending surface rovers to investigate...")
        nextPhase()
    end
end

mission.phases[2] = {}
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].onBeginServer = function()
    mission.data.description = "Rovers are exploring the subterranean ruins. Protect the sector and wait for their report."
    mission.data.custom.waitTime = Server().unpausedRuntime + 30 -- Wait 30 seconds
    
    Player():sendChatMessage("Rover Alpha", 0, "Commander, we're inside the ruins. It's an ancient manufacturing facility. The databanks are mostly corrupted, but we're attempting a direct download of the main schematics now.")
end

mission.phases[2].updateServer = function()
    if Server().unpausedRuntime >= mission.data.custom.waitTime then
        Player():sendChatMessage("Rover Alpha", 0, "Download complete! It's blueprints for an 'Ascendancy Forge'. We're returning to the ship.")
        Player():sendChatMessage("Aegis", 0, "Commander, the blueprints are secured. However, to power the primary reactor and begin forging weapons capable of piercing Eclipse armor, the facility requires a massive influx of raw Avorion as a catalyst.")
        nextPhase()
    end
end

mission.phases[3] = {}
mission.phases[3].onBeginServer = function()
    mission.data.description = "To power the Ascendancy Forge's primary reactor, you need to gather an initial supply of 50,000 Avorion to act as a catalyst."
end

mission.phases[3].updateServer = function()
    local player = Player()
    local iron, tit, nao, tri, xan, ogo, avo = player:getResources()
    if avo >= 50000 then
        player:pay(0, 0, 0, 0, 0, 0, 0, 50000)
        Player():sendChatMessage("Aegis", 0, "Catalyst accepted. The Ascendancy Forge blueprints are fully unlocked. Commander, a new threat has emerged while you were gathering materials. Meet me at these coordinates immediately.")
        Player():setValue("ca_forge_unlocked", true)
        
        local x, y = Sector():getCoordinates()
        local rx, ry = getTargetSector(x, y)
        mission.data.custom.aegisX = rx
        mission.data.custom.aegisY = ry
        nextPhase()
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
            if not plan then
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
                ship:addScriptOnce("entity/ca_envoy_despawn.lua")
                ship:addScriptOnce("entity/story/ca_ascendant_envoy.lua")

                Player():sendChatMessage(ship.name, 0, "Commander. Approach my projection and initiate contact."%_T)
                aegisExists = true -- mark success so the debrief flag below reflects reality
            end
        end
        -- Only mark the player "ready for debrief" once Aegis is actually confirmed present (see
        -- ca_story0_meet_aegis.lua for the full rationale) -- otherwise a failed createShip() would
        -- tell the player to approach a ship that doesn't exist, with no way to recover.
        if aegisExists then
            Player():setValue("ca_ready_for_debrief_2", true)
            mission.data.custom.debriefReady = true
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
            if mission.data.custom.debriefReady and player:getValue("ca_ready_for_debrief_2") == nil then
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
        return x + random:getInt(-30, 30), y + random:getInt(-30, 30)
    end
    
    return targetX, targetY
end