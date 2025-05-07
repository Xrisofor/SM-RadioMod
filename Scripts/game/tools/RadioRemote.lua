dofile("$GAME_DATA/Scripts/game/AnimationUtil.lua")
dofile("$SURVIVAL_DATA/Scripts/util.lua")

RadioRemote = class()

local renderables = {"$CONTENT_DATA/Tools/Remote/char_radio_remote.rend"}
local renderablesTp = {"$GAME_DATA/Character/Char_Male/Animations/char_male_tp_weldtool.rend",
                       "$CONTENT_DATA/Tools/Remote/char_radio_remote_tp_animlist.rend"}
local renderablesFp = {"$CONTENT_DATA/Tools/Remote/char_radio_remote_fp_animlist.rend"}

local currentRenderablesTp = {}
local currentRenderablesFp = {}

sm.tool.preloadRenderables(renderables)
sm.tool.preloadRenderables(renderablesTp)
sm.tool.preloadRenderables(renderablesFp)

function RadioRemote.client_onCreate(self)
    self.isLocal = self.tool:isLocal()
    self.ConnectionCustomRadio = nil

    self:loadAnimations()
end

function RadioRemote.client_onRefresh(self)
    self:loadAnimations()
end

function RadioRemote.loadAnimations(self)
    self.tpAnimations = createTpAnimations(self.tool, {
        idle = {"weldtool_idle"},
        use = {"weldtool_use_idle", {
            nextAnimation = "idle"
        }},
        use_err = {"weldtool_use_error", {
            nextAnimation = "idle"
        }},
        pickup = {"weldtool_pickup", {
            nextAnimation = "idle"
        }},
        putdown = {"weldtool_putdown"}
    })

    local movementAnimations = {
        idle = "weldtool_idle",
        idleRelaxed = "weldtool_idle_relaxed",

        runFwd = "weldtool_run_fwd",
        runBwd = "weldtool_run_bwd",
        sprint = "weldtool_sprint",

        jump = "weldtool_jump_start",
        jumpUp = "weldtool_jump_up",
        jumpDown = "weldtool_jump_down",

        land = "weldtool_jump_land",
        landFwd = "weldtool_jump_land_fwd",
        landBwd = "weldtool_jump_land_bwd",

        crouchIdle = "weldtool_crouch_idle",
        crouchFwd = "weldtool_crouch_fwd",
        crouchBwd = "weldtool_crouch_bwd"
    }

    for name, animation in pairs(movementAnimations) do
        self.tool:setMovementAnimation(name, animation)
    end

    if self.tool:isLocal() then
        self.fpAnimations = createFpAnimations(self.tool, {
            idle = {"weldtool_idle", {
                looping = true
            }},
            use = {"weldtool_use_into", {
                nextAnimation = "idle"
            }},
            use_err = {"weldtool_use_error", {
                nextAnimation = "idle"
            }},
            equip = {"weldtool_pickup", {
                nextAnimation = "idle"
            }},
            unequip = {"weldtool_putdown"}
        })
    end

    setTpAnimation(self.tpAnimations, "idle", 5.0)
    self.blendTime = 0.2
end

function RadioRemote.client_onUpdate(self, dt)
    local isSprinting = self.tool:isSprinting()
    local isCrouching = self.tool:isCrouching()

    local crouchWeight = self.tool:isCrouching() and 1.0 or 0.0
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

            if animation.looping == true then
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
end

function RadioRemote.client_onEquip(self)
    sm.audio.play("Sledgehammer - Equip", self.tool:getPosition())

    self.intendedEquipped = true

    currentRenderablesTp = {}
    currentRenderablesFp = {}

    for k, v in pairs(renderablesTp) do
        currentRenderablesTp[#currentRenderablesTp + 1] = v
    end
    for k, v in pairs(renderablesFp) do
        currentRenderablesFp[#currentRenderablesFp + 1] = v
    end
    for k, v in pairs(renderables) do
        currentRenderablesTp[#currentRenderablesTp + 1] = v
    end
    for k, v in pairs(renderables) do
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

function RadioRemote.client_onUnequip(self)
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

function RadioRemote.client_onToggle(self)
    return false
end

function RadioRemote.client_onEquippedUpdate(self, primaryState, secondaryState, forceBuildActive)
    local _, result = sm.localPlayer.getRaycast(7.5)
    local shape = nil

    local isCustomRadio = false

    if sm.exists(result) and result.type == "body" then
        shape = result:getShape()

        local shape_uuid = shape and shape.uuid
        local is_target_uuid = shape_uuid == sm.uuid.new("d0ad87eb-22ef-41fb-8c39-002e7507d7e3") or shape_uuid ==
                                   sm.uuid.new("f6b6faf5-2554-49cd-aa49-23af1a6cb2a3")

        if is_target_uuid then
            if self.ConnectionCustomRadio == nil then
                local keyBindingText = sm.gui.getKeyBinding("Create", true)
                sm.gui.setInteractionText("", keyBindingText, "#{CONTROLLER_UPGRADE_Connections}")
            else
                local keyBindingText = sm.gui.getKeyBinding("Create", true)
                sm.gui.setInteractionText("", keyBindingText, "#{INTERACTION_REFINE}")
            end

            isCustomRadio = true
        else
            isCustomRadio = false

            local keyBindingText = sm.gui.getKeyBinding("Create", true)
            sm.gui.setInteractionText("", keyBindingText, "#{INFO_BUSY}")
        end
    end

    if primaryState == sm.tool.interactState.start and not forceBuildActive then
        if isCustomRadio then
            setFpAnimation(self.fpAnimations, "use", 0.5)

            if self.ConnectionCustomRadio == nil then
                if shape ~= nil then
                    self.ConnectionCustomRadio = shape

                    sm.audio.play("ConnectTool - Selected")
                end
            else
                self.ConnectionCustomRadio = nil

                sm.audio.play("ConnectTool - Released")
            end
        else
            if not sm.exists(self.ConnectionCustomRadio) then
                self.ConnectionCustomRadio = nil
            end

            if self.ConnectionCustomRadio ~= nil then
                setFpAnimation(self.fpAnimations, "use", 0.5)

                sm.event.sendToInteractable(self.ConnectionCustomRadio.interactable, "remote_control", "")
                sm.audio.play("ConnectTool - Rotate")
            else
                setFpAnimation(self.fpAnimations, "use_err", 0.5)

                sm.audio.play("WeldTool - Error")
            end
        end

    end

    return true, true
end