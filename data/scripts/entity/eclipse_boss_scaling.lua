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
                -- applyPermanentFactor wraps entity:addMultiplyableBias, which the engine
                -- documents as a FLAT bias added before multipliers ("Adds a bias... added to
                -- stat before multipliers are considered") -- not a percentage. Passing 25.0+
                -- there added a negligible +25 raw shield HP instead of the intended ~26x-42x
                -- scaling. addPermanentBaseMultiplier wraps entity:addBaseMultiplier instead,
                -- whose engine semantics are "a factor of 0.3 becomes 1.3" -- a real percentage
                -- multiplier, matching Cosmic War's own boss-shield-scaling precedent
                -- (addBaseMultiplier(ShieldDurability, 9.0) for a Refugee Convoy's 10x shields).
                CosmicVaultBuffs.addPermanentBaseMultiplier(Entity().id, StatsBonuses.ShieldDurability, shieldFactor)
            end
        end
        
        local entity = Entity()
        -- Apply DPS scaling correctly via engine API (using FireRate as a DPS multiplier)
        entity:addBaseMultiplier(StatsBonuses.FireRate, damageFactor - 1.0)
end
