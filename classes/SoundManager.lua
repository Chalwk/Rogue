-- Rogue (2025) – A Modern Dungeon Crawler Adaptation
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local SoundManager = {}
SoundManager.__index = SoundManager

function SoundManager.new()
    local instance = setmetatable({
        sounds = {
            --walk = love.audio.newSource("assets/sounds/walk.wav", "static"),
            --attack = love.audio.newSource("assets/sounds/attack.wav", "static"),
            --monster_hit = love.audio.newSource("assets/sounds/monster_hit.wav", "static"),
            --player_hit = love.audio.newSource("assets/sounds/player_hit.wav", "static"),
            --pickup = love.audio.newSource("assets/sounds/pickup.wav", "static"),
            --level_up = love.audio.newSource("assets/sounds/level_up.wav", "static")
        }
    }, SoundManager)

    for _, sound in pairs(instance.sounds) do sound:setVolume(0.7) end

    return instance
end

function SoundManager:play(soundName, loop)
    if loop then self.sounds[soundName]:setLooping(true) end

    if not self.sounds[soundName] then return end

    self.sounds[soundName]:stop()
    self.sounds[soundName]:play()
end

function SoundManager:setVolume(sound, volume) sound:setVolume(volume) end

return SoundManager
