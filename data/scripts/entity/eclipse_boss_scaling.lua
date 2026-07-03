package.path = package.path .. ";data/scripts/lib/?.lua"

local CosmicVaultBuffs = include("cosmicvaultbuffs")

function initialize()
    if not onServer() then return end
    
    local sector = Sector()
    local players = {sector:getPlayers()}
    local extraPlayers = math.max(0, #players - 1)
    
        -- The Eclipse is the ultimate endgame crisis. 
        -- They receive a baseline massive buff (strictly stronger than War Dreadnoughts which get 10x shields)
        local shieldFactor = 25.0 + (extraPlayers * 2.0)
        local damageFactor = 3.0 + (extraPlayers * 1.0)
        
        if CosmicVaultBuffs then
            local isWorldEater = string.match(Entity().translatedTitle or Entity().title or "", "World%-Eater")
            
            if not isWorldEater then
                CosmicVaultBuffs.applyPermanentFactor(Entity().id, StatsBonuses.ShieldDurability, shieldFactor)
            end
        end
        
        local entity = Entity()
        -- Apply DPS scaling correctly via engine API (using FireRate as a DPS multiplier)
        entity:addMultiplyableBias(StatsBonuses.FireRate, damageFactor - 1.0)
end
