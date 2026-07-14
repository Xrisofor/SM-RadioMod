dofile("$GAME_DATA/Scripts/game/AnimationUtil.lua")
dofile("$SURVIVAL_DATA/Scripts/util.lua")
dofile("$CONTENT_DATA/Scripts/game/Utilities.lua")

RadioPortable = class()

local renderables = { "$CONTENT_DATA/Tools/Portable/radio_portable.rend" }
local renderablesTp = {
    "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_heavytool.rend", 
    "$SURVIVAL_DATA/Character/Char_Tools/char_heavytool/char_heavytool_tp_animlist.rend"
}
local renderablesFp = {
    "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_heavytool.rend",
    "$SURVIVAL_DATA/Character/Char_Tools/char_heavytool/char_heavytool_fp_animlist.rend"
}

local currentRenderablesTp = {}
local currentRenderablesFp = {}

sm.tool.preloadRenderables(renderables)
sm.tool.preloadRenderables(renderablesTp)
sm.tool.preloadRenderables(renderablesFp)

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

-- ─────────────────────────────────────────────
--  HELPERS
-- ─────────────────────────────────────────────

function RadioPortable:isValidEffect()
    return self.cl_audio_effect ~= nil and sm.exists(self.cl_audio_effect)
end

function RadioPortable:hasRealTrack()
    return self.cl_currentAudioName ~= nil and self.cl_currentAudioName ~= ""
end

function RadioPortable:getActiveTracks()
    return Utilities.getPlaylistTracks(self, self.cl_currentPlaylist)
end

function RadioPortable:rebuildShuffleQueue()
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

function RadioPortable:nextShuffleTrack()
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

function RadioPortable:getFMSignal()
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

-- ─────────────────────────────────────────────
--  SERVER
-- ─────────────────────────────────────────────

function RadioPortable.server_onCreate(self)
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
end

function RadioPortable.server_onUnload(self)
    self.storageSave.track_position = math.floor(self.sv_trackPosition or 0)
    self.storage:save(self.storageSave)
end

function RadioPortable:server_onFixedUpdate(dt)
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
end

local SETTING_FIELD = {
    track = "sv_audioName",
    volume = "sv_volumeLevel",
    play_state = "sv_playState",
    play_speed = "sv_playSpeed",
    playlist = "sv_playlist",
    repeat_mode = "sv_repeatMode",
    shuffle = "sv_shuffle",
    fm_mode = "sv_fmMode",
    fm_frequency = "sv_fmFrequency"
}

function RadioPortable:sv_updateSetting(key, value, clientFn)
    if self.storageSave[key] ~= value then
        self.storageSave[key] = value
        self[SETTING_FIELD[key] or ("sv_" .. key)] = value
        self.storage:save(self.storageSave)
        self.network:sendToClients(clientFn, value)
    end
end

function RadioPortable.sv_changeTrack(self, s)
    if self.sv_audioName ~= s then
        self.sv_trackPosition = 0
        self.storageSave.track_position = 0
        self.storage:save(self.storageSave)
    end
    self:sv_updateSetting("track", s, "cl_changeTrack")
end
function RadioPortable.sv_changeTrackVolume(self, s)
    self:sv_updateSetting("volume", s, "cl_changeTrackVolume")
end
function RadioPortable.sv_changePlayState(self, s)
    self.storageSave.track_position = math.floor(self.sv_trackPosition or 0)
    self.storage:save(self.storageSave)
    self:sv_updateSetting("play_state", s, "cl_changePlayState")
end
function RadioPortable.sv_changePlaySpeed(self, s)
    self:sv_updateSetting("play_speed", s, "cl_changePlaySpeed")
end
function RadioPortable.sv_changePlaylist(self, s)
    self:sv_updateSetting("playlist", s, "cl_changePlaylist")
end
function RadioPortable.sv_changeRepeatMode(self, s)
    self:sv_updateSetting("repeat_mode", s, "cl_changeRepeatMode")
end
function RadioPortable.sv_changeShuffle(self, s)
    self:sv_updateSetting("shuffle", s, "cl_changeShuffle")
end
function RadioPortable.sv_toggleFmMode(self, s)
    self:sv_updateSetting("fm_mode", s, "cl_setFmMode")
end
function RadioPortable.sv_setFmFrequency(self, freq)
    self:sv_updateSetting("fm_frequency", freq, "cl_setFmFrequency")
