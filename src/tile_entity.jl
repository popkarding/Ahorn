# Not the most efficient, but renders correctly
# exitBlock for some reason is named differently than its 4 other siblings
function drawTileEntity(ctx::Cairo.CairoContext, room::Maple.Room, entity::Maple.Entity; alpha::Number=getGlobalAlpha())
    x = Int(get(entity.data, "x", 0))
    y = Int(get(entity.data, "y", 0))

    blendIn = get(entity.data, "blendin", false)

    width = Int(get(entity.data, "width", 32))
    height = Int(get(entity.data, "height", 32))

    tx, ty = floor(Int, x / 8) + 1, floor(Int, y / 8) + 1
    tw, th = floor(Int, width / 8), floor(Int, height / 8)

    ftw, fth = ceil.(Int, room.size ./ 8)

    key = entity.name == "exitBlock"? "tileType" : "tiletype"
    tile = get(entity.data, key, "3")
    tile = isa(tile, Number)? string(tile) : tile
    
    # Don't draw air versions, even though they shouldn't exist
    if tile[1] in Maple.tile_entity_legal_tiles
        fakeTiles = fill('0', (th + 2, tw + 2))

        if blendIn
            fakeTiles[1:end, 1:end] = get(room.fgTiles.data, (ty - 1:ty + th, tx - 1:tx + tw), '0')
        end

        fakeTiles[2:end - 1, 2:end - 1] = tile[1]

        drawFakeTiles(ctx, room, fakeTiles, true, x, y, alpha=alpha, clipEdges=true)
    end
end

function drawFakeTiles(ctx::Cairo.CairoContext, room::Maple.Room, tiles::Array{Char, 2}, fg::Bool, x::Number, y::Number; alpha::Number=getGlobalAlpha(), clipEdges::Bool=false)
    fakeDr = DrawableRoom(
        loadedState.map,
        Maple.Room(
            name="$(room.name)-$x-$y",
            fgTiles=Maple.Tiles(fg? tiles : Matrix{Char}(0, 0)),
            bgTiles=Maple.Tiles(!fg? tiles : Matrix{Char}(0, 0))
        ),

        TileStates(),
        TileStates(),

        nothing,
        Layer[],

        colors.background_room_fill
    )

    Cairo.save(ctx)

    if clipEdges
        height, width = (size(tiles) .- 2) .* 8
        rectangle(ctx, x, y, width, height)
        clip(ctx)

        # Offset the drawing since we trimmed away the border
        x -= 8
        y -= 8
    end

    translate(ctx, x, y)
    drawTiles(ctx, fakeDr, fg, alpha=alpha)

    Cairo.restore(ctx)
end

function tileEntityFinalizer(entity::Maple.Entity)
    key = entity.name == "exitBlock"? "tileType" : "tiletype"
    defaultTile = string(Main.Maple.tile_fg_names["Snow"])
    tile = string(get(Main.persistence, "brushes_material_fgTiles", defaultTile))
    tile = tile == "0"? defaultTile : tile
    entity.data[key] = tile
end