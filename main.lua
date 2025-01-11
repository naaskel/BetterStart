local MOD_NAME = "Better Start"

local mod = RegisterMod(MOD_NAME, 1)
local json = require("json")

mod.data = {
    settings = {
        upgradeFirstItem = true,
        teleportToTreasureRoom = true,
        removeCurseOfBlind = true,
    },
    state = {
        firstItemUpgraded = false,
        modConfigInited = false,
    }
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

local function loadSettings()
    if not mod:HasData() then
        return
    end

    mod.data.settings = json.decode(mod:LoadData())
end

local function saveSettings()
    mod:SaveData(json.encode(mod.data.settings))
end

local function modConfigMenuInit()
    ModConfigMenu.AddSpace(MOD_NAME, "Settings")
    ModConfigMenu.AddSetting(MOD_NAME, "Settings", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
            return mod.data.settings.upgradeFirstItem
        end,
        Display = function()
            return "Upgrade first item: " .. (mod.data.settings.upgradeFirstItem and "on" or "off")
        end,
        OnChange = function(value)
            mod.data.settings.upgradeFirstItem = value
        end,
        Info = {
            "Should the first item you encounter",
            "in the item room be upgraded?",
        }
    })
    ModConfigMenu.AddSetting(MOD_NAME, "Settings", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
            return mod.data.settings.teleportToTreasureRoom
        end,
        Display = function()
            return "Teleport to treasure room: " .. (mod.data.settings.teleportToTreasureRoom and "on" or "off")
        end,
        OnChange = function(value)
            mod.data.settings.teleportToTreasureRoom = value
        end,
        Info = {
            "Should Isaac be teleported to the",
            "treasure room at the beginning of the run?",
        }
    })
    ModConfigMenu.AddSetting(MOD_NAME, "Settings", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
            return mod.data.settings.removeCurseOfBlind
        end,
        Display = function()
            return "Remove Curse of the Blind: " .. (mod.data.settings.removeCurseOfBlind and "on" or "off")
        end,
        OnChange = function(value)
            mod.data.settings.removeCurseOfBlind = value
        end,
        Info = {
            "Should Curse of the Blind be",
            "removed on the first floor?",
        }
    })
    ModConfigMenu.AddSpace(MOD_NAME, "About")
    ModConfigMenu.AddText(MOD_NAME, "About", function()
        return MOD_NAME .. " by naaskel"
    end)

    mod.data.state.modConfigInited = true
end

--- @param isContinued boolean
function mod:PostGameStarted(isContinued)
    if ModConfigMenu and mod.data.state.modConfigInited == false then
        loadSettings()
        modConfigMenuInit()

        mod.data.state.modConfigInited = true
    end

    if isContinued then
        mod.data.state.firstItemUpgraded = true

        return
    else
        mod.data.state.firstItemUpgraded = false
    end

    local game = Game()
    local level = game:GetLevel()

    if mod.data.settings.removeCurseOfBlind then
        level:RemoveCurses(LevelCurse.CURSE_OF_BLIND)
    end

    if mod.data.settings.teleportToTreasureRoom then
        teleportToTreasureRoom(game, level)
        teleportIsaacToDoor(game)
    end
end

--- @param itemPoolType ItemPoolType
--- @param decrease boolean
--- @param seed integer
function mod:PreGetCollectible(itemPoolType, decrease, seed)
    if mod.data.state.firstItemUpgraded or mod.data.settings.upgradeFirstItem == false then
        return
    end

    mod.data.state.firstItemUpgraded = true

    return rollQualityItem(3, itemPoolType, RNG(seed))
end

--- @param shouldSave boolean
function mod:PreGameExit(shouldSave)
    if shouldSave then
        saveSettings()
    end
end

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.PostGameStarted)
mod:AddCallback(ModCallbacks.MC_PRE_GET_COLLECTIBLE, mod.PreGetCollectible)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.PreGameExit)
