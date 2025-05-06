dofile("$GAME_DATA/Scripts/game/AnimationUtil.lua")
dofile("$SURVIVAL_DATA/Scripts/util.lua" )
dofile("$CONTENT_DATA/Scripts/game/Utilities.lua")

RadioPortable = class()

local renderables = { "$CONTENT_DATA/Tools/Portable/radio_portable.rend" } -- "$SURVIVAL_DATA/Character/Char_Tools/char_heavytool/char_heavytool.rend"
local renderablesTp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_heavytool.rend", "$SURVIVAL_DATA/Character/Char_Tools/char_heavytool/char_heavytool_tp_animlist.rend" }
local renderablesFp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_heavytool.rend", "$SURVIVAL_DATA/Character/Char_Tools/char_heavytool/char_heavytool_fp_animlist.rend" }

local currentRenderablesTp = {}
local currentRenderablesFp = {}

sm.tool.preloadRenderables(renderables)
sm.tool.preloadRenderables(renderablesTp)
sm.tool.preloadRenderables(renderablesFp)

-- Server

function RadioPortable.server_onCreate(self)
    self.storageSave = self.storage:load()

    if self.storageSave == nil then
        self.storageSave = { track = "No Playing", volume = 1, play_state = false }
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

-- Client

function RadioPortable.client_onCreate(self)
    self.isLocal = self.tool:isLocal()
    self.cl_currentAudioName = "No Playing"
    self.cl_currentAudioVolume = 1
    self.cl_playState = false
    self.cl_audio_effect = sm.effect.createEffect("No Playing", self.tool:getOwner():getCharacter())

    self:loadAnimations()

    self.network:sendToServer("sv_getRadioInfo")

    if sm.cae_injected == nil then
        sm.gui.chatMessage("(Radio Mod / Custom Radio) You have not installed #ff0000SM-CustomAudioExtension#ffffff, all music in the radio will not be played until you install the library!")
    end

    Utilities.loadCustomMusicTracks(self)
end

function RadioPortable.client_onRefresh( self )
	self:loadAnimations()
end

function RadioPortable.cl_updateRadioInfo(self, data)
    self:cl_changeTrack(data.track)
    self:cl_changeTrackVolume(data.volume)
    self:cl_changePlayState(data.playState)
end

-- Loading

