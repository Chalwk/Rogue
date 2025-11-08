-- JeriCraft: Dungeon Crawler
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local ipairs = ipairs
local math_floor = math.floor
local table_insert = table.insert
local table_remove = table.remove
local math_max = math.max
local math_min = math.min
local math_sqrt = math.sqrt

local lg = love.graphics
local math_random = love.math.random

local SoundManager = require("classes.SoundManager")
local DungeonManager = require("classes.DungeonManager")
local ItemManager = require("classes.ItemManager")

local Game = {}
Game.__index = Game

local UI_WIDTH = 200
local UI_PADDING = 8

-- AI Pathfinding constants
local AI_STATES = {
    WANDERING = "wandering",
    CHASING = "chasing",
    PATROLLING = "patrolling"
}

local AI_CONFIG = {
    DETECTION_RANGE = 6,  -- How far monsters can detect the player
    CHASE_RANGE = 8,      -- How far monsters will chase the player
    WANDER_CHANCE = 0.3,  -- Chance to wander each turn
    PATROL_POINTS = 3,    -- Number of patrol points for patrolling monsters
    MEMORY_TURNS = 5      -- How many turns monsters remember player position
}

local function addMessage(self, text)
    table_insert(self.messageLog, 1, text)
    if #self.messageLog > 6 then
        table_remove(self.messageLog, 7)
    end
end

local function levelUp(self)
    self.player.level = self.player.level + 1
    self.player.maxHp = self.player.maxHp + 5
    self.player.hp = self.player.maxHp
    self.player.attack = self.player.attack + 2
    self.player.defense = self.player.defense + 1

    addMessage(self, "You reached level " .. self.player.level .. "! You feel stronger!")
    self.sounds:play("level_up")
end

local function calculateTileSize(self)
    local availableWidth = self.screenWidth - UI_WIDTH - 20
    local availableHeight = self.screenHeight - 100

    local tileWidth = availableWidth / self.dungeonManager.DUNGEON_WIDTH
    local tileHeight = availableHeight / self.dungeonManager.DUNGEON_HEIGHT

    self.tileSize = math_max(8, math_floor(math_min(tileWidth, tileHeight)))

    local dungeonPixelWidth = self.dungeonManager.DUNGEON_WIDTH * self.tileSize
    local dungeonPixelHeight = self.dungeonManager.DUNGEON_HEIGHT * self.tileSize

    self.dungeonOffsetX = UI_WIDTH + (availableWidth - dungeonPixelWidth) / 2
    self.dungeonOffsetY = 50 + (availableHeight - dungeonPixelHeight) / 2
end

local function drawBorder(r, g, b, xOff, yOff, gridWidth, gridHeight)
    lg.setColor(r, g, b, 0.8)
    lg.setLineWidth(3)
    lg.rectangle("line", xOff - 5, yOff + 5, gridWidth + 5, gridHeight + 5)
    lg.setLineWidth(1)
end

local function drawDungeon(self)
    calculateTileSize(self)

    local isSpecialRoom = self.inSpecialRoom
    local tileSize = self.tileSize
    local offsetX, offsetY = self.dungeonOffsetX, self.dungeonOffsetY
    local dungeonWidth, dungeonHeight = self.dungeonManager.DUNGEON_WIDTH, self.dungeonManager.DUNGEON_HEIGHT
    local gridWidth, gridHeight = dungeonWidth * tileSize, dungeonHeight * tileSize

    -- Choose data sources
    local dungeon = isSpecialRoom and self.specialRoomDungeon or self.dungeon
    local visibleTiles = isSpecialRoom and self.specialRoomVisibleTiles or self.visibleTiles
    local exploredTiles = isSpecialRoom and nil or self.exploredTiles
    local items = isSpecialRoom and self.specialRoomItems or self.items
    local monsters = isSpecialRoom and self.specialRoomMonsters or self.monsters
    local borderColor = isSpecialRoom and { 0.8, 0.6, 0.2 } or { 1, 1, 1 }

    -- Set font once
    if not self.dungeonFont or self.dungeonFont:getHeight() ~= tileSize then
        self.dungeonFont = self.fonts:getFontOfSize(tileSize)
    end
    self.fonts:setFont(self.dungeonFont)

    -- Draw border around grid
    drawBorder(borderColor[1], borderColor[2], borderColor[3], offsetX, offsetY, gridWidth, gridHeight)

    -- Draw tiles with optimized loops
    for y = 1, self.dungeonManager.DUNGEON_HEIGHT do
        for x = 1, self.dungeonManager.DUNGEON_WIDTH do
            local tile = dungeon[y][x]
            local screenX, screenY = offsetX + (x - 1) * tileSize, offsetY + (y - 1) * tileSize

            if visibleTiles[y][x] then
                lg.setColor(tile.color)
                lg.print(tile.char, screenX, screenY)
            elseif exploredTiles and exploredTiles[y][x] then
                lg.setColor(tile.color[1] * 0.3, tile.color[2] * 0.3, tile.color[3] * 0.3)
                lg.print(tile.char, screenX, screenY)
            end
        end
    end

    -- Draw items and monsters in single passes
    for i = 1, #items do
        local item = items[i]
        if visibleTiles[item.y][item.x] then
            lg.setColor(item.color)
            lg.print(item.char, offsetX + (item.x - 1) * tileSize, offsetY + (item.y - 1) * tileSize)
        end
    end

    for i = 1, #monsters do
        local monster = monsters[i]
        if visibleTiles[monster.y][monster.x] then
            lg.setColor(monster.color)
            lg.print(monster.char, offsetX + (monster.x - 1) * tileSize, offsetY + (monster.y - 1) * tileSize)

            -- Draw AI state indicator for debugging (optional)
            --if self.debugAI then
                self.fonts:setFont("tinyFont")
                lg.setColor(1, 1, 1)
                lg.print(monster.aiState:sub(1, 1), offsetX + (monster.x - 1) * tileSize, offsetY + (monster.y - 1) * tileSize - 10)
                self.fonts:setFont(self.dungeonFont)
            --end
        end
    end

    -- Draw player
    lg.setColor(self.player.color)
    lg.print(self.player.char, offsetX + (self.player.x - 1) * tileSize, offsetY + (self.player.y - 1) * tileSize)
