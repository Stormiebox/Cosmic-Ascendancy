package.path = package.path .. ";data/scripts/lib/?.lua"

local cv_buffs = include("cosmicvaultbuffs")
include("cosmicascendancyconfig")
-- namespace AscendancyPlayer
AscendancyPlayer = {}

function AscendancyPlayer.initialize()
    if onServer() then Player():addScriptOnce("data/scripts/player/background/ca_campaign_controller.lua") end
    if onServer() then Player():addScriptOnce("data/scripts/player/background/ca_darksector_generator.lua") end
    if onServer() then
        Player():registerCallback("onSectorEntered", "onSectorEntered")
        Player():registerCallback("onShipChanged", "onShipChanged")
        Player():addScriptOnce("data/scripts/player/cosmicascendancycodex.lua")
    end
end

local function applyToEntity(entityId, playerIndex)
    local entity = Entity(entityId)
    if not entity then return end

    if entity.type ~= EntityType.Ship and entity.type ~= EntityType.Station then return end

    local p = Player(playerIndex)
    if not p then return end

    -- Apply to ships/stations owned by the player, OR their alliance!
    local ownerIndex = entity.factionIndex
    if ownerIndex ~= p.index then
        local allianceIndex = p.allianceIndex
        if not allianceIndex or ownerIndex ~= allianceIndex then return end
    end

    entity:addScriptOnce("data/scripts/entity/ca_ascendancy_ship_buff.lua")
    
    if entity.isStation then
        entity:addScriptOnce("data/scripts/entity/ca_station_overdrive.lua")
    end
end

