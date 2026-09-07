dofile( "$CONTENT_40639a2c-bb9f-4d4f-b88c-41bfe264ffa8/Scripts/ModDatabase.lua" )

RecipeManager = class()

local BENCH_FILES = {
    "craftbot",
    "hideout",
    "workbench",
    "dispenser",
    "refinery",
    "cookbot",
    "dressbot",
}

local recipes = nil

local function isUuidValid( uuid )
    return sm.shape.uuidExists( uuid ) or sm.tool.uuidExists( uuid )
end

local function tryOpenJson( path )
    local ok, data = pcall( sm.json.open, path )
    if ok then
        return data
    end
    return nil
end

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
            loadedMods[localId] = true
        end
    end

    for localId, _ in pairs( ModDatabase.databases.toolsets ) do
        if loadedMods[localId] == nil and ModDatabase.isModLoaded( localId ) then
            loadedMods[localId] = true
        end
    end

    for localId, _ in pairs( loadedMods ) do
        if descs[localId] and descs[localId].type == "Custom Game" then
            loadedMods[localId] = nil
        end
    end

    return loadedMods
end

local function collectRecipeRoots()
    local roots = { "$SURVIVAL_DATA/CraftingRecipes" }

    local ok, loadedMods = pcall( getAllLoadedMods )
    if ok and loadedMods then
        for localId, _ in pairs( loadedMods ) do
            table.insert( roots, "$CONTENT_" .. localId .. "/CraftingRecipes" )
        end
    end

    return roots
end

local function parseRecipeList( list, target )
    local count = 0

    for _, recipe in ipairs( list ) do
        if type( recipe ) == "table" and recipe.itemId then
            local ok, outUuid = pcall( sm.uuid.new, recipe.itemId )

            if ok and isUuidValid( outUuid ) then
                local ingredients = {}

                for _, ing in ipairs( recipe.ingredientList or {} ) do
                    if type( ing ) == "table" and ing.itemId then
                        local ok2, ingUuid = pcall( sm.uuid.new, ing.itemId )
                        if ok2 and isUuidValid( ingUuid ) then
                            table.insert( ingredients, { uuid = ingUuid, quantity = ing.quantity or 1 } )
                        end
                    end
                end

                if #ingredients > 0 then
                    target[tostring( outUuid )] = {
                        quantity = recipe.quantity or 1,
                        ingredients = ingredients,
                    }
                    count = count + 1
                end
            end
        end
    end

    return count
end

function RecipeManager.load()
    recipes = {}

    local roots = collectRecipeRoots()
    local totalRecipes, totalFiles = 0, 0

    for _, root in ipairs( roots ) do
        for _, bench in ipairs( BENCH_FILES ) do
            local data = tryOpenJson( root .. "/" .. bench .. ".json" )
            if type( data ) == "table" then
                totalRecipes = totalRecipes + parseRecipeList( data, recipes )
                totalFiles = totalFiles + 1
            end
        end
    end

    print( "(Upgrader) Loaded " .. totalRecipes .. " crafting recipe(s) from " .. totalFiles .. " file(s) across " .. #roots .. " mod root(s)" )
end

function RecipeManager.getRecipe( uuid )
    if not recipes then
        RecipeManager.load()
    end

    if not uuid or uuid:isNil() then
        return nil
    end

    return recipes[tostring( uuid )]
end