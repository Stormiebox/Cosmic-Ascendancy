package.path = package.path .. ";data/scripts/lib/?.lua"

local EclipseGenerator = include("eclipsegenerator")
local spawnedRaid = false

function initialize()
    if onServer() then
        Sector():registerCallback("onEntityCreated", "onEntityCreated")
    end
end

function onEntityCreated(entityId)
    if not onServer() then return end
    if spawnedRaid then return end

    local entity = Entity(entityId)
    if not entity then return end

    if entity:hasComponent(ComponentType.CargoLoot) then
        local loot = CargoLoot(entity)
        if loot and loot:matches("Eclipse Datacore") then
            -- We must ensure the player dropped this, and it didn't just drop from a dying Juggernaut.
            -- Juggernauts belong to the Eclipse faction. So if there are no Eclipse ships currently here,
            -- the player must have brought this Datacore here manually.
            local faction = EclipseGenerator.getFaction()
            if not faction then return end
            
            local sector = Sector()
            local eclipseEntities = {sector:getEntitiesByFaction(faction.index)}
            
            if #eclipseEntities == 0 then
                spawnedRaid = true
                
                -- Destroy the dropped Datacore
                sector:deleteEntity(entity)
                
                -- Broadcast and summon
                sector:broadcastChatMessage("System", 0, "WARNING: Quantum Datacore rupture detected. Massive spatial anomaly opening!")
                
                -- Spawn the World Eater
                local pos = MatrixLookUpPosition(vec3(0,0,1), vec3(0,1,0), vec3(0, 0, 0))
                -- The boss will jump in from hyperspace
                local boss = EclipseGenerator.createWorldEater(pos)
                if boss then
                    sector:createHyperspaceJumpAnimation(boss, boss.look, ColorRGB(0.5, 0.0, 1.0), 1.0)
                    sector:broadcastChatMessage(boss.title, 2, "WHO DARES DISTURB THE VOID.")
                end
            end
        end
    end
end
