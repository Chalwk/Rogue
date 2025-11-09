-- JeriCraft: Dungeon Crawler
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local ipairs, math_sin = ipairs, math.sin

local BUTTON_DATA = {
    MENU = {
        { text = "START GAME", action = "start",   width = 240, height = 45, color = { 0.8, 0.1, 0.1 } }, -- Red like old CRT monitors
        { text = "OPTIONS",    action = "options", width = 240, height = 45, color = { 0.1, 0.6, 0.8 } }, -- Cyan terminal color
        { text = "QUIT GAME",  action = "quit",    width = 240, height = 45, color = { 0.6, 0.6, 0.1 } }  -- Amber like old displays
    },
    OPTIONS = {
        DIFFICULTY = {
            { text = "EASY",   action = "diff easy",   width = 100, height = 35, color = { 0.1, 0.7, 0.1 } }, -- Green
            { text = "MEDIUM", action = "diff medium", width = 100, height = 35, color = { 0.9, 0.7, 0.1 } }, -- Amber
            { text = "HARD",   action = "diff hard",   width = 100, height = 35, color = { 0.8, 0.1, 0.1 } }  -- Red
        },
        CHARACTER = {
            { text = "WARRIOR", action = "char warrior", width = 120, height = 35, color = { 0.8, 0.3, 0.1 } }, -- Orange
            { text = "ROGUE",   action = "char rogue",   width = 120, height = 35, color = { 0.1, 0.7, 0.1 } }, -- Green
            { text = "WIZARD",  action = "char wizard",  width = 120, height = 35, color = { 0.3, 0.5, 0.8 } }  -- Blue
        },
        NAVIGATION = {
            { text = "BACK", action = "back", width = 160, height = 40, color = { 0.4, 0.4, 0.4 } } -- Gray
        }
    }
}

local HELP_TEXT = {
    "JERICRAFT: DUNGEON CRAWLER",
    "",
    "GAMEPLAY:",
    "• EXPLORE RANDOMLY GENERATED DUNGEONS",
    "• FIGHT MONSTERS AND COLLECT TREASURE",
    "• FIND THE DOORS TO DESCEND DEEPER",
    "• SURVIVE AS LONG AS YOU CAN!",
    "",
    "CONTROLS:",
    "• MOVEMENT: ARROW KEYS / WASD",
    "• WAIT: SPACEBAR",
    "• REST: R (HEALS SLOWLY)",
    "• INVENTORY: I",
    "• MENU: ESC",
    "",
    "SYMBOLS:",
    "♜ - YOU",
    "▥ - WALLS",
    "▩ - FLOOR",
    "🚪 - DOORS",
    "CLICK ANYWHERE TO CLOSE"
}

local lg = love.graphics

local Menu = {}
Menu.__index = Menu

local LAYOUT = {
    DIFF_BUTTON = { W = 100, H = 35, SPACING = 15 },
    CHAR_BUTTON = { W = 120, H = 35, SPACING = 15, GRID_SPACING = 12 },
    TOTAL_SECTIONS_HEIGHT = 280,
    HELP_BOX = { W = 600, H = 650, LINE_HEIGHT = 18 }
}

local function initButton(button, x, y, section)
    button.x, button.y, button.section = x, y, section
    return button
end

local function updateOptionsButtonPositions(self)
    local centerX, centerY = self.screenWidth * 0.5, self.screenHeight * 0.5
    local startY = centerY - LAYOUT.TOTAL_SECTIONS_HEIGHT * 0.5

    -- Difficulty buttons
    local diff = LAYOUT.DIFF_BUTTON
    local diffTotalW = 3 * diff.W + 2 * diff.SPACING
    local diffStartX = centerX - diffTotalW * 0.5
    local diffY = startY + 40

    -- Character buttons
    local char = LAYOUT.CHAR_BUTTON
    local charTotalW = 3 * char.W + 2 * char.SPACING
    local charStartX = centerX - charTotalW * 0.5
    local charY = startY + 120

    -- Navigation button
    local navY = startY + 278

    -- Update all options buttons
    for i, button in ipairs(self.optionsButtons) do
        if button.section == "difficulty" then
            button.x = diffStartX + (i - 1) * (diff.W + diff.SPACING)
            button.y = diffY
        elseif button.section == "character" then
            local index = i - 4 -- Offset for difficulty buttons
            button.x = charStartX + (index - 1) * (char.W + char.SPACING)
            button.y = charY
        elseif button.section == "navigation" then
            button.x = centerX - button.width * 0.5
            button.y = navY
        end
    end
