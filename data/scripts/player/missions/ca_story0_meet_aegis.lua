package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
include("structuredmission")

mission._Debug = 0
mission._Name = "A Mysterious Summons"

mission.data.title = "A Mysterious Summons"
mission.data.description = "You have received an encrypted transmission from an entity claiming to be 'Aegis'. The destruction of the Wormhole Guardian has seemingly triggered a response. You should investigate the coordinates provided."

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBeginServer = function()
    local player = Player()
    local x, y = Sector():getCoordinates()
    
    -- Target a random nearby empty sector (5 to 30 jumps away)
    local MissionUT = include("missionutility")
    local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    local targetX, targetY = MissionUT.getEmptySector(x, y, 5, 30, insideBarrier)
    
    -- Fallback in case the search fails to find one
    if not targetX or not targetY then 
        local random = Random()
        targetX = x + random:getInt(-30, 30)
        targetY = y + random:getInt(-30, 30)
    end
    
    mission.data.custom.targetX = targetX
    mission.data.custom.targetY = targetY
    
    mission.data.description = "Rendezvous with the entity 'Aegis' at sector (" .. targetX .. ":" .. targetY .. ")."
    
    -- Send Mail
    local mail = Mail()
    mail.text = "Commander. Do not be alarmed by my intrusion into your systems. I am Aegis.\n\nBy destroying the Keystone, you have unraveled the dimensional knot. We must speak immediately. I have transmitted secure rendezvous coordinates to your ship's computer.\n\nDo not delay."%_T
    mail.header = "Secure Transmission"%_T
    mail.sender = "Aegis"%_T
    player:addMail(mail)
    
    player:sendChatMessage("Ship Computer"%_T, 3, "New rendezvous coordinates received: \\s(%1%:%2%)"%_T, targetX, targetY)
end

function getUpdateInterval()
    return 1.0
end

mission.phases[1].onSectorEntered = function(x, y)
    if x == mission.data.custom.targetX and y == mission.data.custom.targetY then
        local player = Player()
        local sector = Sector()
        
        local aegisExists = false
        local entities = {sector:getEntitiesByScript("entity/story/ca_ascendant_envoy.lua")}
        if #entities > 0 then
            aegisExists = true
        end
        
        if not aegisExists then
            -- Spawn Aegis
            local generator = include("SectorGenerator")(sector:getCoordinates())
            local faction = Galaxy():getNearestFaction(0, 0)
            local ship = generator:createShip(faction, "data/scripts/entity/story/ca_ascendant_envoy.lua")
            ship.name = "Aegis, The Ascendant Envoy"%_T
            ship.title = "Ascendant AI Construct"%_T
            ship:setInvincible(true)
            ship.dockable = false
            ship.crew = ship.minCrew
            
            local plan = LoadPlanFromFile("data/plans/ascendant/ca_aegis.xml")
            if plan then ship:setPlan(plan) end
            
            local ShipUtility = include("shiputility")
            ShipUtility.addTurretsToCraft(ship, nil, 0, 0)
            ship:addScriptOnce("entity/ca_envoy_despawn.lua")
        end
        
        player:sendChatMessage("Aegis, The Ascendant Envoy"%_T, 0, "Commander. Approach my projection and initiate contact."%_T)
        
        -- Play OST just for this player
        player:addScriptOnce("data/scripts/player/ca_boss_audio_hook.lua")
        player:invokeFunction("data/scripts/player/ca_boss_audio_hook.lua", "triggerGuardianFellMusic")
        
        player:setValue("ca_ready_for_debrief_intro", true)
        
        mission.data.description = "You have found Aegis. Approach the Ascendant AI Construct and initiate contact."
    end
end

mission.phases[1].updateServer = function()
    local player = Player()
    if mission.data.custom.targetX and mission.data.custom.targetY then
        local x, y = Sector():getCoordinates()
        if x == mission.data.custom.targetX and y == mission.data.custom.targetY then
            -- If Aegis removed the flag, it means the player talked to her and got mission 1.
            if player:getValue("ca_ready_for_debrief_intro") == nil then
                finish()
            end
        end
    end
end