end

local UI_BG_COLOR = { 0.1, 0.1, 0.2, 0.9 }
local UI_BORDER_COLOR = { 0.3, 0.3, 0.8 }
local UI_TEXT_COLOR = { 0.8, 0.9, 1.0 }

local function drawMessageLog(self, x, y)
    local boxWidth = UI_WIDTH + 120 - UI_PADDING * 2
    local boxHeight = 120
    local boxY = self.screenHeight - boxHeight - UI_PADDING

    -- Message log with scanlines effect
    lg.setColor(0.05, 0.05, 0.15, 0.8)
    lg.rectangle("fill", x, boxY, boxWidth, boxHeight)

    lg.setColor(0.2, 0.4, 0.8)
    lg.setLineWidth(1)
    lg.rectangle("line", x, boxY, boxWidth, boxHeight)

    -- Messages with typing effect
    lg.setColor(0.8, 1.0, 0.8)
    self.fonts:setFont("tinyFont")
    local maxMessages = 6
    for i = 1, math_min(#self.messageLog, maxMessages) do
        lg.print(self.messageLog[i], x + 4, boxY + 4 + (i - 1) * 18)
    end
end

local controls = {
    "↑↓←→ / WASD - Move",
    "SPACE - Wait",
    "R - Rest/Heal",
    "E - Use/Open",
    "I - Inventory",
    "ESC - Menu"
}

local function drawUI(self)
    local x, y = UI_PADDING, UI_PADDING

    -- UI Background
    love.graphics.setColor(UI_BG_COLOR)
    love.graphics.rectangle("fill", 0, 0, UI_WIDTH + 120, self.screenHeight - 4)
    love.graphics.setColor(UI_BORDER_COLOR)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 0, 0, UI_WIDTH + 120, self.screenHeight - 4)
    love.graphics.setLineWidth(1)

    -- Header
    self.fonts:setFont("mediumFont")
    lg.setColor(0.9, 0.9, 0.2)
    lg.print("╔═STATUS═╗", x, y)
    y = y + 40

    local text_offset = 10

    -- Player stats
    self.fonts:setFont("smallFont")
    lg.setColor(UI_TEXT_COLOR)
    lg.print("♚ Level: " .. self.dungeonLevel, x + text_offset, y); y = y + 24
    lg.print("♥ HP: " .. self.player.hp .. "/" .. self.player.maxHp, x + text_offset, y); y = y + 24
    lg.print("⚔ Atk: " .. self.player.attack, x + text_offset, y); y = y + 20
    lg.print("🛡 Def: " .. self.player.defense, x + text_offset, y); y = y + 20
    lg.print("💰 Gold: " .. self.player.gold, x + text_offset, y); y = y + 20
    lg.print("⭐ XP: " .. self.player.xp .. "/" .. (self.player.level * 10), x + text_offset, y); y = y + 20
    lg.print("⏱ Turn: " .. self.turn, x + text_offset, y); y = y + 20

    -- Location indicator
    if self.inSpecialRoom then
        lg.setColor(0.9, 0.7, 0.2)
        lg.print("📍 Special Chamber", x + text_offset, y); y = y + 32
    else
        lg.setColor(0.6, 0.8, 1.0)
        lg.print("🏰 Dungeon Level " .. self.dungeonLevel, x + text_offset, y); y = y + 32
    end

    -- Controls
    lg.setColor(0.9, 0.9, 0.2)
    self.fonts:setFont("mediumFont")
    lg.print("╔═CONTROLS═╗", x, y); y = y + 37
    lg.setColor(UI_TEXT_COLOR)
    self.fonts:setFont("smallFont")
    for _, control in ipairs(controls) do
        lg.print(control, x + text_offset, y)
        y = y + 20
    end
    y = y + 10

    drawMessageLog(self, x, y)
end

