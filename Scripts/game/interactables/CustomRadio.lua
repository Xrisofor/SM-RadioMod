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

local SLOTS_PER_PAGE = 9
local PLAYLIST_SLOTS_PER_PAGE = 3

local FM_DRIFT_THRESHOLD_MS = 500

local SEEK_SLIDER_STEPS = 1000
local SEEK_SYNC_COOLDOWN = 0.6

local MIN_PLAY_TIME_BEFORE_DONE = 0.3
local MAX_TRACK_START_RETRIES = 6

local function repeatModeState(mode)
    return mode == REPEAT_TRACK or mode == REPEAT_PLAYLIST
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
            playSpeed = self.cl_playSpeed,
            position = self.cl_trackPosition or 0
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
        fm_frequency = 0,
        track_position = 0
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
    self.sv_trackPosition = self.storageSave.track_position or 0
    self.sv_positionSaveTimer = 0

    Utilities.loadCustomMusicTracks(self)

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

function CustomRadio.server_onUnload(self)
    self.storageSave.track_position = math.floor(self.sv_trackPosition or 0)
    self.storage:save(self.storageSave)
end

function CustomRadio:server_onFixedUpdate(dt)
    dt = dt or (1 / 40)

    if self.sv_playState and not self.sv_fmMode and self.sv_audioName and self.sv_audioName ~= "" then
        local speed = (self.sv_playSpeed and self.sv_playSpeed > 0) and self.sv_playSpeed or 1
        self.sv_trackPosition = (self.sv_trackPosition or 0) + dt * 1000 * speed

        local info = Utilities.getTrackInfo(self, self.sv_audioName)
        local duration = info.Duration or 0
        if duration > 0 and self.sv_trackPosition > duration then
            self.sv_trackPosition = duration
        end

        self.sv_positionSaveTimer = (self.sv_positionSaveTimer or 0) + dt
        if self.sv_positionSaveTimer >= 3 then
            self.sv_positionSaveTimer = 0
            self.storageSave.track_position = math.floor(self.sv_trackPosition)
            self.storage:save(self.storageSave)
        end
    end

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
    if self.sv_audioName ~= s then
        self.sv_trackPosition = 0
        self.storageSave.track_position = 0
        self.storage:save(self.storageSave)
    end
    self:sv_updateSetting("track", s, "cl_changeTrack")
end
function CustomRadio.sv_changeTrackVolume(self, s)
    self:sv_updateSetting("volume", s, "cl_changeTrackVolume")
end
function CustomRadio.sv_changePlayState(self, s)
    self.storageSave.track_position = math.floor(self.sv_trackPosition or 0)
    self.storage:save(self.storageSave)
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

function CustomRadio.sv_seekTrack(self, positionMs)
    self.sv_trackPosition = positionMs
    self.storageSave.track_position = math.floor(positionMs)
    self.storage:save(self.storageSave)
    self.network:sendToClients("cl_seekTrack", positionMs)
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
        fmFrequency = self.sv_fmFrequency,
        position = self.sv_trackPosition or 0
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
    self.cl_trackPage = 0
    self.cl_currentPageTracks = {}
    self.cl_playlistPage = 0
    self.cl_currentPagePlaylists = {}
    self.cl_effectJustStarted = false
    self.cl_pendingRadioInfo = nil
    self.cl_audio_effect = nil

    self.cl_trackPosition = 0
    self.cl_trackDuration = 0
    self.cl_guiPositionTimer = 0
    self.cl_elapsedTime = 0
    self.cl_lastUserSeekAt = -math.huge
    self.cl_seekBarSyncing = false
    self.cl_trackStartClock = 0
    self.cl_trackStartRetries = 0

    self.cl_fmMode = false
    self.cl_fmFrequency = 0
    self.cl_fmCurrentTrack = nil
    self.cl_fmTrackPosition = 0
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
    self:cl_seekTo(data.position or 0)
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

function CustomRadio:retryCurrentTrack()
    self.cl_trackStartRetries = (self.cl_trackStartRetries or 0) + 1

    if self:isValidEffect() then
        if self.cl_audio_effect:isPlaying() then
            self.cl_audio_effect:stop()
        end
        self.cl_audio_effect:destroy()
    end
    self.cl_audio_effect = nil

    if self.cl_currentAudioName and self.cl_currentAudioName ~= "" then
        self.cl_audio_effect = sm.effect.createEffect(self.cl_currentAudioName, self.interactable)
    end

    self.cl_effectJustStarted = false
