package.path = package.path .. ";data/scripts/lib/?.lua"

local cv_success, cv_news = pcall(require, "cosmicvaultnews")
local cv_fleet_success, cv_fleet = pcall(require, "cosmicvaultfleet")

-- namespace EclipseBossBehavior
EclipseBossBehavior = {}
local self = EclipseBossBehavior

function EclipseBossBehavior.initialize()
    if onServer() then
        Entity():registerCallback("onDestroyed", "onDestroyed")
        Entity():registerCallback("onDamaged", "onDamaged")
        
        if cv_fleet_success and cv_fleet.orderAttackEnemies then
            cv_fleet.orderAttackEnemies(Entity().index, true)
        end
    end
end

function EclipseBossBehavior.getUpdateInterval()
    return 10
end

function EclipseBossBehavior.updateClient()
    registerBoss(Entity().index)
end

function EclipseBossBehavior.updateServer()
    local entity = Entity()
    if cv_fleet_success and cv_fleet.orderAttackEnemies then
        cv_fleet.orderAttackEnemies(entity.index, true)
    end
end

local triggeredWarning = false
function EclipseBossBehavior.onDamaged(objectIndex, amount, inflictor)
    if not triggeredWarning then
        local ratio = Entity().durability / Entity().maxDurability
        if ratio < 0.5 then
            triggeredWarning = true
            Sector():broadcastChatMessage(Entity().name, 2, "PATHETIC. THE OBLIVION ENGINE CANNOT BE STOPPED. INITIATING OMEGA PURGE."%_t)
        end
    end
end

function EclipseBossBehavior.onDestroyed(index, lastDamageInflictor)
    local sector = Sector()
    local x, y = sector:getCoordinates()

    Server():broadcastChatMessage("System"%_T, 0, "The Eclipse Oblivion Engine has been destroyed in sector \\s(%1%:%2%)!"%_T, x, y)
    Server():setValue("eclipse_annihilator_dead", true)

    if cv_success and cv_news.publishArticle then
        cv_news.publishArticle({
            title = "Oblivion Engine Neutralized!",
            content = "In an impossible feat of galactic coordination, the Eclipse superweapon known as The Eclipse Oblivion Engine has been destroyed in sector [" .. x .. ":" .. y .. "]. Trillions of lives have been saved.",
            category = "Galactic War"
        })
    end

    local players = {sector:getPlayers()}
    for _, player in pairs(players) do
        player:receive("Eclipse Oblivion Bounty", 5000000000) 
        player:sendChatMessage("Recovered Datapad", 0, "'The Oblivion Engine operates at peak efficiency. The galaxy will be purged, just as the architect intended. Project Stormbox is a complete success.'")
    end
end

return EclipseBossBehavior
