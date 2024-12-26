local mod = RegisterMod("Better Start", 1)

mod.state = {
    firstItemUpgraded = false,
}

--- @param game Game
--- @param level Level
local function teleportToTreasureRoom(game, level)
    if game:IsGreedMode() then
        game:ChangeRoom(98) -- Silver Treasure Room grid index

        return
    end

    local treasureRoom
    local rooms = level:GetRooms()
    for i = 0, rooms.Size - 1 do
        local roomDescriptor = rooms:Get(i)
        if roomDescriptor.Data.Type == RoomType.ROOM_TREASURE then
            treasureRoom = roomDescriptor
        end
    end

    assert(treasureRoom ~= nil, "Treasure room not found!")
    game:ChangeRoom(treasureRoom.GridIndex)
end

--- @param quality integer
--- @param itemPoolType ItemPoolType
--- @param rng RNG
---
--- @return CollectibleType
local function rollQualityItem(quality, itemPoolType, rng)
    quality = quality or 3
    itemPoolType = itemPoolType or ItemPoolType.POOL_TREASURE
    rng = rng or RNG()

    local game = Game()
    local itemPool = game:GetItemPool()
    local itemConfig = Isaac:GetItemConfig()

    local rolledQuality = -1
    local rolledItem = CollectibleType.COLLECTIBLE_NULL
    local seed = rng:GetSeed()

    while rolledQuality < 3 do
        rolledItem = itemPool:GetCollectible(itemPoolType, false, seed)
        rolledQuality = itemConfig:GetCollectible(rolledItem).Quality
        seed = rng:Next()
    end

    return rolledItem
end

--- @param game Game
local function teleportIsaacToDoor(game)
    local player = game:GetPlayer(0)
    local room = game:GetRoom()

    if game:IsGreedMode() then
        local door = room:GetDoor(0)
        player.Position = room:FindFreeTilePosition(door.Position, 0)

        return
    end

    local door
    for _, value in pairs(DoorSlot) do
        door = room:GetDoor(value)
        if door ~= nil then
            break
        end
    end

    assert(door ~= nil, "Door in treasure room not found!")
    player.Position = room:FindFreeTilePosition(door.Position, 0)
end

--- @param isContinued boolean
function mod:PostGameStarted(isContinued)
    if isContinued then
        mod.state.firstItemUpgraded = true

        return
    else
        mod.state.firstItemUpgraded = false
    end

    local game = Game()
    local level = game:GetLevel()

    level:RemoveCurses(LevelCurse.CURSE_OF_BLIND)
    teleportToTreasureRoom(game, level)
    teleportIsaacToDoor(game)
end

--- @param itemPoolType ItemPoolType
--- @param decrease boolean
--- @param seed integer
function mod:PreGetCollectible(itemPoolType, decrease, seed)
    if mod.state.firstItemUpgraded then
        return
    end

    mod.state.firstItemUpgraded = true

    return rollQualityItem(3, itemPoolType, RNG(seed))
end

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.PostGameStarted)
mod:AddCallback(ModCallbacks.MC_PRE_GET_COLLECTIBLE, mod.PreGetCollectible)
