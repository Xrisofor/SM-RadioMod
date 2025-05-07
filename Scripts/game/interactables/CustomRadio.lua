dofile("$CONTENT_DATA/Scripts/game/Utilities.lua")

CustomRadio = class()

CustomRadio.maxParentCount = 1
CustomRadio.connectionInput = sm.interactable.connectionType.logic + (sm.interactable.connectionType.composite or 0)
CustomRadio.connectionOutput = sm.interactable.connectionType.logic
CustomRadio.colorNormal = sm.color.new("#df6d2d")
CustomRadio.colorHighlight = sm.color.new("#c84c05")
CustomRadio.poseWeightCount = 1
CustomRadio.maxChildCount = 15
CustomRadio.componentType = "customRadio"

-- Helpers
function CustomRadio:consumeFlag(flag)
    if self[flag] then
        self[flag] = nil
        return true
    end
    return false
end

function CustomRadio:sv_updateSetting(key, value, clientFn)
    if self.storageSave[key] ~= value then
        self.storageSave[key] = value
        self["sv_" .. key] = value
        self.storage:save(self.storageSave)
        self.network:sendToClients(clientFn, value)
    end
end

function table.indexOf(tbl, val)
    for i, v in ipairs(tbl) do
        if v == val then
            return i
        end
    end
end

function CustomRadio:isValidEffect()
    return self.cl_audio_effect and sm.exists(self.cl_audio_effect)
end

-- Server
function CustomRadio.server_onCreate(self)
    self.storageSave = self.storage:load() or {
        track = "No Playing",
        volume = 1,
        play_state = false
    }

    self.sv_audioName = self.storageSave.track
    self.sv_volumeLevel = self.storageSave.volume
    self.sv_playState = self.storageSave.play_state

    self.connectedElements = self.interactable:getChildren()

    self.interactable.publicData = {
        sc_component = {
            type = CustomRadio.componentType,
            api = {
                getState = function()
                    return self.storageSave
                end,
                setState = function()
                    self.sc_set_state = true
                end,
                play = function()
                    self.sc_play = true
                end,
                stop = function()
                    self.sc_stop = true
                end,
                next = function()
                    self.sc_next_sound = true
                end,
                back = function()
                    self.sc_back_sound = true
                end,
                getTrackInfo = function()
                    return self.trackInfo[self.cl_currentAudioName] or {
                        Name = "Unknown",
                        Author = "Unknown",
                        Image = "Gui/Icons/default_image.png",
                        Duration = 0
                    }
                end
            }
        }
    }
end

function CustomRadio:server_onFixedUpdate()
    local hostPlayer = sm.player.getAllPlayers()[1]

    if self:consumeFlag("sc_set_state") then
        self.network:sendToClient(hostPlayer, "onSetPlayState")
    end

    if self:consumeFlag("sc_play") and self.storageSave.play_state then
        self.network:sendToClient(hostPlayer, "onSetPlayState")
    end

    if self:consumeFlag("sc_stop") and not self.storageSave.play_state then
        self.network:sendToClient(hostPlayer, "onSetPlayState")
    end

    if self:consumeFlag("sc_next_sound") then
        self.network:sendToClient(hostPlayer, "changeSound", 1)
    end

    if self:consumeFlag("sc_back_sound") then
        self.network:sendToClient(hostPlayer, "changeSound", -1)
    end
end

function CustomRadio.sv_changeTrack(self, setting, player)
    self:sv_updateSetting("track", setting, "cl_changeTrack")
end

function CustomRadio.sv_changeTrackVolume(self, setting, player)
    self:sv_updateSetting("volume", setting, "cl_changeTrackVolume")
end

function CustomRadio.sv_changePlayState(self, setting, player)
    self:sv_updateSetting("play_state", setting, "cl_changePlayState")
end

function CustomRadio.sv_getRadioInfo(self, _, player)
    self.network:sendToClient(player, "cl_updateRadioInfo", {
        track = self.sv_audioName,
        volume = self.sv_volumeLevel,
        playState = self.sv_playState
    })
