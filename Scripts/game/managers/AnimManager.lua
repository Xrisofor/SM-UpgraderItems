AnimManager = class()

local function isAnyOf( value, list )
    for _, val in ipairs( list ) do
        if value == val then
            return true
        end
    end
    return false
end

local function magicInterpolation( current, target, deltaTime, speed )
    local steps = speed > 0 and ( deltaTime / speed ) or 1.0
    return current + ( target - current ) * math.min( 1.0, steps )
end

local function createPortableEffects( self )
    self.cl.mainEffects = {
        unfold = sm.effect.createEffect( "Babycraftbot - Unpack", self.interactable ),
        idle = sm.effect.createEffect( "Babycraftbot - Idle", self.interactable ),
        idlespecial01 = sm.effect.createEffect( "Babycraftbot - Idle_special01", self.interactable ),
        idlespecial02 = sm.effect.createEffect( "Babycraftbot - Idle_special02", self.interactable ),
        craft_start = sm.effect.createEffect( "Babycraftbot - Start", self.interactable ),
        craft_loop01 = sm.effect.createEffect( "Babycraftbot - Craft_loop", self.interactable, "root_jnt" ),
        craft_loop02 = sm.effect.createEffect( "Babycraftbot - craft_loop_special01", self.interactable, "root_jnt" ),
        craft_loop03 = sm.effect.createEffect( "Babycraftbot - craft_loop_special02", self.interactable, "root_jnt" ),
        craft_finish = sm.effect.createEffect( "Babycraftbot - Craft_finish", self.interactable, "root_jnt" ),
        fold_idle = sm.effect.createEffect( "Babycraftbot - Fold_idle", self.interactable ),
        fold_idlespecial01 = sm.effect.createEffect( "Babycraftbot - Fold_idle_special01", self.interactable ),
    }
    self.cl.secondaryEffects = {
        craft_loop03 = sm.effect.createEffect( "Babycraftbot - Craft_loop_special02_smoketrail", self.interactable, "root_jnt" ),
        craft_finish = sm.effect.createEffect( "Babycraftbot - Craftingdone", self.interactable, "root_jnt" ),
    }
end

function AnimManager.cl_onCreate( self )
    self.cl = {
        animName = nil,
        animTime = 0,
        animDuration = 1,
        upDownControl = 0.5,
        leftRightControl = 0.5,

        currentMainEffect = nil,
        currentSecondaryEffect = nil,
    }

    createPortableEffects( self )
end

function AnimManager.cl_onDestroy( self )
    if not self.cl then
        return
    end

    if self.cl.animName and self.interactable:hasAnim( self.cl.animName ) then
        self.interactable:setAnimEnabled( self.cl.animName, false )
    end

    for _, effect in pairs( self.cl.mainEffects or {} ) do
        effect:stopImmediate()
        effect:destroy()
    end

    for _, effect in pairs( self.cl.secondaryEffects or {} ) do
        effect:stopImmediate()
        effect:destroy()
    end
end