end

function RadioPortable.sv_seekTrack(self, positionMs)
    self.sv_trackPosition = positionMs
    self.storageSave.track_position = math.floor(positionMs)
    self.storage:save(self.storageSave)
    self.network:sendToClients("cl_seekTrack", positionMs)
end

function RadioPortable.sv_getRadioInfo(self, _, player)
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

function RadioPortable.client_onCreate(self)
    self.isLocal = self.tool:isLocal()
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

    self:loadAnimations()

    self.network:sendToServer("sv_getRadioInfo")

    Utilities.checkCAE()
    Utilities.loadCustomMusicTracks(self)

    if self.cl_pendingRadioInfo then
        self:applyRadioInfo(self.cl_pendingRadioInfo)
        self.cl_pendingRadioInfo = nil
    end
end

function RadioPortable.client_onRefresh(self)
    self:loadAnimations()
end

function RadioPortable.cl_updateRadioInfo(self, data)
    if not self.tracks then
        self.cl_pendingRadioInfo = data
        return
    end
    self:applyRadioInfo(data)
end

function RadioPortable:applyRadioInfo(data)
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
--  TRACK END LOGIC
-- ─────────────────────────────────────────────

function RadioPortable:retryCurrentTrack()
    self.cl_trackStartRetries = (self.cl_trackStartRetries or 0) + 1

    if self:isValidEffect() then
        if self.cl_audio_effect:isPlaying() then
            self.cl_audio_effect:stop()
        end
        self.cl_audio_effect:destroy()
    end
    self.cl_audio_effect = nil

    if self.cl_currentAudioName and self.cl_currentAudioName ~= "" then
        self.cl_audio_effect = sm.effect.createEffect(self.cl_currentAudioName, self.tool:getOwner():getCharacter())
    end

    self.cl_effectJustStarted = false
end

function RadioPortable:onTrackEnded()
    if self.cl_fmMode then
        return
    end

    if self.cl_repeatMode == REPEAT_TRACK then
        if self:isValidEffect() then
            if self.cl_audio_effect:isPlaying() then
                self.cl_audio_effect:stop()
            end
            self.cl_audio_effect:destroy()
        end
        self.cl_audio_effect = sm.effect.createEffect(self.cl_currentAudioName, self.tool:getOwner():getCharacter())
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

function RadioPortable:updateAudioEffect(play)
    if play then
        if self:hasRealTrack() then
            if self:isValidEffect() and not self.cl_audio_effect:isPlaying() then
                self.cl_audio_effect:start()
                self.cl_effectJustStarted = true
                self.cl_trackStartClock = self.cl_elapsedTime or 0

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
        end
    else
        if self:isValidEffect() then
            if self.cl_audio_effect:isPlaying() then
                self.cl_audio_effect:stop()
            end
        end
    end
end

function RadioPortable:updateFmAudio(shouldPlay, dt)
    local signal = self:getFMSignal()

    if not signal then
        if self:isValidEffect() and self.cl_audio_effect:isPlaying() then
            self.cl_audio_effect:stop()
        end
        self.cl_fmCurrentTrack = nil
        self.cl_fmTrackPosition = 0
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
        end
        self.cl_audio_effect = nil
        self.cl_fmCurrentTrack = signal.track
        self.cl_fmTrackPosition = signal.position or 0

        if signal.track and signal.track ~= "" then
            self.cl_audio_effect = sm.effect.createEffect(signal.track, self.tool:getOwner():getCharacter())
            self.cl_audio_effect:setParameter("CAE_Position", self.cl_fmTrackPosition / 1000.0)
        end
    end

    local antennaPlaying = signal.playState
    local actualPlay = shouldPlay and antennaPlaying

    if actualPlay then
        if self:isValidEffect() and not self.cl_audio_effect:isPlaying() then
            self.cl_audio_effect:start()
            self.cl_fmTrackPosition = signal.position or 0
            self.cl_audio_effect:setParameter("CAE_Position", self.cl_fmTrackPosition / 1000.0)
        end
    else
        if self:isValidEffect() and self.cl_audio_effect:isPlaying() then
            self.cl_audio_effect:stop()
        end
    end

    if actualPlay and not trackChanged and wasPlaying then
        local speed = (signal.playSpeed and signal.playSpeed > 0) and signal.playSpeed or 1
        self.cl_fmTrackPosition = (self.cl_fmTrackPosition or 0) + (dt or 0) * 1000 * speed

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
end