local function drawInventory(self)
    local panelX, panelY = 345, 75
    local panelW, panelH = 440, 380

    -- Background panel with border and drop shadow
    lg.setColor(0, 0, 0, 0.75)
    lg.rectangle("fill", panelX + 4, panelY + 4, panelW, panelH, 8, 8)
    lg.setColor(0.1, 0.1, 0.15, 0.9)
    lg.rectangle("fill", panelX, panelY, panelW, panelH, 8, 8)

    -- Gold border accent
    lg.setColor(1, 0.85, 0.3, 0.8)
    lg.setLineWidth(2)
    lg.rectangle("line", panelX, panelY, panelW, panelH, 8, 8)

    -- Title
    self.fonts:setFont("largeFont")
    lg.setColor(1, 0.9, 0.5)
    lg.printf("INVENTORY", panelX, panelY + 15, panelW, "center")

    -- Divider line
    lg.setColor(1, 0.85, 0.3, 0.3)
    lg.rectangle("fill", panelX + 20, panelY + 55, panelW - 40, 1)

    -- Inventory list area
    self.fonts:setFont("listFont")

    if #self.player.inventory == 0 then
        lg.setColor(0.8, 0.8, 0.8)
        lg.printf("Your inventory is empty.", panelX, panelY + panelH / 2 - 10, panelW, "center")
    else
        local startY = panelY + 75
        local itemSpacing = 26

        for i, item in ipairs(self.player.inventory) do
            local y = startY + (i - 1) * itemSpacing
            local isSelected = (i == self.selectedItem)

            if isSelected then
                -- Highlight background for selected item
                lg.setColor(0.25, 0.25, 0.35, 0.8)
                lg.rectangle("fill", panelX + 24, y + 2, panelW - 48, itemSpacing - 2, 6, 6)
                lg.setColor(1, 1, 0.6)

                -- Show item description for selected item
                local description = self.itemManager:getItemDescription(item)
                lg.setColor(0.8, 0.8, 1)
                self.fonts:setFont("smallFont")
                lg.printf(description, panelX + 30, y + 24, panelW - 60, "left")
                self.fonts:setFont("listFont")
            else
                lg.setColor(0.9, 0.9, 0.9)
            end

            lg.print("- " .. item, panelX + 36, y)
        end
    end

    -- Footer info
    self.fonts:setFont("mediumFont")
    lg.setColor(0.75, 0.75, 0.75, 1)
    lg.printf("↑↓: Select | E: Use | I: Close", panelX, panelY + panelH - 35, panelW, "center")
end

local function drawGameOver(self)
    lg.setColor(0, 0, 0, 0.7)
    lg.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

    self.fonts:setFont("largeFont")

    if self.won then
        lg.setColor(0.2, 0.8, 0.2)
        lg.printf("VICTORY!", 0, self.screenHeight / 2 - 80, self.screenWidth, "center")
    else
        lg.setColor(0.8, 0.2, 0.2)
        lg.printf("GAME OVER", 0, self.screenHeight / 2 - 80, self.screenWidth, "center")
    end

    lg.setColor(1, 1, 1)
    self.fonts:setFont("mediumFont")
    lg.printf("You reached dungeon level " .. self.dungeonLevel,
        0, self.screenHeight / 2, self.screenWidth, "center")
    lg.printf("Click anywhere to continue",
        0, self.screenHeight / 2 + 60, self.screenWidth, "center")
end

local function attackMonster(self, monsterIndex, inSpecialRoom)
    local monsters = inSpecialRoom and self.specialRoomMonsters or self.monsters
    local monster = monsters[monsterIndex]
    local damage = math_max(1, self.player.attack - math_random(0, 2))

    monster.hp = monster.hp - damage

    addMessage(self, "+" .. damage .. " to " .. monster.name)
    self.sounds:play("monster_hit")

    if monster.hp <= 0 then
        addMessage(self, "You killed the " .. monster.name .. "!")
        self.player.xp = self.player.xp + monster.xp
        self.player.gold = self.player.gold + math_random(1, 5)
        table_remove(monsters, monsterIndex)

        -- Check level up
        if self.player.xp >= self.player.level * 10 then levelUp(self) end
    else
        -- Monster counterattack
        local playerDamage = math_max(1, monster.attack - math_random(0, self.player.defense))
        self.player.hp = self.player.hp - playerDamage
        addMessage(self, monster.name .. " attacks you (+" .. playerDamage .. " dmg!)")
        self.sounds:play("player_hit")

        if self.player.hp <= 0 then self:setGameOver(false) end
    end
end

local function pickupItem(self, itemIndex, inSpecialRoom)
    local items = inSpecialRoom and self.specialRoomItems or self.items
    local item = items[itemIndex]

    if item.char == self.dungeonManager.TILES.GOLD then
        local gold = math_random(1, 10)
        self.player.gold = self.player.gold + gold
        addMessage(self, "You found " .. gold .. " gold pieces!")
    elseif item.name == "Food" then
        table_insert(self.player.inventory, item.name)
        addMessage(self, "You pick up " .. item.name)
    elseif item.char == self.dungeonManager.TILES.POTION and item.name == "Healing Potion" then
        local heal = math_random(5, 10)
        self.player.hp = math_min(self.player.maxHp, self.player.hp + heal)
        addMessage(self, "You drink a healing potion and restore " .. heal .. " HP!")
    else
        table_insert(self.player.inventory, item.name)
        addMessage(self, "You pick up " .. item.name)
    end

    table_remove(items, itemIndex)
end

