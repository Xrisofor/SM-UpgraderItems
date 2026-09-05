SpinManager = class()

local SPIN_TICKS = 400
local SPIN_SPEED = 250

local function setSpinContainersLocked( giveContainer, wantContainer, locked )
    local allow = not locked
    giveContainer:setAllowSpend( allow )
    giveContainer:setAllowCollect( allow )
    wantContainer:setAllowSpend( allow )
    wantContainer:setAllowCollect( allow )
end

function SpinManager.sv_syncState( self )
    local state = {
        spinning = ( self.sv.activeSpin ~= nil ),
        ticksLeft = self.sv.activeSpin and self.sv.activeSpin.ticksLeft or 0,
        success = self.sv.activeSpin and self.sv.activeSpin.success or false
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
            setSpinContainersLocked( giveContainer, wantContainer, false )
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

    local giveValue = resolveValue( giveItem.uuid )
    local wantValue = resolveValue( wantItem.uuid )
    local chance = calcChance( giveValue * giveItem.quantity, wantValue )

    local roll = math.random() * 100
    local success = roll <= chance

    setSpinContainersLocked( giveContainer, wantContainer, true )

    self.sv.activeSpin = {
        ticksLeft = SPIN_TICKS,
        success = success,
        chance = chance,
        player = player,
        giveUuid = giveItem.uuid,
        giveQuantity = giveItem.quantity,
        wantUuid = wantItem.uuid
    }

    SpinManager.sv_syncState( self )
    self.network:sendToClient( player, "client_onSpinStarted", { success = success } )
end

function SpinManager.sv_onFixedUpdate( self )
    if self.sv and self.sv.activeSpin then
        local spin = self.sv.activeSpin
        spin.ticksLeft = spin.ticksLeft - 1

        if spin.ticksLeft <= 0 then
            local giveContainer = self.interactable:getContainer( GIVE_CONTAINER_INDEX )
            local wantContainer = self.interactable:getContainer( WANT_CONTAINER_INDEX )

            setSpinContainersLocked( giveContainer, wantContainer, false )

            sm.container.beginTransaction()
            sm.container.spend( giveContainer, spin.giveUuid, spin.giveQuantity, true )
            if not sm.container.endTransaction() then
                print( "(Upgrader) Failed to spend the given item at spin resolution" )
            end

            if spin.success then
                sm.container.beginTransaction()
                sm.container.collect( giveContainer, spin.wantUuid, 1, true )
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
        local frame = math.floor( self.cl.spinTime * SPIN_SPEED ) % 101
        GuiManager.cl_updateArrowFrame( self, frame )
    end
end

function SpinManager.cl_onClientDataUpdate( self, data )
    if data then
        if data.spinning then
            if not self.cl.spinning then
                SpinManager.cl_startSpin( self, { success = data.success } )
            end
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