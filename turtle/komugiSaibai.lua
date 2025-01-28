-- 基本設定
local Config = {
    HATAKE_WIDTH = 18,
    HATAKE_HEIGHT = 18,
    SLEEP_TIME = 300,
    KEEP_SEEDS = 64,
    DIRECTIONS = {
        NORTH = 0,
        EAST = 1,
        SOUTH = 2,
        WEST = 3
    },
    ITEMS = {
        WHEAT = "minecraft:wheat",
        WHEAT_SEEDS = "minecraft:wheat_seeds",
        FARMLAND = "minecraft:farmland"
    }
}

-- 方向制御モジュール
local DirectionController = {
    -- 指定した方向に向きを変える
    -- @param current 現在の方向
    -- @param targetDirection 目標の方向
    -- @return 新しい方向
    turnTo = function(current, targetDirection)
        local newDirection = current
        while newDirection ~= targetDirection do
            turtle.turnRight()
            newDirection = (newDirection + 1) % 4
        end
        return newDirection
    end
}

-- 位置制御モジュール
local PositionController = {
    -- 位置を更新する
    -- @param x 現在のX座標
    -- @param y 現在のY座標
    -- @param direction 現在の方向
    -- @param moveForward 前進したかどうか
    -- @return 新しいX座標, 新しいY座標
    updatePosition = function(x, y, direction, moveForward)
        if not moveForward then return x, y end
        
        if direction == Config.DIRECTIONS.NORTH then
            return x, y + 1
        elseif direction == Config.DIRECTIONS.SOUTH then
            return x, y - 1
        elseif direction == Config.DIRECTIONS.EAST then
            return x + 1, y
        elseif direction == Config.DIRECTIONS.WEST then
            return x - 1, y
        end
        return x, y
    end
}

-- インベントリ管理モジュール
local InventoryController = {
    -- 指定したアイテムの合計数をカウント
    -- @param itemId アイテムID
    -- @return 合計数
    countItem = function(itemId)
        local total = 0
        for slot = 1, 16 do
            turtle.select(slot)
            local data = turtle.getItemDetail()
            if data and data.name == itemId then
                total = total + turtle.getItemCount()
            end
        end
        return total
    end,
    
    -- 指定したアイテムのスロットを検索
    -- @param itemId アイテムID
    -- @return スロット番号、見つからない場合はnil
    findItemSlot = function(itemId)
        for slot = 1, 16 do
            turtle.select(slot)
            local data = turtle.getItemDetail()
            if data and data.name == itemId then
                return slot
            end
        end
        return nil
    end,
    
    -- 空きスロットの確認
    -- @return 空きスロットがある場合はtrue
    hasEmptySlot = function()
        for slot = 1, 16 do
            if turtle.getItemCount(slot) == 0 then
                return true
            end
        end
        return false
    end,
    
    -- 指定したアイテムを指定した数だけ保持し、残りを収納
    -- @param itemId アイテムID
    -- @param keepAmount 保持する数
    storeExcessItem = function(itemId, keepAmount)
        for slot = 1, 16 do
            turtle.select(slot)
            local data = turtle.getItemDetail()
            if data and data.name == itemId then
                local count = turtle.getItemCount()
                if count > keepAmount then
                    turtle.drop(count - keepAmount)
                end
            end
        end
    end
}

-- チェスト操作モジュール
local ChestController = {
    -- チェストの検出
    -- @return チェストが検出された場合はtrue
    detectChest = function()
        local success, data = turtle.inspect()
        return success and data.name:find("chest")
    end,
    
    -- アイテムの収納
    -- @param rules 収納ルール（アイテムIDと保持数のテーブル）
    storeItems = function(rules)
        for slot = 1, 16 do
            turtle.select(slot)
            local data = turtle.getItemDetail()
            if data then
                local keepAmount = rules[data.name] or 0
                local count = turtle.getItemCount()
                if count > keepAmount then
                    turtle.drop(count - keepAmount)
                end
            end
        end
    end,
    
    -- アイテムの補充
    -- @param itemId アイテムID
    -- @param targetAmount 目標の数
    refillItem = function(itemId, targetAmount)
        local currentAmount = InventoryController.countItem(itemId)
        if currentAmount < targetAmount then
            local emptySlot = nil
            for slot = 1, 16 do
                if turtle.getItemCount(slot) == 0 then
                    emptySlot = slot
                    break
                end
            end
            
            if emptySlot then
                turtle.select(emptySlot)
                turtle.suck(targetAmount - currentAmount)
            end
        end
    end
}