-- ─────────────────────────────────────────────
--  ANIMATION
-- ─────────────────────────────────────────────

function RadioPortable.loadAnimations(self)
    self.tpAnimations = createTpAnimations(self.tool, {
        idle = {"heavytool_idle", {
            looping = true
        }},
        sprint = {"heavytool_sprint_idle"},
        pickup = {"heavytool_pickup", {
            nextAnimation = "idle"
        }},
        putdown = {"heavytool_putdown"}
    })

    local movementAnimations = {
        idle = "heavytool_idle",
        runFwd = "heavytool_run",
        runBwd = "heavytool_runbwd",
        sprint = "heavytool_sprint_idle",
        jump = "heavytool_jump",
        jumpUp = "heavytool_jump_up",
        jumpDown = "heavytool_jump_down",
        land = "heavytool_jump_land",
        landFwd = "heavytool_jump_land_fwd",
        landBwd = "heavytool_jump_land_bwd",
        crouchIdle = "heavytool_crouch_idle",
        crouchFwd = "heavytool_crouch_run",
        crouchBwd = "heavytool_crouch_runbwd"
    }
    for name, animation in pairs(movementAnimations) do
        self.tool:setMovementAnimation(name, animation)
    end

    if self.tool:isLocal() then
        self.fpAnimations = createFpAnimations(self.tool, {
            idle = {"heavytool_idle", {
                looping = true
            }},
            sprintInto = {"heavytool_sprint_into", {
                nextAnimation = "sprintIdle",
                blendNext = 0.2
            }},
            sprintIdle = {"heavytool_sprint_idle", {
                looping = true
            }},
            sprintExit = {"heavytool_sprint_exit", {
                nextAnimation = "idle",
                blendNext = 0
            }},
            equip = {"heavytool_pickup", {
                nextAnimation = "idle"
            }},
            unequip = {"heavytool_putdown"}
        })
    end

    setTpAnimation(self.tpAnimations, "idle", 5.0)
    self.blendTime = 0.2
end

-- ─────────────────────────────────────────────
--  CLIENT UPDATE
-- ─────────────────────────────────────────────

function RadioPortable.client_onUpdate(self, dt)
    self.cl_elapsedTime = (self.cl_elapsedTime or 0) + dt

    local isCrouching = self.tool:isCrouching()
    local crouchWeight = isCrouching and 1.0 or 0.0
    local normalWeight = 1.0 - crouchWeight
    local totalWeight = 0.0

    if self.tool:isLocal() then
        updateFpAnimations(self.fpAnimations, self.equipped, dt)
    end

    if not self.equipped then
        if self.intendedEquipped then
            self.intendedEquipped = false
            self.equipped = true
        end
        return
    end

    for name, animation in pairs(self.tpAnimations.animations) do
        animation.time = animation.time + dt

        if name == self.tpAnimations.currentAnimation then
            animation.weight = math.min(animation.weight + (self.tpAnimations.blendSpeed * dt), 1.0)

            if animation.looping then
                if animation.time >= animation.info.duration then
                    animation.time = animation.time - animation.info.duration
                end
            end

            if animation.time >= animation.info.duration - self.blendTime and not animation.looping then
                if name == "use" then
                    setTpAnimation(self.tpAnimations, "idle", 10.0)
                elseif name == "pickup" then
                    setTpAnimation(self.tpAnimations, "idle", 0.001)
                elseif animation.nextAnimation ~= "" then
                    setTpAnimation(self.tpAnimations, animation.nextAnimation, 0.001)
                end
            end
        else
            animation.weight = math.max(animation.weight - (self.tpAnimations.blendSpeed * dt), 0.0)
        end

        totalWeight = totalWeight + animation.weight
    end

    totalWeight = totalWeight == 0 and 1.0 or totalWeight
    for name, animation in pairs(self.tpAnimations.animations) do
        local weight = animation.weight / totalWeight
        if name == "idle" then
            self.tool:updateMovementAnimation(animation.time, weight)
        elseif animation.crouch then
            self.tool:updateAnimation(animation.info.name, animation.time, weight * normalWeight)
            self.tool:updateAnimation(animation.crouch.name, animation.time, weight * crouchWeight)
        else
            self.tool:updateAnimation(animation.info.name, animation.time, weight)
        end
    end

    if self.cl_fmMode then
        self:updateFmAudio(self.cl_playState, dt)
        return
    end

    self:updateAudioEffect(self.cl_playState)

    if self.cl_playState and self:isValidEffect() then
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

    if self:isValidEffect() then
        self.cl_audio_effect:setParameter("CAE_Volume", self.cl_currentAudioVolume / 10.0)
        self.cl_audio_effect:setParameter("CAE_Pitch", self.cl_playSpeed > 0 and self.cl_playSpeed or 0.5)
    end
