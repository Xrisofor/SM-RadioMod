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

-- Server

function CustomRadio.server_onCreate(self)
    self.storageSave = self.storage:load()

    if self.storageSave == nil then
        self.storageSave = { track = "No Playing", volume = 1, play_state = false }
    end

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
                    return self.trackInfo[self.cl_currentAudioName] or { Name = "Unknown", Author = "Unknown", Image = "Gui/Icons/default_image.png", Duration = 0 }
                end
            },
        }
    }
end

function CustomRadio:server_onFixedUpdate()
    local hostPlayer = sm.player.getAllPlayers()[1]

    if self.sc_set_state then
        self.network:sendToClient(hostPlayer, "onSetPlayState")
        self.sc_set_state = nil
    end

    if self.sc_play then
        if self.storageSave.play_state then
            self.network:sendToClient(hostPlayer, "onSetPlayState")
        end
        self.sc_next_sound = nil
    end
    
    if self.sc_stop then
        if not self.storageSave.play_state then
            self.network:sendToClient(hostPlayer, "onSetPlayState")
        end
        self.sc_next_sound = nil
    end

    if self.sc_next_sound then
        self.network:sendToClient(hostPlayer, "changeSound", 1)
        self.sc_next_sound = nil
    end

    if self.sc_back_sound then
        self.network:sendToClient(hostPlayer, "changeSound", -1)
        self.sc_back_sound = nil
    end
end

function CustomRadio.sv_changeTrack(self, setting, player)
    if self.sv_audioName ~= setting then
        self.sv_audioName = setting
        self.storageSave.track = setting
        self.storage:save(self.storageSave)
        self.network:sendToClients("cl_changeTrack", setting)
    end
end

function CustomRadio.sv_changeTrackVolume(self, setting, player)
    if self.sv_volumeLevel ~= setting then
        self.sv_volumeLevel = setting
        self.storageSave.volume = setting
        self.storage:save(self.storageSave)
        self.network:sendToClients("cl_changeTrackVolume", setting)
    end
end

function CustomRadio.sv_changePlayState(self, setting, player)
    if self.sv_playState ~= setting then
        self.sv_playState = setting
        self.storageSave.play_state = setting
        self.storage:save(self.storageSave)
        self.network:sendToClients("cl_changePlayState", setting)
    end
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
    self.cl_audio_effect = sm.effect.createEffect("No Playing", self.interactable)

    self.network:sendToServer("sv_getRadioInfo")

    if sm.cae_injected == nil then
        sm.gui.chatMessage("(Radio Mod / Custom Radio) You have not installed #ff0000SM-CustomAudioExtension#ffffff, all music in the radio will not be played until you install the library!")
    end

    Utilities.loadCustomMusicTracks(self)
end

function CustomRadio.cl_updateRadioInfo(self, data)
    self:cl_changeTrack(data.track)
    self:cl_changeTrackVolume(data.volume)
    self:cl_changePlayState(data.playState)
end

-- Client

function CustomRadio.send_toSpeaker(self, fun, params)
	for _, element in ipairs(self.connectedElements) do
		local shape = element:getShape()
		if shape and shape.uuid == sm.uuid.new("99ae2a73-b28d-4b7c-a558-104ed1b59b1d") then
			sm.event.sendToInteractable(element, fun, params)
		end
	end
end

function CustomRadio.client_onUpdate(self)
    local parent = self.interactable:getSingleParent()
    self.connectedElements = self.interactable:getChildren()

    local function updateAudioEffect(play)
        if play then
            if not sm.exists(self.cl_audio_effect) or not self.cl_audio_effect:isPlaying() then
                if self.cl_currentAudioName ~= "No Playing" then
                    self.cl_audio_effect:start()
                    self.interactable:setPoseWeight(0, 1)
                else
                    if sm.exists(self.cl_audio_effect) then
                        self.cl_audio_effect:destroy()
                    end
                    self.interactable:setPoseWeight(0, 0)
                end
            end
        else
            if sm.exists(self.cl_audio_effect) and self.cl_audio_effect:isPlaying() then
                self.cl_audio_effect:stop()
                self.interactable:setPoseWeight(0, 0)
            end
        end
    end

    if not sm.exists(parent) then
        updateAudioEffect(self.cl_playState)

		self:send_toSpeaker("remote_radio_controller", {
			currentAudioName = self.cl_currentAudioName,
			currentAudioVolume = self.cl_currentAudioVolume,
            currentPlayState = self.cl_playState
		})
    else
        local isCompositeConnection = (parent:getType() == "scripted")

        local active --local active = isCompositeConnection and true or parent.active
        local clockShape = parent:getShape()
		if clockShape and clockShape.uuid == sm.uuid.new("3f7a7d81-e33a-4a73-91b7-7f9f20d8489d") then
			active = parent.active
        else
            active = isCompositeConnection and true or parent.active
        end

        updateAudioEffect(active and self.cl_playState)

        self:send_toSpeaker("remote_radio_controller", {
			currentAudioName = self.cl_currentAudioName,
			currentAudioVolume = self.cl_currentAudioVolume,
            currentPlayState = active and self.cl_playState
		})
    end

    if sm.exists(self.cl_audio_effect) then
        self.cl_audio_effect:setParameter("CAE_Volume", self.cl_currentAudioVolume / 10.0)
    end
