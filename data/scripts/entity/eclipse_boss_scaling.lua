package.path = package.path .. ";data/scripts/lib/?.lua"

local cv_success, CosmicVaultBuffs = pcall(require, "cosmicvaultbuffs")

function initialize()
    if not onServer() then return end
    
    local sector = Sector()
    local players = {sector:getPlayers()}
    local extraPlayers = math.max(0, #players - 1)
    
    if extraPlayers > 0 and cv_success then
        local shieldFactor = extraPlayers * 1.0
        local damageFactor = extraPlayers * 0.5
        
        CosmicVaultBuffs.applyPermanentFactor(Entity().id, StatsBonuses.ShieldDurability, shieldFactor)
        CosmicVaultBuffs.applyPermanentFactor(Entity().id, StatsBonuses.Damage, damageFactor)
    end
end
