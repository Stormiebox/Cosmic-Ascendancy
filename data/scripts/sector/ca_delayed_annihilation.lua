package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

-- =========================================================================
-- COSMIC ASCENDANCY: DELAYED SECTOR ANNIHILATION WIPER
-- =========================================================================
-- This script is attached to unloaded sectors by the Galaxy conquest manager.
-- When a player finally visits this sector, this script boots up, physically
-- annihilates all entities, applies Dark Matter Fog, and terminates.
-- =========================================================================

function initialize()
    if onServer() then
        local sector = Sector()
        local eclipseFaction = Galaxy():findFaction("The Eclipse")
        if not eclipseFaction then terminate() return end

        -- Forcefully clear any existing weather that might block Dark Matter Fog
        if sector:hasScript("sector/cv_weather_controller.lua") then
            sector:removeScript("sector/cv_weather_controller.lua")
        end
        sector:addScriptOnce("data/scripts/sector/cv_weather_controller.lua", "DarkMatterFog", -1)

        local entities = {sector:getEntities()}
        for _, entity in pairs(entities) do
            if entity.type == EntityType.Station or entity.type == EntityType.Ship then
                if entity.factionIndex ~= eclipseFaction.index then
                    if not entity.playerOwned and not entity.allianceOwned then
                        sector:deleteEntity(entity)
                    end
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
