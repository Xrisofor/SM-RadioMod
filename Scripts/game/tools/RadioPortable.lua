dofile("$GAME_DATA/Scripts/game/AnimationUtil.lua")
dofile("$SURVIVAL_DATA/Scripts/util.lua")
dofile("$CONTENT_DATA/Scripts/game/Utilities.lua")

RadioPortable = class()

local renderables = {"$CONTENT_DATA/Tools/Portable/radio_portable.rend"}
local renderablesTp = {"$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_heavytool.rend",
                       "$SURVIVAL_DATA/Character/Char_Tools/char_heavytool/char_heavytool_tp_animlist.rend"}
local renderablesFp = {"$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_heavytool.rend",
                       "$SURVIVAL_DATA/Character/Char_Tools/char_heavytool/char_heavytool_fp_animlist.rend"}

local currentRenderablesTp = {}
local currentRenderablesFp = {}

sm.tool.preloadRenderables(renderables)
sm.tool.preloadRenderables(renderablesTp)
sm.tool.preloadRenderables(renderablesFp)

-- ─────────────────────────────────────────────
--  SERVER
-- ─────────────────────────────────────────────

function RadioPortable.server_onCreate(self)
    self.storageSave = self.storage:load() or {}

    local defaults = {
        track = nil,
        volume = 1,
        play_state = false
    }
    for k, v in pairs(defaults) do
        if self.storageSave[k] == nil then
            self.storageSave[k] = v
        end
    end

    self.sv_audioName = self.storageSave.track
    self.sv_volumeLevel = self.storageSave.volume
    self.sv_playState = self.storageSave.play_state
end

function RadioPortable.sv_changeTrack(self, setting, player)
    if self.sv_audioName ~= setting then
        self.sv_audioName = setting
        self.storageSave.track = setting
        self.storage:save(self.storageSave)
        self.network:sendToClients("cl_changeTrack", setting)
    end
end

function RadioPortable.sv_changeTrackVolume(self, setting, player)
    if self.sv_volumeLevel ~= setting then
        self.sv_volumeLevel = setting
        self.storageSave.volume = setting
        self.storage:save(self.storageSave)
        self.network:sendToClients("cl_changeTrackVolume", setting)
    end
end

function RadioPortable.sv_changePlayState(self, setting, player)
    if self.sv_playState ~= setting then
        self.sv_playState = setting
        self.storageSave.play_state = setting
        self.storage:save(self.storageSave)
        self.network:sendToClients("cl_changePlayState", setting)
    end
end

function RadioPortable.sv_getRadioInfo(self, _, player)
    self.network:sendToClient(player, "cl_updateRadioInfo", {
        track = self.sv_audioName,
        volume = self.sv_volumeLevel,
        playState = self.sv_playState
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
    self.cl_shuffle = false
    self.cl_shuffleQueue = {}
    self.cl_audio_effect = nil

    self:loadAnimations()

    self.network:sendToServer("sv_getRadioInfo")

    Utilities.checkCAE()

    Utilities.loadCustomMusicTracks(self)
end

function RadioPortable.client_onRefresh(self)
    self:loadAnimations()
end

function RadioPortable.cl_updateRadioInfo(self, data)
    self:cl_changeTrack(data.track)
    self:cl_changeTrackVolume(data.volume)
    self:cl_changePlayState(data.playState)
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

    local function isValidEffect()
        return self.cl_audio_effect ~= nil and sm.exists(self.cl_audio_effect)
    end

    if self.cl_playState then
        if self.cl_currentAudioName ~= nil then
            if isValidEffect() and not self.cl_audio_effect:isPlaying() then
                self.cl_audio_effect:start()
            end
        else
            if isValidEffect() then
                self.cl_audio_effect:destroy()
                self.cl_audio_effect = nil
            end
        end
    else
        if isValidEffect() and self.cl_audio_effect:isPlaying() then
            self.cl_audio_effect:stop()
        end
    end

    if isValidEffect() then
        self.cl_audio_effect:setParameter("CAE_Volume", self.cl_currentAudioVolume / 10.0)
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

        self:cl_refreshTrackGrid()

        self.gui:setImage("PlayerIcon", self.cl_playState and STOP_ICON or PLAY_ICON)
        self.gui:setButtonState("ShuffleButton", self.cl_shuffle)

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

    self.gui:setButtonCallback("PlayerButton", "onSetPlayState")
    self.gui:setButtonCallback("NextButton", "onNextSound")
    self.gui:setButtonCallback("BackButton", "onBackSound")
    self.gui:setButtonCallback("ShuffleButton", "onToggleShuffle")
end

function RadioPortable.cl_refreshTrackGrid(self)
    local activeTracks = self.tracks or {}

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

function RadioPortable.cl_onTrackClicked(self, grid, index)
    local activeTracks = self.tracks or {}
    local trackKey = activeTracks[index + 1]
    if trackKey then
        self:selectTrack(trackKey)
        self:cl_refreshTrackGrid()
    end
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

function RadioPortable.onToggleShuffle(self)
    self.cl_shuffle = not self.cl_shuffle
    Utilities.rebuildShuffleQueue(self)
    if sm.exists(self.gui) then
        self.gui:setButtonState("ShuffleButton", self.cl_shuffle)
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
    if newTrack == self.cl_currentAudioName then
        return
    end

    if self.cl_audio_effect ~= nil and sm.exists(self.cl_audio_effect) then
        if self.cl_audio_effect:isPlaying() then
            self.cl_audio_effect:stop()
        end
        self.cl_audio_effect:destroy()
        self.cl_audio_effect = nil
    end

    self.cl_currentAudioName = newTrack

    if newTrack ~= nil and newTrack ~= "" then
        self.cl_audio_effect = sm.effect.createEffect(newTrack, self.tool:getOwner():getCharacter())
    end

    if sm.exists(self.gui) then
        local info = Utilities.getTrackInfo(self, newTrack)
        local modPrefix = info.ModUUID and ("$CONTENT_" .. tostring(info.ModUUID)) or "$CONTENT_DATA"

        self.gui:setText("TrackName", info.Name)
        self.gui:setText("TrackAuthor", info.Author)
        self.gui:setImage("TrackImage", modPrefix .. "/" .. info.Image)

        local activeTracks = self.tracks or {}
        for i, trackKey in ipairs(activeTracks) do
            self.gui:setGridItem("TrackGrid", i - 1, {
                HighlightItemIcon = (trackKey == newTrack)
            })
        end
    end
end

function RadioPortable.cl_changeTrackVolume(self, newVolume)
    self.cl_currentAudioVolume = newVolume or 1
end

-- ─────────────────────────────────────────────
--  TRACK SELECTION
-- ─────────────────────────────────────────────

function RadioPortable.selectTrack(self, trackName)
    if not trackName or trackName == "" then
        return
    end
    self:cl_changeTrack(trackName)
    self.network:sendToServer("sv_changeTrack", trackName)
end

function RadioPortable.onSetPlayState(self)
    local shouldPlay = not self.cl_playState

    if shouldPlay and self.cl_currentAudioName == nil then
        Utilities.selectRandomTrack(self, function(track)
            self:selectTrack(track)
        end)
    end

    self.network:sendToServer("sv_changePlayState", shouldPlay)
end

function RadioPortable.onNextSound(self)
    Utilities.changeSound(self, 1, self.tracks, function(track)
        self:selectTrack(track)
    end)
end

function RadioPortable.onBackSound(self)
    Utilities.changeSound(self, -1, self.tracks, function(track)
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
