package.path = package.path .. ";data/scripts/lib/?.lua"

local CaBossAudioHook = {}
CaBossAudioHook.bossPhase = 0

function CaBossAudioHook.initialize()
    if onServer() then return end
end

-- Invoked from Server to bridge to Client
function CaBossAudioHook.triggerCinematicBanner(text, soundPath)
    if onClient() then return end
    invokeClientFunction(Player(), "showCinematicBanner", text, soundPath)
end

-- Invoked by the server to show the Cinematic UI Banner for Doomsday
function CaBossAudioHook.showCinematicBanner(text, soundPath)
    if onServer() then return end
    local CosmicVaultUI = include("cosmicvaultui")
    if CosmicVaultUI and CosmicVaultUI.ShowCinematicBanner then
        CosmicVaultUI.ShowCinematicBanner(Player(), text, ColorRGB(1, 0, 0), soundPath or "data/sounds/siren.ogg", 5)
    end
end

-- Invoked when entering the sector or when phase changes
function CaBossAudioHook.playBossMusic(phase)
    if onServer() then return end
    CaBossAudioHook.bossPhase = phase

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
    CaBossAudioHook.bossPhase = 0
    Music():fadeOut(3.0)
    print("Cosmic Ascendancy Hook: Stopping boss music.")
end

function CaBossAudioHook.playGuardianFellMusic()
    if onServer() then return end
    -- Fade out the Wormhole Guardian combat music or other music smoothly over 3 seconds
    Music():fadeOut(3.0)
    -- Start the Forge The Ascendant OST
    Music():playTrack("data/music/special/forge_the_ascendant.ogg", false, 1.0)
    print("Cosmic Ascendancy Hook: Playing Forge The Ascendant OST.")
end



-- Server-to-Client Bridge Functions
function CaBossAudioHook.triggerGuardianFellMusic()
    if onClient() then return end
    invokeClientFunction(Player(), "playGuardianFellMusic")
end

function CaBossAudioHook.triggerCinematicBanner(text, soundPath)
    if onClient() then return end
    invokeClientFunction(Player(), "showCinematicBanner", text, soundPath)
end

function CaBossAudioHook.triggerBossMusic(phase)
    if onClient() then return end
    invokeClientFunction(Player(), "playBossMusic", phase)
end

function CaBossAudioHook.triggerStopBossMusic()
    if onClient() then return end
    invokeClientFunction(Player(), "stopBossMusic")
end

function initialize(...)
    if CaBossAudioHook.initialize then return CaBossAudioHook.initialize(...) end
end

function triggerGuardianFellMusic(...)
    if CaBossAudioHook.triggerGuardianFellMusic then return CaBossAudioHook.triggerGuardianFellMusic(...) end
end
function triggerCinematicBanner(...)
    if CaBossAudioHook.triggerCinematicBanner then return CaBossAudioHook.triggerCinematicBanner(...) end
end
function triggerBossMusic(...)
    if CaBossAudioHook.triggerBossMusic then return CaBossAudioHook.triggerBossMusic(...) end
end
function triggerStopBossMusic(...)
    if CaBossAudioHook.triggerStopBossMusic then return CaBossAudioHook.triggerStopBossMusic(...) end
end

function showCinematicBanner(...)
    if CaBossAudioHook.showCinematicBanner then return CaBossAudioHook.showCinematicBanner(...) end
end
function playBossMusic(...)
    if CaBossAudioHook.playBossMusic then return CaBossAudioHook.playBossMusic(...) end
end
function stopBossMusic(...)
    if CaBossAudioHook.stopBossMusic then return CaBossAudioHook.stopBossMusic(...) end
end
function playGuardianFellMusic(...)
    if CaBossAudioHook.playGuardianFellMusic then return CaBossAudioHook.playGuardianFellMusic(...) end
end

callable(nil, "showCinematicBanner")
callable(nil, "playBossMusic")
callable(nil, "stopBossMusic")
callable(nil, "playGuardianFellMusic")

callable(nil, "triggerGuardianFellMusic")
callable(nil, "triggerCinematicBanner")
callable(nil, "triggerBossMusic")
callable(nil, "triggerStopBossMusic")

return CaBossAudioHook