end

-- ─────────────────────────────────────────────
--  EQUIP / UNEQUIP
-- ─────────────────────────────────────────────

function RadioPortable.client_onEquip(self)
    sm.audio.play("Sledgehammer - Equip", self.tool:getPosition())

    self.intendedEquipped = true
    currentRenderablesTp = {}
    currentRenderablesFp = {}

    for _, v in pairs(renderablesTp) do
        currentRenderablesTp[#currentRenderablesTp + 1] = v
    end

    for _, v in pairs(renderablesFp) do
        currentRenderablesFp[#currentRenderablesFp + 1] = v
    end

    for _, v in pairs(renderables) do
        currentRenderablesTp[#currentRenderablesTp + 1] = v
    end

    for _, v in pairs(renderables) do
        currentRenderablesFp[#currentRenderablesFp + 1] = v
    end

    self.tool:setTpRenderables(currentRenderablesTp)
    if self.tool:isLocal() then
        self.tool:setFpRenderables(currentRenderablesFp)
    end

    self:loadAnimations()
    setTpAnimation(self.tpAnimations, "pickup", 0.0001)
    if self.tool:isLocal() then
        swapFpAnimation(self.fpAnimations, "unequip", "equip", 0.2)
    end
end

function RadioPortable.client_onUnequip(self)
    sm.audio.play("Sledgehammer - Unequip", self.tool:getPosition())

    self.intendedEquipped = false
    self.equipped = false

    if sm.exists(self.tool) then
        setTpAnimation(self.tpAnimations, "putdown")
        if self.tool:isLocal() and self.fpAnimations.currentAnimation ~= "unequip" then
            swapFpAnimation(self.fpAnimations, "equip", "unequip", 0.2)
        end
    end
end

function RadioPortable.client_onToggle(self)
    return false
end

-- ─────────────────────────────────────────────
--  EQUIPPED UPDATE
-- ─────────────────────────────────────────────

function RadioPortable.client_onEquippedUpdate(self, primaryState, secondaryState, forceBuildActive)
    if primaryState == sm.tool.interactState.start and not forceBuildActive then
        if not sm.exists(self.gui) then
            self:createGui()
        end

        local info = Utilities.getTrackInfo(self, self.cl_currentAudioName)
        local modPrefix = info.ModUUID and ("$CONTENT_" .. tostring(info.ModUUID)) or "$CONTENT_DATA"

        self.gui:setText("TrackName", info.Name)
        self.gui:setText("TrackAuthor", info.Author)
        self.gui:setImage("TrackImage", modPrefix .. "/" .. info.Image)
        self.gui:setText("SubTitle", "Music is always nearby")

        self:cl_refreshTrackList()
        self:cl_refreshPlaylistList()
        self:cl_updateTrackPositionGui()

        self.gui:setImage("PlayerIcon", self.cl_playState and STOP_ICON or PLAY_ICON)
        self.gui:setButtonState("RepeatButton", repeatModeState(self.cl_repeatMode))
        self.gui:setButtonState("ShuffleButton", self.cl_shuffle)

        self:cl_refreshFmGui()

        self.gui:open()
        sm.audio.play("ConnectTool - Selected")
    end

    return true, true
end

-- ─────────────────────────────────────────────
--  GUI
-- ─────────────────────────────────────────────

function RadioPortable.createGui(self)
    self.gui = sm.gui.createGuiFromLayout(MAIN_LAYOUT)

    self.gui:setIconImage("Icon", sm.uuid.new("8cef2bc5-e57f-4068-85a6-0082601dc2e5"))

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

function RadioPortable:cl_refreshFmGui()
    if not sm.exists(self.gui) then
        return
    end

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
        self.gui:setVisible("TrackTimeLabel", true)
        self:cl_updateTrackPositionGui()
    end
end

function RadioPortable:cl_refreshTrackList()
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

function RadioPortable:cl_onTrackSlotClicked(slot)
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
    RadioPortable["cl_onTrackSlot" .. i] = function(self)
        self:cl_onTrackSlotClicked(i)
    end
end

function RadioPortable:onTrackPageUp()
    if self.cl_fmMode then
        return
    end
    self.cl_trackPage = self.cl_trackPage + 1
    self:cl_refreshTrackList()
end

function RadioPortable:onTrackPageDown()
    if self.cl_fmMode then
        return
    end
    if self.cl_trackPage > 0 then
        self.cl_trackPage = self.cl_trackPage - 1
    end
    self:cl_refreshTrackList()
end

-- ─────────────────────────────────────────────
--  PLAYLISTS
-- ─────────────────────────────────────────────

function RadioPortable:cl_refreshPlaylistList()
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

function RadioPortable:cl_onPlaylistSlotClicked(slot)
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
    RadioPortable["cl_onPlaylistSlot" .. i] = function(self)
        self:cl_onPlaylistSlotClicked(i)
    end
end

function RadioPortable:onPlaylistPageUp()
    self.cl_playlistPage = self.cl_playlistPage + 1
    self:cl_refreshPlaylistList()
end

function RadioPortable:onPlaylistPageDown()
    if self.cl_playlistPage > 0 then
        self.cl_playlistPage = self.cl_playlistPage - 1
    end
    self:cl_refreshPlaylistList()
end

-- ─────────────────────────────────────────────
--  GUI CALLBACKS
-- ─────────────────────────────────────────────

function RadioPortable.client_onVolumeSliderMoved(self, value)
    self.network:sendToServer("sv_changeTrackVolume", value / 10.0)

    if sm.exists(self.gui) then
        self.gui:setImage("VolumeIcon", value > 0 and VOLUME_ON_ICON or VOLUME_OFF_ICON)
    end
end

function RadioPortable.client_onSpeedSliderMoved(self, value)
    if self.cl_fmMode then
        return
    end
    self.network:sendToServer("sv_changePlaySpeed", value)
end

function RadioPortable:onCycleRepeat()
    if self.cl_fmMode then
        return
    end
    local next = (self.cl_repeatMode + 1) % 3
    self.network:sendToServer("sv_changeRepeatMode", next)
    self:cl_changeRepeatMode(next)
end

function RadioPortable:onToggleShuffle()
    if self.cl_fmMode then
        return
    end
    local next = not self.cl_shuffle
    self.network:sendToServer("sv_changeShuffle", next)
    self:cl_changeShuffle(next)
end

function RadioPortable:onToggleFmMode()
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
        end
        self.cl_audio_effect = nil
        if self.cl_currentAudioName and self.cl_currentAudioName ~= "" then
            self.cl_audio_effect = sm.effect.createEffect(self.cl_currentAudioName, self.tool:getOwner():getCharacter())
        end
    end

    if sm.exists(self.gui) then
        self:cl_refreshFmGui()
    end
end

function RadioPortable:onFmFrequencyUp()
    local next = math.min(255, self.cl_fmFrequency + 1)
    self.network:sendToServer("sv_setFmFrequency", next)
    self:cl_setFmFrequency(next)
    if sm.exists(self.gui) then
        self:cl_refreshFmGui()
    end
end

function RadioPortable:onFmFrequencyDown()
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

function RadioPortable.cl_changePlayState(self, newState)
    self.cl_playState = newState
    if sm.exists(self.gui) then
        self.gui:setImage("PlayerIcon", newState and STOP_ICON or PLAY_ICON)
    end
end

function RadioPortable.cl_changeTrack(self, newTrack)
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
    end
    self.cl_audio_effect = nil
    self.cl_effectJustStarted = false
    self.cl_currentAudioName = newTrack

    if newTrack ~= nil and newTrack ~= "" then
        self.cl_audio_effect = sm.effect.createEffect(newTrack, self.tool:getOwner():getCharacter())
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

function RadioPortable.cl_changeTrackVolume(self, newVolume)
    self.cl_currentAudioVolume = newVolume or 1

    if self:isValidEffect() then
        self.cl_audio_effect:setParameter("CAE_Volume", self.cl_currentAudioVolume / 10.0)
        local positionMs = self.cl_fmMode and (self.cl_fmTrackPosition or 0) or (self.cl_trackPosition or 0)
        self.cl_audio_effect:setParameter("CAE_Position", positionMs / 1000.0)
    end
end

function RadioPortable.cl_changePlaySpeed(self, newSpeed)
    self.cl_playSpeed = newSpeed or 1
end

function RadioPortable.cl_changePlaylist(self, newPlaylist)
    if newPlaylist and newPlaylist ~= "" then
        self.cl_currentPlaylist = newPlaylist
    end
end

function RadioPortable.cl_changeRepeatMode(self, mode)
    self.cl_repeatMode = mode
    if sm.exists(self.gui) then
        self.gui:setButtonState("RepeatButton", repeatModeState(mode))
    end
end

function RadioPortable.cl_changeShuffle(self, state)
    self.cl_shuffle = state
    if sm.exists(self.gui) then
        self.gui:setButtonState("ShuffleButton", state)
    end
    if state then
        self:rebuildShuffleQueue()
    end
end

function RadioPortable.cl_setFmMode(self, state)
    self.cl_fmMode = state
    if sm.exists(self.gui) then
        self.gui:setButtonState("FmButton", state)
    end
end

function RadioPortable.cl_setFmFrequency(self, freq)
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

function RadioPortable:cl_updateTrackPositionGui()
    if not sm.exists(self.gui) then
        return
    end

    local duration = self.cl_trackDuration or 0
    local hasDuration = duration > 0

    if not hasDuration then
        self.gui:setText("TrackTimeLabel", "Seeking unavailable")
        self.gui:setVisible("SeekBar", false)
        return
    end

    if not self.cl_fmMode then
        self.gui:setVisible("SeekBar", true)
    end

    self.gui:setText("TrackTimeLabel", Utilities.formatTime(self.cl_trackPosition or 0) .. " / " .. Utilities.formatTime(duration))

    local sinceUserInput = (self.cl_elapsedTime or 0) - (self.cl_lastUserSeekAt or -math.huge)
    if sinceUserInput < SEEK_SYNC_COOLDOWN then
        return
    end

    local position = self.cl_trackPosition or 0

    local sliderValue = math.floor((position / duration) * SEEK_SLIDER_STEPS + 0.5)
    sliderValue = math.max(0, math.min(SEEK_SLIDER_STEPS, sliderValue))

    self.cl_seekBarSyncing = true
    self.gui:setSliderPosition("SeekBar", sliderValue)
    self.cl_seekBarSyncing = false
end

function RadioPortable:cl_seekTo(positionMs)
    positionMs = math.max(0, positionMs or 0)
    if self.cl_trackDuration and self.cl_trackDuration > 0 then
        positionMs = math.min(positionMs, self.cl_trackDuration)
    end
    self.cl_trackPosition = positionMs

    if self:isValidEffect() then
        self.cl_audio_effect:setParameter("CAE_Position", positionMs / 1000.0)
    end

    self:cl_updateTrackPositionGui()
end

function RadioPortable.cl_seekTrack(self, positionMs)
    self:cl_seekTo(positionMs)
end

function RadioPortable.client_onSeekBarMoved(self, value)
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

function RadioPortable:selectTrack(trackName)
    if self.cl_fmMode then
        return
    end
    if not trackName or trackName == "" then
        return
    end
    self:cl_changeTrack(trackName)
    self.network:sendToServer("sv_changeTrack", trackName)
end

function RadioPortable:onSetPlayState()
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

function RadioPortable:onNextSound()
    if self.cl_fmMode then
        return
    end
    Utilities.changeSound(self, 1, self:getActiveTracks(), function(track)
        self:selectTrack(track)
    end)
end

function RadioPortable:onBackSound()
    if self.cl_fmMode then
        return
    end
    Utilities.changeSound(self, -1, self:getActiveTracks(), function(track)
        self:selectTrack(track)
    end)
end

function RadioPortable:onRandomSound()
    if self.cl_fmMode then
        return
    end
    Utilities.selectRandomTrack(self, function(track)
        self:selectTrack(track)
    end)
end

-- ─────────────────────────────────────────────
--  DESTROY
-- ─────────────────────────────────────────────

function RadioPortable.client_onDestroy(self)
    if self.cl_audio_effect ~= nil and sm.exists(self.cl_audio_effect) then
        self.cl_audio_effect:destroy()
    end
    if sm.exists(self.gui) then
        self.gui:destroy()
    end
end