NAEGI = 16
MARUISHI = 2
GENBOKU = 3
ROW_COUNT = 5
ALL_COUNT = 15
ueta = 0

function kikori()
  turtle.dig()
  turtle.forward()
  k_count = 0
  while true do
    if turtle.compareUp() then
        turtle.digUp()
        turtle.up()
        k_count = k_count + 1
    else
        for i = 1, k_count do
            turtle.down()
        end
        turtle.back()
        ueru()
        break
    end
  end
end

function ueru()
    -- 苗木
    turtle.select(NAEGI)
    turtle.place()
    ukai()
end

function ukai()
    turtle.up()
    turtle.forward()
    turtle.forward()
    turtle.down()
end

turtle.refuel(1)
sayuu_f = 1
while true do
    -- 初期化
    if ueta == ALL_COUNT then
        turtle.turnRight()
        turtle.turnRight()
        ueta = 0
    end

    if ueta ~= 0 then
        if ueta % ROW_COUNT == 0 then
            turtle.forward()
            if sayuu_f == 1 then
                turtle.turnRight()
                for i = 1, 6 do
                 turtle.forward()
                 end
                turtle.turnRight()
            else
                turtle.turnLeft()
                for i = 1, 6 do
                    turtle.forward()
                end
                turtle.turnLeft()
            end
            sayuu_f = -sayuu_f
        end
    end
    turtle.forward()
    turtle.suck()
    -- 丸石
    turtle.select(MARUISHI)
    if turtle.compareDown() then
        -- 原木
        turtle.select(GENBOKU)
        if turtle.compare() then
            kikori()
        elseif not turtle.detect() then
            ueru()
        end
        turtle.select(NAEGI)
        if turtle.compare() then
            ukai()
        end
        ueta = ueta + 1
    end
end
