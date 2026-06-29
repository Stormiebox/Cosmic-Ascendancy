package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

function initialize()
    if onServer() then
        Entity():registerCallback("onDestroyed", "onDestroyed")
    end
end

function onDestroyed()
    if onServer() then
        local sector = Sector()
        sector:removeScript("sector/ca_rift_hazard.lua")
        sector:broadcastChatMessage("System", 1, "The Eclipse Rift Stabilizer has been destroyed! The subspace tear is closing."%_t)
    end
end
