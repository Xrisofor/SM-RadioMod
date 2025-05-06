-- utilities.lua
Utilities = {}

function Utilities.loadCustomMusicTracks(customRadio)
    customRadio.trackInfo = {}
    customRadio.tracks = { "No Playing" }

    local function loadTracks(filePath)
        local fileExtension = filePath:match("%.([a-zA-Z0-9]+)$")
        local tracks = sm.json.open(filePath)

        if fileExtension == "effectset" then
            for name, effect in pairs(tracks) do
                if name:gsub(":", "") == name then
                    table.insert(customRadio.tracks, name)
                    if effect.radioMod then
                        customRadio.trackInfo[name] = {
                            Name = effect.radioMod.Name or name,
                            Author = effect.radioMod.Author or "Unknown",
                            Image = effect.radioMod.Image or "Gui/Icons/default_image.png",
                            Duration = effect.radioMod.Duration or 0
                        }
                    end
                end
            end
        else
            for _, file in ipairs(tracks) do
                local effects = sm.json.open("$CONTENT_DATA/Effects/Database/EffectSets/" .. file)
                for name, effect in pairs(effects) do
                    if name:gsub(":", "") == name then
                        table.insert(customRadio.tracks, name)
                        if effect.radioMod then
                            customRadio.trackInfo[name] = {
                                Name = effect.radioMod.Name or name,
                                Author = effect.radioMod.Author or "Unknown",
                                Image = effect.radioMod.Image or "Gui/Icons/default_image.png",
                                Duration = effect.radioMod.Duration or 0
                            }
                        end
                    end
                end
            end
        end
    end

    loadTracks("$CONTENT_DATA/Effects/Database/EffectSets/game.effectset")
    loadTracks("$CONTENT_DATA/Effects/Database/EffectSets/events.effectset")
    if sm.json.fileExists("$CONTENT_DATA/Effects/custom_effects.json") then
        loadTracks("$CONTENT_DATA/Effects/custom_effects.json")
    end

    table.sort(customRadio.tracks)
    if customRadio.tracks[1] == "No Playing" then
        table.remove(customRadio.tracks, 1)
    end
end