function AscendancyPlayer.onSectorEntered(playerIndex, x, y)
    local entities = {Sector():getEntitiesByFaction(playerIndex)}

    local p = Player(playerIndex)
    if p and p.allianceIndex then
        local allianceEntities = {Sector():getEntitiesByFaction(p.allianceIndex)}
        for _, e in pairs(allianceEntities) do
            table.insert(entities, e)
        end
    end

    for _, entity in pairs(entities) do
        applyToEntity(entity.id, playerIndex)
    end

    -- Spawn Eclipse Strongholds safely. 
    -- We dynamically roll the Stronghold flag on first player entry to bypass impossible Server() generation hooks
    if onServer() then
        local sector = Sector()
        
        -- PROGRESSIVE MATERIALIZATION INTERCEPT (Lag Fix)
        local pendingAnnihilations = Server():getValue("eclipse_pending_annihilations") or ""
        local pendingSieges = Server():getValue("eclipse_pending_sieges") or ""
        local coordStr = x .. "_" .. y .. ","
        local escapedCoordStr = string.gsub(coordStr, "%-", "%%-")
        -- These lists only delimit entries with a trailing comma (e.g. "25_10,5_10,"), so a bare
        -- "5_10," pattern would false-match as a substring inside "25_10,". Anchor the leading
        -- side too by searching/replacing against a "," + haystack, then restore the original
        -- (no-leading-comma) convention with :sub(2) after any removal.
        local anchoredPattern = "," .. escapedCoordStr

        if string.find("," .. pendingAnnihilations, anchoredPattern) then
            -- Remove from pending list
            Server():setValue("eclipse_pending_annihilations", string.gsub("," .. pendingAnnihilations, anchoredPattern, ","):sub(2))
            if not sector:hasScript("sector/ca_delayed_annihilation.lua") then
                sector:addScriptOnce("data/scripts/sector/ca_delayed_annihilation.lua")
            end
        end

        if string.find("," .. pendingSieges, anchoredPattern) then
            -- Remove from pending list
            Server():setValue("eclipse_pending_sieges", string.gsub("," .. pendingSieges, anchoredPattern, ","):sub(2))
            if not sector:hasScript("events/siegeevent.lua") then
                sector:addScriptOnce("data/scripts/events/siegeevent.lua")
            end
        end
        
        -- AI / Pirate Expansion Intercept (Cosmic Vault)
        local pendingExpansions = Server():getValue("CosmicVault_PendingExpansions") or ""
        local vaultPrefix = string.gsub(x .. "__" .. y .. "__", "%-", "%%-")
        local vaultPattern = vaultPrefix .. "([%-%w]+)__([%w]+),"
        local factionStr, pirateStr = string.match(pendingExpansions, vaultPattern)

        if factionStr and pirateStr then
            local isPirate = (pirateStr == "true")
            local factionIndex = tonumber(factionStr)
            
            local entryToRemove = x .. "__" .. y .. "__" .. factionStr .. "__" .. pirateStr .. ","
            local escapedEntry = string.gsub(entryToRemove, "%-", "%%-")
            Server():setValue("CosmicVault_PendingExpansions", string.gsub(pendingExpansions, escapedEntry, ""))
            
            -- Generate the Outpost/Hideout natively!
            if isPirate then
                local PirateGenerator = include("pirategenerator")
                local level = Balancing_GetPirateLevel(x, y)
                local faction = Galaxy():getPirateFaction(level)
                if faction then
                    local SectorGenerator = include("SectorGenerator")
                    local generator = SectorGenerator(x, y)
                    if random():getFloat() < 0.5 then
                        generator:createStation(faction, "data/scripts/entity/merchants/smugglersmarket.lua").title = "Smuggler's Hideout"
                    else
                        generator:createStation(faction, "data/scripts/entity/merchants/shipyard.lua").title = "Pirate Shipyard"
                    end
                end
            else
                local faction = Faction(factionIndex)
                if faction then
                    local SectorGenerator = include("SectorGenerator")
                    local generator = SectorGenerator(x, y)
                    local types = {
                        "data/scripts/entity/merchants/militaryoutpost.lua",
                        "data/scripts/entity/merchants/resourcedepot.lua",
                        "data/scripts/entity/merchants/tradingpost.lua",
                        "data/scripts/entity/merchants/researchstation.lua"
                    }
                    generator:createStation(faction, types[random():getInt(1, #types)])
                end
            end
        end
        
        if Server():getValue("eclipse_fully_awake") and not sector:getValue("eclipse_stronghold_rolled") then
            sector:setValue("eclipse_stronghold_rolled", true)
            
            local SectorSpecifics = include("sectorspecifics")
            local specs = SectorSpecifics(x, y, Server().seed)
            if specs.regular then
                local dist = math.sqrt(x*x + y*y)
                local rand = Random(Seed(Server().seed + x + y))
                local chance = 0.0
                if dist <= 75 then chance = 0.50
                elseif dist <= 150 then chance = 0.25
                else chance = rand:getFloat(0.05, 0.15) end
                
                if rand:getFloat() < chance then
                    sector:setValue("is_eclipse_stronghold", true)
                end
            end
        end

        if sector:getValue("is_eclipse_stronghold") and not sector:getValue("eclipse_stronghold_spawned") then
            sector:setValue("eclipse_stronghold_spawned", true)
            local EclipseGenerator = include("eclipsegenerator")
            EclipseGenerator.createStation(Matrix())
                
                local defenderTypes = {"ca_obliterator", "ca_voidweaver", "ca_phantom", "ca_singularity", "ca_juggernaut", "ca_interceptor", "ca_harvester", "ca_defiler"}
                for i = 1, 4 do
                    local typeIdx = random():getInt(1, #defenderTypes)
                    local sType = defenderTypes[typeIdx]
                    local pos = MatrixLookUpPosition(vec3(0,0,1), vec3(0,1,0), vec3(random():getInt(-1000, 1000), 0, random():getInt(-1000, 1000)))
                    
                    local defender
                    if sType == "ca_voidweaver" then
                        defender = EclipseGenerator.createCarrier(pos)
                    elseif sType == "ca_phantom" then
                        defender = EclipseGenerator.createAssassin(pos)
                    elseif sType == "ca_singularity" then
                        defender = EclipseGenerator.createArtillery(pos)
                    elseif sType == "ca_juggernaut" then
                        defender = EclipseGenerator.createJuggernaut(pos)
                    elseif sType == "ca_interceptor" then
                        defender = EclipseGenerator.createInterceptor(pos)
                    elseif sType == "ca_harvester" then
                        defender = EclipseGenerator.createHarvester(pos)
                    elseif sType == "ca_defiler" then
                        defender = EclipseGenerator.createDefiler(pos)
                    else
                        defender = EclipseGenerator.createShip(pos, sType)
                    end
                    
                    -- Ensure the generator successfully created a defender before assigning AI scripts
                    if defender then
                        defender:addScriptOnce("ai/patrol.lua")
                    end
                end
            end
        

        
        -- Raid Summoner (Listens for Datacore jettisons)
        if not Sector():hasScript("data/scripts/sector/ca_raid_summoner.lua") then
            Sector():addScriptOnce("data/scripts/sector/ca_raid_summoner.lua")
        end
    end
end


function AscendancyPlayer.onShipChanged(playerIndex, craftId)
    applyToEntity(craftId, playerIndex)
end
