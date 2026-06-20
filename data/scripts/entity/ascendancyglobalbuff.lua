package.path = package.path .. ";data/scripts/lib/?.lua"

local cv_buffs = include("cosmicvaultbuffs")

-- namespace AscendancyGlobalBuff
AscendancyGlobalBuff = {}

local appliedTier = 0

function AscendancyGlobalBuff.getUpdateInterval()
    return 15 -- Check every 15 seconds
end

function AscendancyGlobalBuff.updateServer(timeStep)
    local entity = Entity()
    if not entity then return end

    local factionIndex = entity.factionIndex
    if not factionIndex then return end

    local tier = 0
    if cv_buffs.getGlobalTier then
        tier = cv_buffs.getGlobalTier(factionIndex)
    end

    if appliedTier ~= tier then
        AscendancyGlobalBuff.removeBuffs()
        appliedTier = tier
        AscendancyGlobalBuff.applyBuffs(tier)
    end
end

function AscendancyGlobalBuff.applyBuffs(tier)
    if tier < 2 then return end
    local entity = Entity()

    -- Tier 2 Buffs: The Outpost (+10% Shield, +10% Speed)
    if tier >= 2 then
        entity:addMultiplier(StatsBonuses.ShieldDurability, 1.1)
        entity:addMultiplier(StatsBonuses.Velocity, 1.1)
    end

    -- Tier 3 Buffs: The Fortress (+15% Shield, +15% Speed, +1 Arbitrary Turret, +20% Cargo)
    if tier >= 3 then
        entity:addMultiplier(StatsBonuses.ShieldDurability, 1.05) -- stacks
        entity:addMultiplier(StatsBonuses.Velocity, 1.05)
        entity:addMultiplier(StatsBonuses.CargoHold, 1.2)
        entity:addAbsolute(StatsBonuses.ArbitraryTurrets, 1)
    end

    -- Tier 4 Buffs: The Capital (+20% Shield, +20% Speed, +2 Turrets, +20% Energy, +10% Fire Rate)
    if tier >= 4 then
        entity:addMultiplier(StatsBonuses.ShieldDurability, 1.05)
        entity:addMultiplier(StatsBonuses.Velocity, 1.05)
        entity:addMultiplier(StatsBonuses.GeneratedEnergy, 1.2)
        entity:addMultiplier(StatsBonuses.FireRate, 1.1)
        entity:addAbsolute(StatsBonuses.ArbitraryTurrets, 1)
    end

    -- Tier 5 Buffs: The Ascendant Empire (+30% Shield, +30% Speed, +4 Turrets, +30% Energy, +20% Fire Rate)
    if tier >= 5 then
        entity:addMultiplier(StatsBonuses.ShieldDurability, 1.1)
        entity:addMultiplier(StatsBonuses.Velocity, 1.1)
        entity:addMultiplier(StatsBonuses.GeneratedEnergy, 1.1)
        entity:addMultiplier(StatsBonuses.FireRate, 1.1)
        entity:addAbsolute(StatsBonuses.ArbitraryTurrets, 2)
        entity:addAbsolute(StatsBonuses.FighterSquads, 1)
    end
end

function AscendancyGlobalBuff.removeBuffs()
    local entity = Entity()
    if appliedTier >= 2 then
        entity:removeMultiplier(StatsBonuses.ShieldDurability, 1.1)
        entity:removeMultiplier(StatsBonuses.Velocity, 1.1)
    end
    if appliedTier >= 3 then
        entity:removeMultiplier(StatsBonuses.ShieldDurability, 1.05)
        entity:removeMultiplier(StatsBonuses.Velocity, 1.05)
        entity:removeMultiplier(StatsBonuses.CargoHold, 1.2)
        entity:removeAbsolute(StatsBonuses.ArbitraryTurrets, 1)
    end
    if appliedTier >= 4 then
        entity:removeMultiplier(StatsBonuses.ShieldDurability, 1.05)
        entity:removeMultiplier(StatsBonuses.Velocity, 1.05)
        entity:removeMultiplier(StatsBonuses.GeneratedEnergy, 1.2)
        entity:removeMultiplier(StatsBonuses.FireRate, 1.1)
        entity:removeAbsolute(StatsBonuses.ArbitraryTurrets, 1)
    end
    if appliedTier >= 5 then
        entity:removeMultiplier(StatsBonuses.ShieldDurability, 1.1)
        entity:removeMultiplier(StatsBonuses.Velocity, 1.1)
        entity:removeMultiplier(StatsBonuses.GeneratedEnergy, 1.1)
        entity:removeMultiplier(StatsBonuses.FireRate, 1.1)
        entity:removeAbsolute(StatsBonuses.ArbitraryTurrets, 2)
        entity:removeAbsolute(StatsBonuses.FighterSquads, 1)
    end
end

function AscendancyGlobalBuff.onDestroyed()
    AscendancyGlobalBuff.removeBuffs()
end

function AscendancyGlobalBuff.onRemove()
    AscendancyGlobalBuff.removeBuffs()
end

function AscendancyGlobalBuff.secure()
    return {appliedTier = appliedTier}
end

function AscendancyGlobalBuff.restore(data)
    appliedTier = data.appliedTier or 0
end


function getUpdateInterval(...)
    if AscendancyGlobalBuff.getUpdateInterval then return AscendancyGlobalBuff.getUpdateInterval(...) end
end
function updateServer(...)
    if AscendancyGlobalBuff.updateServer then return AscendancyGlobalBuff.updateServer(...) end
end
function secure(...)
    if AscendancyGlobalBuff.secure then return AscendancyGlobalBuff.secure(...) end
end
function restore(...)
    if AscendancyGlobalBuff.restore then return AscendancyGlobalBuff.restore(...) end
end

return AscendancyGlobalBuff
