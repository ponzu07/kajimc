mon = peripheral.wrap("top")
mon.clear()

sp = peripheral.wrap("right")

while true do
  time = os.time()
  time_str = textutils.formatTime(time)

  mon.setCursorPos(1,1)
  mon.clearLine()
  mon.write(time_str)
  
  if time_str == "6:30 PM" then
    for i=1,10 do
        sp.playSound("minecraft:block.bell.use",1,5)
        sleep(0.3)
      end
  end

  sleep(1)
  
end
