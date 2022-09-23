-- // Modules \\ --
local tween = require 'tween'

-- // Variables \\ --
local width, height = love.window.getDesktopDimensions(1)

floor = math.floor

local difficulties = {
    BEGINNER = 12.35;
    INTERMEDIATE = 15.63;
    EXPERT = 20.63;
}

local surrounding = {
    {-1, 1};
    {0, 1};
    {1, 1};
    {1, 0};
    {1, -1};
    {0, -1};
    {-1, -1};
    {-1, 0};
}

local limitSurrounding = {
    {0, -1};
    {0, 1};
    {-1, 0};
    {1, 0};
}

-- // Custom Functions \\ --
function string.split (inputstr, sep)
    if sep == nil then sep = "%s" end

    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

activeTasks = {}
function delay(t, f, ...)
  table.insert(activeTasks, {
    f = f; -- task function
    e = 0; -- elapsed time
    t = t; -- time till function runs
    args = {...};
  })
end

function GetDictionaryLength(dict)
    local c=0;for k,v in pairs(dict) do if v == 1 then c=c+1 end end; return c
end

checkedTiles = {}
function checkNeighbours(x, y, i)
    if checkedTiles[x .. ":" .. y] then return end
    checkedTiles[x .. ":" .. y] = true

    if x > -1 and x < grid.sizeX and y > -1 and y < grid.sizeY and not mines[x .. ":" .. y] then
        for _, offset in ipairs(limitSurrounding) do

            local mineCount = 0
            for _, o in ipairs(surrounding) do
                if mines[x+offset[1]+o[1] .. ":" .. y+offset[2]+o[2]] then
                    mineCount = mineCount + 1
                end
            end

            if mineCount == 0 and not mines[x+offset[1] .. ":" .. y+offset[2]] then
                for _, o in ipairs(surrounding) do
                    if not mines[x+offset[1]+o[1] .. ":" .. y+offset[2]+o[2]] then

                        local str = x+offset[1]+o[1] .. ":" .. y+offset[2]+o[2]

                        tween.create(1, 0, {time = 0.3, style = "easeOutQuad"}, str)

                        delay(0.3, function(str)
                            hasRevealed[str] = true
                        end, str)

                        --hasRevealed[x+offset[1]+o[1] .. ":" .. y+offset[2]+o[2]] = true
                    end
                end

                tween.create(1, 0, {time = 0.3, style = "easeOutQuad"}, x+offset[1] .. ":" .. y+offset[2])
                delay(0.2, function(str)
                    hasRevealed[str] = true
                end, x+offset[1] .. ":" .. y+offset[2])

                --hasRevealed[x+offset[1] .. ":" .. y+offset[2]] = true
                checkNeighbours(x+offset[1], y+offset[2], i + 1)
            end
        end
    end
end

-- // LOVE2D Functions \\ --
function love.mousepressed(mX, mY, button)
    if gameData.hasFinished then return end

    mTilePosX, mTilePosY = floor((mX-startX)/tileSize), floor((mY-startY)/tileSize)

    if button == 1 then
        if (mX > startX and mX < startX + grid.sizeX*tileSize) and (mY > startY and mY < startY + grid.sizeY*tileSize) then

            -- generate mines
            if not hasGeneratedMines then
                hasGeneratedMines = true

                for i = 1, gameData.mineAmount do
                    local minePosX, minePosY
                    repeat
                        minePosX, minePosY = love.math.random(0, grid.sizeX-1), love.math.random(0, grid.sizeY-1)
                    until not mines[minePosX..":"..minePosY] and minePosX ~= mTilePosX and minePosY ~= mTilePosY

                    mines[minePosX..":"..minePosY] = true
                end
            end

            if mines[mTilePosX .. ":" .. mTilePosY] then
                gameData.hasFinished = true
            end
            
            tween.create(1, 0, {time = 0.3, style = "easeOutQuad"}, mTilePosX..":"..mTilePosY)
            delay(0.2, function(str)
                hasRevealed[str] = true
            end, mTilePosX .. ":" .. mTilePosY)

            checkedTiles = {}
            checkNeighbours(mTilePosX, mTilePosY, 0)
        end
    elseif button == 2 and hasGeneratedMines then

        if flagged[mTilePosX .. ":" .. mTilePosY] then
            flagged[mTilePosX .. ":" .. mTilePosY] = nil
            gameData.flagsLeft = gameData.flagsLeft + 1
        elseif gameData.flagsLeft > 0 then
            flagged[mTilePosX .. ":" .. mTilePosY] = true
            gameData.flagsLeft = gameData.flagsLeft - 1
        end

        local flaggedAll = true
        for minePos in pairs(mines) do
            if not flagged[minePos] then
                flaggedAll = false
            end
        end

        if flaggedAll then
            gameData.hasFinished = true
            gameData.wonGame = true
        end

    end
