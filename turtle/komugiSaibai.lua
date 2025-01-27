-- 設定
HATAKE_WIDTH = 18
HATAKE_HEIGHT = 18
SLEEP_TIME = 300
KEEP_SEEDS = 64

-- 方向の定義
DIRECTIONS = {
    NORTH = 0,
    EAST = 1,
    SOUTH = 2,
    WEST = 3
}

-- グローバル状態
local currentDirection = DIRECTIONS.NORTH
local currentX = 0
local currentY = 0
local hatakeMap = {}

-- マップ初期化
function initializeMap()
    hatakeMap = {}
    for y = 0, HATAKE_HEIGHT - 1 do
        hatakeMap[y] = {}
        for x = 0, HATAKE_WIDTH - 1 do
            hatakeMap[y][x] = {
                type = "unknown",
                lastChecked = 0
            }
        end
    end
    print("Map initialized")
end

-- 方向制御
function turnToDirection(targetDirection)
    while currentDirection ~= targetDirection do
        turtle.turnRight()
        currentDirection = (currentDirection + 1) % 4
    end
end

function updatePosition(moveForward)
    if moveForward then
        if currentDirection == DIRECTIONS.NORTH then
            currentY = currentY + 1
        elseif currentDirection == DIRECTIONS.SOUTH then
            currentY = currentY - 1
        elseif currentDirection == DIRECTIONS.EAST then
            currentX = currentX + 1
        elseif currentDirection == DIRECTIONS.WEST then
            currentX = currentX - 1
        end
    end
end

-- インベントリ管理
function hasEmptySlot()
    for slot = 1, 16 do
        if turtle.getItemCount(slot) == 0 then
            return true
        end
    end
    return false
end

function findSeedSlot()
    for slot = 1, 16 do
        turtle.select(slot)
        local data = turtle.getItemDetail()
        if data and data.name == "minecraft:wheat_seeds" then
            return slot
        end
    end
    return nil
end

function countSeeds()
    local total = 0
    for slot = 1, 16 do
        turtle.select(slot)
        local data = turtle.getItemDetail()
        if data and data.name == "minecraft:wheat_seeds" then
            total = total + turtle.getItemCount()
        end
    end
    return total
end

-- チェストの検出と収納処理
function detectChest()
    local success, data = turtle.inspect()
    return success and data.name:find("chest")
end

function storeItems()
    print("Storing items...")
    local originalDirection = currentDirection
    
    -- 初期位置でのチェスト検知（南向き）
    turnToDirection(DIRECTIONS.SOUTH)
    if not detectChest() then
        print("Error: Chest not found")
        turnToDirection(originalDirection)
        return false
    end

    -- アイテムの収納
    for slot = 1, 16 do
        turtle.select(slot)
        local data = turtle.getItemDetail()
        if data then
            -- 小麦と余分な種を収納
            if data.name == "minecraft:wheat" then
                turtle.drop()
            elseif data.name == "minecraft:wheat_seeds" then
                local count = turtle.getItemCount()
                if count > KEEP_SEEDS then
                    turtle.drop(count - KEEP_SEEDS)
                end
            end
        end
    end
    
    -- 元の向きに戻す
    turnToDirection(originalDirection)
    print("Items stored successfully")
    return true
end

-- 種の補充
function refillSeeds()
    local currentSeeds = countSeeds()
    if currentSeeds < KEEP_SEEDS then
        print("Refilling seeds...")
        turnToDirection(DIRECTIONS.SOUTH)
        if detectChest() then
            local emptySlot = nil
            for slot = 1, 16 do
                if turtle.getItemCount(slot) == 0 then
                    emptySlot = slot
                    break
                end
            end
            
            if emptySlot then
                turtle.select(emptySlot)
                turtle.suck(KEEP_SEEDS - currentSeeds)
            end
        end
        turnToDirection(DIRECTIONS.NORTH)
    end
end

-- ブロック検査と更新
function inspectAndUpdateMap()
    local success, data = turtle.inspectDown()
    if success then
        hatakeMap[currentY][currentX] = {
            type = data.name,
            age = data.state and data.state.age or nil,
            lastChecked = os.time()
        }
    else
        hatakeMap[currentY][currentX] = {
            type = "empty",
            lastChecked = os.time()
        }
    end
end

function isWheatMature()
    local success, data = turtle.inspectDown()
    if success and data.name == "minecraft:wheat" then
        return data.state.age == 7
    end
    return false
end

-- 移動制御
function moveForward()
    if turtle.forward() then
        updatePosition(true)
        inspectAndUpdateMap()
        return true
    end
    return false
end

function moveToStart()
    print("Returning to start position...")
    
    -- X座標を0に
    if currentX > 0 then
        turnToDirection(DIRECTIONS.WEST)
        for i = 1, currentX do
            moveForward()
        end
    end
    
    -- Y座標を0に
    if currentY > 0 then
        turnToDirection(DIRECTIONS.SOUTH)
        for i = 1, currentY do
            moveForward()
        end
    end
    
    -- 北向きに
    turnToDirection(DIRECTIONS.NORTH)
    print("Arrived at start position")
end

-- 農作業
function processCurrentBlock()
    inspectAndUpdateMap()
    
    -- インベントリが一杯なら収納
    if not hasEmptySlot() then
        print("Inventory full")
        moveToStart()
        storeItems()
        refillSeeds()
    end
    
    local block = hatakeMap[currentY][currentX]
    if block.type == "minecraft:wheat" and block.age == 7 then
        turtle.select(1)
        if turtle.digDown() then
            local seedSlot = findSeedSlot()
            if not seedSlot then
                moveToStart()
                refillSeeds()
                seedSlot = findSeedSlot()
            end
            
            if seedSlot then
                turtle.select(seedSlot)
                turtle.placeDown()
            end
        end
    elseif block.type == "minecraft:farmland" and not turtle.detectDown() then
        local seedSlot = findSeedSlot()
        if not seedSlot then
            moveToStart()
            refillSeeds()
            seedSlot = findSeedSlot()
        end
        
        if seedSlot then
            turtle.select(seedSlot)
            turtle.placeDown()
        end
    end
end

-- メイン処理
function farm()
    local isMovingRight = true
    currentX = 0
    currentY = 0
    
    turnToDirection(DIRECTIONS.NORTH)
    inspectAndUpdateMap()
    
    for y = 0, HATAKE_HEIGHT - 1 do
        processCurrentBlock()
        
        for x = 1, HATAKE_WIDTH - 1 do
            if isMovingRight then
                turnToDirection(DIRECTIONS.EAST)
            else
                turnToDirection(DIRECTIONS.WEST)
            end
            moveForward()
            processCurrentBlock()
        end
        
        if y < HATAKE_HEIGHT - 1 then
            turnToDirection(DIRECTIONS.NORTH)
            moveForward()
            isMovingRight = not isMovingRight
        end
    end
    
    -- 巡回終了時の収納処理
    moveToStart()
    storeItems()
    refillSeeds()
end

-- メインループ
print("Starting automated wheat farming system")
print("Keeping " .. KEEP_SEEDS .. " seeds in inventory")
initializeMap()

while true do
    print("Starting farm inspection")
    farm()
    print("Sleeping for " .. SLEEP_TIME .. " seconds")
    sleep(SLEEP_TIME)
end
