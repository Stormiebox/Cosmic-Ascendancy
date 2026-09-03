

if onServer() then
    local entity = Entity()
    if entity and not entity.aiOwned and entity.isShip and entity.playerOrAllianceOwned then
        entity:addScriptOnce("data/scripts/entity/ca_eclipse_interface.lua")
    end
end
