package.path = package.path .. ";data/scripts/lib/?.lua"

local CosmicAscendancyConfig = include("cosmicascendancyconfig")
local CosmicVaultTerritory = include("cosmicvaultterritory")

-- namespace CosmicAscendancyExpansionManager
CosmicAscendancyExpansionManager = {}
local self = CosmicAscendancyExpansionManager

self.timer = 0

function CosmicAscendancyExpansionManager.getUpdateInterval()
    return 60 -- Run every minute
end

function CosmicAscendancyExpansionManager.updateServer(timeStep)
    local config = CosmicAscendancyConfig.get()
    if not config.enableExpansion then return end

    self.timer = self.timer + timeStep
    if self.timer < config.expansionInterval * 60 then return end
    self.timer = self.timer - (config.expansionInterval * 60)

    if random():getInt(1, 100) > config.expansionChance then
        return
    end

    self.attemptExpansion(config)
end

function CosmicAscendancyExpansionManager.attemptExpansion(config)
    local galaxy = Galaxy()
    local isPirateExpansion = false

    if config.allowPirateExpansion and random():getFloat() < 0.15 then
        isPirateExpansion = true
    end

    if isPirateExpansion then
        -- Find a random empty sector for pirates
        for tries = 1, 20 do
            local x = random():getInt(-450, 450)
            local y = random():getInt(-450, 450)
            local dist = math.sqrt(x*x + y*y)

            -- Prevent pirates from spawning inside the extreme core (0-50)
            if dist > 50 and not galaxy:getControllingFaction(x, y) then
                if CosmicVaultTerritory and CosmicVaultTerritory.expandToSector then
                    CosmicVaultTerritory.expandToSector(x, y, nil, true)
                end
                return
            end
        end
    else
        -- Standard AI Faction Expansion
        local cpuTimer = HighResolutionTimer()
        cpuTimer:start()
        
        local faction
        for tries = 1, 50 do
            local x = random():getInt(-490, 490)
            local y = random():getInt(-490, 490)
            local f = galaxy:getLocalFaction(x, y)
            if f and f.isAIFaction then
                faction = f
                break
            end
            
            -- CPU Tick Safety
            if cpuTimer.seconds > 0.05 then break end
        end

        if not faction then return end

        local hx, hy = faction:getHomeSectorCoordinates()
        if not hx or not hy then return end

        local homeDist = math.sqrt(hx*hx + hy*hy)

        local currentX, currentY = hx, hy
        local angle = random():getFloat() * math.pi * 2
        local dx = math.cos(angle)
        local dy = math.sin(angle)

        local targetX, targetY
        for step = 1, 30 do
            currentX = currentX + dx * 2
            currentY = currentY + dy * 2
            local cx = math.floor(currentX)
            local cy = math.floor(currentY)

            local cDist = math.sqrt(cx*cx + cy*cy)
            if homeDist > 150 and cDist <= 150 then
                break -- Don't cross the barrier natively
            end

            local controlling = galaxy:getControllingFaction(cx, cy)
            if not controlling then
                targetX = cx
                targetY = cy
                break
            elseif controlling.index ~= faction.index then
                -- Hit another faction's territory
                break
            end
            
            -- CPU Tick Safety
            if cpuTimer.seconds > 0.05 then break end
        end

        if targetX and targetY then
            if CosmicVaultTerritory and CosmicVaultTerritory.expandToSector then
                CosmicVaultTerritory.expandToSector(targetX, targetY, faction.index, false)
            end
        end
    end
end