function AnimManager.cl_onUpdate( self, deltaTime )
    local reactToInactive = false
    local playersInRange = GetPlayersInRange( self.shape.worldPosition, 6.0, self.shape.body:getWorld() )
    reactToInactive = ( #playersInRange == 0 )

    self.cl.animTime = self.cl.animTime + deltaTime
    local animDone = false
    if self.cl.animTime > self.cl.animDuration then
        self.cl.animTime = math.fmod( self.cl.animTime, self.cl.animDuration )
        animDone = true
    end

    local isCraftAnim = isAnyOf( self.cl.animName, { "craft_start", "craft_loop01", "craft_loop02", "craft_loop03", "craft_finish" } )

    if self.cl.spinning or ( isCraftAnim and self.cl.animName ~= "craft_finish" ) or ( self.cl.animName == "craft_finish" and not animDone ) then
        self.cl.animState = "craft"
    elseif reactToInactive then
        self.cl.animState = "inactive"
    else
        self.cl.animState = "idle"
    end

    local prevAnimName = self.cl.animName

    if self.cl.animState == "inactive" then
        if not isAnyOf( self.cl.animName, { "fold_in", "fold_idle", "fold_out", "fold_idlespecial01" } ) then
            if self.cl.animName == nil then
                self.cl.animName = "unfold"
                animDone = true
            else
                self.cl.animName = "fold_in"
            end
        else
            if animDone then
                local rand = math.random( 1, 4 )
                if rand == 1 then
                    self.cl.animName = "fold_idlespecial01"
                else
                    self.cl.animName = "fold_idle"
                end
            end
        end

    elseif self.cl.animState == "idle" then
        if self.cl.animName == nil then
            self.cl.animName = "unfold"
            animDone = true
        elseif isAnyOf( self.cl.animName, { "fold_in", "fold_idle", "fold_idlespecial01" } ) then
            self.cl.animName = "fold_out"
            animDone = true
        elseif isAnyOf( self.cl.animName, { "unfold", "craft_finish" } ) then
            if animDone then
                self.cl.animName = "idle"
            end
        elseif self.cl.animName == "idle" then
            if animDone then
                local rand = math.random( 1, 5 )
                if rand == 1 then
                    self.cl.animName = "idlespecial01"
                elseif rand == 2 then
                    self.cl.animName = "idlespecial02"
                else
                    self.cl.animName = "idle"
                end
            end
        elseif self.cl.animName == "idlespecial01" or self.cl.animName == "idlespecial02" then
            if animDone then
                self.cl.animName = "idle"
            end
        else
            if animDone then
                self.cl.animName = "idle"
            end
        end

    elseif self.cl.animState == "craft" then
        if isAnyOf( self.cl.animName, { "idle", "idlespecial01", "idlespecial02", "unfold", "fold_in", "fold_idle", "fold_idlespecial01" } ) or self.cl.animName == nil then
            self.cl.animName = "craft_start"
            animDone = true
        elseif self.cl.animName == "craft_start" then
            if animDone then
                self.cl.animName = "craft_loop01"
            end
        elseif self.cl.animName == "craft_loop01" or self.cl.animName == "craft_loop02" or self.cl.animName == "craft_loop03" then
            if animDone then
                if not self.cl.spinning then
                    self.cl.animName = "craft_finish"
                else
                    local rand = math.random( 1, 4 )
                    if rand == 1 and not self.cl.spinSuccess then
                        self.cl.animName = "craft_loop02"
                    elseif rand == 2 then
                        self.cl.animName = "craft_loop03"
                    else
                        self.cl.animName = "craft_loop01"
                    end
                end
            end
        elseif self.cl.animName == "craft_finish" then
            if animDone then
                if self.cl.spinning then
                    self.cl.animName = "craft_start"
                else
                    self.cl.animName = "idle"
                end
            end
        end
    end

    if self.cl.animName ~= prevAnimName then
        if prevAnimName then
            self.interactable:setAnimEnabled( prevAnimName, false )
            self.interactable:setAnimProgress( prevAnimName, 0 )
        end

        self.cl.animDuration = self.interactable:getAnimDuration( self.cl.animName ) or 1
        self.cl.animTime = 0
        self.interactable:setAnimEnabled( self.cl.animName, true )
    end

    self.interactable:setAnimProgress( self.cl.animName, self.cl.animTime / self.cl.animDuration )

    if animDone or self.cl.animName ~= prevAnimName then
        local mainEffect = self.cl.mainEffects[self.cl.animName]
        local secondaryEffect = self.cl.secondaryEffects[self.cl.animName]

        if mainEffect ~= self.cl.currentMainEffect then
            if self.cl.currentMainEffect then
                self.cl.currentMainEffect:stop()
            end
            self.cl.currentMainEffect = mainEffect
        end

        if secondaryEffect ~= self.cl.currentSecondaryEffect then
            if self.cl.currentSecondaryEffect then
                self.cl.currentSecondaryEffect:stop()
            end
            self.cl.currentSecondaryEffect = secondaryEffect
        end

        if self.cl.currentMainEffect then
            if not self.cl.currentMainEffect:isPlaying() then
                self.cl.currentMainEffect:start()
            else
                self.cl.currentMainEffect:stop()
                self.cl.currentMainEffect:start()
            end
        end

        if self.cl.currentSecondaryEffect then
            if not self.cl.currentSecondaryEffect:isPlaying() then
                self.cl.currentSecondaryEffect:start()
            end
        end
    end

    local lookAtSettings = { lookAtRange = 5.0, headUpOffset = 0.3, headForwardOffset = -2.0, headLerpSpeed = 1.0 / 15.0 }
    if self.interactable:hasAnim( "aimbend_updown" ) and self.interactable:hasAnim( "aimbend_leftright" ) then
        self.interactable:setAnimEnabled( "aimbend_updown", true )
        self.interactable:setAnimEnabled( "aimbend_leftright", true )

        local upDownControl = 0.5
        local leftRightControl = 0.5

        if self.cl.animName == "idle" then
            local closestPlayer = GetClosestPlayer( self.shape.worldPosition, lookAtSettings.lookAtRange, self.shape.body:getWorld() )
            if closestPlayer and closestPlayer.character then
                local stationUp = self.shape:getAt()
                local stationRight = -self.shape:getRight()
                local stationForward = self.shape:getUp()

                local lookAtPosition = closestPlayer.character.worldPosition
                local toPlayerDir = ( lookAtPosition - self.shape.worldPosition ):safeNormalize( stationForward )

                if stationForward:dot( toPlayerDir ) > 0 then
                    local lookFromPosition = self.shape.worldPosition + self.shape:getAt() * lookAtSettings.headUpOffset + self.shape:getUp() * lookAtSettings.headForwardOffset
                    local lookDirection = ( lookAtPosition - lookFromPosition ):safeNormalize( stationForward )

                    local upProjection = lookDirection:dot( stationUp )
                    local rightProjection = lookDirection:dot( stationRight )

                    upDownControl = math.max( 0, math.min( 1, 1.0 - ( ( upProjection + 1 ) / 2 ) ) )
                    leftRightControl = math.max( 0, math.min( 1, ( rightProjection + 1 ) / 2 ) )
                end
            end
        end

        self.cl.upDownControl = magicInterpolation( self.cl.upDownControl, upDownControl, deltaTime, lookAtSettings.headLerpSpeed )
        self.cl.leftRightControl = magicInterpolation( self.cl.leftRightControl, leftRightControl, deltaTime, lookAtSettings.headLerpSpeed )
        self.interactable:setAnimProgress( "aimbend_updown", self.cl.upDownControl )
        self.interactable:setAnimProgress( "aimbend_leftright", self.cl.leftRightControl )
    end
end