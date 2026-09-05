SpinManager = class()

local SPIN_TICKS = 400
local ARROW_BOTTOM_FRAME = 50
local SPIN_EXTRA_TURNS = 24

local function setContainersLocked( giveContainer, wantContainer, locked )
    local allow = not locked
    giveContainer:setAllowSpend( allow )
    giveContainer:setAllowCollect( allow )
    wantContainer:setAllowSpend( allow )
    wantContainer:setAllowCollect( allow )
end

local function pickTargetArrowFrame( success, chance )
    chance = math.max( 0, math.min( 100, chance or 0 ) )
    local halfZone = chance / 2

    local pos
    if success then
        pos = ARROW_BOTTOM_FRAME - halfZone + math.random() * chance
    else
        local lossSpan = 100 - chance
        local pick = halfZone + math.random() * lossSpan
        if math.random() < 0.5 then
            pick = -pick
        end
        pos = ARROW_BOTTOM_FRAME + pick
    end

    return pos % 100
end

function SpinManager.sv_syncState( self )
    local state = {
        spinning = ( self.sv.activeSpin ~= nil ),
        ticksLeft = self.sv.activeSpin and self.sv.activeSpin.ticksLeft or 0,
        success = self.sv.activeSpin and self.sv.activeSpin.success or false,
        chance = self.sv.activeSpin and self.sv.activeSpin.chance or 0
    }
    self.network:setClientData( state )
end

function SpinManager.sv_onCreate( self )
    self.sv = {
        activeSpin = nil
    }
    SpinManager.sv_syncState( self )
end

function SpinManager.sv_onRefresh( self )
    self.sv = self.sv or {}
    SpinManager.sv_syncState( self )

    if not self.sv.activeSpin then
        local giveContainer = self.interactable:getContainer( GIVE_CONTAINER_INDEX )
        local wantContainer = self.interactable:getContainer( WANT_CONTAINER_INDEX )
        if giveContainer and wantContainer then
            setContainersLocked( giveContainer, wantContainer, false )
        end
    end
end

function SpinManager.sv_onSpinRequest( self, params, player )
    if self.sv.activeSpin then
        self.network:sendToClient( player, "client_onSpinRejected", { reason = "already_spinning" } )
        return
    end

    local giveContainer = self.interactable:getContainer( GIVE_CONTAINER_INDEX )
    local wantContainer = self.interactable:getContainer( WANT_CONTAINER_INDEX )

    local giveItem = getFirstItem( giveContainer )
    local wantItem = getFirstItem( wantContainer )

    if not giveItem or not giveItem.uuid or not wantItem or not wantItem.uuid then
        self.network:sendToClient( player, "client_onSpinRejected", { reason = "no_items" } )
        return
    end

    if not sm.container.canSpend( giveContainer, giveItem.uuid, giveItem.quantity ) then
        self.network:sendToClient( player, "client_onSpinRejected", { reason = "spend_failed" } )
        return
    end

    local multiplier = 1
    if params and params.multiplier then
        local m = tonumber( params.multiplier )
        if m == 1 or m == 2 or m == 4 or m == 8 then
            multiplier = m
        end
    end

    local giveValue = resolveValue( giveItem.uuid )
    local wantValue = resolveValue( wantItem.uuid )
    local chance = calcChance( giveValue * giveItem.quantity, wantValue * multiplier )

    local roll = math.random() * 100
    local success = roll <= chance

    setContainersLocked( giveContainer, wantContainer, true )

    self.sv.activeSpin = {
        ticksLeft = SPIN_TICKS,
        success = success,
        chance = chance,
        player = player,
        giveUuid = giveItem.uuid,
        giveQuantity = giveItem.quantity,
        wantUuid = wantItem.uuid,
        multiplier = multiplier
    }

    SpinManager.sv_syncState( self )
    self.network:sendToClient( player, "client_onSpinStarted", { success = success, chance = chance } )
end

function SpinManager.sv_onFixedUpdate( self )
    if self.sv and self.sv.activeSpin then
        local spin = self.sv.activeSpin
        spin.ticksLeft = spin.ticksLeft - 1

        if spin.ticksLeft <= 0 then
            local giveContainer = self.interactable:getContainer( GIVE_CONTAINER_INDEX )
            local wantContainer = self.interactable:getContainer( WANT_CONTAINER_INDEX )

            setContainersLocked( giveContainer, wantContainer, false )

            sm.container.beginTransaction()
            sm.container.spend( giveContainer, spin.giveUuid, spin.giveQuantity, true )
            if not sm.container.endTransaction() then
                print( "(Upgrader) Failed to spend the given item at spin resolution" )
            end

            if spin.success then
                local amount = spin.multiplier or 1
                sm.container.beginTransaction()
                sm.container.collect( giveContainer, spin.wantUuid, amount, true )
                sm.container.endTransaction()
            end

            if sm.exists( spin.player ) then
                self.network:sendToClient( spin.player, "client_onSpinResult", {
                    success = spin.success,
                    chance = spin.chance,
                } )
            end

            self.sv.activeSpin = nil
            SpinManager.sv_syncState( self )
        end
    end
end

function SpinManager.cl_startSpin( self, params )
    self.cl.spinning = true
    self.cl.spinTime = 0
    self.cl.spinResult = nil
    self.cl.spinSuccess = ( params and params.success == true )
    self.cl.targetArrowFrame = pickTargetArrowFrame( self.cl.spinSuccess, params and params.chance )
    self.cl.spinDuration = SPIN_TICKS / 40
    self.cl.finishTriggered = false
    GuiManager.cl_onSpinStarted( self )
end

function SpinManager.cl_finishSpin( self, result )
    self.cl.spinning = false
    self.cl.lastGiveItem = "force_update"
    GuiManager.cl_onSpinFinished( self, result )
end

function SpinManager.cl_onUpdate( self, deltaTime )
    if self.cl.spinning then
        self.cl.spinTime = self.cl.spinTime + deltaTime

        local totalDuration = SPIN_TICKS / 40
        local progress = math.min( self.cl.spinTime / totalDuration, 1.0 )
        local easedProgress = 1 - math.pow( 1 - progress, 3 )

        local totalDistance = ( SPIN_EXTRA_TURNS * 100 ) + ( self.cl.targetArrowFrame or 0 )
        local currentPos = easedProgress * totalDistance

        GuiManager.cl_updateArrowFrame( self, currentPos % 100 )
    end
end

function SpinManager.cl_onClientDataUpdate( self, data )
    if data then
        if data.spinning then
            if not self.cl.spinning then
                SpinManager.cl_startSpin( self, { success = data.success, chance = data.chance } )
            end
            self.cl.spinDuration = SPIN_TICKS / 40
            self.cl.spinTime = ( SPIN_TICKS - data.ticksLeft ) / 40
            self.cl.spinSuccess = data.success
        else
            self.cl.spinning = false
        end
    end
end

function SpinManager.cl_onSpinStarted( self, params )
    SpinManager.cl_startSpin( self, params )
end

function SpinManager.cl_onSpinResult( self, params )
    self.cl.spinResult = params
    SpinManager.cl_finishSpin( self, params )
end

function SpinManager.cl_onSpinRejected( self, params )
    self.cl.spinning = false
    GuiManager.cl_onSpinRejected( self, params )
end