end

local function updateButtonPositions(self)
    local startY = self.screenHeight * 0.5 - 60
    for i, button in ipairs(self.menuButtons) do
        button.x = (self.screenWidth - button.width) * 0.5
        button.y = startY + (i - 1) * 60
    end
    self.helpButton.y = self.screenHeight - 60
end

local function createMenuButtons(self)
    self.menuButtons = {}
    for i, data in ipairs(BUTTON_DATA.MENU) do
        self.menuButtons[i] = initButton({
            text = data.text,
            action = data.action,
            width = data.width,
            height = data.height,
            color = data.color
        }, 0, 0, "menu")
    end

    self.helpButton = initButton({
        text = "?",
        action = "help",
        width = 40,
        height = 40,
        x = 20,
        y = self.screenHeight - 60,
        color = { 0.3, 0.6, 0.9 }
    }, 20, self.screenHeight - 60, "help")

    updateButtonPositions(self)
end

local function createOptionsButtons(self)
    self.optionsButtons = {}
    local index = 1

    -- Add difficulty buttons
    for _, data in ipairs(BUTTON_DATA.OPTIONS.DIFFICULTY) do
        self.optionsButtons[index] = initButton({
            text = data.text,
            action = data.action,
            width = data.width,
            height = data.height,
            color = data.color
        }, 0, 0, "difficulty")
        index = index + 1
    end

    -- Add character buttons
    for _, data in ipairs(BUTTON_DATA.OPTIONS.CHARACTER) do
        self.optionsButtons[index] = initButton({
            text = data.text,
            action = data.action,
            width = data.width,
            height = data.height,
            color = data.color
        }, 0, 0, "character")
        index = index + 1
    end

    -- Add navigation button
    for _, data in ipairs(BUTTON_DATA.OPTIONS.NAVIGATION) do
        self.optionsButtons[index] = initButton({
            text = data.text,
            action = data.action,
            width = data.width,
            height = data.height,
            color = data.color
        }, 0, 0, "navigation")
    end

    updateOptionsButtonPositions(self)
end

local function drawRetroButton(self, button)
    local isHovered = self.buttonHover == button.action
    local r, g, b = button.color[1], button.color[2], button.color[3]

    -- Button background with scanline effect
    for y = button.y, button.y + button.height, 2 do
        local alpha = 0.3 + (y % 4) * 0.1
        lg.setColor(r * 0.3, g * 0.3, b * 0.3, alpha)
        lg.rectangle("fill", button.x, y, button.width, 1)
    end

    -- Main button fill
    lg.setColor(r * 0.6, g * 0.6, b * 0.6, 0.8)
    lg.rectangle("fill", button.x, button.y, button.width, button.height)

    -- CRT scanline overlay
    for y = button.y + 1, button.y + button.height - 1, 2 do
        lg.setColor(0, 0, 0, 0.1)
        lg.rectangle("fill", button.x, y, button.width, 1)
    end

    -- Border with 80s computer aesthetic
    lg.setLineWidth(2)

    -- Outer border (dark)
    lg.setColor(0.1, 0.1, 0.1, 0.9)
    lg.rectangle("line", button.x, button.y, button.width, button.height)

    -- Inner highlight (bright)
    lg.setColor(r * 1.2, g * 1.2, b * 1.2, 1)
    lg.line(button.x + 1, button.y + 1, button.x + button.width - 2, button.y + 1)  -- top
    lg.line(button.x + 1, button.y + 1, button.x + 1, button.y + button.height - 2) -- left

    -- Hover effect - brighter border
    if isHovered then
        lg.setColor(1, 1, 1, 0.8)
        lg.setLineWidth(3)
        lg.rectangle("line", button.x - 1, button.y - 1, button.width + 2, button.height + 2)
        lg.setLineWidth(2)
    end

    -- Button text
    local font = self.fonts:getFont("mediumFont")
    self.fonts:setFont(font)

    local textWidth = font:getWidth(button.text)
    local textHeight = font:getHeight()
    local textX = button.x + (button.width - textWidth) * 0.5
    local textY = button.y + (button.height - textHeight) * 0.5

    -- Text shadow for depth
    lg.setColor(0, 0, 0, 0.7)
    lg.print(button.text, textX + 2, textY + 2)

    -- Main text with slight glow on hover
    if isHovered then
        lg.setColor(1, 1, 1, 1)       -- Bright white when hovered
    else
        lg.setColor(0.9, 0.9, 0.7, 1) -- Amber color for text
    end
    lg.print(button.text, textX, textY)

    lg.setLineWidth(1)
