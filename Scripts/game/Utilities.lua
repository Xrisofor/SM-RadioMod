dofile("$CONTENT_40639a2c-bb9f-4d4f-b88c-41bfe264ffa8/Scripts/ModDatabase.lua")

Utilities = class()

function Utilities.loadCustomMusicTracks(customRadio)
    customRadio.trackInfo = {}
    customRadio.tracks = { "No Playing" }

    local function loadTracks(filePath)
        if not sm.json.fileExists(filePath) then
            print("File not found: " .. filePath)
            return
        end

        local success, data = pcall(sm.json.open, filePath)
        if not success or type(data) ~= "table" then
            print("Failed to open or invalid format: " .. filePath)
            return
        end

        local isEffectSet = false
        for k, _ in pairs(data) do
            if type(k) == "string" then
                isEffectSet = true
            end
            break
        end

        if isEffectSet then
            for name, effect in pairs(data) do
                if type(name) == "string" and name:gsub(":", "") == name then
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
            for _, file in ipairs(data) do
                local fullPath = "$CONTENT_DATA/Effects/Database/EffectSets/" .. file
                if sm.json.fileExists(fullPath) then
                    local success2, effects = pcall(sm.json.open, fullPath)
                    if success2 and type(effects) == "table" then
                        for name, effect in pairs(effects) do
                            if type(name) == "string" and name:gsub(":", "") == name then
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
                        print("Failed to load effects from: " .. fullPath)
                    end
                else
                    print("File not found: " .. fullPath)
                end
            end
        end
    end

    loadTracks("$CONTENT_DATA/Effects/Database/EffectSets/game.effectset")
    loadTracks("$CONTENT_DATA/Effects/Database/EffectSets/events.effectset")
    loadTracks("$CONTENT_DATA/Effects/custom_effects.json")

    Utilities.initCustomTracks(customRadio)

    table.sort(customRadio.tracks)
    if customRadio.tracks[1] == "No Playing" then
        table.remove(customRadio.tracks, 1)
    end
end

function Utilities.initCustomTracks(customRadio)
    print("Load Custom Tracks")

    ModDatabase.loadDescriptions()
    local loadedMods = ModDatabase.getAllInstalledMods()

    for _, localId in ipairs(loadedMods) do
        if localId ~= sm.uuid.new("e8d9c47d-8029-4441-b662-95ef4ccd55be") and ModDatabase.isModInstalled(localId) then
            local modPath = "$CONTENT_" .. localId
            local customEffectsPath = modPath .. "/Effects/custom_effects.json"

            sm.log.info(customEffectsPath)

            if sm.json.fileExists(customEffectsPath) then
                print("Find 'custom_effects.json' in " .. localId)

                local success, effectList = pcall(sm.json.open, customEffectsPath)
                if success and type(effectList) == "table" then
                    for _, filename in ipairs(effectList) do
                        local fullPath = modPath .. "/Effects/Database/EffectSets/" .. filename
                        if sm.json.fileExists(fullPath) then
                            local success2, effects = pcall(sm.json.open, fullPath)
                            if success2 and type(effects) == "table" then
                                for name, effect in pairs(effects) do
                                    if type(name) == "string" and name:gsub(":", "") == name then
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
                                print("Couldn't load effects from: " .. fullPath)
                            end
                        else
                            print("File not found: " .. fullPath)
                        end
                    end
                else
                    print("Couldn't load list of effects from: " .. customEffectsPath)
                end
            end
        end
    end

    ModDatabase.unloadDescriptions()
end