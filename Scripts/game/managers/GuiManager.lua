GuiManager = class()

local GUI_JSON = dofile( "$CONTENT_DATA/Gui/JsonGui/Upgrader.gui" )
ReplaceSubLayouts( GUI_JSON )

local Circle = {
    Percent = FindWidget( GUI_JSON, "Percent" ),
    Arrow = FindWidget( GUI_JSON, "Arrow" ),
    Text = FindWidget( GUI_JSON, "PercentText" ),
    Result = FindWidget( GUI_JSON, "ResultText" )
}

local Container = {
    Item = FindWidget( GUI_JSON, "Item" ),
    GiveItem = FindWidget( GUI_JSON, "GiveItem" )
}

local Buttons = {
    Two = FindWidget( GUI_JSON, "TwoButton" ),
    Four = FindWidget( GUI_JSON, "FourButton" ),
    Eight = FindWidget( GUI_JSON, "EightButton" )
}

local function titleCase( str )
    return str:gsub("(%S+)", function(word)
        return word:sub(1, 1):upper() .. word:sub(2):lower()
    end)
end

local function clampPercentFrame( value )
    local frame = math.floor( ( value or 0 ) + 0.5 )
    return math.max( 0, math.min( 100, frame ) )
end

local function spritePath( prefix, frame )
    local dir = titleCase( prefix )
    return getContentPath() .. "/Gui/" .. dir .. "/" .. prefix .. "_" .. string.format( "%03d", clampPercentFrame( frame ) ) .. ".png"
end

local function setContainerWidgetsEnabled( self, enabled )
    if Container.Item then
        Container.Item.Enabled = enabled
    end
    if Container.GiveItem then
        Container.GiveItem.Enabled = enabled
    end

    if self.cl.jsonGui then
        self.cl.jsonGui:render( GUI_JSON )
    end
end

local function updateButtonStates( self )
    local mult = self.cl.multiplier or 1

    if Buttons.Two then
        Buttons.Two.StateSelected = ( mult == 2 )
    end

    if Buttons.Four then
        Buttons.Four.StateSelected = ( mult == 4 )
    end

    if Buttons.Eight then
        Buttons.Eight.StateSelected = ( mult == 8 )
    end

    GuiManager.cl_recalcRisk( self )
end

function GuiManager.cl_updateArrowFrame( self, frame )
    if Circle.Arrow then
        Circle.Arrow.ImageTexture = spritePath( "arrow", frame )
    end

    if self.cl.jsonGui then
        self.cl.jsonGui:render( GUI_JSON )
    end
end

function GuiManager.cl_updateRiskCircle( self, percent )
    local frame = clampPercentFrame( percent )

    if Circle.Text then
        Circle.Text.Caption = string.format( "%.2f%%", percent )
    end

    if Circle.Percent then
        Circle.Percent.ImageTexture = spritePath( "circle", frame )
    end

    if self.cl.jsonGui then
        self.cl.jsonGui:render( GUI_JSON )
    end
end

function GuiManager.cl_recalcRisk( self )
    local giveContainer = self.interactable:getContainer( GIVE_CONTAINER_INDEX )
    local wantContainer = self.interactable:getContainer( WANT_CONTAINER_INDEX )

    local giveItem = getFirstItem( giveContainer )
    local wantItem = getFirstItem( wantContainer )

    if not giveItem or not giveItem.uuid or not wantItem or not wantItem.uuid then
        GuiManager.cl_updateRiskCircle( self, 0 )
        return
    end

    local giveValue = resolveValue( giveItem.uuid )
    local wantValue = resolveValue( wantItem.uuid )
    local multiplier = self.cl.multiplier or 1

    GuiManager.cl_updateRiskCircle( self, calcChance( giveValue * giveItem.quantity, wantValue * multiplier ) )
end

function GuiManager.cl_onUpdate( self, deltaTime )
    local giveContainer = self.interactable:getContainer( GIVE_CONTAINER_INDEX )
    local wantContainer = self.interactable:getContainer( WANT_CONTAINER_INDEX )
    if not ( giveContainer and wantContainer ) then
        return
    end

    local giveItem = getFirstItem( giveContainer )
    local wantItem = getFirstItem( wantContainer )

    local giveUuid = giveItem and giveItem.uuid or nil
    local giveQty = giveItem and giveItem.quantity or 0
    local wantUuid = wantItem and wantItem.uuid or nil
    local wantQty = wantItem and wantItem.quantity or 0

    if giveUuid ~= self.cl.lastGiveItem or giveQty ~= self.cl.lastGiveQuantity or
       wantUuid ~= self.cl.lastWantItem or wantQty ~= self.cl.lastWantQuantity then

        self.cl.lastGiveItem = giveUuid
        self.cl.lastGiveQuantity = giveQty
        self.cl.lastWantItem = wantUuid
        self.cl.lastWantQuantity = wantQty

        if not self.cl.spinning then
            GuiManager.cl_recalcRisk( self )
        end
    end