end

local function drawRetroHelpButton(self)
    local button = self.helpButton
    local isHovered = self.buttonHover == "help"

    -- Button background with scanlines
    for y = button.y, button.y + button.height, 2 do
        local alpha = 0.3 + (y % 4) * 0.1
        lg.setColor(0.3, 0.6, 0.9, alpha)
        lg.rectangle("fill", button.x, y, button.width, 1)
    end

    -- Main circle
    local centerX, centerY = button.x + button.width * 0.5, button.y + button.height * 0.5
    lg.setColor(0.3, 0.6, 0.9, 0.8)
    lg.circle("fill", centerX, centerY, button.width * 0.5)

    -- CRT scanline effect
    for y = button.y + 1, button.y + button.height - 1, 2 do
        lg.setColor(0, 0, 0, 0.1)
        lg.rectangle("fill", button.x, y, button.width, 1)
    end

    -- Border
    lg.setLineWidth(2)
    lg.setColor(0.1, 0.1, 0.1, 0.9)
    lg.circle("line", centerX, centerY, button.width * 0.5)
    lg.setColor(0.6, 0.8, 1, 1)
    lg.circle("line", centerX, centerY, button.width * 0.5 - 1)

    -- Hover effect
    if isHovered then
        lg.setColor(1, 1, 1, 0.8)
        lg.setLineWidth(3)
        lg.circle("line", centerX, centerY, button.width * 0.5 + 2)
        lg.setLineWidth(2)
    end

    -- Question mark
    local font = self.fonts:getFont("mediumFont")
    self.fonts:setFont(font)

    local textWidth = font:getWidth(button.text)
    local textHeight = font:getHeight()

    lg.setColor(0, 0, 0, 0.7)
    lg.print(button.text, button.x + (button.width - textWidth) * 0.5 + 1,
        button.y + (button.height - textHeight) * 0.5 + 1)

    if isHovered then
        lg.setColor(1, 1, 1, 1)
    else
        lg.setColor(0.9, 0.9, 0.7, 1)
    end
    lg.print(button.text, button.x + (button.width - textWidth) * 0.5, button.y + (button.height - textHeight) * 0.5)

    lg.setLineWidth(1)
end

local function drawOptionSection(self, section)
    for _, button in ipairs(self.optionsButtons) do
        if button.section == section then
            drawRetroButton(self, button)

            -- Draw selection indicator with retro style
            local actionType, value = button.action:match("^(%w+) (.+)$")
            if (actionType == "diff" and value == self.difficulty) or
                (actionType == "char" and value == self.character) then
                -- Retro selection box with scanlines
                lg.setColor(0.1, 0.8, 0.1, 0.2)
                lg.rectangle("fill", button.x - 6, button.y - 6, button.width + 12, button.height + 12)

                -- Blinking border for selection
                local blink = math_sin(self.time * 8) > 0
                if blink then
                    lg.setColor(0.1, 1, 0.1, 0.8)
                    lg.setLineWidth(2)
                    lg.rectangle("line", button.x - 6, button.y - 6, button.width + 12, button.height + 12)

                    -- Corner brackets for extra retro feel
                    local bracketSize = 8
                    lg.line(button.x - 6, button.y - 6, button.x - 6 + bracketSize, button.y - 6) -- top-left horizontal
                    lg.line(button.x - 6, button.y - 6, button.x - 6, button.y - 6 + bracketSize) -- top-left vertical

                    lg.line(button.x + button.width + 6, button.y - 6, button.x + button.width + 6 - bracketSize,
                        button.y - 6)               -- top-right horizontal
                    lg.line(button.x + button.width + 6, button.y - 6, button.x + button.width + 6,
                        button.y - 6 + bracketSize) -- top-right vertical

                    lg.line(button.x - 6, button.y + button.height + 6, button.x - 6 + bracketSize,
                        button.y + button.height + 6)               -- bottom-left horizontal
                    lg.line(button.x - 6, button.y + button.height + 6, button.x - 6,
                        button.y + button.height + 6 - bracketSize) -- bottom-left vertical

                    lg.line(button.x + button.width + 6, button.y + button.height + 6,
                        button.x + button.width + 6 - bracketSize, button.y + button.height + 6) -- bottom-right horizontal
                    lg.line(button.x + button.width + 6, button.y + button.height + 6, button.x + button.width + 6,
                        button.y + button.height + 6 - bracketSize)                              -- bottom-right vertical

                    lg.setLineWidth(1)
                end
            end
        end
    end
