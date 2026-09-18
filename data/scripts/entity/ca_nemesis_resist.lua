package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

-- Pure attachment point: ca_nemesis_hunt.lua conditionally addScriptOnce's this onto the wounded,
-- relocated Dread-Lord, passing the damage type it fled from as the argument. The actual damage
-- math -- both the 90% type reduction and the shared 8% cap -- lives entirely in
-- ca_nemesis_system.lua, which is always attached to every Harbinger and reads the resisted type
-- back off the entity. Two independent onDamaged/onShieldDamaged callbacks on the same entity each
-- see the engine's raw, unmodified hit amount; if this script refunded its own 90% on top of
-- ca_nemesis_system.lua's separate 8% refund, a big resisted hit could get refunded twice over,
-- healing the ship instead of hurting it. Keeping the reduction and the cap in one callback, applied
-- in sequence, is what avoids that.
function initialize(damageType)
    if onServer() then
        local entity = Entity()
        entity:setValue("ca_nemesis_resist_type", damageType or DamageType.Physical)

        -- Alert players that it has adapted
        Sector():broadcastChatMessage(entity.title, 2, "ADAPTATION COMPLETE. NEMESIS PROTOCOLS ENGAGED.")
    end
end
