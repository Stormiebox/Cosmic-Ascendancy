package.path = package.path .. ";data/scripts/lib/?.lua"

local cv_buffs = include("cosmicvaultbuffs")
include("cosmicascendancyconfig")
-- namespace AscendancyPlayer
AscendancyPlayer = {}

function AscendancyPlayer.initialize()
    if onServer() then Player():addScriptOnce("data/scripts/player/background/ca_campaign_controller.lua") end
    if onServer() then Player():addScriptOnce("data/scripts/player/background/ca_darksector_generator.lua") end
    if onServer() then
        Player():registerCallback("onSectorEntered", "onSectorEntered")
        Player():registerCallback("onShipChanged", "onShipChanged")
        Player():addScriptOnce("data/scripts/player/cosmicascendancycodex.lua")
    end
end

local function applyToEntity(entityId)
    local entity = Entity(entityId)
    if not entity then return end

    -- Apply to ships/stations owned by the player, OR their alliance!
    local ownerIndex = entity.factionIndex
    if ownerIndex ~= Player().index then
        local allianceIndex = Player().allianceIndex
        if not allianceIndex or ownerIndex ~= allianceIndex then return end
    end

    entity:addScriptOnce("data/scripts/entity/ca_ascendancy_ship_buff.lua")
    
    if entity.isStation then
        entity:addScriptOnce("data/scripts/entity/ca_station_overdrive.lua")
    end
end

function AscendancyPlayer.onSectorEntered(playerIndex, x, y)
    local entities = {Sector():getEntitiesByFaction(playerIndex)}

    local p = Player(playerIndex)
    if p and p.allianceIndex then
        local allianceEntities = {Sector():getEntitiesByFaction(p.allianceIndex)}
        for _, e in pairs(allianceEntities) do
            table.insert(entities, e)
        end
    end

    for _, entity in pairs(entities) do
        applyToEntity(entity.id)
    end

    -- Spawn Eclipse Strongholds safely. 
    -- The galaxy generation scripts flag coordinates globally; when a player jumps in, 
    -- this script reads the flag and handles the physical entity spawning to avoid context crashes.
    if onServer() then
        if Server():getValue("eclipse_stronghold_" .. x .. "_" .. y) then
            local sector = Sector()
            if not sector:getValue("eclipse_stronghold_spawned") then
                sector:setValue("eclipse_stronghold_spawned", true)
                local EclipseGenerator = include("eclipsegenerator")
                local station = EclipseGenerator.createStation(Matrix())
                
                local defenderTypes = {"pyramid", "voidweaver", "phantom", "singularity", "juggernaut", "interceptor", "harvester", "defiler"}
                for i = 1, 4 do
                    local typeIdx = random():getInt(1, #defenderTypes)
                    local sType = defenderTypes[typeIdx]
                    local pos = MatrixLookUpPosition(vec3(0,0,1), vec3(0,1,0), vec3(random():getInt(-1000, 1000), 0, random():getInt(-1000, 1000)))
                    
                    local defender
                    if sType == "voidweaver" then
                        defender = EclipseGenerator.createCarrier(pos)
                    elseif sType == "phantom" then
                        defender = EclipseGenerator.createAssassin(pos)
                    elseif sType == "singularity" then
                        defender = EclipseGenerator.createArtillery(pos)
                    elseif sType == "juggernaut" then
                        defender = EclipseGenerator.createJuggernaut(pos)
                    elseif sType == "interceptor" then
                        defender = EclipseGenerator.createInterceptor(pos)
                    elseif sType == "harvester" then
                        defender = EclipseGenerator.createHarvester(pos)
                    elseif sType == "defiler" then
                        defender = EclipseGenerator.createDefiler(pos)
                    else
                        defender = EclipseGenerator.createShip(pos, sType)
                    end
                    
                    -- Ensure the generator successfully created a defender before assigning AI scripts
                    if defender then
                        defender:addScriptOnce("ai/patrol.lua")
                    end
                end
                
                sector:setValue("is_eclipse_stronghold", true)
            end
        end
        

        
        -- Raid Summoner (Listens for Datacore jettisons)
        if not Sector():hasScript("data/scripts/sector/ca_raid_summoner.lua") then
            Sector():addScriptOnce("data/scripts/sector/ca_raid_summoner.lua")
        end
    end
end


function AscendancyPlayer.onShipChanged(playerIndex, craftId)
    applyToEntity(craftId)
end


function initialize(...)
    if AscendancyPlayer.initialize then return AscendancyPlayer.initialize(...) end
end
function onSectorEntered(...)
    if AscendancyPlayer.onSectorEntered then return AscendancyPlayer.onSectorEntered(...) end
end


-- Global Event Callbacks
function onShipChanged(...)
    if AscendancyPlayer.onShipChanged then return AscendancyPlayer.onShipChanged(...) end
end

return AscendancyPlayer