end

local function drawRetroHelpOverlay(self, screenWidth, screenHeight)
    -- Old CRT monitor overlay effect
    for i = 1, 4 do
        local alpha = 0.95 - (i * 0.2)
        lg.setColor(0, 0.1, 0, alpha) -- Dark green like old monitors
        lg.rectangle("fill", -i, -i, screenWidth + i * 2, screenHeight + i * 2)
    end

    -- Help box with CRT bezel
    local box = LAYOUT.HELP_BOX
    local boxX = (screenWidth - box.W) * 0.5
    local boxY = (screenHeight - box.H) * 0.5

    -- Box background with phosphor glow effect
    for y = boxY, boxY + box.H do
        local progress = (y - boxY) / box.H
        local r = 0.05 + progress * 0.05
        local g = 0.15 + progress * 0.1
        local b = 0.08 + progress * 0.05
        lg.setColor(r, g, b, 0.98)
        lg.line(boxX, y, boxX + box.W, y)
    end

    -- Add scanlines to the box
    for y = boxY + 2, boxY + box.H - 2, 3 do
        lg.setColor(0, 0.2, 0, 0.1)
        lg.rectangle("fill", boxX, y, box.W, 1)
    end

    -- Box border with old computer aesthetic
    lg.setColor(0.3, 0.8, 0.3, 0.9)
    lg.setLineWidth(4)
    lg.rectangle("line", boxX, boxY, box.W, box.H)

    -- Inner bevel
    lg.setColor(0.6, 1, 0.6, 0.6)
    lg.setLineWidth(2)
    lg.rectangle("line", boxX + 2, boxY + 2, box.W - 4, box.H - 4)

    -- Title with retro computer style
    lg.setColor(0.8, 1, 0.8, 1)
    self.fonts:setFont("mediumFont")
    lg.printf("JERICRAFT: DUNGEON CRAWLER", boxX, boxY + 20, box.W, "center")

    -- Help text in classic terminal green
    self.fonts:setFont("smallFont")

    for i, line in ipairs(HELP_TEXT) do
        local y = boxY + 80 + (i - 1) * box.LINE_HEIGHT
        if line:sub(1, 2) == "• " then
            lg.setColor(0.6, 0.9, 0.6, 1)   -- Bright green for bullet points
        elseif line == "" then
            lg.setColor(0.3, 0.7, 0.3, 0.5) -- Dim green for empty lines
        else
            lg.setColor(0.5, 0.8, 0.5, 1)   -- Regular green for text
        end
        lg.printf(line, boxX + 30, y, box.W - 60, "left")
    end

    lg.setLineWidth(1)
end

local function drawRetroTitle(self, screenWidth, screenHeight)
    local centerX, centerY = screenWidth * 0.5, screenHeight * 0.2

    lg.push()
    lg.translate(centerX, centerY)
    lg.scale(1.6, 1.6)

    local font = self.fonts:getFont("largeFont")
    self.fonts:setFont(font)

    local height_offset = 55

    -- Title shadow with multiple offsets for retro depth
    lg.setColor(0, 0.3, 0, 0.8)
    for i = 1, 3 do
        lg.printf(self.title.text, -300 + i, -font:getHeight() * 0.5 + i - height_offset, 600, "center")
    end

    -- Main title with phosphor glow effect
    local glow = math_sin(self.time * 4) * 0.2 + 0.8
    lg.setColor(0.2, 0.9, 0.2, glow)
    lg.printf(self.title.text, -300, -font:getHeight() * 0.5 - height_offset, 600, "center")

    -- Subtle scanline effect over title
    lg.setColor(0, 0.1, 0, 0.1)
    for y = -font:getHeight() * 0.5 - height_offset - 5, -font:getHeight() * 0.5 - height_offset + font:getHeight() + 5, 2 do
        lg.line(-320, y, 320, y)
    end

    lg.pop()
end

function Menu.new(fontManager)
    local instance = setmetatable({}, Menu)

    instance.screenWidth = 800
    instance.screenHeight = 600
    instance.difficulty = "medium"
    instance.character = "warrior"
    instance.title = {
        text = "JERICRAFT: DUNGEON CRAWLER",
        subtitle =
        "EXPLORE DUNGEONS, FIGHT MONSTERS, AND FIND TREASURE!\nSURVIVE AS LONG AS YOU CAN IN THIS DUNGEON CRAWLER!",
        scale = 1,
        scaleDirection = 1,
        scaleSpeed = 0.4,
        minScale = 0.92,
        maxScale = 1.08,
        glow = 0
    }
    instance.showHelp = false
    instance.time = 0
    instance.buttonHover = nil
    instance.fonts = fontManager

    createMenuButtons(instance)
    createOptionsButtons(instance)

    return instance
