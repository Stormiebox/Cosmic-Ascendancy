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
            
            local damageBonuses = {StatsBonuses.ArmedTurrets, StatsBonuses.ArbitraryTurrets}
            for _, stat in pairs(damageBonuses) do
                CosmicVaultBuffs.applyPermanentFactor(Entity().id, stat, damageFactor)
            end
        end
        
        local entity = Entity()
        local shield = Shield(entity.id)
        if shield then
            shield.durability = shield.maximum
        end
end
