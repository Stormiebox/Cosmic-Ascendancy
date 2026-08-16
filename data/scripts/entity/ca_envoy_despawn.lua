package.path = package.path .. ";data/scripts/lib/?.lua"

function initialize()
    if onServer() then
        Sector():registerCallback("onPlayerLeft", "onPlayerLeft")
        
        -- In case there are somehow no players in the sector upon spawning
        checkDespawn()
    end
end

function onPlayerLeft(playerIndex, sectorChangeType)
    checkDespawn()
end

function checkDespawn()
    local players = {Sector():getPlayers()}
    if #players == 0 then
        -- No players left in the sector. Clean up Aegis to prevent clutter.
        local entity = Entity()
        if entity then
            entity:addScriptOnce("entity/utility/delayeddelete.lua", 1.0)
        end
    end
end
