dofile( "$SURVIVAL_DATA/Scripts/game/survival_items.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )

dofile( "$CONTENT_DATA/Scripts/game/Utilities.lua" )
dofile( "$CONTENT_DATA/Scripts/game/managers/AnimManager.lua" )
dofile( "$CONTENT_DATA/Scripts/game/managers/GuiManager.lua" )
dofile( "$CONTENT_DATA/Scripts/game/managers/SpinManager.lua" )

Upgrader = class()

GIVE_CONTAINER_INDEX = 0
WANT_CONTAINER_INDEX = 1

local function ensureContainers( self )
    if not self.interactable:getContainer( GIVE_CONTAINER_INDEX ) then
        self.interactable:addContainer( GIVE_CONTAINER_INDEX, 1, 999 )
    end
    if not self.interactable:getContainer( WANT_CONTAINER_INDEX ) then
        self.interactable:addContainer( WANT_CONTAINER_INDEX, 1, 999 )
    end
end

function Upgrader.server_onCreate( self )
    reloadAllData()
    ensureContainers( self )
    SpinManager.sv_onCreate( self )
end

function Upgrader.server_onRefresh( self )
    ensureContainers( self )
    SpinManager.sv_onRefresh( self )
end

function Upgrader.server_onReloadCommand( self, player )
    reloadAllData()
    print( "(Upgrader) Data reloaded: " .. tostring( player and player:getId() ) )
end

function Upgrader.server_onFixedUpdate( self )
    SpinManager.sv_onFixedUpdate( self )
end

function Upgrader.server_onSpinRequest( self, params, player )
    SpinManager.sv_onSpinRequest( self, params, player )
end

function Upgrader.client_onCreate( self )
    self.cl = {
        spinning = false,
        spinSuccess = false,
        spinTime = 0,
        spinResult = nil,

        lastGiveItem = nil,
        lastGiveQuantity = 0,
        lastWantItem = nil,
        lastWantQuantity = 0,
    }

    loadItemValues()
    AnimManager.cl_onCreate( self )
end

function Upgrader.client_onDestroy( self )
    AnimManager.cl_onDestroy( self )
    GuiManager.cl_onClose( self )
end

function Upgrader.client_onClientDataUpdate( self, data )
    SpinManager.cl_onClientDataUpdate( self, data )
end

function Upgrader.client_onUpdate( self, deltaTime )
    SpinManager.cl_onUpdate( self, deltaTime )
    AnimManager.cl_onUpdate( self, deltaTime )
    GuiManager.cl_onUpdate( self, deltaTime )
end

function Upgrader.client_onInteract( self, character, state )
    if not state then
        return
    end

    GuiManager.cl_onInteract( self, character, state )
end

function Upgrader.cl_onUpgradeClick( self, _ )
    GuiManager.cl_onUpgradeClick( self, _ )
end

function Upgrader.cl_onClose( self )
    GuiManager.cl_onClose( self )
end

function Upgrader.cl_onItemEndDrag( self )
    GuiManager.cl_onItemEndDrag( self )
end

function Upgrader.client_onSpinStarted( self, params )
    SpinManager.cl_onSpinStarted( self, params )
end

function Upgrader.client_onSpinResult( self, params )
    SpinManager.cl_onSpinResult( self, params )
end

function Upgrader.client_onSpinRejected( self, params )
    SpinManager.cl_onSpinRejected( self, params )
end