end

function love.load()
    love.window.setFullscreen(true)
    love.graphics.setBackgroundColor(22/255, 25/255, 32/255)
    love.graphics.setDefaultFilter('nearest', 'nearest')

    tileSize = 30
    grid = {
        sizeX = 10;
        sizeY = 10;
    }

    startX, startY = width/2-grid.sizeX/2*tileSize, height/2-grid.sizeY/2*tileSize

    hasRevealed = {}
    flagged = {}
    mines = {}
    hasGeneratedMines = false

    difficulty = "BEGINNER"
    mineNumber = math.floor(grid.sizeX * grid.sizeY * difficulties[difficulty]/100)

    gameData = {
        difficulty = difficulty;
        mineAmount = mineNumber;
        elapsedTime = 0;
        hasFinished = false;
        wonGame = false;
        flagsLeft = mineNumber;
    }

    FlagIcon = love.graphics.newImage("sprites/ui/FlagIcon.png")
    MineIcon = love.graphics.newImage("sprites/ui/MineIcon.png")

    testFont = love.graphics.newFont("fonts/momcake/bold.otf", 16)
    testFont:setFilter("nearest", "nearest")

    particles = {}

    gradient = love.graphics.newShader [[
        extern vec2 screenSize;

        vec4 effect(vec4 color, Image image, vec2 uvs, vec2 screen_coords) {
            float t = screen_coords.y/screenSize.y;
            vec4 pixel = Texel(image, uvs) * color;

            return vec4(pixel.r, pixel.g, pixel.b, mix(0, 1, t));
        }
    ]]

    testTween = tween.create(0, width-200, {time = 5, style = "easeOutQuad"})
end

function love.update(dt)
    if not gameData.hasFinished then
        gameData.elapsedTime = gameData.elapsedTime + dt
    end

    if math.random(1, 10) == 1 then
        randomPosX = math.random(100, width-100);

        canCreate = true
        for _, particle in ipairs(particles) do
            if math.abs(particle.posX - randomPosX) < particle.size*2 then
                canCreate = false
            end
        end

        if canCreate then
            table.insert(particles, {
                rotation = 0;
                posX = randomPosX;
                posY = height;
                speed = math.random(1, 3);
                size = math.random(5, 20);
            })
        end
    end

    for i, particle in ipairs(particles) do
        particle.rotation = particle.rotation + math.rad(2)
        particle.posY = particle.posY - particle.speed

        if particle.posY < 0 - particle.size then
            table.remove(particles, i)
        end
    end

    -- delayed tasks update handling
    for i, task in ipairs(activeTasks) do
        task.e = task.e + dt
        if task.e > task.t then
            table.remove(activeTasks, i)
            task.f(unpack(task.args))
        end
    end

    tween.update(dt)
end

