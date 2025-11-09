-- JeriCraft: Dungeon Crawler
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local DungeonManager = {}
DungeonManager.__index = DungeonManager

local ipairs = ipairs
local math_floor = math.floor
local table_insert = table.insert
local math_max = math.max
local math_min = math.min
local math_random = love.math.random

-- Constants
local DUNGEON_WIDTH = 60
local DUNGEON_HEIGHT = 40
local ROOM_MIN_SIZE = 4
local ROOM_MAX_SIZE = 10
local MAX_ROOMS = 20
local SPECIAL_ROOM_CHANCE = 0.3
local SPECIAL_ROOM_MIN_SIZE = 6
local SPECIAL_ROOM_MAX_SIZE = 12
local DECORATION_CHANCE = 0.08
local FOV_RADIUS = 8
local FOV_RADIUS_SQUARED = FOV_RADIUS * FOV_RADIUS

local FLOOR_COLORS = {
    { 0.35, 0.35, 0.35, 0.3 },
    { 0.4,  0.35, 0.3,  0.3 },
    { 0.3,  0.35, 0.4,  0.3 },
    { 0.38, 0.32, 0.28, 0.3 }
}

local WALL_COLORS = {
    { 0.3,  0.3,  0.5 },
    { 0.35, 0.3,  0.45 },
    { 0.25, 0.35, 0.4 },
    { 0.4,  0.25, 0.3 }
}

local SPECIAL_WALL_COLORS = {
    { 0.6, 0.3, 0.6 },
    { 0.7, 0.4, 0.2 },
    { 0.3, 0.6, 0.6 }
}

local CRACK_COLOR = { 0.2, 0.2, 0.2, 0.5 }
local MOSS_COLOR = { 0.2, 0.6, 0.3 }

local TILES = {
    WALL = "█",
    WALL_ALT = "▒",
    WALL_CORNER = "┼",
    FLOOR = "·",
    FLOOR_ALT = "•",
    FLOOR_DUST = "˙",
    EXIT = "🚪",
    PLAYER = "♜",
    DOOR = "🚪",
    SPECIAL_WALL = "◙",
    SPECIAL_FLOOR = "✦",
    PILLAR = "█",
    CRACK = "░",
    MOSS = "♣"
}

local MONSTERS = {
    { char = "⎈", name = "Kobold", color = { 0.6, 0.6, 0.2 }, hp = 5, attack = 2, xp = 5 },
    { char = "⍾", name = "Orc", color = { 0.3, 0.7, 0.3 }, hp = 10, attack = 4, xp = 15 },
    { char = "⍲", name = "Snake", color = { 0.3, 0.8, 0.3 }, hp = 3, attack = 1, xp = 3 },
    { char = "⍦", name = "Zombie", color = { 0.4, 0.6, 0.4 }, hp = 15, attack = 3, xp = 20 },
    { char = "⏄", name = "Bat", color = { 0.7, 0.5, 0.7 }, hp = 2, attack = 1, xp = 2 },
    { char = "⌘", name = "Spider", color = { 0.5, 0.4, 0.6 }, hp = 4, attack = 2, xp = 4 }
}

local FLOOR_COLORS_COUNT = #FLOOR_COLORS
local WALL_COLORS_COUNT = #WALL_COLORS
local SPECIAL_WALL_COLORS_COUNT = #SPECIAL_WALL_COLORS
local MONSTERS_COUNT = #MONSTERS

local temp_positions = {}
for i = 1, 100 do temp_positions[i] = {x = 0, y = 0} end

local function getFOVBounds(playerX, playerY)
    return {
        minX = math_max(1, playerX - FOV_RADIUS),
        maxX = math_min(DUNGEON_WIDTH, playerX + FOV_RADIUS),
        minY = math_max(1, playerY - FOV_RADIUS),
        maxY = math_min(DUNGEON_HEIGHT, playerY + FOV_RADIUS)
    }
end

local function getRandomFloorColor()
    return FLOOR_COLORS[math_random(FLOOR_COLORS_COUNT)]
end

local function getRandomWallColor()
    return WALL_COLORS[math_random(WALL_COLORS_COUNT)]
end

local function getRandomSpecialWallColor()
    return SPECIAL_WALL_COLORS[math_random(SPECIAL_WALL_COLORS_COUNT)]
end

local itemTileCache, itemColorCache = {}, {}

