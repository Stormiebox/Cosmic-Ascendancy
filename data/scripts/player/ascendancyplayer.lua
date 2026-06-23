package.path = package.path .. ";data/scripts/lib/?.lua"

local cv_buffs = include("cosmicvaultbuffs")
include("cosmicascendancyconfig")
-- namespace AscendancyPlayer
AscendancyPlayer = {}

function AscendancyPlayer.initialize()
    if onServer() then Player():addScriptOnce("data/scripts/player/background/ca_campaign_controller.lua") end
    if onServer() then
        Player():registerCallback("onSectorEntered", "onSectorEntered")
        Player():registerCallback("onEntityCreated", "onEntityCreated")
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

    if not entity:hasScript("data/scripts/entity/ascendancyglobalbuff.lua") then
        entity:addScript("data/scripts/entity/ascendancyglobalbuff.lua")
    end
    
    if entity.isStation then
        if not entity:hasScript("data/scripts/entity/ca_station_overdrive.lua") then
            entity:addScript("data/scripts/entity/ca_station_overdrive.lua")
        end
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

    -- IMPORTANT ARCHITECTURE NOTE:
    -- We cannot physically spawn stations or ships in the `onSectorGenerated` galaxy event
    -- inside `server.lua`, because calling `Sector()` there crashes the game.
    -- Instead, `server.lua` flags the coordinates globally. When a player physical enters, 
    -- this player script reads the flag and spawns the Stronghold safely inside the sector.
    if onServer() then
        if Server():getValue("eclipse_stronghold_" .. x .. "_" .. y) then
            local sector = Sector()
            if not sector:getValue("eclipse_stronghold_spawned") then
                sector:setValue("eclipse_stronghold_spawned", true)
                local EclipseGenerator = include("eclipsegenerator")
                local station = EclipseGenerator.createStation(Matrix())
                station:addScript("entity/deleteonplayersleft.lua")
                
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
                    
                    defender:addScript("ai/patrol.lua")
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

function AscendancyPlayer.onEntityCreated(entityId)
    applyToEntity(entityId)
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
function onEntityCreated(...)
    if AscendancyPlayer.onEntityCreated then return AscendancyPlayer.onEntityCreated(...) end
end
function onShipChanged(...)
    if AscendancyPlayer.onShipChanged then return AscendancyPlayer.onShipChanged(...) end
end

return AscendancyPlayer
