dofile("$CONTENT_DATA/Scripts/game/Utilities.lua")

CustomRadio = class()

CustomRadio.maxParentCount = 1
CustomRadio.connectionInput = sm.interactable.connectionType.logic + sm.interactable.connectionType.seated +
                                  (sm.interactable.connectionType.composite or 0)
CustomRadio.connectionOutput = sm.interactable.connectionType.logic
CustomRadio.colorNormal = sm.color.new("#df6d2d")
CustomRadio.colorHighlight = sm.color.new("#c84c05")
CustomRadio.poseWeightCount = 1
CustomRadio.maxChildCount = 15
CustomRadio.componentType = "customRadio"

local ANTENNA = sm.uuid.new("70eda77b-aff9-4c23-a818-0fcaaf6d577d")

local function repeatModeState(mode)
    return mode == REPEAT_TRACK or mode == REPEAT_PLAYLIST
end

local function formatTime(seconds)
    local s = math.floor(seconds)
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

if not fmdata then
    fmdata = {}
end

if not fmantenna then
    fmantenna = {}
end

-- ─────────────────────────────────────────────
--  HELPERS
-- ─────────────────────────────────────────────

function CustomRadio:consumeFlag(flag)
    if self[flag] then
        self[flag] = nil
        return true
    end
    return false
end

function CustomRadio:isValidEffect()
    return self.cl_audio_effect ~= nil and sm.exists(self.cl_audio_effect)
end

function CustomRadio:hasRealTrack()
    return self.cl_currentAudioName ~= nil and self.cl_currentAudioName ~= ""
end

function CustomRadio:getActiveTracks()
    return Utilities.getPlaylistTracks(self, self.cl_currentPlaylist)
end