end

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
        self.cl_trackPosition = 0
        self.cl_trackStartRetries = 0
        self:cl_updateTrackPositionGui()
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
                self.cl_trackStartClock = self.cl_elapsedTime or 0
                self.interactable:setPoseWeight(0, 1)

                if self.cl_trackPosition and self.cl_trackPosition > 0 then
                    self.cl_audio_effect:setParameter("CAE_Position", self.cl_trackPosition / 1000.0)
                end
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



function CustomRadio:updateFmAudio(shouldPlay, dt)
    local signal = self:getFMSignal()

    if not signal then
        if self:isValidEffect() and self.cl_audio_effect:isPlaying() then
            self.cl_audio_effect:stop()
        end
        self.interactable:setPoseWeight(0, 0)
        self.cl_fmCurrentTrack = nil
        self.cl_fmTrackPosition = 0
        self:send_toSpeaker("remote_radio_controller", {
            currentAudioName = nil,
            currentAudioVolume = self.cl_currentAudioVolume,
            currentPlayState = false,
            currentPosition = 0
        })
        return
    end

    local wasPlaying = self:isValidEffect() and self.cl_audio_effect:isPlaying()
    local trackChanged = signal.track ~= self.cl_fmCurrentTrack

    if trackChanged then
        if self:isValidEffect() then
            if self.cl_audio_effect:isPlaying() then
                self.cl_audio_effect:stop()
            end
            self.cl_audio_effect:destroy()
            self:send_toSpeaker("remote_radio_controller_destroy", "")
        end
        self.cl_audio_effect = nil
        self.cl_fmCurrentTrack = signal.track
        self.cl_fmTrackPosition = signal.position or 0

        if signal.track and signal.track ~= "" then
            self.cl_audio_effect = sm.effect.createEffect(signal.track, self.interactable)
            self.cl_audio_effect:setParameter("CAE_Position", self.cl_fmTrackPosition / 1000.0)
        end
    end

    local antennaPlaying = signal.playState
    local actualPlay = shouldPlay and antennaPlaying

    if actualPlay then
        if self:isValidEffect() and not self.cl_audio_effect:isPlaying() then
            self.cl_audio_effect:start()
            self.interactable:setPoseWeight(0, 1)
            self.cl_fmTrackPosition = signal.position or 0
            self.cl_audio_effect:setParameter("CAE_Position", self.cl_fmTrackPosition / 1000.0)
        end
    else
        if self:isValidEffect() and self.cl_audio_effect:isPlaying() then
            self.cl_audio_effect:stop()
        end
        self.interactable:setPoseWeight(0, 0)
    end

    if actualPlay and not trackChanged and wasPlaying then
        local speed = (signal.playSpeed and signal.playSpeed > 0) and signal.playSpeed or 1
        self.cl_fmTrackPosition = (self.cl_fmTrackPosition or 0) + dt * 1000 * speed

        local drift = math.abs((self.cl_fmTrackPosition or 0) - (signal.position or 0))
        if drift > FM_DRIFT_THRESHOLD_MS then
            self.cl_fmTrackPosition = signal.position or 0
            if self:isValidEffect() then
                self.cl_audio_effect:setParameter("CAE_Position", self.cl_fmTrackPosition / 1000.0)
            end
        end
    end

    if self:isValidEffect() then
        self.cl_audio_effect:setParameter("CAE_Volume", self.cl_currentAudioVolume / 10.0)
        local spd = signal.playSpeed or 1
        self.cl_audio_effect:setParameter("CAE_Pitch", spd > 0 and spd or 0.5)
    end

    self:send_toSpeaker("remote_radio_controller", {
        currentAudioName = signal.track,
        currentAudioVolume = self.cl_currentAudioVolume,
        currentPlayState = actualPlay,
        currentPosition = self.cl_fmTrackPosition or 0
    })
end