end

-- Client
function CustomRadio.client_onCreate(self)
    self.cl_currentAudioName = "No Playing"
    self.cl_currentAudioVolume = 1
    self.cl_playState = false
    self.cl_lastUpdate = sm.game.getTimeOfDay()

    self.cl_audio_effect = sm.effect.createEffect("No Playing", self.interactable)

    self.network:sendToServer("sv_getRadioInfo")

    if sm.cae_injected == nil then
        sm.gui.chatMessage(
            "(Radio Mod / Custom Radio) You have not installed #ff0000SM-CustomAudioExtension#ffffff, all music in the radio will not be played until you install the library!")
    end

    Utilities.loadCustomMusicTracks(self)
end

function CustomRadio.cl_updateRadioInfo(self, data)
    self:cl_changeTrack(data.track)
    self:cl_changeTrackVolume(data.volume)
    self:cl_changePlayState(data.playState)
end

function CustomRadio.send_toSpeaker(self, fun, params)
    for _, element in ipairs(self.connectedElements) do
        local shape = element:getShape()
        if shape and shape.uuid == sm.uuid.new("99ae2a73-b28d-4b7c-a558-104ed1b59b1d") then
            sm.event.sendToInteractable(element, fun, params)
        end
    end
end

function CustomRadio:updateAudioEffect(play)
    if play then
        if not self:isValidEffect() or not self.cl_audio_effect:isPlaying() then
            if self.cl_currentAudioName ~= "No Playing" then
                self.cl_audio_effect:start()
                self.interactable:setPoseWeight(0, 1)
            else
                if self:isValidEffect() then
                    self.cl_audio_effect:destroy()
                end
                self.interactable:setPoseWeight(0, 0)
            end
        end
    else
        if self:isValidEffect() and self.cl_audio_effect:isPlaying() then
            self.cl_audio_effect:stop()
            self.interactable:setPoseWeight(0, 0)
        end
    end
end

function CustomRadio.client_onUpdate(self)
    local parent = self.interactable:getSingleParent()
    self.connectedElements = self.interactable:getChildren()

    local active
    if parent then
        local isCompositeConnection = parent:getType() == "scripted"
        local shape = parent:getShape()

        if shape and shape.uuid == sm.uuid.new("3f7a7d81-e33a-4a73-91b7-7f9f20d8489d") then
            active = parent.active
        else
            active = isCompositeConnection and true or parent.active
        end
    end

    local shouldPlay = (not parent and self.cl_playState) or (active and self.cl_playState)
    self:updateAudioEffect(shouldPlay)

    self:send_toSpeaker("remote_radio_controller", {
        currentAudioName = self.cl_currentAudioName,
        currentAudioVolume = self.cl_currentAudioVolume,
        currentPlayState = shouldPlay
    })

    if self:isValidEffect() then
        self.cl_audio_effect:setParameter("CAE_Volume", self.cl_currentAudioVolume / 10.0)
    end
end