function RadioPortable.loadAnimations( self )

	self.tpAnimations = createTpAnimations(
        self.tool,
        {
            idle = { "heavytool_idle", { looping = true } },
			sprint = { "heavytool_sprint_idle" },
			pickup = { "heavytool_pickup", { nextAnimation = "idle" } },
			putdown = { "heavytool_putdown" }
        }
    )

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

    for name, animation in pairs( movementAnimations ) do
        self.tool:setMovementAnimation( name, animation )
    end

    if self.tool:isLocal() then
        self.fpAnimations = createFpAnimations(
            self.tool,
            {
                idle = { "heavytool_idle", { looping = true } },

                sprintInto = { "heavytool_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
                sprintIdle = { "heavytool_sprint_idle", { looping = true } },
                sprintExit = { "heavytool_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },

                equip = { "heavytool_pickup", { nextAnimation = "idle" } },
                unequip = { "heavytool_putdown" }
            }
        )
    end
      
    setTpAnimation( self.tpAnimations, "idle", 5.0 )
    self.blendTime = 0.2

end

-- Client

function RadioPortable.client_onUpdate( self, dt )
    local isSprinting = self.tool:isSprinting()
    local isCrouching = self.tool:isCrouching()

    local crouchWeight = self.tool:isCrouching() and 1.0 or 0.0
    local normalWeight = 1.0 - crouchWeight 
    local totalWeight = 0.0

    if self.tool:isLocal() then
        updateFpAnimations( self.fpAnimations, self.equipped, dt )
    end

    if not self.equipped then

        if self.intendedEquipped then
            self.intendedEquipped = false
            self.equipped = true
        end
        
        return

    end

    for name, animation in pairs( self.tpAnimations.animations ) do
        animation.time = animation.time + dt
    
        if name == self.tpAnimations.currentAnimation then
            animation.weight = math.min( animation.weight + ( self.tpAnimations.blendSpeed * dt ), 1.0 )
          
            if animation.looping == true then
                if animation.time >= animation.info.duration then
                animation.time = animation.time - animation.info.duration
                end
            end

            if animation.time >= animation.info.duration - self.blendTime and not animation.looping then
                if name == "use" then
                    setTpAnimation( self.tpAnimations, "idle", 10.0 )
                elseif name == "pickup" then
                    setTpAnimation( self.tpAnimations, "idle", 0.001 )
                elseif animation.nextAnimation ~= "" then
                    setTpAnimation( self.tpAnimations, animation.nextAnimation, 0.001 )
                end
            
            end
        else
            animation.weight = math.max( animation.weight - ( self.tpAnimations.blendSpeed * dt ), 0.0 )
        end
    
        totalWeight = totalWeight + animation.weight
    end

    totalWeight = totalWeight == 0 and 1.0 or totalWeight
    for name, animation in pairs( self.tpAnimations.animations ) do
    
        local weight = animation.weight / totalWeight
        if name == "idle" then
            self.tool:updateMovementAnimation( animation.time, weight )
        elseif animation.crouch then
            self.tool:updateAnimation( animation.info.name, animation.time, weight * normalWeight )
            self.tool:updateAnimation( animation.crouch.name, animation.time, weight * crouchWeight )
        else
            self.tool:updateAnimation( animation.info.name, animation.time, weight )
        end

    end

    local function updateAudioEffect(play)
        if play then
            if not sm.exists(self.cl_audio_effect) or not self.cl_audio_effect:isPlaying() then
                if self.cl_currentAudioName ~= "No Playing" then
                    self.cl_audio_effect:start()
                else
                    if sm.exists(self.cl_audio_effect) then
                        self.cl_audio_effect:destroy()
                    end
                end
            end
        else
            if sm.exists(self.cl_audio_effect) and self.cl_audio_effect:isPlaying() then
                self.cl_audio_effect:stop()
            end
        end
    end

    updateAudioEffect(self.cl_playState)

    if sm.exists(self.cl_audio_effect) then
        self.cl_audio_effect:setParameter("CAE_Volume", self.cl_currentAudioVolume / 10.0)
    end
end

function RadioPortable.client_onEquip( self )
	sm.audio.play( "Sledgehammer - Equip", self.tool:getPosition() )
  
    self.intendedEquipped = true
  
    currentRenderablesTp = {}
    currentRenderablesFp = {}
  
    for k,v in pairs( renderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
    for k,v in pairs( renderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
    for k,v in pairs( renderables ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
    for k,v in pairs( renderables ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
  
    self.tool:setTpRenderables( currentRenderablesTp )
    if self.tool:isLocal() then
      self.tool:setFpRenderables( currentRenderablesFp )
    end
  
    self:loadAnimations()
  
    setTpAnimation( self.tpAnimations, "pickup", 0.0001 )
    if self.tool:isLocal() then
        swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
    end
  end

function RadioPortable.client_onUnequip( self )
    sm.audio.play( "Sledgehammer - Unequip", self.tool:getPosition() )

    self.intendedEquipped = false
    self.equipped = false

    if sm.exists( self.tool ) then
        setTpAnimation( self.tpAnimations, "putdown" )
        if self.tool:isLocal() and self.fpAnimations.currentAnimation ~= "unequip" then
            swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
        end
    end

end

function RadioPortable.client_onToggle( self )
	return false
end

function RadioPortable.client_onEquippedUpdate( self, primaryState, secondaryState, forceBuildActive )

    local _, result = sm.localPlayer.getRaycast( 7.5 )
    local shape = nil

    if primaryState == sm.tool.interactState.start and not forceBuildActive then
        if not sm.exists(self.gui) then
            self:createGui()
        end

        local trackInfo = self.trackInfo[self.cl_currentAudioName] or { Name = "Unknown", Author = "Unknown", Image = "Gui/Icons/default_image.png", Duration = 0 }
        self.gui:setText("TrackName", trackInfo.Name)
        self.gui:setText("TrackAuthor", trackInfo.Author)
        self.gui:setText("TrackTime", string.format("%d Min", trackInfo.Duration))
        self.gui:setImage("TrackImage", "$CONTENT_DATA/" .. trackInfo.Image)

        self.gui:setText("ConnectedElem", "0 / 0")

        self.gui:setSelectedDropDownItem("DropDown", self.cl_currentAudioName)
        self.gui:setText("PlayStopButton", self.cl_playState and "Stop" or "Play")
        self.gui:open()

        sm.audio.play( "ConnectTool - Selected" )
    end

    return true, true
    
end

function RadioPortable.cl_onDropdownInteract(self, option)
    self.network:sendToServer("sv_changeTrack", option)

    if self.cl_playState then
        self.gui:setText("PlayStopButton", "Stop")
    else
        self.gui:setText("PlayStopButton", "Play")
    end
end

function RadioPortable.createGui(self)
    local options = { "No Playing" }
    local effects = sm.json.open("$CONTENT_DATA/Effects/Database/EffectSets/events.effectset")
    
    for name, _ in pairs(effects) do
        if name:gsub(":", "") == name then
            options[#options + 1] = name
        end
    end

    table.sort(options)
    options[1] = options[1]:gsub("No Playing", "")

    self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/CustomRadio.layout")
    self.gui:createDropDown("DropDown", "cl_onDropdownInteract", self.tracks)
    self.gui:createHorizontalSlider("VolumeSlider", 11, self.cl_currentAudioVolume * 10, "client_onSliderMoved")
    
    self.gui:setButtonCallback("PlayStopButton", "onSetPlayState")
    self.gui:setButtonCallback("NextButton", "onNextSound")
    self.gui:setButtonCallback("BackButton", "onBackSound")
    self.gui:setButtonCallback("RandomButton", "onRandom")
end

function RadioPortable.cl_changeTrack(self, newSetting)
    if self.cl_currentAudioName ~= newSetting and newSetting ~= "" then
        self.cl_currentAudioName = newSetting

        if sm.exists(self.cl_audio_effect) then
            self.cl_audio_effect:destroy()
        end

        if self.cl_currentAudioName ~= nil then
            self.cl_audio_effect = sm.effect.createEffect(self.cl_currentAudioName, self.tool:getOwner():getCharacter())
        else
            print("(Radio Mod) Track path is nil? " .. self.cl_currentAudioName)
        end

        if sm.exists(self.gui) then
            local trackInfo = self.trackInfo[self.cl_currentAudioName] or { Name = "Unknown", Author = "Unknown", Image = "Gui/Icons/default_image.png", Duration = 0 }
            self.gui:setSelectedDropDownItem("DropDown", self.cl_currentAudioName)
            self.gui:setText("TrackName", trackInfo.Name)
            self.gui:setText("TrackAuthor", trackInfo.Author)
            self.gui:setText("TrackTime", string.format("%d Min", trackInfo.Duration))
            self.gui:setImage("TrackImage", "$CONTENT_DATA/" .. trackInfo.Image)
        end
    else
        self.cl_currentAudioName = "No Playing"
    end
end

function RadioPortable.cl_changePlayState(self, newSetting)
    if self.cl_playState ~= newSetting then
        self.cl_playState = newSetting
    end
end

function RadioPortable.cl_changeTrackVolume(self, newSetting)
    if self.cl_currentAudioVolume ~= newSetting and newSetting ~= "" then
        self.cl_currentAudioVolume = newSetting
    else
        self.cl_currentAudioVolume = 1
    end
end

function RadioPortable.client_onSliderMoved(self, value)
    if self.cl_audio_effect and sm.exists(self.cl_audio_effect) then
        self.network:sendToServer("sv_changeTrackVolume", value / 10.0)
    end
end

function RadioPortable.client_onDestroy(self)
    if sm.exists(self.cl_audio_effect) then
        self.cl_audio_effect:destroy()
    end

    if sm.exists(self.gui) then
        self.gui:destroy()
    end
end

function RadioPortable.onSetPlayState(self)
    if sm.exists(self.cl_audio_effect) then
        if self.cl_audio_effect:isPlaying() then
            self.network:sendToServer("sv_changePlayState", false)
            self.gui:setText("PlayStopButton", "Play")
        else
            if self.cl_currentAudioName == "No Playing" then
                local randomIndex = math.random(1, #self.tracks)
                self.gui:setSelectedDropDownItem("DropDown", self.tracks[randomIndex])
                self.network:sendToServer("sv_changeTrack", self.tracks[randomIndex])
            end
            self.network:sendToServer("sv_changePlayState", true)
            self.gui:setText("PlayStopButton", "Stop")
        end
    else
        if self.cl_currentAudioName == "No Playing" then
            local randomIndex = math.random(1, #self.tracks)
            self.gui:setSelectedDropDownItem("DropDown", self.tracks[randomIndex])
            self.network:sendToServer("sv_changeTrack", self.tracks[randomIndex])
        end
        self.network:sendToServer("sv_changePlayState", true)
        self.gui:setText("PlayStopButton", "Stop")
    end
end

function RadioPortable.changeSound(self, direction)
    local trackNames = self.tracks
    table.sort(trackNames)

    local currentIndex = 1
    for i, name in ipairs(trackNames) do
        if name == self.cl_currentAudioName then
            currentIndex = i
            break
        end
    end

    currentIndex = currentIndex + direction

    if currentIndex > #trackNames then
        currentIndex = 1
    elseif currentIndex < 1 then
        currentIndex = #trackNames
    end

    self.gui:setSelectedDropDownItem("DropDown", trackNames[currentIndex])
    self.network:sendToServer("sv_changeTrack", trackNames[currentIndex])
end

function RadioPortable.onNextSound(self)
    self:changeSound(1)
end

function RadioPortable.onBackSound(self)
    self:changeSound(-1)
end

function RadioPortable.onRandom(self)
    local randomIndex = math.random(1, #self.tracks)
    self.gui:setSelectedDropDownItem("DropDown", self.tracks[randomIndex])
    self.network:sendToServer("sv_changeTrack", self.tracks[randomIndex])
end