function CustomRadio:rebuildShuffleQueue()
    local activeTracks = self:getActiveTracks()
    local pool = {}
    for _, t in ipairs(activeTracks) do
        if t ~= self.cl_currentAudioName then
            table.insert(pool, t)
        end
    end
    for i = #pool, 2, -1 do
        local j = math.random(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    self.cl_shuffleQueue = pool
end

function CustomRadio:nextShuffleTrack()
    if #self.cl_shuffleQueue == 0 then
        self:rebuildShuffleQueue()
    end
    if #self.cl_shuffleQueue == 0 then
        return nil
    end
    local track = self.cl_shuffleQueue[1]
    table.remove(self.cl_shuffleQueue, 1)
    return track
end

-- ─────────────────────────────────────────────
--  FM HELPERS
-- ─────────────────────────────────────────────

function CustomRadio:getFMSignal()
    local freq = self.cl_fmFrequency
    if not fmdata[freq] then
        return nil
    end
    for _, entry in pairs(fmdata[freq]) do
        if entry and entry.track then
            return entry
        end
    end
    return nil
end

function CustomRadio:findAntennaChild()
    for _, child in ipairs(self.interactable:getChildren()) do
        local shape = child:getShape()
        if shape and shape.uuid == ANTENNA then
            return child
        end
    end
    return nil
end

function CustomRadio:cl_updateFMSender()
    local myId = self.interactable.id

    local targetFreq = nil
    local antenna = self:findAntennaChild()
    if antenna and sm.exists(antenna) then
        targetFreq = fmantenna[antenna.id]
    end

    if self.cl_lastAntennaFreq ~= nil and self.cl_lastAntennaFreq ~= targetFreq then
        if fmdata[self.cl_lastAntennaFreq] then
            fmdata[self.cl_lastAntennaFreq][myId] = nil
        end
    end
    self.cl_lastAntennaFreq = targetFreq

    if targetFreq == nil then
        return
    end

    if not fmdata[targetFreq] then
        fmdata[targetFreq] = {}
    end

    if self.cl_currentAudioName and self.cl_currentAudioName ~= "" then
        fmdata[targetFreq][myId] = {
            track = self.cl_currentAudioName,
            volume = self.cl_currentAudioVolume,
            playState = self.cl_playState,
            playSpeed = self.cl_playSpeed
        }
    else
        fmdata[targetFreq][myId] = nil
    end
end

-- ─────────────────────────────────────────────
--  SERVER
-- ─────────────────────────────────────────────

function CustomRadio.server_onCreate(self)
    self.storageSave = self.storage:load() or {}

    local defaults = {
        track = nil,
        volume = 1,
        play_state = false,
        play_speed = 1,
        playlist = "All Tracks",
        repeat_mode = REPEAT_NONE,
        shuffle = false,
        fm_mode = false,
        fm_frequency = 0
    }
    for k, v in pairs(defaults) do
        if self.storageSave[k] == nil then
            self.storageSave[k] = v
        end
    end

    self.sv_audioName = self.storageSave.track
    self.sv_volumeLevel = self.storageSave.volume
    self.sv_playState = self.storageSave.play_state
    self.sv_playSpeed = self.storageSave.play_speed
    self.sv_playlist = self.storageSave.playlist
    self.sv_repeatMode = self.storageSave.repeat_mode
    self.sv_shuffle = self.storageSave.shuffle
    self.sv_fmMode = self.storageSave.fm_mode
    self.sv_fmFrequency = self.storageSave.fm_frequency

    self.connectedElements = self.interactable:getChildren()

    self.interactable.publicData = {
        sc_component = {
            type = CustomRadio.componentType,
            api = {
                getState = function()
                    return {
                        track = self.sv_audioName,
                        volume = self.sv_volumeLevel,
                        play_state = self.sv_playState,
                        play_speed = self.sv_playSpeed,
                        playlist = self.sv_playlist,
                        repeat_mode = self.sv_repeatMode,
                        shuffle = self.sv_shuffle,
                        fm_mode = self.sv_fmMode,
                        fm_frequency = self.sv_fmFrequency
                    }
                end,
                play = function()
                    self.sc_play = true
                end,
                stop = function()
                    self.sc_stop = true
                end,
                next = function()
                    if not self.sv_fmMode then
                        self.sc_next_sound = true
                    end
                end,
                back = function()
                    if not self.sv_fmMode then
                        self.sc_back_sound = true
                    end
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
    if self:consumeFlag("sc_play") then
        self.network:sendToClient(hostPlayer, "onSetPlayState")
    end
    if self:consumeFlag("sc_stop") then
        self.network:sendToClient(hostPlayer, "onSetPlayState")
    end
    if self:consumeFlag("sc_next_sound") then
        self.network:sendToClient(hostPlayer, "changeSound", 1)
    end
    if self:consumeFlag("sc_back_sound") then
        self.network:sendToClient(hostPlayer, "changeSound", -1)
    end
end

function CustomRadio:sv_updateSetting(key, value, clientFn)
    if self.storageSave[key] ~= value then
        self.storageSave[key] = value
        self["sv_" .. key] = value
        self.storage:save(self.storageSave)
        self.network:sendToClients(clientFn, value)
    end
end

function CustomRadio.sv_changeTrack(self, s)
    self:sv_updateSetting("track", s, "cl_changeTrack")
end
function CustomRadio.sv_changeTrackVolume(self, s)
    self:sv_updateSetting("volume", s, "cl_changeTrackVolume")
end
function CustomRadio.sv_changePlayState(self, s)
    self:sv_updateSetting("play_state", s, "cl_changePlayState")
end
function CustomRadio.sv_changePlaySpeed(self, s)
    self:sv_updateSetting("play_speed", s, "cl_changePlaySpeed")
end
function CustomRadio.sv_changePlaylist(self, s)
    self:sv_updateSetting("playlist", s, "cl_changePlaylist")
end
function CustomRadio.sv_changeRepeatMode(self, s)
    self:sv_updateSetting("repeat_mode", s, "cl_changeRepeatMode")
end
function CustomRadio.sv_changeShuffle(self, s)
    self:sv_updateSetting("shuffle", s, "cl_changeShuffle")
end
function CustomRadio.sv_toggleFmMode(self, s)
    self:sv_updateSetting("fm_mode", s, "cl_setFmMode")
end
function CustomRadio.sv_setFmFrequency(self, freq)
    self:sv_updateSetting("fm_frequency", freq, "cl_setFmFrequency")
end

function CustomRadio.sv_getRadioInfo(self, _, player)
    self.network:sendToClient(player, "cl_updateRadioInfo", {
        track = self.sv_audioName,
        volume = self.sv_volumeLevel,
        playState = self.sv_playState,
        playSpeed = self.sv_playSpeed,
        playlist = self.sv_playlist,
        repeatMode = self.sv_repeatMode,
        shuffle = self.sv_shuffle,
        fmMode = self.sv_fmMode,
        fmFrequency = self.sv_fmFrequency
    })
end

-- ─────────────────────────────────────────────
--  CLIENT
-- ─────────────────────────────────────────────

function CustomRadio.client_onCreate(self)
    self.cl_currentAudioName = nil
    self.cl_currentAudioVolume = 1
    self.cl_playState = false
    self.cl_playSpeed = 1
    self.cl_currentPlaylist = "All Tracks"
    self.cl_repeatMode = REPEAT_NONE
    self.cl_shuffle = false
    self.cl_shuffleQueue = {}
    self.cl_effectJustStarted = false
    self.cl_trackTimer = 0
    self.cl_pendingRadioInfo = nil
    self.cl_audio_effect = nil
    self.cl_fmMode = false
    self.cl_fmFrequency = 0
    self.cl_fmCurrentTrack = nil
    self.cl_lastAntennaFreq = nil

    self.network:sendToServer("sv_getRadioInfo")

    Utilities.checkCAE()
    Utilities.loadCustomMusicTracks(self)

    if self.cl_pendingRadioInfo then
        self:applyRadioInfo(self.cl_pendingRadioInfo)
        self.cl_pendingRadioInfo = nil
    end
end

function CustomRadio.cl_updateRadioInfo(self, data)
    if not self.tracks then
        self.cl_pendingRadioInfo = data
        return
    end
    self:applyRadioInfo(data)
end

function CustomRadio:applyRadioInfo(data)
    self:cl_changePlaylist(data.playlist or "All Tracks")
    self:cl_changeRepeatMode(data.repeatMode or REPEAT_NONE)
    self:cl_changeShuffle(data.shuffle or false)
    self:cl_changeTrack(data.track)
    self:cl_changeTrackVolume(data.volume)
    self:cl_changePlayState(data.playState)
    self:cl_changePlaySpeed(data.playSpeed)
    self:cl_setFmMode(data.fmMode or false)
    self:cl_setFmFrequency(data.fmFrequency or 0)
end

-- ─────────────────────────────────────────────
--  SPEAKER
-- ─────────────────────────────────────────────

function CustomRadio.send_toSpeaker(self, fun, params)
    for _, element in ipairs(self.connectedElements) do
        local shape = element:getShape()
        if shape and shape.uuid == sm.uuid.new("99ae2a73-b28d-4b7c-a558-104ed1b59b1d") then
            sm.event.sendToInteractable(element, fun, params)
        end
    end
end

-- ─────────────────────────────────────────────
--  TRACK END LOGIC
-- ─────────────────────────────────────────────

function CustomRadio:onTrackEnded()
    if self.cl_fmMode then
        return
    end

    if self.cl_repeatMode == REPEAT_TRACK then
        if self:isValidEffect() then
            if self.cl_audio_effect:isPlaying() then
                self.cl_audio_effect:stop()
            end
            self.cl_audio_effect:destroy()
            self:send_toSpeaker("remote_radio_controller_destroy", "")
        end
        self.cl_audio_effect = sm.effect.createEffect(self.cl_currentAudioName, self.interactable)
        self.cl_effectJustStarted = true
        return
    end

    if self.cl_shuffle then
        local next = self:nextShuffleTrack()
        if next then
            self:selectTrack(next)
        end
        return
    end

    local activeTracks = self:getActiveTracks()
    local idx = 0
    for i, t in ipairs(activeTracks) do
        if t == self.cl_currentAudioName then
            idx = i
            break
        end
    end

    if idx >= #activeTracks then
        if self.cl_repeatMode == REPEAT_PLAYLIST then
            self:selectTrack(activeTracks[1])
        else
            self.network:sendToServer("sv_changePlayState", false)
        end
    else
        self:selectTrack(activeTracks[idx + 1])
    end
end

-- ─────────────────────────────────────────────
--  AUDIO MANAGER
-- ─────────────────────────────────────────────

function CustomRadio:updateAudioEffect(play)
    if play then
        if self:hasRealTrack() then
            if self:isValidEffect() and not self.cl_audio_effect:isPlaying() then
                self.cl_audio_effect:start()
                self.cl_effectJustStarted = true
                self.interactable:setPoseWeight(0, 1)
            end
        else
            if self:isValidEffect() then
                if self.cl_audio_effect:isPlaying() then
                    self.cl_audio_effect:stop()
                end
                self.cl_audio_effect:destroy()
                self.cl_audio_effect = nil
            end
            self.interactable:setPoseWeight(0, 0)
        end
    else
        if self:isValidEffect() then
            if self.cl_audio_effect:isPlaying() then
                self.cl_audio_effect:stop()
            end
            self.interactable:setPoseWeight(0, 0)
        end
    end
end

function CustomRadio:updateFmAudio(shouldPlay)
    local signal = self:getFMSignal()

    if not signal then
        if self:isValidEffect() and self.cl_audio_effect:isPlaying() then
            self.cl_audio_effect:stop()
        end
        self.interactable:setPoseWeight(0, 0)
        self.cl_fmCurrentTrack = nil
        self:send_toSpeaker("remote_radio_controller", {
            currentAudioName = nil,
            currentAudioVolume = self.cl_currentAudioVolume,
            currentPlayState = false
        })
        return
    end

    if signal.track ~= self.cl_fmCurrentTrack then
        if self:isValidEffect() then
            if self.cl_audio_effect:isPlaying() then
                self.cl_audio_effect:stop()
            end
            self.cl_audio_effect:destroy()
            self:send_toSpeaker("remote_radio_controller_destroy", "")
        end
        self.cl_audio_effect = nil
        self.cl_fmCurrentTrack = signal.track

        if signal.track and signal.track ~= "" then
            self.cl_audio_effect = sm.effect.createEffect(signal.track, self.interactable)
        end
    end

    local antennaPlaying = signal.playState
    local actualPlay = shouldPlay and antennaPlaying

    if actualPlay then
        if self:isValidEffect() and not self.cl_audio_effect:isPlaying() then
            self.cl_audio_effect:start()
            self.interactable:setPoseWeight(0, 1)
        end
    else
        if self:isValidEffect() and self.cl_audio_effect:isPlaying() then
            self.cl_audio_effect:stop()
        end
        self.interactable:setPoseWeight(0, 0)
    end

    if self:isValidEffect() then
        self.cl_audio_effect:setParameter("CAE_Volume", self.cl_currentAudioVolume / 10.0)
        local spd = signal.playSpeed or 1
        self.cl_audio_effect:setParameter("CAE_Pitch", spd > 0 and spd or 0.5)
    end

    self:send_toSpeaker("remote_radio_controller", {
        currentAudioName = signal.track,
        currentAudioVolume = self.cl_currentAudioVolume,
        currentPlayState = actualPlay
    })
end

function CustomRadio.client_onUpdate(self, dt)
    local parent = self.interactable:getSingleParent()
    self.connectedElements = self.interactable:getChildren()

    local active
    if parent then
        local shape = parent:getShape()
        if shape and shape.uuid == sm.uuid.new("3f7a7d81-e33a-4a73-91b7-7f9f20d8489d") then
            active = parent.active
        else
            active = (parent:getType() == "scripted") and true or parent.active
        end
    end

    local shouldPlay = (not parent and self.cl_playState) or (active and self.cl_playState)

    if self.cl_fmMode then
        self:updateFmAudio(shouldPlay)

        if sm.exists(self.gui) then
            self:updateGuiProgress()
        end
        return
    end

    self:updateAudioEffect(shouldPlay)

    if shouldPlay and self:isValidEffect() then
        if self.cl_effectJustStarted then
            if self.cl_audio_effect:isPlaying() then
                self.cl_effectJustStarted = false
            end
        else
            self.cl_trackTimer = (self.cl_trackTimer or 0) + dt
            if self.cl_audio_effect:isDone() then
                self.cl_trackTimer = 0
                self:onTrackEnded()
            end
        end
    end

    if sm.exists(self.gui) then
        self:updateGuiProgress()
    end

    self:send_toSpeaker("remote_radio_controller", {
        currentAudioName = self.cl_currentAudioName,
        currentAudioVolume = self.cl_currentAudioVolume,
        currentPlayState = shouldPlay
    })

    if self:isValidEffect() then
        self.cl_audio_effect:setParameter("CAE_Volume", self.cl_currentAudioVolume / 10.0)
        self.cl_audio_effect:setParameter("CAE_Pitch", self.cl_playSpeed > 0 and self.cl_playSpeed or 0.5)
    end
end

-- ─────────────────────────────────────────────
--  CLIENT FIXED UPDATE — FM SENDER
-- ─────────────────────────────────────────────

function CustomRadio.client_onFixedUpdate(self)
    self:cl_updateFMSender()
end

-- ─────────────────────────────────────────────
--  CLIENT DESTROY
-- ─────────────────────────────────────────────

function CustomRadio.client_onDestroy(self)
    local myId = self.interactable.id
    if self.cl_lastAntennaFreq ~= nil and fmdata[self.cl_lastAntennaFreq] then
        fmdata[self.cl_lastAntennaFreq][myId] = nil
    end
end

-- ─────────────────────────────────────────────
--  GUI
-- ─────────────────────────────────────────────

function CustomRadio:updateGuiProgress()
    local info = self.trackInfo and self.trackInfo[self.cl_currentAudioName]
    local durationSec = info and info.Duration and (info.Duration * 60) or 0
    local elapsed = self.cl_trackTimer or 0

    if durationSec > 0 then
        self.gui:setText("ProgressLabel", formatTime(elapsed) .. " / " .. formatTime(durationSec))
    else
        self.gui:setText("ProgressLabel", elapsed > 0 and (formatTime(elapsed) .. " / --:--") or "--:-- / --:--")
    end
end

function CustomRadio:openGui()
    if not sm.exists(self.gui) then
        self:createGui()
    end

    local info = Utilities.getTrackInfo(self, self.cl_currentAudioName)
    local modPrefix = info.ModUUID and ("$CONTENT_" .. tostring(info.ModUUID)) or "$CONTENT_DATA"

    self.gui:setText("TrackName", info.Name)
    self.gui:setText("TrackAuthor", info.Author)
    self.gui:setImage("TrackImage", modPrefix .. "/" .. info.Image)
    self.gui:setText("SubTitle", tostring(#self.connectedElements) .. " / " .. tostring(CustomRadio.maxChildCount))

    self:cl_refreshTrackGrid()

    self.gui:setImage("PlayerIcon", self.cl_playState and STOP_ICON or PLAY_ICON)
    self.gui:setButtonState("RepeatButton", repeatModeState(self.cl_repeatMode))
    self.gui:setButtonState("ShuffleButton", self.cl_shuffle)

    self:cl_refreshFmGui()

    self.gui:open()
end

function CustomRadio:cl_refreshFmGui()
    if not sm.exists(self.gui) then
        return
    end

    local hasAntenna = self:findAntennaChild() ~= nil
    self.gui:setVisible("FmButton", not hasAntenna)
    self.gui:setVisible("FmFrequencyPanel", hasAntenna and false or (self.cl_fmMode and true or false))

    local fm = self.cl_fmMode
    self.gui:setButtonState("FmButton", fm)
    self.gui:setVisible("FmFrequencyPanel", fm)

    if fm then
        self.gui:setText("FmFrequencyLabel", "FM " .. tostring(self.cl_fmFrequency))

        self.gui:setVisible("NextButton", false)
        self.gui:setVisible("BackButton", false)
        self.gui:setVisible("RepeatButton", false)
        self.gui:setVisible("ShuffleButton", false)
        self.gui:setVisible("TrackGrid", false)

        local signal = self:getFMSignal()
        if signal and signal.track then
            local info = Utilities.getTrackInfo(self, signal.track)
            local modPrefix = info.ModUUID and ("$CONTENT_" .. tostring(info.ModUUID)) or "$CONTENT_DATA"

            self.gui:setText("TrackName", info.Name)
            self.gui:setText("TrackAuthor", info.Author)
            self.gui:setImage("TrackImage", modPrefix .. "/" .. info.Image)
        else
            self.gui:setText("TrackName", "No FM signal")
            self.gui:setText("TrackAuthor", "Frequency: " .. tostring(self.cl_fmFrequency))
            self.gui:setImage("TrackImage", "$CONTENT_DATA/Gui/Icons/default_image.png")
        end
    else
        self.gui:setVisible("NextButton", true)
        self.gui:setVisible("BackButton", true)
        self.gui:setVisible("RepeatButton", true)
        self.gui:setVisible("ShuffleButton", true)
        self.gui:setVisible("TrackGrid", true)
    end
end

function CustomRadio:createGui()
    self.gui = sm.gui.createGuiFromLayout(MAIN_LAYOUT)

    self.gui:setIconImage("Icon", self.shape.uuid)

    self.gui:createHorizontalSlider("VolumeSlider", 11, self.cl_currentAudioVolume * 10, "client_onVolumeSliderMoved")

    self.gui:setButtonCallback("PlayerButton", "onSetPlayState")
    self.gui:setButtonCallback("NextButton", "onNextSound")
    self.gui:setButtonCallback("BackButton", "onBackSound")
    self.gui:setButtonCallback("RepeatButton", "onCycleRepeat")
    self.gui:setButtonCallback("ShuffleButton", "onToggleShuffle")

    self.gui:setButtonCallback("FmButton", "onToggleFmMode")
    self.gui:setButtonCallback("FmFrequencyUp", "onFmFrequencyUp")
    self.gui:setButtonCallback("FmFrequencyDown", "onFmFrequencyDown")
end

function CustomRadio.remote_control(self)
    self:openGui()
end

function CustomRadio.client_onInteract(self, char, lookAt)
    if lookAt then
        self:remote_control()
    end
end

function CustomRadio:cl_refreshTrackGrid()
    local activeTracks = self:getActiveTracks()

    self.gui:createGridFromJson("TrackGrid", {
        type = "itemGrid",
        layout = TRACK_ITEM_LAYOUT,
        itemWidth = 270,
        itemHeight = 90,
        itemCount = #activeTracks
    })
    self.gui:setGridButtonCallback("MainPanel", "cl_onTrackClicked")

    for i, trackKey in ipairs(activeTracks) do
        local info = Utilities.getTrackInfo(self, trackKey)
        self.gui:setGridItem("TrackGrid", i - 1, {
            Name = info.Name,
            Author = info.Author,
            HighlightItemIcon = (trackKey == self.cl_currentAudioName),
            itemId = "00000000-0000-0000-0000-000000000000"
        })
    end
end

function CustomRadio.cl_onTrackClicked(self, grid, index)
    if self.cl_fmMode then
        return
    end

    local activeTracks = self:getActiveTracks()
    local trackKey = activeTracks[index + 1]
    if trackKey then
        self:selectTrack(trackKey)
        self:cl_refreshTrackGrid()
    end
end

-- ─────────────────────────────────────────────
--  GUI CALLBACKS
-- ─────────────────────────────────────────────

function CustomRadio.cl_onPlaylistDropdownInteract(self, option)
    if self.cl_fmMode then
        return
    end
    self.network:sendToServer("sv_changePlaylist", option)
    self:cl_changePlaylist(option)
    if sm.exists(self.gui) then
        self:cl_refreshTrackGrid()
    end
    self:rebuildShuffleQueue()
end

function CustomRadio.client_onVolumeSliderMoved(self, value)
    self.network:sendToServer("sv_changeTrackVolume", value / 10.0)
    if sm.exists(self.gui) then
        self.gui:setImage("VolumeIcon", value > 0 and VOLUME_ON_ICON or VOLUME_OFF_ICON)
    end
end

function CustomRadio.client_onSpeedSliderMoved(self, value)
    if self.cl_fmMode then
        return
    end
    self.network:sendToServer("sv_changePlaySpeed", value)
end

function CustomRadio:onCycleRepeat()
    if self.cl_fmMode then
        return
    end
    local next = (self.cl_repeatMode + 1) % 3
    self.network:sendToServer("sv_changeRepeatMode", next)
    self:cl_changeRepeatMode(next)
end

function CustomRadio:onToggleShuffle()
    if self.cl_fmMode then
        return
    end
    local next = not self.cl_shuffle
    self.network:sendToServer("sv_changeShuffle", next)
    self:cl_changeShuffle(next)
end

function CustomRadio:onToggleFmMode()
    local next = not self.cl_fmMode
    self.network:sendToServer("sv_toggleFmMode", next)
    self:cl_setFmMode(next)

    if not next then
        self.cl_fmCurrentTrack = nil
        if self:isValidEffect() then
            if self.cl_audio_effect:isPlaying() then
                self.cl_audio_effect:stop()
            end
            self.cl_audio_effect:destroy()
            self:send_toSpeaker("remote_radio_controller_destroy", "")
        end
        self.cl_audio_effect = nil
        if self.cl_currentAudioName and self.cl_currentAudioName ~= "" then
            self.cl_audio_effect = sm.effect.createEffect(self.cl_currentAudioName, self.interactable)
        end
    end

    if sm.exists(self.gui) then
        self:cl_refreshFmGui()
    end
end

function CustomRadio:onFmFrequencyUp()
    local next = math.min(255, self.cl_fmFrequency + 1)
    self.network:sendToServer("sv_setFmFrequency", next)
    self:cl_setFmFrequency(next)
    if sm.exists(self.gui) then
        self:cl_refreshFmGui()
    end
end

function CustomRadio:onFmFrequencyDown()
    local next = math.max(0, self.cl_fmFrequency - 1)
    self.network:sendToServer("sv_setFmFrequency", next)
    self:cl_setFmFrequency(next)
    if sm.exists(self.gui) then
        self:cl_refreshFmGui()
    end
end

-- ─────────────────────────────────────────────
--  CLIENT STATE SETTERS
-- ─────────────────────────────────────────────

function CustomRadio.cl_changePlayState(self, newState)
    self.cl_playState = newState
    if sm.exists(self.gui) then
        self.gui:setImage("PlayerIcon", newState and STOP_ICON or PLAY_ICON)
    end
end

function CustomRadio.cl_changeTrack(self, newTrack)
    if self.cl_fmMode then
        return
    end
    if self.cl_currentAudioName == newTrack then
        return
    end
    if newTrack == "" then
        return
    end

    if self:isValidEffect() then
        if self.cl_audio_effect:isPlaying() then
            self.cl_audio_effect:stop()
        end
        self.cl_audio_effect:destroy()
        self:send_toSpeaker("remote_radio_controller_destroy", "")
    end
    self.cl_audio_effect = nil
    self.cl_effectJustStarted = false
    self.cl_trackTimer = 0
    self.cl_currentAudioName = newTrack

    if newTrack ~= nil and newTrack ~= "" then
        self.cl_audio_effect = sm.effect.createEffect(newTrack, self.interactable)
    end

    if sm.exists(self.gui) then
        local info = Utilities.getTrackInfo(self, newTrack)
        local modPrefix = info.ModUUID and ("$CONTENT_" .. tostring(info.ModUUID)) or "$CONTENT_DATA"

        self.gui:setText("TrackName", info.Name)
        self.gui:setText("TrackAuthor", info.Author)
        self.gui:setImage("TrackImage", modPrefix .. "/" .. info.Image)

        local activeTracks = self:getActiveTracks()
        for i, trackKey in ipairs(activeTracks) do
            self.gui:setGridItem("TrackGrid", i - 1, {
                HighlightItemIcon = (trackKey == newTrack)
            })
        end
    end
end

function CustomRadio.cl_changeTrackVolume(self, newVolume)
    self.cl_currentAudioVolume = newVolume or 1
    self:send_toSpeaker("remote_radio_controller_volume", self.cl_currentAudioVolume)
end

function CustomRadio.cl_changePlaySpeed(self, newSpeed)
    self.cl_playSpeed = newSpeed or 1
    if not self.cl_fmMode then
        self:send_toSpeaker("remote_radio_controller_speed", self.cl_playSpeed)
    end
end

function CustomRadio.cl_changePlaylist(self, newPlaylist)
    if newPlaylist and newPlaylist ~= "" then
        self.cl_currentPlaylist = newPlaylist
    end
end

function CustomRadio.cl_changeRepeatMode(self, mode)
    self.cl_repeatMode = mode
    if sm.exists(self.gui) then
        self.gui:setButtonState("RepeatButton", repeatModeState(mode))
    end
end

function CustomRadio.cl_changeShuffle(self, state)
    self.cl_shuffle = state
    if sm.exists(self.gui) then
        self.gui:setButtonState("ShuffleButton", state)
    end
    if state then
        self:rebuildShuffleQueue()
    end
end

function CustomRadio.cl_setFmMode(self, state)
    self.cl_fmMode = state
    if sm.exists(self.gui) then
        self.gui:setButtonState("FmButton", state)
    end
end

function CustomRadio.cl_setFmFrequency(self, freq)
    self.cl_fmFrequency = freq
    if sm.exists(self.gui) then
        if self.cl_fmMode then
            self.gui:setText("FmFrequencyLabel", "FM " .. tostring(freq))
        end
    end
end

-- ─────────────────────────────────────────────
--  TRACK SELECTION
-- ─────────────────────────────────────────────

function CustomRadio:selectTrack(trackName)
    if self.cl_fmMode then
        return
    end
    if not trackName or trackName == "" then
        return
    end
    self:cl_changeTrack(trackName)
    self.network:sendToServer("sv_changeTrack", trackName)
end

function CustomRadio:onSetPlayState()
    local shouldPlay = not self.cl_playState

    if shouldPlay and not self.cl_fmMode then
        local activeTracks = self:getActiveTracks()
        local trackInPlaylist = false
        for _, t in ipairs(activeTracks) do
            if t == self.cl_currentAudioName then
                trackInPlaylist = true
                break
            end
        end

        if self.cl_currentAudioName == nil or not self:isValidEffect() or not trackInPlaylist then
            if self.cl_shuffle then
                local next = self:nextShuffleTrack()
                if next then
                    self:selectTrack(next)
                end
            else
                Utilities.selectRandomTrack(self, function(track)
                    self:selectTrack(track)
                end)
            end
        end
    end

    self.network:sendToServer("sv_changePlayState", shouldPlay)
end

function CustomRadio:onNextSound()
    if self.cl_fmMode then
        return
    end
    Utilities.changeSound(self, 1, self:getActiveTracks(), function(track)
        self:selectTrack(track)
    end)
end

function CustomRadio:onBackSound()
    if self.cl_fmMode then
        return
    end
    Utilities.changeSound(self, -1, self:getActiveTracks(), function(track)
        self:selectTrack(track)
    end)
end

function CustomRadio:onRandomSound()
    if self.cl_fmMode then
        return
    end
    Utilities.selectRandomTrack(self, function(track)
        self:selectTrack(track)
    end)
end