function CustomRadio:openGui()
    if not sm.exists(self.gui) then
        self:createGui()
    end

    local trackInfo = self.trackInfo[self.cl_currentAudioName] or {
        Name = "Unknown",
        Author = "Unknown",
        Image = "Gui/Icons/default_image.png",
        Duration = 0
    }

    self.gui:setText("TrackName", trackInfo.Name)
    self.gui:setText("TrackAuthor", trackInfo.Author)
    self.gui:setText("TrackTime", string.format("%d Min", trackInfo.Duration))
    self.gui:setImage("TrackImage", "$CONTENT_DATA/" .. trackInfo.Image)

    self.gui:setText("ConnectedElem", tostring(#self.connectedElements) .. " / " .. tostring(CustomRadio.maxChildCount))

    self.gui:setSelectedDropDownItem("DropDown", self.cl_currentAudioName)
    self.gui:setText("PlayStopButton", self.cl_playState and "Stop" or "Play")
    self.gui:open()
end

function CustomRadio:createGui()
    self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/CustomRadio.layout")

    self.gui:createDropDown("DropDown", "cl_onDropdownInteract", self.tracks)
    self.gui:createHorizontalSlider("VolumeSlider", 11, self.cl_currentAudioVolume * 10, "client_onSliderMoved")

    self.gui:setButtonCallback("PlayStopButton", "onSetPlayState")
    self.gui:setButtonCallback("NextButton", "onNextSound")
    self.gui:setButtonCallback("BackButton", "onBackSound")
    self.gui:setButtonCallback("RandomButton", "onRandomSound")
end

function CustomRadio.remote_control(self)
    self:openGui()
end

function CustomRadio.client_onInteract(self, char, lookAt)
    if lookAt then
        self:remote_control()
    end
end

function CustomRadio.cl_onDropdownInteract(self, option)
    self:selectTrack(option)
end

function CustomRadio.client_onSliderMoved(self, value)
    self.network:sendToServer("sv_changeTrackVolume", value / 10.0)
end

function CustomRadio.cl_changePlayState(self, newState)
    self.cl_playState = newState
    if sm.exists(self.gui) then
        self.gui:setText("PlayStopButton", newState and "Stop" or "Play")
    end
end

function CustomRadio.cl_changeTrack(self, newTrack)
    if self.cl_currentAudioName ~= newTrack and newTrack ~= "" then
        self.cl_currentAudioName = newTrack

        if self:isValidEffect() then
            self.cl_audio_effect:destroy()
            self:send_toSpeaker("remote_radio_controller_destroy", "")
        end

        self.cl_audio_effect = sm.effect.createEffect(newTrack, self.interactable)

        if sm.exists(self.gui) then
            local info = self.trackInfo[newTrack] or {
                Name = "Unknown",
                Author = "Unknown",
                Image = "Gui/Icons/default_image.png",
                Duration = 0
            }

            self.gui:setSelectedDropDownItem("DropDown", newTrack)
            self.gui:setText("TrackName", info.Name)
            self.gui:setText("TrackAuthor", info.Author)
            self.gui:setText("TrackTime", string.format("%d Min", info.Duration))
            self.gui:setImage("TrackImage", "$CONTENT_DATA/" .. info.Image)
        end
    end
end

function CustomRadio.cl_changeTrackVolume(self, newVolume)
    self.cl_currentAudioVolume = newVolume or 1
    self:send_toSpeaker("remote_radio_controller_volume", self.cl_currentAudioVolume)
end

function CustomRadio:selectTrack(trackName)
    if not trackName or trackName == "" then
        return
    end

    if sm.exists(self.gui) then
        self.gui:setSelectedDropDownItem("DropDown", trackName)
    end
    self.network:sendToServer("sv_changeTrack", trackName)
end

function CustomRadio:selectRandomTrack()
    if not self.tracks or #self.tracks == 0 then
        return
    end
    local randomIndex = math.random(1, #self.tracks)
    self:selectTrack(self.tracks[randomIndex])
end

function CustomRadio:onSetPlayState()
    local shouldPlay = not self.cl_playState

    if shouldPlay and (self.cl_currentAudioName == "No Playing" or not self:isValidEffect()) then
        self:selectRandomTrack()
    end

    self.network:sendToServer("sv_changePlayState", shouldPlay)
end

function CustomRadio:changeSound(direction)
    if not self.tracks or #self.tracks == 0 then
        return
    end

    table.sort(self.tracks)
    local currentIndex = table.indexOf(self.tracks, self.cl_currentAudioName) or 1

    local newIndex = ((currentIndex - 1 + direction) % #self.tracks) + 1
    self:selectTrack(self.tracks[newIndex])
end

function CustomRadio:onNextSound()
    self:changeSound(1)
end

function CustomRadio:onBackSound()
    self:changeSound(-1)
end

function CustomRadio:onRandomSound()
    self:selectRandomTrack()
end
