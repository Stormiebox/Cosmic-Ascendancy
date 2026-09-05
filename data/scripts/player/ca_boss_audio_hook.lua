package.path = package.path .. ";data/scripts/lib/?.lua"
include("callable")

-- namespace CaBossAudioHook
CaBossAudioHook = {}

function CaBossAudioHook.initialize()
    if onServer() then return end
end

-- CosmicVaultUI.ShowCinematicBanner(player, ...) is itself a SERVER-side entry point (its own
-- first line is `if not onServer() then return false end`) that does its own complete
-- server->client relay internally (player:invokeFunction into the player's own
-- cosmicvaultcinematic.lua instance, which then invokeClientFunction's the actual client-side
-- renderer). The previous version of this file called it from the CLIENT side, after already
-- relaying there itself via triggerCinematicBanner's invokeClientFunction -- a double-relay that
-- meant ShowCinematicBanner's own onServer() guard always failed and the banner never rendered
-- for ANY of this file's callers ("THE ECLIPSE AWAKENS", "MASSIVE HYPERSPACE ANOMALY", "BLACK
-- AVORION SIGNATURES DETECTED", "DOOMSDAY EVENT - N MINS", every use across eclipse_awakes.lua
-- and ca_world_eater_manager.lua). Fixed by calling ShowCinematicBanner directly from the
-- server-side trigger function below -- no client-side banner wrapper needed at all, since
-- ShowCinematicBanner already gets it there on its own.
function CaBossAudioHook.triggerCinematicBanner(text, soundPath)
    if onClient() then return end
    local CosmicVaultUI = include("cosmicvaultui")
    if CosmicVaultUI and CosmicVaultUI.ShowCinematicBanner then
        CosmicVaultUI.ShowCinematicBanner(Player(), text, ColorRGB(1, 0, 0), soundPath or "data/sounds/siren.ogg", 5)
    end
end
callable(CaBossAudioHook, "triggerCinematicBanner")

-- The Choir's proximity stinger: a lightweight, quiet-dread cue for crossing
-- into Eclipse-held territory -- deliberately not using the default siren.ogg, since that sound
-- is already the mod's "loud alarm" cue (Doomsday warnings, awakening alerts) and reusing it here
-- would undercut the "something noticed you, quietly" tone this is going for. No dedicated
-- stinger sound asset exists in data/sounds -- rather than invent a file path that doesn't exist
-- (which would silently fail to play, or worse), this is text-only. Same direct-from-server call
-- as triggerCinematicBanner above, for the same reason.
function CaBossAudioHook.triggerAmbientStinger(text)
    if onClient() then return end
    local CosmicVaultUI = include("cosmicvaultui")
    if CosmicVaultUI and CosmicVaultUI.ShowCinematicBanner then
        CosmicVaultUI.ShowCinematicBanner(Player(), text, ColorRGB(0.5, 0.05, 0.6), nil, 4)
    end
end
callable(CaBossAudioHook, "triggerAmbientStinger")

-- Invoked when entering the sector or when phase changes
function CaBossAudioHook.playBossMusic(phase)
    if onServer() then return end

    local musicPath = ""
    if phase == 1 then
        musicPath = "data/music/world_eater_phase1.ogg"
    elseif phase == 2 then
        musicPath = "data/music/world_eater_enraged.ogg"
    end

    if musicPath ~= "" then
        Music():fadeOut(1.0)
        Music():playTrack(musicPath, true, 1.0)
    end
    print("Cosmic Ascendancy Hook: Playing boss music " .. musicPath)
end

function CaBossAudioHook.stopBossMusic()
    if onServer() then return end
    Music():fadeOut(3.0)
    print("Cosmic Ascendancy Hook: Stopping boss music.")
end

function CaBossAudioHook.playGuardianFellMusic()
    if onServer() then return end
    -- Immediately kill the vanilla combat/background music so it doesn't overlap
    Music():stop()
    -- Start the Forge The Ascendant OST
    Music():playTrack("data/music/special/forge_the_ascendant.ogg", false, 1.0)
    print("Cosmic Ascendancy Hook: Playing Forge The Ascendant OST.")
end



-- Server-to-Client Bridge Functions
function CaBossAudioHook.triggerGuardianFellMusic()
    if onClient() then return end
    invokeClientFunction(Player(), "playGuardianFellMusic")
end

function CaBossAudioHook.triggerBossMusic(phase)
    if onClient() then return end
    invokeClientFunction(Player(), "playBossMusic", phase)
end

function CaBossAudioHook.triggerStopBossMusic()
    if onClient() then return end
    invokeClientFunction(Player(), "stopBossMusic")
end
callable(CaBossAudioHook, "playBossMusic")
callable(CaBossAudioHook, "stopBossMusic")
callable(CaBossAudioHook, "playGuardianFellMusic")

callable(CaBossAudioHook, "triggerGuardianFellMusic")
callable(CaBossAudioHook, "triggerBossMusic")
callable(CaBossAudioHook, "triggerStopBossMusic")
