package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local cv_news = include("cosmicvaultnews")

EclipseRoamingBoss = {}
local self = EclipseRoamingBoss

local data = {}
data.countDown = 5 * 60 -- Only 5 mins for testing initially, then it will reset to 45 mins

function EclipseRoamingBoss.getUpdateInterval()
    return 10
end

function EclipseRoamingBoss.initialize()
    if not onServer() then return end
end

function EclipseRoamingBoss.hasPlayerStations(galaxy, x, y)
    local view = galaxy:getSectorView(x, y)
    if not view then return false end
    for index, stations in pairs(view:getStationsByFaction()) do
        if stations > 0 and galaxy:playerFactionExists(index) then
            return true
        end
    end
    return false
end

function EclipseRoamingBoss.calculateNextAttackedSector()
    local rand = random()
    local galaxy = Galaxy()
    local x = 0
    local y = 0

    for i = 1, 100 do
        local dist = rand:getInt(0, 140)
        local angle = rand:getFloat(0, math.pi * 2)
        x = math.floor(math.cos(angle) * dist)
        y = math.floor(math.sin(angle) * dist)

        local view = galaxy:getSectorView(x, y)
        if view and (view.stations or 0) > 0 and not self.hasPlayerStations(galaxy, x, y) then
            return {x=x, y=y}
        end
    end

    -- Fallback
    local dist = rand:getInt(0, 140)
    local angle = rand:getFloat(0, math.pi * 2)
    return {x = math.floor(math.cos(angle) * dist), y = math.floor(math.sin(angle) * dist)}
end

function EclipseRoamingBoss.update(timeStep)
    local server = Server()
    if not server:getValue("eclipse_fully_awake") then return end
    if server:getValue("eclipse_annihilator_dead") then return end

    data.countDown = data.countDown - timeStep

    if data.countDown <= 0 then
        local galaxy = Galaxy()

        if data.currentlyAttackedSector then
            local coords = data.currentlyAttackedSector.coords

            if not galaxy:sectorLoaded(coords.x, coords.y) then
                galaxy:loadSector(coords.x, coords.y)
            else
                local code = [[
                    function run()
                        Sector():invokeFunction("data/scripts/sector/background/spawneclipseboss.lua", "finish")
                    end
                ]]
                runSectorCode(coords.x, coords.y, true, code, "run")

                data.currentlyAttackedSector = nil
                data.countDown = random():getInt(35, 45) * 60
            end
        else
            local coords = self.calculateNextAttackedSector()

            if not galaxy:sectorLoaded(coords.x, coords.y) then
                galaxy:loadSector(coords.x, coords.y)
            else
                local code = [[
                    function run()
                        Sector():addScriptOnce("data/scripts/sector/background/spawneclipseboss.lua")
                    end
                ]]
                runSectorCode(coords.x, coords.y, true, code, "run")

                data.currentlyAttackedSector = {}
                data.currentlyAttackedSector.coords = coords
                data.countDown = 20 * 60

                Server():broadcastChatMessage("System"%_T, 1, "CRITICAL ALERT: The Eclipse Oblivion Engine has arrived in sector \\s(%1%:%2%)!"%_T, coords.x, coords.y)

                if cv_news.publishArticle then
                    cv_news.publishArticle({
                        title = "World-Eater Sighted!",
                        content = "A superweapon of incomprehensible scale, designated 'The Eclipse Oblivion Engine', has invaded sector [" .. coords.x .. ":" .. coords.y .. "]. It is obliterating everything in its path.",
                        category = "Galactic War"
                    })
                end
            end
        end
    end
end

function EclipseRoamingBoss.secure()
    return data
end

function EclipseRoamingBoss.restore(data_in)
    data = data_in
end

function getUpdateInterval(...)
    if EclipseRoamingBoss.getUpdateInterval then return EclipseRoamingBoss.getUpdateInterval(...) end
end
function initialize(...)
    if EclipseRoamingBoss.initialize then return EclipseRoamingBoss.initialize(...) end
end
function update(...)
    if EclipseRoamingBoss.update then return EclipseRoamingBoss.update(...) end
end
function secure(...)
    if EclipseRoamingBoss.secure then return EclipseRoamingBoss.secure(...) end
end
function restore(...)
    if EclipseRoamingBoss.restore then return EclipseRoamingBoss.restore(...) end
end

return EclipseRoamingBoss