local function attackPlayer(self, monsterIndex, inSpecialRoom)
    local monsters = inSpecialRoom and self.specialRoomMonsters or self.monsters
    local monster = monsters[monsterIndex]
    local damage = math_max(1, monster.attack - math_random(0, self.player.defense))

    self.player.hp = self.player.hp - damage
    addMessage(self, "The " .. monster.name .. " hits you for " .. damage .. " damage!")
    self.sounds:play("player_hit")

    if self.player.hp <= 0 then self:setGameOver(false) end
end

local function updateFOV(self)
    if self.inSpecialRoom then
        self.dungeonManager:updateFOV(self.player, self.specialRoomVisibleTiles, {})
    else
        self.dungeonManager:updateFOV(self.player, self.visibleTiles, self.exploredTiles)
    end
end

local function initializeMonsterAI(monster)
    monster.aiState = AI_STATES.WANDERING
    monster.lastKnownPlayerPos = nil
    monster.memoryTurns = 0
    monster.patrolPoints = {}
    monster.currentPatrolIndex = 1

    -- Set AI behavior based on monster type
    if monster.name:lower():find("boss") then
        monster.aiType = "aggressive"
        monster.detectionRange = AI_CONFIG.DETECTION_RANGE + 2
    elseif monster.name:lower():find("guard") then
        monster.aiType = "patrol"
        -- Generate patrol points around starting position
        for i = 1, AI_CONFIG.PATROL_POINTS do
            table_insert(monster.patrolPoints, {
                x = monster.x + math_random(-3, 3),
                y = monster.y + math_random(-3, 3)
            })
        end
    else
        monster.aiType = "standard"
        monster.detectionRange = AI_CONFIG.DETECTION_RANGE
    end
end

local function generateDungeon(self)
    local dungeon, monsters, items, visibleTiles, specialDoors = self.dungeonManager:generateDungeon(self.player)

    self.dungeon = dungeon
    self.monsters = monsters
    self.items = items
    self.visibleTiles = visibleTiles
    self.specialDoors = specialDoors or {}

    -- Initialize AI for monsters
    for _, monster in ipairs(self.monsters) do
        initializeMonsterAI(monster)
    end

    -- Reset explored tiles for the new level
    for y = 1, self.dungeonManager.DUNGEON_HEIGHT do
        self.exploredTiles[y] = {}
        for x = 1, self.dungeonManager.DUNGEON_WIDTH do
            self.exploredTiles[y][x] = false
        end
    end

    updateFOV(self)
end

-- AI Pathfinding functions
local function calculateDistance(x1, y1, x2, y2)
    return math_floor(math_sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2))
end

local pathfinding_directions = {
    {0, -1}, {1, 0}, {0, 1}, {-1, 0},  -- up, right, down, left
    {1, -1}, {1, 1}, {-1, 1}, {-1, -1} -- diagonals
}

local function getNeighbors(self, x, y, dungeon, monsters, player, ignoreMonsters)
    local neighbors = {}
    for _, dir in ipairs(pathfinding_directions) do
        local newX, newY = x + dir[1], y + dir[2]
        if newX >= 1 and newX <= #dungeon[1] and newY >= 1 and newY <= #dungeon then
            local tile = dungeon[newY][newX]
            if tile.type ~= "wall" then
                if ignoreMonsters or not self.dungeonManager:isBlocked(dungeon, monsters, player, newX, newY) then
                    table_insert(neighbors, {x = newX, y = newY})
                end
            end
        end
    end
    return neighbors
end

local function findPath(self, startX, startY, targetX, targetY, dungeon, monsters, player)
    local openSet = {}
    local closedSet = {}
    local cameFrom = {}

    local function getKey(x, y) return x .. "," .. y end

    local gScore = {}
    local fScore = {}

    local startKey = getKey(startX, startY)
    gScore[startKey] = 0
    fScore[startKey] = calculateDistance(startX, startY, targetX, targetY)

    table_insert(openSet, {x = startX, y = startY})

    while #openSet > 0 do
        -- Find node with lowest fScore
        local currentIndex = 1
        for i = 2, #openSet do
            local currentKey = getKey(openSet[currentIndex].x, openSet[currentIndex].y)
            local testKey = getKey(openSet[i].x, openSet[i].y)
            if fScore[testKey] < fScore[currentKey] then
                currentIndex = i
            end
        end

        local current = openSet[currentIndex]
        local currentKey = getKey(current.x, current.y)

        if current.x == targetX and current.y == targetY then
            -- Reconstruct path
            local path = {}
            while cameFrom[currentKey] do
                table_insert(path, 1, current)
                current = cameFrom[currentKey]
                currentKey = getKey(current.x, current.y)
            end
            return path
        end

        table_remove(openSet, currentIndex)
        closedSet[currentKey] = true

        local neighbors = getNeighbors(self, current.x, current.y, dungeon, monsters, player, true)
        for _, neighbor in ipairs(neighbors) do
            local neighborKey = getKey(neighbor.x, neighbor.y)
            if not closedSet[neighborKey] then
                local tentative_gScore = gScore[currentKey] + 1

                if not gScore[neighborKey] or tentative_gScore < gScore[neighborKey] then
                    cameFrom[neighborKey] = current
                    gScore[neighborKey] = tentative_gScore
                    fScore[neighborKey] = tentative_gScore + calculateDistance(neighbor.x, neighbor.y, targetX, targetY)

                    local inOpenSet = false
                    for _, node in ipairs(openSet) do
                        if node.x == neighbor.x and node.y == neighbor.y then
                            inOpenSet = true
                            break
                        end
                    end

                    if not inOpenSet then
                        table_insert(openSet, neighbor)
                    end
                end
            end
        end
    end

    return nil -- No path found