boxPad = 10
function love.draw()
    love.graphics.setFont(testFont)

    gradient:send("screenSize", {width, height})
    love.graphics.setShader(gradient)
    love.graphics.setColor(42/255, 45/255, 52/255)
    love.graphics.rectangle("fill", 0, 0, width, height)
    love.graphics.setShader()

    love.graphics.setColor(1, 1, 1, 1)
    startX, startY = width/2-grid.sizeX/2*tileSize, height/2-grid.sizeY/2*tileSize

    -- drop shadow
    love.graphics.setColor(13/255, 14/255, 19/255, 0.7)
    love.graphics.rectangle("fill", startX-boxPad, startY+8+boxPad, grid.sizeX*tileSize+boxPad*2, grid.sizeY*tileSize, 10)

    -- background particle effects
    for _, particle in ipairs(particles) do
        love.graphics.push()
        love.graphics.setColor(1, 1, 1, 0.08)
        love.graphics.translate(particle.posX, particle.posY)
        love.graphics.rotate(particle.rotation)
        love.graphics.rectangle("fill", -particle.size/2, -particle.size/2, particle.size, particle.size)
        love.graphics.pop()
    end

    -- grid background
    love.graphics.setColor(36/255, 35/255, 49/255)
    love.graphics.rectangle("fill", startX-boxPad, startY-boxPad, grid.sizeX*tileSize+boxPad*2, grid.sizeY*tileSize+boxPad*2, 10)

    local font = love.graphics.getFont()

    love.graphics.setColor(61/255, 60/255, 76/255)
    for x = 0, grid.sizeX-1 do
        for y = 0, grid.sizeY-1 do

            if not hasRevealed[x..":"..y] then
                love.graphics.setColor(61/255, 60/255, 76/255)

                if floor((love.mouse:getX()-startX)/tileSize) == x and floor((love.mouse.getY()-startY)/tileSize) == y then
                    love.graphics.setColor(81/255, 80/255, 96/255)
                end

                local sizeTween = tween.value(x .. ":" .. y) or 1
                local sizeOffset = ( tileSize - (tileSize-2) * sizeTween ) / 2
                love.graphics.rectangle("fill", startX+x*tileSize+sizeOffset, startY+y*tileSize+sizeOffset, (tileSize-2)*sizeTween, (tileSize-2)*sizeTween, tileSize*0.2)

                if not gameData.hasFinished then
                    if flagged[x..":"..y] then
                        love.graphics.setColor(1, 1, 1)
                        local imageWidth, imageHeight = tileSize*0.6, tileSize*0.6
                        love.graphics.draw(FlagIcon, startX+x*tileSize+(tileSize-imageWidth)/2, startY+y*tileSize+(tileSize-imageHeight)/2, 0, imageWidth/FlagIcon:getWidth(), imageHeight/FlagIcon:getHeight())
                    end
                elseif mines[x..":"..y] then
                    love.graphics.setColor(1, 1, 1)
                    local imageWidth, imageHeight = tileSize*0.8, tileSize*0.8
                    love.graphics.draw(MineIcon, startX+x*tileSize+(tileSize-imageWidth)/2, startY+y*tileSize+(tileSize-imageHeight)/2, 0, imageWidth/MineIcon:getWidth(), imageHeight/MineIcon:getHeight())
                end
            else

                if mines[x..":"..y] then

                    love.graphics.setColor(1, 1, 1)
                    local imageWidth, imageHeight = tileSize*0.8, tileSize*0.8
                    love.graphics.draw(MineIcon, startX+x*tileSize+(tileSize-imageWidth)/2, startY+y*tileSize+(tileSize-imageHeight)/2, 0, imageWidth/MineIcon:getWidth(), imageHeight/MineIcon:getHeight())
                
                else
                    local mineCount = 0
                    for _, offset in ipairs(surrounding) do
                        if mines[x+offset[1] .. ":" .. y+offset[2] ] then
                            mineCount = mineCount + 1
                        end
                    end

                    local textWidth, textHeight = font:getWidth(tostring(mineCount)), font:getHeight(tostring(mineCount))

                    if mineCount > 0 then
                        love.graphics.setColor(1, 1, 1, 0.5)
                        love.graphics.print(mineCount, startX+x*tileSize+(tileSize-textWidth)/2, startY+y*tileSize+(tileSize-textHeight)/2)
                    end
                end

            end
        end
    end

    -- ui
   --[[if gameData.hasFinished then
        love.graphics.setColor(56/255, 54/255, 52/255)
        love.graphics.rectangle("fill", width/2-300/2, height/2-250/2, 300, 250, 5)
    end]]

    -- show timer
    love.graphics.setColor(1, 1, 1, 1)

    local eT = floor(gameData.elapsedTime)
    local formattedTime = ("%02i:%02i"):format(eT/60, eT%60)
    local textWidth, textHeight = font:getWidth(formattedTime), font:getHeight(formattedTime)

    love.graphics.print(formattedTime, startX+(grid.sizeX*tileSize-textWidth)/2, startY-40+(20-textHeight)/2)

    -- show difficulty

    local d = gameData.difficulty
    local textWidth, textHeight = font:getWidth(d), font:getHeight(d)
    love.graphics.print(d, startX+(grid.sizeX*tileSize-textWidth)/2, startY-80+(20-textHeight)/2)

    -- show flag amount
    local textWidth, textHeight = font:getWidth(tostring(gameData.flagsLeft)), font:getHeight(tostring(gameData.flagsLeft))

    love.graphics.draw(FlagIcon, startX+grid.sizeX*tileSize-FlagIcon:getWidth()+5, startY-38, 0, 0.7, 0.7)
    love.graphics.print(gameData.flagsLeft, startX+grid.sizeX*tileSize-FlagIcon:getWidth()-textWidth, startY-40+(20-textHeight)/2)

    -- show mine amount
    local textWidth, textHeight = font:getWidth(tostring(gameData.mineAmount)), font:getHeight(tostring(gameData.mineAmount))

    love.graphics.draw(MineIcon, startX-5, startY-40, 0, 1, 1)
    love.graphics.print(gameData.mineAmount, startX+MineIcon:getWidth(), startY-40+(20-textHeight)/2)

    --[[love.graphics.setColor(1, 0, 0)
    love.graphics.line(width/2, 0, width/2, height)
    love.graphics.line(0, height/2, width, height/2)]]

    --love.graphics.setColor(1, 1, 1, 1)
    --love.graphics.rectangle("fill", tween.value(testTween), height/2-100, 200, 200)
end