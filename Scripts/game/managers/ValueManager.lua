ValueManager = class()

local MATERIAL_MULTIPLIERS = {
    Metal       = 5.0,
    Mechanical  = 8.0,
    Electronics = 15.0,
    Glass       = 3.0,
    Rock        = 4.0,
    Wood        = 2.0,
    Plastic     = 1.5,
    Fence       = 2.0,
    Cardboard   = 0.5,
    Rubber      = 3.0,
    Default     = 1.0,
}
local DEFAULT_MATERIAL_MULTIPLIER = 2.0

ValueManager.settings = {
    chanceMultiplier = 0.9,
    minChance = 0.1,
    maxChance = 90,
}

local valueCache = {}

local function safeCall( fn, uuid, fallback )
    if not fn then
        return fallback
    end
    local ok, result = pcall( fn, uuid )
    if ok and result ~= nil then
        return result
    end
    return fallback
end

local function getItemVolume( uuid )
    local size = safeCall( sm.item.getShapeSize, uuid, nil )
    if not size then
        return 1.0
    end

    local volume = ( size.x or 1 ) * ( size.y or 1 ) * ( size.z or 1 )
    if volume <= 0 then
        return 1.0
    end
    return volume
end

local function getMaterialMultiplier( uuid )
    local material = safeCall( sm.item.getMaterial, uuid, nil )
    if not material then
        return DEFAULT_MATERIAL_MULTIPLIER
    end
    return MATERIAL_MULTIPLIERS[material] or DEFAULT_MATERIAL_MULTIPLIER
end

local function getRatingsModifier( uuid )
    local ratings = {
        safeCall( sm.item.getDurabilityRating, uuid, nil ),
        safeCall( sm.item.getBuoyancyRating, uuid, nil ),
        safeCall( sm.item.getFrictionRating, uuid, nil ),
        safeCall( sm.item.getDensityRating, uuid, nil ),
    }

    local sum, count = 0, 0
    for _, rating in ipairs( ratings ) do
        if type( rating ) == "number" then
            sum = sum + rating
            count = count + 1
        end
    end

    if count == 0 then
        return 1.0
    end

    local avgRating = sum / count
    return 1.0 + ( avgRating / 5.0 )
end

function ValueManager.resolveValue( uuid )
    if not uuid or uuid:isNil() then
        return 1.0
    end

    local key = tostring( uuid )
    local cached = valueCache[key]
    if cached then
        return cached
    end

    local value = getItemVolume( uuid ) * getMaterialMultiplier( uuid ) * getRatingsModifier( uuid )
    valueCache[key] = value

    return value
end

function ValueManager.calcChance( giveValue, wantValue )
    local settings = ValueManager.settings
    if not giveValue or not wantValue or wantValue <= 0 then
        return settings.minChance
    end

    local chance = settings.chanceMultiplier * ( giveValue / wantValue ) * 100
    return math.max( settings.minChance, math.min( settings.maxChance, chance ) )
end

function ValueManager.clearCache()
    valueCache = {}
end