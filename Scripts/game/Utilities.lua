dofile( "$CONTENT_40639a2c-bb9f-4d4f-b88c-41bfe264ffa8/Scripts/ModDatabase.lua" )

function getModUUID()
    return sm.json.open( "$CONTENT_DATA/description.json" ).localId
end

function getContentPath()
    return "$CONTENT_" .. getModUUID()
end

-- The code is taken from Modded Craftbot Recipes
local function getAllLoadedMods()
    ModDatabase.unloadDescriptions()
    ModDatabase.unloadShapesets()
    ModDatabase.unloadToolsets()

    ModDatabase.loadDescriptions()
    ModDatabase.loadShapesets()
    ModDatabase.loadToolsets()

    local loadedMods = {}
    local descs = ModDatabase.databases.descriptions

    for localId, _ in pairs( ModDatabase.databases.shapesets ) do
        if ModDatabase.isModLoaded( localId ) then
            loadedMods[localId] = descs[localId].fileId
        end
    end

    -- Tool-only mods
    for localId, _ in pairs( ModDatabase.databases.toolsets ) do
        if loadedMods[localId] == nil and ModDatabase.isModLoaded( localId ) then
            loadedMods[localId] = descs[localId].fileId
        end
    end

    -- Exclude custom games
    for localId, _ in pairs( loadedMods ) do
        if descs[localId].type == "Custom Game" then
            loadedMods[localId] = nil
        end
    end

    return loadedMods
end

local function sortMods( tbl )
    local keys = {}
    for k, _ in pairs( tbl ) do
        table.insert( keys, k )
    end
    table.sort( keys, function( a, b ) return tbl[a] < tbl[b] end )
    return keys
end

local function tryLoadJson( path )
    local ok, data = pcall( sm.json.open, path )
    if ok then
        return data
    end
    return nil
end

loadedItemValues = loadedItemValues or {}
settings = {
    chanceMultiplier = 0.9,
    minChance = 0.1,
    maxChance = 90,
}

local _sm_shape_uuidExists = sm.shape.uuidExists
local _sm_tool_uuidExists  = sm.tool.uuidExists
local function isUuidValid( uuid )
    return _sm_shape_uuidExists( uuid ) or _sm_tool_uuidExists( uuid )
end

function getBaseItemValue( uuid )
    for _, item in ipairs( loadedItemValues ) do
        if item.uuid == uuid then
            return item.value
        end
    end
    return nil
end

local function loadValueFile( path )
    local data = tryLoadJson( path )
    if not data then
        print( "(Upgrader) Failed to load value file: " .. tostring( path ) )
        return
    end

    for _, entry in ipairs( data ) do
        if type( entry ) == "table" and entry.itemId ~= nil and type( entry.value ) == "number" then
            local ok, uuid = pcall( sm.uuid.new, entry.itemId )
            if ok and isUuidValid( uuid ) then
                if not getBaseItemValue( uuid ) then
                    table.insert( loadedItemValues, { uuid = uuid, value = entry.value } )
                end
            else
                print( "(Upgrader) Invalid itemId '" .. tostring( entry.itemId ) .. "' in " .. path )
            end
        else
            print( "(Upgrader) Malformed value entry in " .. path )
        end
    end
end

local function loadValueIndex( indexPath )
    local index = tryLoadJson( indexPath )
    if not index then
        print( "(Upgrader) Failed to load value index: " .. tostring( indexPath ) )
        return
    end

    for setName, path in pairs( index ) do
        loadValueFile( path )
    end
end

function loadItemValues()
    loadedItemValues = {}

    local ownContentPath = getContentPath()
    local indexPaths = { ownContentPath .. "/CraftingRecipes/upgrader/upgrader.json" }

    local loadedMods = sortMods( getAllLoadedMods() )
    for _, localId in ipairs( loadedMods ) do
        local modContentPath = "$CONTENT_" .. localId
        if modContentPath ~= ownContentPath then
            table.insert( indexPaths, modContentPath .. "/CraftingRecipes/upgrader/upgrader.json" )
        end
    end

    for _, indexPath in ipairs( indexPaths ) do
        loadValueIndex( indexPath )
    end

    print( "(Upgrader) Loaded " .. #loadedItemValues .. " item values (own mod + " .. #loadedMods .. " loaded mod(s) checked)" )
end

function getFirstItem( container )
    if not container then return nil end
    for i = 0, container:getSize() - 1 do
        local item = container:getItem( i )
        if item and item.uuid and not item.uuid:isNil() and item.quantity > 0 then
            return item
        end
    end
    return nil
end

function resolveValue( uuid )
    return getBaseItemValue( uuid ) or 1
end

function calcChance( giveValue, wantValue )
    if not giveValue or not wantValue or wantValue <= 0 then
        return settings.minChance
    end
    local chance = settings.chanceMultiplier * ( giveValue / wantValue ) * 100
    return math.max( settings.minChance, math.min( settings.maxChance, chance ) )
end

function reloadAllData()
    loadItemValues()
end