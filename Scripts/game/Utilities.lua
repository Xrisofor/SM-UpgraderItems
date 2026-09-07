function getModUUID()
    return sm.json.open( "$CONTENT_DATA/description.json" ).localId
end

function getContentPath()
    return "$CONTENT_" .. getModUUID()
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