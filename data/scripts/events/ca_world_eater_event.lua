package.path = package.path .. ";data/scripts/lib/?.lua"

local WorldEaterEvent = {}
WorldEaterEvent.worldEaterId = nil

function WorldEaterEvent.initialize(timeLeft)
    if not onServer() then return end
    
    local EclipseGenerator = include("eclipsegenerator")
    -- Spawn far away
    local mat = MatrixLookUpPosition(vec3(0,1,0), vec3(1,0,0), vec3(10000, 5000, -10000))
    local ship = EclipseGenerator.createShip(mat, "juggernaut")
    ship:setTitle("Eclipse World-Eater"%_T, {})
    
    -- Make it incredibly tanky
    ship:addMultiplyableFactor(StatsBonuses.ShieldDurability, 15.0) -- Massive shields
    ship:addMultiplyableFactor(StatsBonuses.Velocity, -0.9)
    ship.scale = 5.0 -- Physically massive
    
    ship:registerCallback("onDestroyed", "onWorldEaterDestroyed")
    WorldEaterEvent.worldEaterId = ship.id.string
end

function WorldEaterEvent.onWorldEaterDestroyed()
    if not onServer() then return end
    local galaxy = Galaxy()
    galaxy:invokeFunction("data/scripts/galaxy/ca_world_eater_manager.lua", "cancelEvent")
    terminate()
end

return WorldEaterEvent