end

function CustomRadio.createGui(self)
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

function CustomRadio.remote_control(self)
    if not sm.exists(self.gui) then
        self:createGui()
    end

    local trackInfo = self.trackInfo[self.cl_currentAudioName] or { Name = "Unknown", Author = "Unknown", Image = "Gui/Icons/default_image.png", Duration = 0 }
    self.gui:setText("TrackName", trackInfo.Name)
    self.gui:setText("TrackAuthor", trackInfo.Author)
    self.gui:setText("TrackTime", string.format("%d Min", trackInfo.Duration))
    self.gui:setImage("TrackImage", "$CONTENT_DATA/" .. trackInfo.Image)

    self.gui:setText("ConnectedElem", tostring(#self.connectedElements).." / "..tostring(CustomRadio.maxChildCount))

    self.gui:setSelectedDropDownItem("DropDown", self.cl_currentAudioName)
    self.gui:setText("PlayStopButton", self.cl_playState and "Stop" or "Play")
    self.gui:open()
end

function CustomRadio.client_onInteract(self, char, lookAt)
    if lookAt then
        self:remote_control()
    end
end

function CustomRadio.cl_onDropdownInteract(self, option)
    self.network:sendToServer("sv_changeTrack", option)

    if self.cl_playState then
        self.gui:setText("PlayStopButton", "Stop")
    else
        self.gui:setText("PlayStopButton", "Play")
    end
end

function CustomRadio.cl_changeTrack(self, newSetting)
    if self.cl_currentAudioName ~= newSetting and newSetting ~= "" then
        self.cl_currentAudioName = newSetting

        if sm.exists(self.cl_audio_effect) then
            self.cl_audio_effect:destroy()

			self:send_toSpeaker("remote_radio_controller_destroy", "")
        end

        if self.cl_currentAudioName ~= nil then
            self.cl_audio_effect = sm.effect.createEffect(self.cl_currentAudioName, self.interactable)
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

function CustomRadio.cl_changePlayState(self, newSetting)
    if self.cl_playState ~= newSetting then
        self.cl_playState = newSetting
    end
end

function CustomRadio.cl_changeTrackVolume(self, newSetting)
    if self.cl_currentAudioVolume ~= newSetting and newSetting ~= "" then
        self.cl_currentAudioVolume = newSetting

		self:send_toSpeaker("remote_radio_controller_volume", newSetting)
    else
        self.cl_currentAudioVolume = 1
    end
end

function CustomRadio.client_onSliderMoved(self, value)
    if self.cl_audio_effect and sm.exists(self.cl_audio_effect) then
        self.network:sendToServer("sv_changeTrackVolume", value / 10.0)
    end
end

function CustomRadio.client_onDestroy(self)
    if sm.exists(self.cl_audio_effect) then
		self:send_toSpeaker("remote_radio_controller_destroy", "")

        self.cl_audio_effect:destroy()
    end

    if sm.exists(self.gui) then
        self.gui:destroy()
    end
end

function CustomRadio.onSetPlayState(self)
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

function CustomRadio.changeSound(self, direction)
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

function CustomRadio.onNextSound(self)
    self:changeSound(1)
end

function CustomRadio.onBackSound(self)
    self:changeSound(-1)
end

function CustomRadio.onRandom(self)
    local randomIndex = math.random(1, #self.tracks)
    self.gui:setSelectedDropDownItem("DropDown", self.tracks[randomIndex])
    self.network:sendToServer("sv_changeTrack", self.tracks[randomIndex])
end