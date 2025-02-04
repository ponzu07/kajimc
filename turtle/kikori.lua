-- アイテムの定義
BIRCH_SAPLING = "minecraft:birch_sapling"  -- 白樺の苗木
BIRCH_LOG = "minecraft:birch_log"          -- 白樺の原木
COBBLESTONE = "minecraft:cobblestone"      -- 丸石
CHEST = "minecraft:chest" -- チェスト
STICK = "minecraft:stick" -- 木の棒
BONE_MEAL_ID = "minecraft:bone_meal" -- 骨粉

ROW_COUNT = 5
ALL_COUNT = 15
ueta = 0

-- 指定されたアイテムIDのスロットを探して選択する
function findItem(itemId)
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and item.name == itemId then
            turtle.select(slot)
            return true
        end
    end
    return false
end

-- 指定されたアイテムIDを移動する
function dropItem (itemId)
    if findItem (itemId) then
        turtle.drop()
        return true
    else
        return false
    end
end

-- 骨粉が手持ちにあれば使用する。
function useBoneMeal()
    if findItem("minecraft:bone_meal") then
        turtle.place()
        return true
    else
        return false
    end
end

-- 木を上方向に向かって切る
function kikori()
    if not turtle.dig() then return false end
    if not turtle.forward() then return false end
    local k_count = 0
    
    while true do
        local success, data = turtle.inspectUp()
        if success and data and data.name == BIRCH_LOG then
            if not turtle.digUp() then break end
            if not turtle.up() then break end
            k_count = k_count + 1
        else
            -- 地上に戻る
            for i = 1, k_count do
                if not turtle.down() then break end
            end
            if not turtle.back() then return false end
            ueru()
            break
        end
    end
    return true
end

-- 苗木を植える
function ueru()
    if findItem(BIRCH_SAPLING) then
        if turtle.place() then
            ukai()
            return true
        end
    end
    return false
end

-- 次の位置に移動（障害物があれば回避）
function ukai()
    if not turtle.up() then return false end
    
    -- 前方の移動（2ブロック）で障害物があれば掘る
    for i = 1, 2 do
        if turtle.detect() then
            turtle.dig()
        end
        if not turtle.forward() then return false end
    end
    
    if not turtle.down() then return false end
    return true
end

-- 安全な前進（障害物があれば掘る）
function safeForward()
    if turtle.detect() then
        local success, block = turtle.inspect()
        if success and block then
            if block.name == BIRCH_LOG then
                turtle.dig()
            end
        end
    end
    return turtle.forward()
end

-- メインプログラム

print("Current inventory:")

local sayuu_f = 1
safeForward() -- 最初の一歩

while true do
    -- エリアの終了判定
    if ueta == ALL_COUNT then
        local success, block = turtle.inspect()
        if success and block and block.name == CHEST then
            dropItem(BIRCH_LOG)
            dropItem(STICK)
        end
        turtle.turnRight()
        turtle.turnRight()
        ueta = 0
    end
    
    -- 苗木の確認
    if not findItem(BIRCH_SAPLING) then
        print("Error: No saplings left")
        break
    end
    
    -- 列の終わりの処理
    if ueta ~= 0 and ueta % ROW_COUNT == 0 then
        safeForward()
        
        if sayuu_f == 1 then
            turtle.turnRight()
            for i = 1, 6 do
                safeForward()
            end
            turtle.turnRight()
        else
            turtle.turnLeft()
            for i = 1, 6 do
                safeForward()
            end
            turtle.turnLeft()
        end
        sayuu_f = -sayuu_f
    end
    
    safeForward()
    turtle.suck()
    
    -- 丸石の確認と作業実行
    local success, block = turtle.inspectDown()
    if success and block and block.name == COBBLESTONE then
        -- 原木があれば伐採
        local front_success, front_block = turtle.inspect()
        if front_success and front_block and front_block.name == BIRCH_LOG then
            kikori()
        elseif not turtle.detect() then
            ueru()
        end
        
        -- 苗木があれば次の位置へ
        local sapling_success, sapling_block = turtle.inspect()
        if sapling_success and sapling_block and sapling_block.name == BIRCH_SAPLING then
            ukai()
        end
        
        ueta = ueta + 1
    end
    print("Total planted:", ueta)
end
