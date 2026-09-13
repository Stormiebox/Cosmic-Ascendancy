-- namespace AscendancyRiftHazard
AscendancyRiftHazard = {}

local CosmicVaultRift = include("cosmicvaultrift")
local CosmicVaultWeather = include("cosmicvaultweather")

local conditionId
local canonicalSeen = false
local legacyMigrationComplete = false
local ownerEntityId

local function isAscendancyCondition(condition)
    return type(condition) == "table"
        and condition.weatherType == "RiftInstability"
        and type(condition.sourceId) == "string"
        and string.sub(condition.sourceId, 1, 3) == "ca-"
end

local function findCanonicalCondition()
    local sector = Sector()
    if not sector then return nil, "sector_unavailable" end
    local x, y = sector:getCoordinates()
    local conditions, errorCode = CosmicVaultWeather.ListWeatherAt(x, y)
    if not conditions then return nil, errorCode end

    for _, condition in ipairs(conditions) do
        if condition.conditionId == conditionId or (not conditionId and isAscendancyCondition(condition)) then
            conditionId = condition.conditionId
            return condition
        end
    end
    return false
end

local function migrateLegacyAttachment()
    if legacyMigrationComplete then return false end
    local sector = Sector()
    if not sector then return nil end
    local x, y = sector:getCoordinates()
    local condition = CosmicVaultRift.StartRiftHazard({
        sourceId = "ca-legacy-rift:" .. tostring(x) .. ":" .. tostring(y),
        x = x,
        y = y,
        duration = -1,
        conflictPolicy = "replace"
    })
    if condition then
        conditionId = condition.conditionId
        canonicalSeen = true
        legacyMigrationComplete = true
        return true
    end
    return nil
end

function AscendancyRiftHazard.initialize(initialConditionId, initialOwnerEntityId)
    if not onServer() then return end
    if type(initialConditionId) == "string" then conditionId = initialConditionId end
    if type(initialOwnerEntityId) == "string" then ownerEntityId = initialOwnerEntityId end
end

function AscendancyRiftHazard.getUpdateInterval()
    return 2
end

function AscendancyRiftHazard.updateServer()
    local condition = findCanonicalCondition()
    if condition == nil then
        -- A manager or persistence failure is not evidence that the hazard ended.
        return
    elseif condition == false then
        if canonicalSeen then
            terminate()
            return
        end
        if not migrateLegacyAttachment() then return end
    else
        canonicalSeen = true
    end

    if ownerEntityId and not valid(Entity(Uuid(ownerEntityId))) then
        local ended = conditionId and CosmicVaultRift.EndRiftHazard(conditionId,
            "owner_removed")
        if ended then terminate() end
        return
    end

    local sector = Sector()
    local eclipseFaction = Galaxy():findFaction("The Eclipse")
    local eclipseIndex = eclipseFaction and eclipseFaction.index or -1
    for _, entity in pairs({sector:getEntitiesByType(EntityType.Ship)}) do
        if valid(entity) and entity.factionIndex ~= eclipseIndex then
            local maxShield = entity.shieldMaxDurability or 0
            if maxShield > 0 then
                entity:inflictDamage(maxShield * 0.05, DamageSource.Arbitrary,
                    DamageType.Energy, 0, entity.translationf, entity.id)
            end
        end
    end
end

function AscendancyRiftHazard.secure()
    return {
        conditionId = conditionId,
        ownerEntityId = ownerEntityId,
        canonicalSeen = canonicalSeen,
        legacyMigrationComplete = legacyMigrationComplete
    }
end

function AscendancyRiftHazard.restore(data)
    if type(data) ~= "table" then return end
    conditionId = type(data.conditionId) == "string" and data.conditionId or nil
    ownerEntityId = type(data.ownerEntityId) == "string" and data.ownerEntityId or nil
    canonicalSeen = data.canonicalSeen == true
    legacyMigrationComplete = data.legacyMigrationComplete == true
end