end

local function updateMonsterAI(self, monster, inSpecialRoom)
    local dungeon = inSpecialRoom and self.specialRoomDungeon or self.dungeon
    local monsters = inSpecialRoom and self.specialRoomMonsters or self.monsters
    local player = self.player

    local distanceToPlayer = calculateDistance(monster.x, monster.y, player.x, player.y)
    local canSeePlayer = (inSpecialRoom and self.specialRoomVisibleTiles[monster.y][monster.x]) or
                        (not inSpecialRoom and self.visibleTiles[monster.y][monster.x])

    -- Update memory if player is visible
    if canSeePlayer then
        monster.lastKnownPlayerPos = {x = player.x, y = player.y}
        monster.memoryTurns = AI_CONFIG.MEMORY_TURNS
    elseif monster.lastKnownPlayerPos then
        monster.memoryTurns = monster.memoryTurns - 1
        if monster.memoryTurns <= 0 then
            monster.lastKnownPlayerPos = nil
        end
    end

    -- State transitions
    if canSeePlayer and distanceToPlayer <= monster.detectionRange then
        monster.aiState = AI_STATES.CHASING
    elseif monster.lastKnownPlayerPos and monster.aiState == AI_STATES.CHASING then
        -- Continue chasing last known position
        monster.aiState = AI_STATES.CHASING
    elseif monster.aiType == "patrol" then
        monster.aiState = AI_STATES.PATROLLING
    else
        monster.aiState = AI_STATES.WANDERING
    end

    -- Execute behavior based on state
    if monster.aiState == AI_STATES.CHASING then
        local targetX, targetY = player.x, player.y
        if monster.lastKnownPlayerPos and not canSeePlayer then
            targetX, targetY = monster.lastKnownPlayerPos.x, monster.lastKnownPlayerPos.y
        end

        if distanceToPlayer <= 1 then
            -- Attack if adjacent to player
            for i, m in ipairs(monsters) do
                if m == monster then
                    attackPlayer(self, i, inSpecialRoom)
                    return true
                end
            end
        else
            -- Move toward player
            local path = findPath(self, monster.x, monster.y, targetX, targetY, dungeon, monsters, player)
            if path and #path > 0 then
                local nextStep = path[1]
                if not self.dungeonManager:isBlocked(dungeon, monsters, player, nextStep.x, nextStep.y) then
                    monster.x, monster.y = nextStep.x, nextStep.y
                    return true
                end
            end
        end

    elseif monster.aiState == AI_STATES.PATROLLING then
        if #monster.patrolPoints > 0 then
            local target = monster.patrolPoints[monster.currentPatrolIndex]
            local distanceToTarget = calculateDistance(monster.x, monster.y, target.x, target.y)

            if distanceToTarget <= 1 then
                -- Move to next patrol point
                monster.currentPatrolIndex = (monster.currentPatrolIndex % #monster.patrolPoints) + 1
                target = monster.patrolPoints[monster.currentPatrolIndex]
            end

            local path = findPath(self, monster.x, monster.y, target.x, target.y, dungeon, monsters, player)
            if path and #path > 0 then
                local nextStep = path[1]
                if not self.dungeonManager:isBlocked(dungeon, monsters, player, nextStep.x, nextStep.y) then
                    monster.x, monster.y = nextStep.x, nextStep.y
                    return true
                end
            end
        end

    elseif monster.aiState == AI_STATES.WANDERING then
        if math_random() < AI_CONFIG.WANDER_CHANCE then
            local directions = {
                {0, -1}, {1, 0}, {0, 1}, {-1, 0},
                {1, -1}, {1, 1}, {-1, 1}, {-1, -1}
            }
            local dir = directions[math_random(1, #directions)]
            local newX, newY = monster.x + dir[1], monster.y + dir[2]

            if newX >= 1 and newX <= #dungeon[1] and newY >= 1 and newY <= #dungeon then
                if not self.dungeonManager:isBlocked(dungeon, monsters, player, newX, newY) then
                    monster.x, monster.y = newX, newY
                    return true
                end
            end
        end
    end

    return false
end

local function enterSpecialRoom(self, doorX, doorY)
    -- Create a unique key for this special door
    local cacheKey = doorX .. "," .. doorY

    -- Check if we already have a cached room for this door
    if self.specialRoomCache[cacheKey] then
        -- Load from cache
        local cached = self.specialRoomCache[cacheKey]
        self.specialRoomDungeon = cached.dungeon
        self.specialRoomMonsters = cached.monsters
        self.specialRoomItems = cached.items
        self.specialRoomVisibleTiles = cached.visibleTiles
        self.specialRoomExitX = cached.exitX
        self.specialRoomExitY = cached.exitY
        self.specialRoom = cached.room

        addMessage(self, "You return to the mysterious chamber!")
    else
        -- Generate new special room and cache it
        local specialDungeon, monsters, items, visibleTiles, exitX, exitY, room =
            self.dungeonManager:generateSpecialRoom()

        self.specialRoomDungeon = specialDungeon
        self.specialRoomMonsters = monsters
        self.specialRoomItems = items
        self.specialRoomVisibleTiles = visibleTiles
        self.specialRoomExitX = exitX
        self.specialRoomExitY = exitY
        self.specialRoom = room

        -- Initialize AI for special room monsters
        for _, monster in ipairs(self.specialRoomMonsters) do
            initializeMonsterAI(monster)
        end

        -- Cache the special room
        self.specialRoomCache[cacheKey] = {
            dungeon = specialDungeon,
            monsters = monsters,
            items = items,
            visibleTiles = visibleTiles,
            exitX = exitX,
            exitY = exitY,
            room = room
        }

        addMessage(self, "You enter a mysterious chamber!")
    end

    -- Save return position and door
    self.specialRoomReturnX = self.player.x
    self.specialRoomReturnY = self.player.y
    self.specialRoomDoorX = doorX
    self.specialRoomDoorY = doorY

    -- Place player near the center of the special room
    self.player.x = math_floor(self.specialRoom.x + self.specialRoom.w / 2)
    self.player.y = math_floor(self.specialRoom.y + self.specialRoom.h / 2)

    -- Set state
    self.inSpecialRoom = true

    self.sounds:play("unlock")

    -- Make entire special room visible
    for y = self.specialRoom.y, self.specialRoom.y + self.specialRoom.h do
        for x = self.specialRoom.x, self.specialRoom.x + self.specialRoom.w do
            if y >= 1 and y <= self.dungeonManager.DUNGEON_HEIGHT and
                x >= 1 and x <= self.dungeonManager.DUNGEON_WIDTH then
                self.specialRoomVisibleTiles[y][x] = true
            end
        end
    end
end

local function leaveSpecialRoom(self)
    if not self.inSpecialRoom then return end

    -- Update the cache with current state before leaving
    local cacheKey = self.specialRoomDoorX .. "," .. self.specialRoomDoorY
    if self.specialRoomCache[cacheKey] then
        self.specialRoomCache[cacheKey] = {
            dungeon = self.specialRoomDungeon,
            monsters = self.specialRoomMonsters,
            items = self.specialRoomItems,
            visibleTiles = self.specialRoomVisibleTiles,
            exitX = self.specialRoomExitX,
            exitY = self.specialRoomExitY,
            room = self.specialRoom
        }
    end

    -- Return player to original position (next to the special door)
    self.player.x = self.specialRoomReturnX
    self.player.y = self.specialRoomReturnY

    -- Reset state
    self.inSpecialRoom = false
    self.specialRoomReturnX = nil
    self.specialRoomReturnY = nil
    self.specialRoomDoorX = nil
    self.specialRoomDoorY = nil
    self.specialRoomDungeon = nil
    self.specialRoomMonsters = nil
    self.specialRoomItems = nil
    self.specialRoomVisibleTiles = nil
    self.specialRoomExitX = nil
    self.specialRoomExitY = nil
    self.specialRoom = nil

    addMessage(self, "You return to the dungeon.")
    self.sounds:play("walk")

    updateFOV(self)
end

local function nextLevel(self)
    self.dungeonLevel = self.dungeonLevel + 1
    addMessage(self, "You descend deeper into the dungeon...")
    self.sounds:play("next_level")

    self.specialRoomCache = {}
    generateDungeon(self)
end

local function monsterTurns(self, inSpecialRoom)
    local monsters = inSpecialRoom and self.specialRoomMonsters or self.monsters

    for i = 1, #monsters do
        local monster = monsters[i]
        updateMonsterAI(self, monster, inSpecialRoom)
    end
end

-- up, right, down, left
local directions = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }

local function hasKey(self, keyType)
    local keyIndex = nil
    for i, itemName in ipairs(self.player.inventory) do
        if itemName == keyType then
            keyIndex = i
            break
        end
    end
    return keyIndex
end

local function tryOpenDoor(self)
    for _, dir in ipairs(directions) do
        local checkX = self.player.x + dir[1]
        local checkY = self.player.y + dir[2]
        if checkX >= 1 and checkX <= self.dungeonManager.DUNGEON_WIDTH and
            checkY >= 1 and checkY <= self.dungeonManager.DUNGEON_HEIGHT then
            local tile = self.dungeon[checkY][checkX]

            if tile.type == "locked_door" then
                local keyIndex = hasKey(self, "Key")
                if hasKey then
                    tile.type = "EXIT"
                    tile.char = self.dungeonManager.TILES.EXIT
                    tile.color = { 0.8, 0.8, 0.2 }
                    table_remove(self.player.inventory, keyIndex)
                    addMessage(self, "You unlock the exit door with the key!")
                    self.sounds:play("unlock")
                else
                    addMessage(self, "Door locked. You need the exit key to open it!")
                    self.sounds:play("locked")
                end
                return
            elseif tile.type == "special_door" then
                local keyIndex = hasKey(self, "Special Key")
                if keyIndex then
                    table_remove(self.player.inventory, keyIndex)
                    enterSpecialRoom(self, checkX, checkY)
                else
                    addMessage(self, "Door locked. You need a special key to open it.")
                    self.sounds:play("locked")
                end
                return
            elseif tile.type == "EXIT" then
                addMessage(self, "Exit already unlocked. Step on it to descend.")
                return
            end
        end
    end

    addMessage(self, "There's no door nearby to interact with.")
end

function Game.new(fontManager)
    local instance = setmetatable({}, Game)

    instance.screenWidth = 800
    instance.screenHeight = 600
    instance.gameOver = false
    instance.won = false
    instance.difficulty = "medium"
    instance.character = "warrior"

    -- Game state
    instance.dungeonLevel = 1
    instance.turn = 0
    instance.messageLog = {}
    instance.showInventory = false

    instance.itemManager = ItemManager.new()
    instance.dungeonManager = DungeonManager.new(ItemManager)

    -- Player state
    instance.player = {
        x = 1,
        y = 1,
        char = instance.dungeonManager.TILES.PLAYER,
        color = { 1, 1, 1 },
        hp = 20,
        maxHp = 20,
        attack = 5,
        defense = 2,
        gold = 0,
        xp = 0,
        level = 1,
        inventory = {}
    }

    instance.dungeon = {}
    instance.monsters = {}
    instance.items = {}
    instance.visibleTiles = {}
    instance.exploredTiles = {}
    instance.specialDoors = {}

    -- Special room state
    instance.inSpecialRoom = false
    instance.specialRoomReturnX = nil
    instance.specialRoomReturnY = nil
    instance.specialRoomDoorX = nil
    instance.specialRoomDoorY = nil
    instance.specialRoomDungeon = nil
    instance.specialRoomMonsters = nil
    instance.specialRoomItems = nil
    instance.specialRoomVisibleTiles = nil
    instance.specialRoomExitX = nil
    instance.specialRoomExitY = nil
    instance.specialRoom = nil
    instance.specialRoomCache = {}

    instance.screenShake = { intensity = 0, duration = 0, timer = 0, active = false }
    instance.buttonHover = nil
    instance.time = 0

    -- AI debugging
    instance.debugAI = false -- Set to true to see AI state indicators

    -- Initialize tile size and offsets
    instance.tileSize = nil -- set in calculateTileSize
    instance.dungeonOffsetX = UI_WIDTH + 10
    instance.dungeonOffsetY = 50
    instance.dungeonFont = nil
    instance.fonts = fontManager

    local soundManager = SoundManager.new()
    instance.sounds = soundManager

    return instance
end

function Game:tryOpenDoor() tryOpenDoor(self) end

local function handleMovement(self, newX, newY, dungeon, monsters, items, isSpecial)
    local tile = dungeon[newY] and dungeon[newY][newX]
    if not tile then return false end

    -- Wall check
    if tile.type == "wall" then
        addMessage(self, "You bump into a wall.")
        self.sounds:play("bump")
        return false
    end

    -- Handle special cases
    if isSpecial and tile.type == "special_exit" then
        leaveSpecialRoom(self)
        return true
    end

    if not isSpecial and tile.type == "special_door" then
        addMessage(self, "You see a mysterious door. Press 'E' to enter.")
        self.sounds:play("bump")
        return false
    end

    if not isSpecial and tile.type == "EXIT" then
        nextLevel(self)
        return true
    end

    -- Check for monsters
    local monsterList = isSpecial and self.specialRoomMonsters or self.monsters
    for i = 1, #monsterList do
        local monster = monsterList[i]
        if monster.x == newX and monster.y == newY then
            self.sounds:play("attack")
            attackMonster(self, i, isSpecial)
            return true
        end
    end

    -- Check for items
    local itemList = isSpecial and self.specialRoomItems or self.items
    for i = 1, #itemList do
        local item = itemList[i]
        if item.x == newX and item.y == newY then
            self.sounds:play("pickup")
            pickupItem(self, i, isSpecial)
            self.player.x, self.player.y = newX, newY
            updateFOV(self)
            monsterTurns(self, isSpecial)
            self.turn = self.turn + 1
            return true
        end
    end

    -- Normal movement
    self.sounds:play("walk")
    self.player.x, self.player.y = newX, newY
    updateFOV(self)
    monsterTurns(self, isSpecial)
    self.turn = self.turn + 1
    return true
end

function Game:movePlayer(dx, dy)
    if self.gameOver then return end

    local newX = self.player.x + dx
    local newY = self.player.y + dy

    -- Check bounds
    if newX < 1 or newX > self.dungeonManager.DUNGEON_WIDTH
        or newY < 1 or newY > self.dungeonManager.DUNGEON_HEIGHT then
        addMessage(self, "You can't go that way!")
        self.sounds:play("bump")
        return
    end

    if self.inSpecialRoom then
        handleMovement(self, newX, newY, self.specialRoomDungeon, self.specialRoomMonsters, self.specialRoomItems, true)
    else
        handleMovement(self, newX, newY, self.dungeon, self.monsters, self.items)
    end
end

function Game:waitTurn()
    addMessage(self, "You wait a moment...")
    self.turn = self.turn + 1
    if self.inSpecialRoom then
        monsterTurns(self, true)
    else
        monsterTurns(self, false)
    end
end

function Game:rest()
    local heal = math_random(1, 3)
    self.player.hp = math_min(self.player.maxHp, self.player.hp + heal)
    addMessage(self, "You rest and heal " .. heal .. " HP")
    self.sounds:play("heal")
    self.turn = self.turn + 1
    if self.inSpecialRoom then
        monsterTurns(self, true)
    else
        monsterTurns(self, false)
    end
end

function Game:toggleInventory()
    self.showInventory = not self.showInventory
    if self.showInventory then self.selectedItem = 1 end
end

function Game:useSelectedItem()
    if not self.showInventory or not self.selectedItem then return end

    local itemName = self.player.inventory[self.selectedItem]
    if not itemName then return end

    -- Don't allow using gold or keys from inventory (they have special handling)
    if itemName == "Gold" then
        addMessage(self, "Gold is used automatically when picked up.")
        return
    end

    if itemName == "Special Key" then
        addMessage(self, "Special keys are used automatically when next to locked doors.")
        return
    end

    local result = self.itemManager:useItem(itemName, self.player, self)

    -- Remove the item from inventory if it's consumable (except equipment)
    if self.itemManager:isConsumable(itemName) then
        table_remove(self.player.inventory, self.selectedItem)
        if #self.player.inventory == 0 then
            self.showInventory = false
        else
            self.selectedItem = math_min(self.selectedItem, #self.player.inventory)
        end
    end

    addMessage(self, result)
    self.turn = self.turn + 1

    -- Process monster turns after item use
    if self.inSpecialRoom then
        monsterTurns(self, true)
    else
        monsterTurns(self, false)
    end
end

function Game:setGameOver(won)
    self.gameOver = true
    self.won = won
    if won then
        addMessage(self, "You win! Congratulations!")
    else
        addMessage(self, "You have died... Game Over!")
    end
end

function Game:draw()
    -- Apply screen shake if active
    local offsetX, offsetY = 0, 0
    if self.screenShake.active then
        local progress = self.screenShake.timer / self.screenShake.duration
        local currentIntensity = self.screenShake.intensity * (1 - progress)
        offsetX = math_random(-currentIntensity, currentIntensity)
        offsetY = math_random(-currentIntensity, currentIntensity)
    end

    lg.push()
    lg.translate(offsetX, offsetY)

    drawDungeon(self)
    drawUI(self)

    if self.showInventory then drawInventory(self) end
    if self.gameOver then drawGameOver(self) end

    lg.pop()
end

function Game:update(dt)
    self.time = self.time + dt

    local expiredEffects = self.itemManager:updateEffects(self.player, self.turn)
    for _, effectName in ipairs(expiredEffects) do
        addMessage(self, effectName .. " effect has worn off!")
    end

    -- Update screen shake
    if self.screenShake.active then
        self.screenShake.timer = self.screenShake.timer + dt
        if self.screenShake.timer >= self.screenShake.duration then
            self.screenShake.active = false
            self.screenShake.intensity = 0
        end
    end
end

function Game:isGameOver() return self.gameOver end

function Game:setScreenSize(width, height)
    self.screenWidth = width
    self.screenHeight = height
    calculateTileSize(self)
end

function Game:startNewGame(difficulty, character)
    self.difficulty = difficulty or "medium"
    self.character = character or "warrior"

    self.inSpecialRoom = false
    self.specialRoomReturnX = nil
    self.specialRoomReturnY = nil
    self.specialRoomDoorX = nil
    self.specialRoomDoorY = nil
    self.specialRoomDungeon = nil
    self.specialRoomMonsters = nil
    self.specialRoomItems = nil
    self.specialRoomVisibleTiles = nil
    self.specialRoomExitX = nil
    self.specialRoomExitY = nil
    self.specialRoom = nil
    self.specialRoomCache = {}

    -- Set up player based on character class
    if self.character == "warrior" then
        self.player = {
            x = 1,
            y = 1,
            char = self.dungeonManager.TILES.PLAYER,
            color = { 1, 1, 1 },
            hp = 25,
            maxHp = 25,
            attack = 6,
            defense = 3,
            gold = 0,
            xp = 0,
            level = 1,
            inventory = {}
        }
    elseif self.character == "jc" then
        self.player = {
            x = 1,
            y = 1,
            char = self.dungeonManager.TILES.PLAYER,
            color = { 1, 1, 1 },
            hp = 20,
            maxHp = 20,
            attack = 5,
            defense = 2,
            gold = 10,
            xp = 0,
            level = 1,
            inventory = {}
        }
    else -- wizard
        self.player = {
            x = 1,
            y = 1,
            char = self.dungeonManager.TILES.PLAYER,
            color = { 1, 1, 1 },
            hp = 15,
            maxHp = 15,
            attack = 4,
            defense = 1,
            gold = 5,
            xp = 0,
            level = 1,
            inventory = {}
        }
    end

    self.dungeonLevel = 1
    self.turn = 0
    self.messageLog = {}
    self.showInventory = false
    self.gameOver = false
    self.won = false

    self.exploredTiles = {}
    for y = 1, self.dungeonManager.DUNGEON_HEIGHT do
        self.exploredTiles[y] = {}
        for x = 1, self.dungeonManager.DUNGEON_WIDTH do
            self.exploredTiles[y][x] = false
        end
    end

    generateDungeon(self)
    addMessage(self, "Welcome to the dungeon!")
end

function Game:handleClick() if self.gameOver then return end end

function Game:toggleAIDebug()
    self.debugAI = not self.debugAI
    addMessage(self, "AI debugging: " .. (self.debugAI and "ON" or "OFF"))
end

return Game