local function getItemTile(self, itemName)
    if not itemTileCache[itemName] then
        local itemDef = self.itemManager:getItemDefinition(itemName)
        itemTileCache[itemName] = itemDef and itemDef.char or "?"
    end
    return itemTileCache[itemName]
end

local function getItemColor(self, itemName)
    if not itemColorCache[itemName] then
        local itemDef = self.itemManager:getItemDefinition(itemName)
        itemColorCache[itemName] = itemDef and itemDef.color or { 1, 1, 1 }
    end
    return itemColorCache[itemName]
end

local function getRoomIndex(rooms, special)
    return special and math_random(2, #rooms) or math_random(2, #rooms - 1)
end

local function roomsIntersect(room1, room2)
    return room1.x <= room2.x + room2.w + 1
        and room1.x + room1.w + 1 >= room2.x
        and room1.y <= room2.y + room2.h + 1
        and room1.y + room1.h + 1 >= room2.y
end

local function createTunnel(dungeon, room1, room2)
    local x1 = math_floor(room1.x + room1.w / 2)
    local y1 = math_floor(room1.y + room1.h / 2)
    local x2 = math_floor(room2.x + room2.w / 2)
    local y2 = math_floor(room2.y + room2.h / 2)

    local floorChar = math_random() < 0.7 and TILES.FLOOR or TILES.FLOOR_ALT
    local floorColor = getRandomFloorColor()

    -- Horizontal section
    local stepX = x2 > x1 and 1 or -1
    for x = x1, x2, stepX do
        dungeon[y1][x] = math_random() < 0.1
            and { type = "floor", char = TILES.CRACK, color = CRACK_COLOR }
            or { type = "floor", char = floorChar, color = floorColor }
    end

    -- Vertical section
    local stepY = y2 > y1 and 1 or -1
    for y = y1, y2, stepY do
        dungeon[y][x2] = math_random() < 0.1
            and { type = "floor", char = TILES.CRACK, color = CRACK_COLOR }
            or { type = "floor", char = floorChar, color = floorColor }
    end
end

local function addRoomDecorations(dungeon, room)
    -- Pillars in larger rooms
    if room.w >= 6 and room.h >= 6 then
        local numPillars = math_random(1, 2)
        for _ = 1, numPillars do
            local pillarX = math_random(room.x + 2, room.x + room.w - 2)
            local pillarY = math_random(room.y + 2, room.y + room.h - 2)
            dungeon[pillarY][pillarX] = { type = "wall", char = TILES.PILLAR, color = { 0.5, 0.5, 0.6 } }
        end
    end

    -- Moss on walls with bounds checking
    for y = math_max(1, room.y - 1), math_min(DUNGEON_HEIGHT, room.y + room.h + 1) do
        for x = math_max(1, room.x - 1), math_min(DUNGEON_WIDTH, room.x + room.w + 1) do
            if (y == room.y - 1 or y == room.y + room.h + 1 or
                x == room.x - 1 or x == room.x + room.w + 1) then
                local tile = dungeon[y] and dungeon[y][x]
                if tile and tile.type == "wall" and math_random() < 0.05 then
                    dungeon[y][x] = { type = "wall", char = TILES.MOSS, color = MOSS_COLOR }
                end
            end
        end
    end
end

local function placeEntities(self, dungeon, monsters, items, player, room, isSpecialRoom)
    local numMonsters = math_random(0, isSpecialRoom and 3 or 2)
    local numItems = math_random(isSpecialRoom and 2 or 0, isSpecialRoom and 4 or 2)

    local positions = temp_positions
    local posCount = 0

    for y = room.y + 1, room.y + room.h - 2 do
        for x = room.x + 1, room.x + room.w - 2 do
            if not self:isBlocked(dungeon, monsters, player, x, y, items) then
                posCount = posCount + 1
                positions[posCount].x = x
                positions[posCount].y = y
            end
        end
    end

    -- Shuffle positions
    for i = posCount, 2, -1 do
        local j = math_random(i)
        positions[i].x, positions[j].x = positions[j].x, positions[i].x
        positions[i].y, positions[j].y = positions[j].y, positions[i].y
    end

    -- Place monsters
    local usedPositions = math_min(numMonsters, posCount)
    for i = 1, usedPositions do
        local pos = positions[i]
        local monster = MONSTERS[math_random(MONSTERS_COUNT)]
        table_insert(monsters, {
            x = pos.x,
            y = pos.y,
            char = monster.char,
            color = monster.color,
            name = monster.name,
            hp = monster.hp,
            maxHp = monster.hp,
            attack = monster.attack,
            xp = monster.xp
        })
    end

    -- Place items
    local itemStart = usedPositions + 1
    local itemEnd = math_min(usedPositions + numItems, posCount)
    for i = itemStart, itemEnd do
        local pos = positions[i]
        local itemName, itemChar, itemColor

        if isSpecialRoom then
            itemName = self.itemManager:getRandomEnhancedItem()
            itemChar = getItemTile(self, itemName)
            itemColor = getItemColor(self, itemName)
        else
            local basicItems = self.itemManager:getBasicItemDefinitions()
            local basicItem = basicItems[math_random(#basicItems)]
            itemName = basicItem.name
            itemChar = basicItem.char
            itemColor = basicItem.color
        end

        table_insert(items, {
            x = pos.x,
            y = pos.y,
            char = itemChar,
            color = itemColor,
            name = itemName
        })
    end
end

local function placeKey(self, dungeon, items, monsters, player, rooms, isSpecial)
    if #rooms < 2 then return false end

    local keyRoomIndex = getRoomIndex(rooms, isSpecial)
    local keyRoom = rooms[keyRoomIndex]

    local validPositions = {}
    for y = keyRoom.y + 1, keyRoom.y + keyRoom.h - 2 do
        for x = keyRoom.x + 1, keyRoom.x + keyRoom.w - 2 do
            if not self:isBlocked(dungeon, monsters, player, x, y, items) then
                table_insert(validPositions, {x = x, y = y})
            end
        end
    end

    if #validPositions > 0 then
        local pos = validPositions[math_random(#validPositions)]
        local keyName = isSpecial and "Special Key" or "Key"
        table_insert(items, {
            x = pos.x,
            y = pos.y,
            char = getItemTile(self, keyName),
            color = getItemColor(self, keyName),
            name = keyName
        })
        return true
    end

    return false
end

local function createSpecialDoor(dungeon, room)
    local wall = math_random(1, 4)
    local doorX, doorY

    if wall == 1 then -- top
        doorX = math_random(room.x + 1, room.x + room.w - 1)
        doorY = room.y - 1
    elseif wall == 2 then -- right
        doorX = room.x + room.w + 1
        doorY = math_random(room.y + 1, room.y + room.h - 1)
    elseif wall == 3 then -- bottom
        doorX = math_random(room.x + 1, room.x + room.w - 1)
        doorY = room.y + room.h + 1
    else -- left
        doorX = room.x - 1
        doorY = math_random(room.y + 1, room.y + room.h - 1)
    end

    if doorX >= 1 and doorX <= DUNGEON_WIDTH and doorY >= 1 and doorY <= DUNGEON_HEIGHT then
        dungeon[doorY][doorX] = {
            type = "special_door",
            char = TILES.DOOR,
            color = { 0.8, 0.6, 0.2 },
            connectedRoom = room
        }
        return doorX, doorY
    end

    return nil, nil
end

local function createBasicRoom(dungeon, room)
    local floorColor = getRandomFloorColor()
    local wallColor = getRandomWallColor()

    -- Create floor
    for y = room.y, room.y + room.h do
        for x = room.x, room.x + room.w do
            local floorChar = math_random() < 0.8 and TILES.FLOOR or
                             (math_random() < 0.5 and TILES.FLOOR_ALT or TILES.FLOOR_DUST)
            dungeon[y][x] = { type = "floor", char = floorChar, color = floorColor }
        end
    end

    -- Create walls with bounds checking
    for y = math_max(1, room.y - 1), math_min(DUNGEON_HEIGHT, room.y + room.h + 1) do
        for x = math_max(1, room.x - 1), math_min(DUNGEON_WIDTH, room.x + room.w + 1) do
            if y == room.y - 1 or y == room.y + room.h + 1 or
               x == room.x - 1 or x == room.x + room.w + 1 then
                local tile = dungeon[y] and dungeon[y][x]
                if tile and tile.type ~= "floor" then
                    local wallChar = math_random() < 0.7 and TILES.WALL or TILES.WALL_ALT
                    dungeon[y][x] = { type = "wall", char = wallChar, color = wallColor }
                end
            end
        end
    end

    if math_random() < DECORATION_CHANCE then addRoomDecorations(dungeon, room) end
end

function DungeonManager:generateSpecialRoom()
    local specialDungeon = {}
    local monsters = {}
    local items = {}
    local visibleTiles = {}

    local specialWallColor = getRandomSpecialWallColor()
    local specialFloorColor = { 0.45, 0.4, 0.5, 0.4 }

    -- Initialize
    for y = 1, DUNGEON_HEIGHT do
        specialDungeon[y] = {}
        visibleTiles[y] = {}
        for x = 1, DUNGEON_WIDTH do
            local wallChar = math_random() < 0.7 and TILES.SPECIAL_WALL or TILES.WALL
            specialDungeon[y][x] = { type = "wall", char = wallChar, color = specialWallColor }
            visibleTiles[y][x] = false
        end
    end

    local w = math_random(SPECIAL_ROOM_MIN_SIZE, SPECIAL_ROOM_MAX_SIZE)
    local h = math_random(SPECIAL_ROOM_MIN_SIZE, SPECIAL_ROOM_MAX_SIZE)
    local gridX = math_random(2, DUNGEON_WIDTH - w - 1)
    local gridY = math_random(2, DUNGEON_HEIGHT - h - 1)

    local specialRoom = { x = gridX, y = gridY, w = w, h = h }

    -- Create special room
    for y = specialRoom.y, specialRoom.y + specialRoom.h do
        for x = specialRoom.x, specialRoom.x + specialRoom.w do
            local floorChar = math_random() < 0.7 and TILES.SPECIAL_FLOOR or TILES.FLOOR
            specialDungeon[y][x] = { type = "floor", char = floorChar, color = specialFloorColor }
        end
    end

    -- Create walls
    for y = math_max(1, specialRoom.y - 1), math_min(DUNGEON_HEIGHT, specialRoom.y + specialRoom.h + 1) do
        for x = math_max(1, specialRoom.x - 1), math_min(DUNGEON_WIDTH, specialRoom.x + specialRoom.w + 1) do
            if y == specialRoom.y - 1 or y == specialRoom.y + specialRoom.h + 1 or
               x == specialRoom.x - 1 or x == specialRoom.x + specialRoom.w + 1 then
                local tile = specialDungeon[y] and specialDungeon[y][x]
                if tile then
                    local wallChar = math_random() < 0.6 and TILES.SPECIAL_WALL or TILES.WALL_CORNER
                    specialDungeon[y][x] = { type = "wall", char = wallChar, color = specialWallColor }
                end
            end
        end
    end

    addRoomDecorations(specialDungeon, specialRoom)

    -- Place exit door
    local exitWall = math_random(1, 4)
    local exitX, exitY

    if exitWall == 1 then -- top
        exitX = math_random(specialRoom.x + 1, specialRoom.x + specialRoom.w - 1)
        exitY = specialRoom.y - 1
    elseif exitWall == 2 then -- right
        exitX = specialRoom.x + specialRoom.w + 1
        exitY = math_random(specialRoom.y + 1, specialRoom.y + specialRoom.h - 1)
    elseif exitWall == 3 then -- bottom
        exitX = math_random(specialRoom.x + 1, specialRoom.x + specialRoom.w - 1)
        exitY = specialRoom.y + specialRoom.h + 1
    else -- left
        exitX = specialRoom.x - 1
        exitY = math_random(specialRoom.y + 1, specialRoom.y + specialRoom.h - 1)
    end

    if exitX >= 1 and exitX <= DUNGEON_WIDTH and exitY >= 1 and exitY <= DUNGEON_HEIGHT then
        specialDungeon[exitY][exitX] = { type = "special_exit", char = TILES.DOOR, color = { 0.7, 0.7, 0.9 } }
    end

    placeEntities(self, specialDungeon, monsters, items, { x = 0, y = 0 }, specialRoom, true)

    return specialDungeon, monsters, items, visibleTiles, exitX, exitY, specialRoom
end

function DungeonManager:generateDungeon(player)
    local dungeon = {}
    local monsters = {}
    local items = {}
    local visibleTiles = {}
    local specialDoors = {}

    -- Initialize dungeon
    for y = 1, DUNGEON_HEIGHT do
        dungeon[y] = {}
        visibleTiles[y] = {}
        if not self.exploredTiles[y] then self.exploredTiles[y] = {} end
        for x = 1, DUNGEON_WIDTH do
            local wallChar = math_random() < 0.8 and TILES.WALL or TILES.WALL_ALT
            dungeon[y][x] = { type = "wall", char = wallChar, color = getRandomWallColor() }
            visibleTiles[y][x] = false
            if self.exploredTiles[y][x] == nil then self.exploredTiles[y][x] = false end
        end
    end

    local rooms = {}
    local specialDoorPlaced = false

    for i = 1, MAX_ROOMS do
        local w = math_random(ROOM_MIN_SIZE, ROOM_MAX_SIZE)
        local h = math_random(ROOM_MIN_SIZE, ROOM_MAX_SIZE)
        local x = math_random(2, DUNGEON_WIDTH - w - 1)
        local y = math_random(2, DUNGEON_HEIGHT - h - 1)

        local newRoom = { x = x, y = y, w = w, h = h }

        -- Check for intersections
        local failed = false
        for _, otherRoom in ipairs(rooms) do
            if roomsIntersect(newRoom, otherRoom) then
                failed = true
                break
            end
        end

        if not failed then
            if #rooms == 0 then
                player.x = math_floor(newRoom.x + newRoom.w / 2)
                player.y = math_floor(newRoom.y + newRoom.h / 2)
                createBasicRoom(dungeon, newRoom)
            else
                createBasicRoom(dungeon, newRoom)
                local prevRoom = rooms[#rooms]
                createTunnel(dungeon, prevRoom, newRoom)

                if not specialDoorPlaced and i > 1 and math_random() < SPECIAL_ROOM_CHANCE then
                    local doorX, doorY = createSpecialDoor(dungeon, newRoom)
                    if doorX and doorY then
                        table_insert(specialDoors, { doorX = doorX, doorY = doorY, room = newRoom })
                        specialDoorPlaced = true
                    end
                end
            end

            placeEntities(self, dungeon, monsters, items, player, newRoom, false)
            table_insert(rooms, newRoom)
        end
    end

    -- Place keys
    placeKey(self, dungeon, items, monsters, player, rooms)
    if specialDoorPlaced then
        placeKey(self, dungeon, items, monsters, player, rooms, true)
    end

    -- Place exit
    if #rooms > 0 then
        local lastRoom = rooms[#rooms]
        local sx = math_random(lastRoom.x + 1, lastRoom.x + lastRoom.w - 2)
        local sy = math_random(lastRoom.y + 1, lastRoom.y + lastRoom.h - 2)
        dungeon[sy][sx] = { type = "locked_door", char = TILES.DOOR, color = { 0.8, 0, 0 } }
    end

    return dungeon, monsters, items, visibleTiles, specialDoors
end

function DungeonManager:updateFOV(player, visibleTiles, exploredTiles)
    local bounds = getFOVBounds(player.x, player.y)

    -- Reset visibility in FOV area only
    for y = bounds.minY, bounds.maxY do
        for x = bounds.minX, bounds.maxX do visibleTiles[y][x] = false end
    end

    -- Update visibility and explored tiles
    for y = bounds.minY, bounds.maxY do
        for x = bounds.minX, bounds.maxX do
            local dx = x - player.x
            local dy = y - player.y
            if dx * dx + dy * dy <= FOV_RADIUS_SQUARED then
                visibleTiles[y][x] = true
                if exploredTiles[y] then exploredTiles[y][x] = true end
            end
        end
    end
end

function DungeonManager:isBlocked(dungeon, monsters, player, x, y, items)
    if not dungeon[y] or not dungeon[y][x] then return true end
    if dungeon[y][x].type == "wall" then return true end
    if player.x == x and player.y == y then return true end

    for i = 1, #monsters do
        local monster = monsters[i]
        if monster.x == x and monster.y == y then return true end
    end

    if items then
        for i = 1, #items do
            local item = items[i]
            if item.x == x and item.y == y then return true end
        end
    end

    return false
end

function DungeonManager.new(ItemManager)
    local instance = setmetatable({}, DungeonManager)

    instance.TILES = TILES
    instance.MONSTERS = MONSTERS
    instance.DUNGEON_WIDTH = DUNGEON_WIDTH
    instance.DUNGEON_HEIGHT = DUNGEON_HEIGHT
    instance.ROOM_MIN_SIZE = ROOM_MIN_SIZE
    instance.ROOM_MAX_SIZE = ROOM_MAX_SIZE
    instance.MAX_ROOMS = MAX_ROOMS

    instance.exploredTiles = {}
    instance.itemManager = ItemManager

    return instance
end

return DungeonManager