end

function Menu:update(dt, screenWidth, screenHeight)
    self.time = self.time + dt

    if screenWidth ~= self.screenWidth or screenHeight ~= self.screenHeight then
        self.screenWidth, self.screenHeight = screenWidth, screenHeight
        updateButtonPositions(self)
        updateOptionsButtonPositions(self)
    end

    -- Title animation
    self.title.scale = self.title.scale + self.title.scaleDirection * self.title.scaleSpeed * dt
    self.title.glow = math_sin(self.time * 3) * 0.3 + 0.7

    if self.title.scale > self.title.maxScale then
        self.title.scale, self.title.scaleDirection = self.title.maxScale, -1
    elseif self.title.scale < self.title.minScale then
        self.title.scale, self.title.scaleDirection = self.title.minScale, 1
    end

    -- Update button hover state
    self:updateButtonHover(love.mouse.getX(), love.mouse.getY())
end

function Menu:updateButtonHover(x, y)
    self.buttonHover = nil

    local buttons = self.showHelp and {} or (self.state == "options" and self.optionsButtons or self.menuButtons)

    for _, button in ipairs(buttons) do
        if x >= button.x and x <= button.x + button.width and
            y >= button.y and y <= button.y + button.height then
            self.buttonHover = button.action
            return
        end
    end

    -- Check help button
    if not self.showHelp and self.helpButton and
        x >= self.helpButton.x and x <= self.helpButton.x + self.helpButton.width and
        y >= self.helpButton.y and y <= self.helpButton.y + self.helpButton.height then
        self.buttonHover = "help"
    end
end

function Menu:draw(screenWidth, screenHeight, state)
    self.state = state

    drawRetroTitle(self, screenWidth, screenHeight)

    if state == "menu" then
        if self.showHelp then
            drawRetroHelpOverlay(self, screenWidth, screenHeight)
        else
            for _, button in ipairs(self.menuButtons) do
                drawRetroButton(self, button)
            end

            -- Subtitle
            lg.setColor(0.4, 0.8, 0.4, 0.8)
            self.fonts:setFont("mediumFont")
            lg.printf(self.title.subtitle, 0, screenHeight * 0.5 - 350, screenWidth, "center")

            drawRetroHelpButton(self)
        end
    elseif state == "options" then
        updateOptionsButtonPositions(self)

        local startY = (self.screenHeight - LAYOUT.TOTAL_SECTIONS_HEIGHT) * 0.5

        -- Section headers
        lg.setColor(0.4, 0.9, 0.9, 1)
        self.fonts:setFont("sectionFont")
        lg.printf("DIFFICULTY", 0, startY + 10, self.screenWidth, "center")
        lg.printf("CHARACTER CLASS", 0, startY + 90, self.screenWidth, "center")

        drawOptionSection(self, "difficulty")
        drawOptionSection(self, "character")
        drawOptionSection(self, "navigation")
    end

    lg.setColor(0.9, 0.7, 0.2, 0.6)
    self.fonts:setFont("smallFont")
    lg.printf("© 2025 JERICHO CROSBY - JERICRAFT: DUNGEON CRAWLER", 10, screenHeight - 30, screenWidth - 20, "right")
end

function Menu:handleClick(x, y, state)
    local buttons = state == "menu" and self.menuButtons or self.optionsButtons

    for _, button in ipairs(buttons) do
        if x >= button.x and x <= button.x + button.width and
            y >= button.y and y <= button.y + button.height then
            return button.action
        end
    end

    -- Check help button
    if state == "menu" then
        if self.helpButton and x >= self.helpButton.x and x <= self.helpButton.x + self.helpButton.width and
            y >= self.helpButton.y and y <= self.helpButton.y + self.helpButton.height then
            self.showHelp = true
            return "help"
        end

        if self.showHelp then
            self.showHelp = false
            return "help_close"
        end
    end

    return nil
end

function Menu:setDifficulty(difficulty) self.difficulty = difficulty end

function Menu:getDifficulty() return self.difficulty end

function Menu:setCharacter(character) self.character = character end

function Menu:getCharacter() return self.character end

function Menu:setScreenSize(width, height)
    self.screenWidth, self.screenHeight = width, height
    updateButtonPositions(self)
    updateOptionsButtonPositions(self)
end

return Menu