end

function GuiManager.cl_onInteract( self, char, state )
    local giveContainer = self.interactable:getContainer( GIVE_CONTAINER_INDEX )
    local wantContainer = self.interactable:getContainer( WANT_CONTAINER_INDEX )
    if not giveContainer or not wantContainer then
        print( "(Upgrader) Loaded containers not ready on client!" )
        return
    end

    self.cl.jsonGui = sm.jsonGui.createGui( { isInteractive = true, needsCursor = true } )

    local playerInventoryId = sm.localPlayer.getPlayer():getInventory().id
    local giveContainerId = giveContainer.id
    local wantContainerId = wantContainer.id

    if Container.Item then
        Container.Item.ContainerData.ContainerId = giveContainerId
        Container.Item.ContainerData.DropContainerIds = { playerInventoryId }
    end

    if Container.GiveItem then
        Container.GiveItem.ContainerData.ContainerId = wantContainerId
        Container.GiveItem.ContainerData.DropContainerIds = { playerInventoryId }
    end

    if GUI_JSON.Hotbar then
        GUI_JSON.Hotbar.DropContainerIds = { giveContainerId, wantContainerId }
    end

    if self.cl.multiplier == nil then
        self.cl.multiplier = 1
    end

    setContainerWidgetsEnabled( self, not self.cl.spinning )
    updateButtonStates( self )
end

function GuiManager.cl_onClose( self )
    if self.cl.jsonGui then
        self.cl.jsonGui:close()
        self.cl.jsonGui = nil
    end
end

function GuiManager.cl_onUpgradeClick( self, _ )
    if self.cl.spinning then
        return
    end

    local giveContainer = self.interactable:getContainer( GIVE_CONTAINER_INDEX )
    local wantContainer = self.interactable:getContainer( WANT_CONTAINER_INDEX )
    if not ( giveContainer and wantContainer ) then
        return
    end

    local giveItem = getFirstItem( giveContainer )
    local wantItem = getFirstItem( wantContainer )
    if not giveItem or not wantItem then
        return
    end

    self.network:sendToServer( "server_onSpinRequest", { multiplier = self.cl.multiplier or 1 } )
end

function GuiManager.cl_onTwoClick( self, _ )
    if self.cl.spinning then
        return
    end

    self.cl.multiplier = ( self.cl.multiplier == 2 ) and 1 or 2
    updateButtonStates( self )
end

function GuiManager.cl_onFourClick( self, _ )
    if self.cl.spinning then
        return
    end
    
    self.cl.multiplier = ( self.cl.multiplier == 4 ) and 1 or 4
    updateButtonStates( self )
end

function GuiManager.cl_onEightClick( self, _ )
    if self.cl.spinning then
        return
    end
    
    self.cl.multiplier = ( self.cl.multiplier == 8 ) and 1 or 8
    updateButtonStates( self )
end

function GuiManager.cl_onItemEndDrag( self )
    if not self.cl.spinning then
        GuiManager.cl_recalcRisk( self )
    end
end

function GuiManager.cl_onSpinStarted( self )
    setContainerWidgetsEnabled( self, false )

    if Circle.Result then
        Circle.Result.Caption = "Chance"
        Circle.Result.TextColour = "1 1 1 1"
    end
end

function GuiManager.cl_onSpinFinished( self, result )
    setContainerWidgetsEnabled( self, true )
    GuiManager.cl_updateRiskCircle( self, result.chance )

    if Circle.Result then
        Circle.Result.Caption = result.success and "WIN!" or "LOSE"
        Circle.Result.TextColour = result.success and "0.2 1 0.2 1" or "1 0.2 0.2 1"
    end

    if self.cl.jsonGui then
        self.cl.jsonGui:render( GUI_JSON )
    end
end

function GuiManager.cl_onSpinRejected( self, params )
    if self.cl.jsonGui then
        self.cl.jsonGui:render( GUI_JSON )
    end
end