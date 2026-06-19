package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

-- =========================================================================
-- COSMIC ASCENDANCY: SECTOR ANNIHILATION WIPER
-- =========================================================================
-- This script is dynamically injected into a Player instance by the 
-- Galaxy-level conquest manager. It allows us to safely call `Sector()` 
-- and physically delete all entities in the sector without crashing the server.
-- It cleans up after itself by calling `terminate()` immediately.
-- =========================================================================

function initialize()
    if onServer() then
        local sector = Sector()
        local eclipseFaction = Galaxy():findFaction("The Eclipse")
        if not eclipseFaction then terminate() return end

        sector:addScriptOnce("data/scripts/sector/cv_weather_controller.lua", "DarkMatterFog", -1)

        local entities = {sector:getEntities()}
        for _, entity in pairs(entities) do
            if entity.type == EntityType.Station or entity.type == EntityType.Ship then
                if entity.factionIndex ~= eclipseFaction.index then
                    sector:deleteEntity(entity)
                end
            end
        end

        local EclipseGenerator = include("eclipsegenerator")
        local ship = EclipseGenerator.createShip(Matrix(), "monolith")
        ship:setTitle("Eclipse Obliterator", {})
        ship:addScriptOnce("data/scripts/entity/ca_heroic_defense.lua")

        terminate()
    end
end