-- 畑マップ管理モジュール
local FieldMap = {
    -- マップの初期化
    -- @param width 幅
    -- @param height 高さ
    -- @return 初期化されたマップ
    initialize = function(width, height)
        local map = {}
        for y = 0, height - 1 do
            map[y] = {}
            for x = 0, width - 1 do
                map[y][x] = {
                    type = "unknown",
                    lastChecked = 0
                }
            end
        end
        return map
    end,
    
    -- ブロック情報の更新
    -- @param map マップデータ
    -- @param x X座標
    -- @param y Y座標
    -- @return 更新されたブロック情報
    updateBlock = function(map, x, y)
        local success, data = turtle.inspectDown()
        if success then
            map[y][x] = {
                type = data.name,
                age = data.state and data.state.age or nil,
                lastChecked = os.time()
            }
        else
            map[y][x] = {
                type = "empty",
                lastChecked = os.time()
            }
        end
        return map[y][x]
    end
}

-- 移動制御モジュール
local MovementController = {
    -- 指定した位置への移動
    -- @param current 現在の位置と方向の情報
    -- @param target 目標の位置情報
    -- @return 成功した場合はtrue
    moveTo = function(current, target)
        -- X軸の移動
        if current.x ~= target.x then
            local direction = current.x < target.x and Config.DIRECTIONS.EAST or Config.DIRECTIONS.WEST
            current.direction = DirectionController.turnTo(current.direction, direction)
            while current.x ~= target.x do
                if turtle.forward() then
                    current.x = current.x + (direction == Config.DIRECTIONS.EAST and 1 or -1)
                else
                    return false
                end
            end
        end
        
        -- Y軸の移動
        if current.y ~= target.y then
            local direction = current.y < target.y and Config.DIRECTIONS.NORTH or Config.DIRECTIONS.SOUTH
            current.direction = DirectionController.turnTo(current.direction, direction)
            while current.y ~= target.y do
                if turtle.forward() then
                    current.y = current.y + (direction == Config.DIRECTIONS.NORTH and 1 or -1)
                else
                    return false
                end
            end
        end
        
        return true
    end
}

-- 農作業制御モジュール
local FarmingController = {
    -- ブロックの処理
    -- @param block ブロック情報
    -- @return 処理が成功した場合はtrue
    processBlock = function(block)
        if block.type == Config.ITEMS.WHEAT and block.age == 7 then
            turtle.select(1)
            if turtle.digDown() then
                local seedSlot = InventoryController.findItemSlot(Config.ITEMS.WHEAT_SEEDS)
                if seedSlot then
                    turtle.select(seedSlot)
                    return turtle.placeDown()
                end
            end
        elseif block.type == Config.ITEMS.FARMLAND and not turtle.detectDown() then
            local seedSlot = InventoryController.findItemSlot(Config.ITEMS.WHEAT_SEEDS)
            if seedSlot then
                turtle.select(seedSlot)
                return turtle.placeDown()
            end
        end
        return false
    end
}

-- メインプログラム
print("Starting automated wheat farming system")
print("Keeping " .. Config.KEEP_SEEDS .. " seeds in inventory")

-- 状態の初期化
local state = {
    map = FieldMap.initialize(Config.HATAKE_WIDTH, Config.HATAKE_HEIGHT),
    position = {
        x = 0,
        y = 0,
        direction = Config.DIRECTIONS.NORTH
    }
}

while true do
    print("Starting farm inspection")
    
    -- 農作業の実行
    for y = 0, Config.HATAKE_HEIGHT - 1 do
        for x = 0, Config.HATAKE_WIDTH - 1 do
            -- 移動
            MovementController.moveTo(state.position, {x = x, y = y})
            
            -- ブロックの更新と処理
            local block = FieldMap.updateBlock(state.map, x, y)
            FarmingController.processBlock(block)
            
            -- インベントリ管理
            if not InventoryController.hasEmptySlot() then
                MovementController.moveTo(state.position, {x = 0, y = 0})
                state.position.direction = DirectionController.turnTo(state.position.direction, Config.DIRECTIONS.SOUTH)
                
                if ChestController.detectChest() then
                    ChestController.storeItems({
                        [Config.ITEMS.WHEAT] = 0,
                        [Config.ITEMS.WHEAT_SEEDS] = Config.KEEP_SEEDS
                    })
                    ChestController.refillItem(Config.ITEMS.WHEAT_SEEDS, Config.KEEP_SEEDS)
                end
            end
        end
    end
    
    -- 開始位置に戻る
    MovementController.moveTo(state.position, {x = 0, y = 0})
    print("Sleeping for " .. Config.SLEEP_TIME .. " seconds")
    sleep(Config.SLEEP_TIME)
end
