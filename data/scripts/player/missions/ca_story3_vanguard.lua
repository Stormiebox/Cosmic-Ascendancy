package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

function getUpdateInterval()
    return 1.0
end


mission._Name = "The Vanguard Assault"

abandon = nil -- this mission is not abandonable
mission.data.brief = mission._Name
mission.data.icon = "data/textures/icons/story-mission.png"
mission._Debug = 0

mission.data.description = "The Eclipse are mounting a massive assault against your position. They have tracked the energy signature of the Ascendancy Forge blueprints."
mission.data.title = "The Vanguard Assault"

mission.phases[1] = {}
mission.phases[1].onBeginServer = function()
    local x, y = Sector():getCoordinates()
    mission.data.custom.targetX = x
    mission.data.custom.targetY = y
    
    mission.data.description = "A massive Eclipse Vanguard Juggernaut is warping in! Defend the sector at all costs."
    
    local EclipseGenerator = include("eclipsegenerator")

    local existingBoss = {Sector():getEntitiesByScriptValue("ca_eclipse_boss")}
    if #existingBoss == 0 then
        -- Spawn Boss
        local dir = normalize(vec3(random():getFloat(-1, 1), random():getFloat(-1, 1), random():getFloat(-1, 1)))
        local pos = dir * 1500
        local boss = EclipseGenerator.createJuggernaut(MatrixLookUpPosition(-dir, vec3(0,1,0), pos))
        
        boss:setValue("ca_eclipse_boss", true)
        
        -- Add 4 Interceptors as escorts
        for i = 1, 4 do
            local escortPos = MatrixLookUpPosition(-dir, vec3(0,1,0), pos + vec3(random():getFloat(-200, 200), random():getFloat(-200, 200), random():getFloat(-200, 200)))
            local escort = EclipseGenerator.createInterceptor(escortPos)
            escort:setValue("ca_eclipse_ambush", true)
        end
        
        Player():sendChatMessage("The Eclipse", 2, "Your primitive, chaotic constructs are an insult to absolute order. The Ascendants' Forge belongs to us. Relinquish it, and your sanitation will be swift.")
    end
    mission.data.custom.bossSpawned = true
end

mission.phases[1].updateServer = function()
    local x, y = Sector():getCoordinates()
    if x ~= mission.data.custom.targetX or y ~= mission.data.custom.targetY then return end
    if not mission.data.custom.bossSpawned then return end
    
    local boss = {Sector():getEntitiesByScriptValue("ca_eclipse_boss")}
    if #boss == 0 then
        Player():sendChatMessage("Ship Computer", 0, "The Juggernaut is destroyed! Its core is destabilizing... wait, it's beaming a data packet to the rest of their fleet!")
        Player():sendChatMessage("The Eclipse", 2, "Vanguard lost. Biological chaotic resistance exceeds parameters... Threat level updated. Full galactic sanitation authorized.")
        
        Player():setValue("ca_campaign_completed", nil) -- We no longer end the campaign here
        
        -- Give Reward
        local system = SystemUpgradeTemplate("data/scripts/systems/ascendanteclipsebane.lua", Rarity(5), Seed(123))
        Player():getInventory():add(system)
        Player():sendChatMessage("Reward", 2, "Recovered 'The Eclipse Bane' artifact from the wreckage!")
        
        Player():sendChatMessage("Aegis", 0, "The Vanguard is destroyed, but their transmission went through. We must prepare for what comes next. Meet me at these coordinates.")
        
        local rx, ry = getTargetSector(x, y)
        mission.data.custom.aegisX = rx
        mission.data.custom.aegisY = ry
        nextPhase()
    end
end

mission.phases[2] = {}
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].onBeginServer = function()
    mission.data.description = "Rendezvous with Aegis at (" .. mission.data.custom.aegisX .. ":" .. mission.data.custom.aegisY .. ")."
end

mission.phases[2].onSectorEntered = function(x, y)
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
            Player():setValue("ca_ready_for_debrief_3", true)
            mission.data.custom.debriefReady = true
        end
    end
end

mission.phases[2].updateServer = function()
    local player = Player()
    if mission.data.custom.aegisX and mission.data.custom.aegisY then
        local x, y = player:getSectorCoordinates()
        if x == mission.data.custom.aegisX and y == mission.data.custom.aegisY then
            -- Gated on debriefReady (only set once Aegis was actually confirmed present) so a
            -- pending/failed spawn retry doesn't get misread as a completed debrief.
            if mission.data.custom.debriefReady and player:getValue("ca_ready_for_debrief_3") == nil then
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