CustomRadioSpeaker = class()

CustomRadioSpeaker.maxParentCount = 1
CustomRadioSpeaker.connectionInput = 1
CustomRadioSpeaker.poseWeightCount = 1
CustomRadioSpeaker.connectionInput = sm.interactable.connectionType.logic
CustomRadioSpeaker.colorNormal = sm.color.new("#df6d2d")
CustomRadioSpeaker.colorHighlight = sm.color.new("#c84c05")

function CustomRadioSpeaker.client_onCreate(self)
    self.cl_currentAudioName = "No Playing"
    self.cl_currentAudioVolume = 1
    self.cl_playState = false
    self.cl_playSpeed = 0
    self.cl_audio_effect = sm.effect.createEffect("No Playing", self.interactable)
end

function CustomRadioSpeaker.client_onFixedUpdate(self)
    local parent = self.interactable:getSingleParent()

    if not sm.exists(parent) then
        self:remote_radio_controller_destroy()
    end
end

function CustomRadioSpeaker.remote_radio_controller(self, params)
    self.cl_currentAudioName = params["currentAudioName"]
    self.cl_currentAudioVolume = params["currentAudioVolume"]
    self.cl_playState = params["currentPlayState"]

    if params["actived"] == nil then
        if self.cl_playState then
            if not sm.exists(self.cl_audio_effect) or not self.cl_audio_effect:isPlaying() then
                if self.cl_currentAudioName ~= "No Playing" then
                    self.interactable:setPoseWeight(0, 1)
                    if not sm.exists(self.cl_audio_effect) then
                        self.cl_audio_effect = sm.effect.createEffect(self.cl_currentAudioName, self.interactable)
                        self.cl_audio_effect:setParameter("CAE_Volume", self.cl_currentAudioVolume / 10.0)
                    end
                    self.cl_audio_effect:start()
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
    else
        if self.cl_playState then
            if active and not sm.exists(self.cl_audio_effect) or not self.cl_audio_effect:isPlaying() then
                if self.cl_currentAudioName ~= "No Playing" then
                    self.interactable:setPoseWeight(0, 1)
                    if not sm.exists(self.cl_audio_effect) then
                        self.cl_audio_effect = sm.effect.createEffect(self.cl_currentAudioName, self.interactable)
                        self.cl_audio_effect:setParameter("CAE_Volume", self.cl_currentAudioVolume / 10.0)
                    end
                    self.cl_audio_effect:start()
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
end

function CustomRadioSpeaker.remote_radio_controller_volume(self, param)
    if sm.exists(self.cl_audio_effect) then
        self.cl_currentAudioVolume = param
        self.cl_audio_effect:setParameter("CAE_Volume", self.cl_currentAudioVolume / 10.0)
    end
end

function CustomRadioSpeaker.remote_radio_controller_speed(self, param)
    if sm.exists(self.cl_audio_effect) then
        self.cl_playSpeed = param
        self.cl_audio_effect:setParameter("CAE_Pitch", self.cl_playSpeed > 0 and self.cl_playSpeed or 0.5)
    end
end

function CustomRadioSpeaker.remote_radio_controller_destroy(self)
    if sm.exists(self.cl_audio_effect) then
        self.cl_audio_effect:destroy()
        self.cl_currentAudioName = "No Playing"
        self.cl_currentAudioVolume = 1
        self.interactable:setPoseWeight(0, 0)
    end
end
