CustomRadioClock = class()

CustomRadioClock.maxParentCount = 0
CustomRadioClock.connectionInput = 1
CustomRadioClock.maxChildCount = 255
CustomRadioClock.connectionInput = sm.interactable.connectionType.none
CustomRadioClock.connectionOutput = sm.interactable.connectionType.logic
CustomRadioClock.colorNormal = sm.color.new("#8b5dff")
CustomRadioClock.colorHighlight = sm.color.new("#6a42c2")

function CustomRadioClock.server_onCreate(self)
    self.storageSave = self.storage:load()

    if self.storageSave == nil then
        self.storageSave = { time = 0, state = false }
    end

    self.sv_clockTime = self.storageSave.time
    self.sv_stateToggle = self.storageSave.state

    self.interactable:setActive(self.sv_stateToggle)
    self.connectedElements = self.interactable:getChildren()

    print("(Radio Mod / Clock) Initialized with time:", self.sv_clockTime, "and state:", self.sv_stateToggle)
end

function CustomRadioClock.sv_changeTime(self, setting, player)
    if self.sv_clockTime ~= setting then
        self.sv_clockTime = setting
        self.storageSave.time = setting
        self.storage:save(self.storageSave)
        self.network:sendToClients("cl_changeTime", setting)
    end
end

function CustomRadioClock.sv_getTime(self, _, player)
    self.network:sendToClient(player, "cl_changeTime", self.sv_clockTime)
end

function CustomRadioClock:server_onFixedUpdate()
    local epsilon = 0.0001
    local currentTime = sm.game.getTimeOfDay()

    if math.abs(self.sv_clockTime - currentTime) < epsilon then
        if not self.stateToggle then
            local newActiveState = not self.sv_stateToggle
            self.sv_stateToggle = newActiveState
            self.storageSave.state = newActiveState
            self.storage:save(self.storageSave)

            self.interactable:setActive(newActiveState)
            self.stateToggle = true

            print("(Radio Mod / Clock) State toggled:", newActiveState)
        end
    else
        self.stateToggle = false
    end
end

function CustomRadioClock.client_onCreate(self)
    self.cl_timeOfDay = 0

    self.network:sendToServer("sv_getTime")
end

function CustomRadioClock.client_onInteract(self, char, lookAt)
    if lookAt then
        local newTime = (self.cl_timeOfDay + 0.05) % 1.0

        self.network:sendToServer("sv_changeTime", newTime)

        local totalMinutes = math.floor(newTime * 1440)
        local hours = math.floor(totalMinutes / 60)
        local minutes = totalMinutes % 60

        local formattedTime = string.format("%02d:%02d", hours, minutes)
        sm.gui.displayAlertText("The next trigger is at " .. formattedTime, 3)
    end
end

function CustomRadioClock.cl_changeTime(self, newSetting)
    if self.cl_timeOfDay ~= newSetting and newSetting ~= "" then
        self.cl_timeOfDay = newSetting
    end
end