function CustomRadio.client_onUpdate(self, dt)
    self.cl_elapsedTime = (self.cl_elapsedTime or 0) + dt

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
        self:updateFmAudio(shouldPlay, dt)
        return
    end

    self:updateAudioEffect(shouldPlay)

    if shouldPlay and self:isValidEffect() then
        if self.cl_effectJustStarted then
            if self.cl_audio_effect:isPlaying() then
                self.cl_effectJustStarted = false
            end
        else
            if self.cl_audio_effect:isDone() then
                local playedFor = (self.cl_elapsedTime or 0) - (self.cl_trackStartClock or 0)
                if playedFor < MIN_PLAY_TIME_BEFORE_DONE and (self.cl_trackStartRetries or 0) < MAX_TRACK_START_RETRIES then
                    self:retryCurrentTrack()
                else
                    self:onTrackEnded()
                end
            else
                local durationMs = self.cl_trackDuration or 0
                local speed = self.cl_playSpeed > 0 and self.cl_playSpeed or 1
                self.cl_trackPosition = (self.cl_trackPosition or 0) + dt * 1000 * speed
                if durationMs > 0 and self.cl_trackPosition > durationMs then
                    self.cl_trackPosition = durationMs
                end
            end
        end
    end

    self.cl_guiPositionTimer = (self.cl_guiPositionTimer or 0) + dt
    if self.cl_guiPositionTimer >= 0.25 then
        self.cl_guiPositionTimer = 0
        self:cl_updateTrackPositionGui()
    end

    self:send_toSpeaker("remote_radio_controller", {
        currentAudioName = self.cl_currentAudioName,
        currentAudioVolume = self.cl_currentAudioVolume,
        currentPlayState = shouldPlay,
        currentPosition = self.cl_trackPosition or 0
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

    self:cl_refreshTrackList()
    self:cl_refreshPlaylistList()
    self:cl_updateTrackPositionGui()

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
        self.gui:setVisible("TrackListPanel", false)
        self.gui:setVisible("PlaylistPanel", false)
        self.gui:setVisible("SeekBar", false)
        self.gui:setVisible("TrackTimeLabel", false)

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
        self.gui:setVisible("TrackListPanel", true)
        self.gui:setVisible("PlaylistPanel", true)
        self.gui:setVisible("SeekBar", true)
        self.gui:setVisible("TrackTimeLabel", true)
    end
end

function CustomRadio:createGui()
    self.gui = sm.gui.createGuiFromLayout(MAIN_LAYOUT)

    self.gui:setIconImage("Icon", self.shape.uuid)

    self.gui:createHorizontalSlider("VolumeSlider", 11, self.cl_currentAudioVolume * 10, "client_onVolumeSliderMoved")
    self.gui:createHorizontalSlider("SeekBar", 1000, 0, "client_onSeekBarMoved")

    self.gui:setButtonCallback("PlayerButton", "onSetPlayState")
    self.gui:setButtonCallback("NextButton", "onNextSound")
    self.gui:setButtonCallback("BackButton", "onBackSound")
    self.gui:setButtonCallback("RepeatButton", "onCycleRepeat")
    self.gui:setButtonCallback("ShuffleButton", "onToggleShuffle")

    self.gui:setButtonCallback("FmButton", "onToggleFmMode")
    self.gui:setButtonCallback("FmFrequencyUp", "onFmFrequencyUp")
    self.gui:setButtonCallback("FmFrequencyDown", "onFmFrequencyDown")

    for i = 1, SLOTS_PER_PAGE do
        self.gui:setButtonCallback("TrackSlot_" .. i, "cl_onTrackSlot" .. i)
    end
    self.gui:setButtonCallback("TrackPageUp", "onTrackPageUp")
    self.gui:setButtonCallback("TrackPageDown", "onTrackPageDown")

    self.gui:setButtonCallback("PlaylistPageUp", "onPlaylistPageUp")
    self.gui:setButtonCallback("PlaylistPageDown", "onPlaylistPageDown")
    for i = 1, PLAYLIST_SLOTS_PER_PAGE do
        self.gui:setButtonCallback("PlaylistSlot_" .. i, "cl_onPlaylistSlot" .. i)
    end
end

function CustomRadio.remote_control(self)
    self:openGui()
end

function CustomRadio.client_onInteract(self, char, lookAt)
    if lookAt then
        self:remote_control()
    end
end

function CustomRadio:cl_refreshTrackList()
    local activeTracks = self:getActiveTracks()
    local totalPages = math.max(1, math.ceil(#activeTracks / SLOTS_PER_PAGE))

    if self.cl_trackPage > totalPages - 1 then
        self.cl_trackPage = totalPages - 1
    end
    if self.cl_trackPage < 0 then
        self.cl_trackPage = 0
    end

    local start = self.cl_trackPage * SLOTS_PER_PAGE + 1
    self.cl_currentPageTracks = {}

    for slot = 1, SLOTS_PER_PAGE do
        local trackKey = activeTracks[start + slot - 1]
        self.cl_currentPageTracks[slot] = trackKey

        if trackKey then
            local info = Utilities.getTrackInfo(self, trackKey)
            local modPrefix = info.ModUUID and ("$CONTENT_" .. tostring(info.ModUUID)) or "$CONTENT_DATA"

            self.gui:setVisible("TrackSlot_" .. slot, true)
            self.gui:setText("TrackName_" .. slot, info.Name)
            self.gui:setText("TrackAuthor_" .. slot, info.Author)
            self.gui:setImage("TrackImage_" .. slot, modPrefix .. "/" .. info.Image)
            self.gui:setButtonState("TrackSlot_" .. slot, trackKey == self.cl_currentAudioName)
        else
            self.gui:setVisible("TrackSlot_" .. slot, false)
            self.gui:setButtonState("TrackSlot_" .. slot, false)
        end
    end

    self.gui:setText("TrackPageLabel", tostring(self.cl_trackPage + 1) .. "/" .. tostring(totalPages))
    self.gui:setVisible("TrackPageDown", self.cl_trackPage ~= 0)
    self.gui:setVisible("TrackPageUp", self.cl_trackPage ~= (totalPages - 1))
end

function CustomRadio:cl_onTrackSlotClicked(slot)
    if self.cl_fmMode then
        return
    end

    local trackKey = self.cl_currentPageTracks[slot]
    if trackKey then
        self:selectTrack(trackKey)
        self:cl_refreshTrackList()
    end
end

for i = 1, SLOTS_PER_PAGE do
    CustomRadio["cl_onTrackSlot" .. i] = function(self)
        self:cl_onTrackSlotClicked(i)
    end
end

function CustomRadio:onTrackPageUp()
    if self.cl_fmMode then
        return
    end
    self.cl_trackPage = self.cl_trackPage + 1
    self:cl_refreshTrackList()
end

function CustomRadio:onTrackPageDown()
    if self.cl_fmMode then
        return
    end
    if self.cl_trackPage > 0 then
        self.cl_trackPage = self.cl_trackPage - 1
    end
    self:cl_refreshTrackList()
end

-- ─────────────────────────────────────────────
--  GUI CALLBACKS
-- ─────────────────────────────────────────────

function CustomRadio:cl_refreshPlaylistList()
    local names = self.playlistNames or {}
    local totalPages = math.max(1, math.ceil(#names / PLAYLIST_SLOTS_PER_PAGE))

    if self.cl_playlistPage > totalPages - 1 then
        self.cl_playlistPage = totalPages - 1
    end
    if self.cl_playlistPage < 0 then
        self.cl_playlistPage = 0
    end

    local start = self.cl_playlistPage * PLAYLIST_SLOTS_PER_PAGE + 1
    self.cl_currentPagePlaylists = {}

    for slot = 1, PLAYLIST_SLOTS_PER_PAGE do
        local playlistName = names[start + slot - 1]
        self.cl_currentPagePlaylists[slot] = playlistName

        if playlistName then
            local info = Utilities.getPlaylistInfo(self, playlistName)
            local modPrefix = info.ModUUID and ("$CONTENT_" .. tostring(info.ModUUID)) or "$CONTENT_DATA"

            self.gui:setVisible("PlaylistSlot_" .. slot, true)
            self.gui:setText("PlaylistName_" .. slot, info.Name)
            self.gui:setText("PlaylistAuthor_" .. slot, info.Author)
            self.gui:setImage("PlaylistImage_" .. slot, modPrefix .. "/" .. info.Image)
            self.gui:setButtonState("PlaylistSlot_" .. slot, playlistName == self.cl_currentPlaylist)
        else
            self.gui:setVisible("PlaylistSlot_" .. slot, false)
            self.gui:setButtonState("PlaylistSlot_" .. slot, false)
        end
    end

    self.gui:setText("PlaylistPageLabel", tostring(self.cl_playlistPage + 1) .. "/" .. tostring(totalPages))
    self.gui:setVisible("PlaylistPageDown", self.cl_playlistPage ~= 0)
    self.gui:setVisible("PlaylistPageUp", self.cl_playlistPage ~= (totalPages - 1))
end

function CustomRadio:cl_onPlaylistSlotClicked(slot)
    if self.cl_fmMode then
        return
    end

    local playlistName = self.cl_currentPagePlaylists[slot]
    if not playlistName or playlistName == self.cl_currentPlaylist then
        return
    end

    self.network:sendToServer("sv_changePlaylist", playlistName)
    self:cl_changePlaylist(playlistName)
    self.cl_trackPage = 0
    self:rebuildShuffleQueue()

    self:cl_refreshTrackList()
    self:cl_refreshPlaylistList()
end

for i = 1, PLAYLIST_SLOTS_PER_PAGE do
    CustomRadio["cl_onPlaylistSlot" .. i] = function(self)
        self:cl_onPlaylistSlotClicked(i)
    end
end

function CustomRadio:onPlaylistPageUp()
    self.cl_playlistPage = self.cl_playlistPage + 1
    self:cl_refreshPlaylistList()
end

function CustomRadio:onPlaylistPageDown()
    if self.cl_playlistPage > 0 then
        self.cl_playlistPage = self.cl_playlistPage - 1
    end
    self:cl_refreshPlaylistList()
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
    self.cl_currentAudioName = newTrack

    if newTrack ~= nil and newTrack ~= "" then
        self.cl_audio_effect = sm.effect.createEffect(newTrack, self.interactable)
    end

    local info = Utilities.getTrackInfo(self, newTrack)
    self.cl_trackDuration = info.Duration or 0
    self.cl_trackPosition = 0
    self.cl_trackStartRetries = 0

    if sm.exists(self.gui) then
        local modPrefix = info.ModUUID and ("$CONTENT_" .. tostring(info.ModUUID)) or "$CONTENT_DATA"

        self.gui:setText("TrackName", info.Name)
        self.gui:setText("TrackAuthor", info.Author)
        self.gui:setImage("TrackImage", modPrefix .. "/" .. info.Image)

        self:cl_refreshTrackList()
        self:cl_updateTrackPositionGui()
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
--  TRACK POSITION / SEEK
-- ─────────────────────────────────────────────

function CustomRadio:cl_updateTrackPositionGui()
    if not sm.exists(self.gui) then
        return
    end

    self.gui:setText("TrackTimeLabel", Utilities.formatTime(self.cl_trackPosition or 0) .. " / " .. Utilities.formatTime(self.cl_trackDuration or 0))

    local sinceUserInput = (self.cl_elapsedTime or 0) - (self.cl_lastUserSeekAt or -math.huge)
    if sinceUserInput < SEEK_SYNC_COOLDOWN then
        return
    end

    local duration = self.cl_trackDuration or 0
    local position = self.cl_trackPosition or 0

    local sliderValue = 0
    if duration > 0 then
        sliderValue = math.floor((position / duration) * SEEK_SLIDER_STEPS + 0.5)
        sliderValue = math.max(0, math.min(SEEK_SLIDER_STEPS, sliderValue))
    end

    self.cl_seekBarSyncing = true
    self.gui:setSliderPosition("SeekBar", sliderValue)
    self.cl_seekBarSyncing = false
end

function CustomRadio:cl_seekTo(positionMs)
    positionMs = math.max(0, positionMs or 0)
    if self.cl_trackDuration and self.cl_trackDuration > 0 then
        positionMs = math.min(positionMs, self.cl_trackDuration)
    end
    self.cl_trackPosition = positionMs

    if self:isValidEffect() then
        self.cl_audio_effect:setParameter("CAE_Position", positionMs / 1000.0)
    end
    self:send_toSpeaker("remote_radio_controller_seek", positionMs)

    self:cl_updateTrackPositionGui()
end

function CustomRadio.cl_seekTrack(self, positionMs)
    self:cl_seekTo(positionMs)
end

function CustomRadio.client_onSeekBarMoved(self, value)
    if self.cl_seekBarSyncing then
        return
    end

    self.cl_lastUserSeekAt = self.cl_elapsedTime or 0

    if self.cl_fmMode or not self:hasRealTrack() then
        return
    end
    if not self.cl_trackDuration or self.cl_trackDuration <= 0 then
        return
    end

    local targetMs = (value / SEEK_SLIDER_STEPS) * self.cl_trackDuration

    self:cl_seekTo(targetMs)
    self.network:sendToServer("sv_seekTrack", self.cl_trackPosition)
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