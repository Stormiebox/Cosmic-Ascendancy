package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

package.path = package.path .. ";data/scripts/lib/?.lua"

-- =========================================================================
-- COSMIC ASCENDANCY: DELAYED SECTOR ANNIHILATION WIPER
-- =========================================================================
-- This script is attached to unloaded sectors by the Galaxy conquest manager.
-- When a player finally visits this sector, this script boots up, physically
-- annihilates all entities, applies Dark Matter Fog, and terminates.
-- =========================================================================

include("stringutility")

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

        -- Eclipse Wastes: the fog + permanent Obliterator guardian below
        -- already made this a visually hostile zone, but nothing made it mechanically dangerous
        -- to linger in -- ca_rift_hazard.lua (the same shield-drain hazard used for Dark Sectors
        -- near the core) closes that gap with no new code needed, just attaching it here too.
        sector:addScriptOnce("data/scripts/sector/ca_rift_hazard.lua")

        -- Reclaimed ships: capture each deleted entity's faction/position
        -- before it's gone, then have a small chance to spawn a normal Eclipse ship near where
        -- one stood, flavor-tagged with whose it was. Not an attempt to convert the actual wreck
        -- object -- that's uncertain API territory, and the entities are about to be deleted
        -- anyway -- just a thematically-linked new spawn using the same createShip() pipeline
        -- already proven safe everywhere else in this file.
        local reclaimCandidates = {}
        local entities = {sector:getEntities()}
        for _, entity in pairs(entities) do
            if entity.type == EntityType.Station or entity.type == EntityType.Ship then
                if entity.factionIndex ~= eclipseFaction.index then
                    if not entity.playerOwned and not entity.allianceOwned then
                        local owner = Faction(entity.factionIndex)
                        if owner and entity.type == EntityType.Ship then
                            table.insert(reclaimCandidates, {pos = entity.translationf, factionName = owner.translatedName})
                        end
                        sector:deleteEntity(entity)
                    end
                end
            end
        end

        local EclipseGenerator = include("eclipsegenerator")

        if #reclaimCandidates > 0 and random():getFloat() < 0.15 then
            local candidate = reclaimCandidates[random():getInt(1, #reclaimCandidates)]
            local mat = MatrixLookUpPosition(vec3(0, 0, 1), vec3(0, 1, 0), candidate.pos)
            local reclaimed = EclipseGenerator.createInterceptor(mat)
            if reclaimed then
                reclaimed:setTitle(Format("Reclaimed %1% Vessel"%_T, candidate.factionName), {})
                reclaimed:addScriptOnce("ai/patrol.lua")
            end
        end

        -- A player is guaranteed to be physically present here (this script only runs "when a
        -- player finally visits this sector", per the header comment above), so spawn the guardian
        -- with a small offset rather than at literal sector origin -- matches the spread already
        -- used for the Eclipse Stronghold defenders in ascendancyplayer.lua.
        local guardianPos = MatrixLookUpPosition(vec3(0, 0, 1), vec3(0, 1, 0), vec3(random():getFloat(-500, 500), random():getFloat(-500, 500), random():getFloat(-500, 500)))
        local ship = EclipseGenerator.createShip(guardianPos, "ca_obliterator")
        if ship then
            ship:setTitle("Eclipse Obliterator", {})
            ship:addScriptOnce("data/scripts/entity/ca_heroic_defense.lua")
        end

        terminate()
    end
end
