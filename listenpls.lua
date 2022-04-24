local eve = require("botutils")
local robot = require("robot")
local computer = require("computer")
local event = require("event")
local component = require("component")

-- YEET THIS SHIT WORKING
local invController = component.inventory_controller
local geolyzer = component.geolyzer

local keyToPerform = "stop"

local savedPositions = {
  ["storage"] = eve.getConfig("posStorage"),
  ["charging"] = eve.getConfig("posCharging")
}

local networkPass = "t?aeWwZd36_A6[Yf"
event.listen("modem_message", function(_, _, from, port, _, message)
  local colonIndex = message:find(":")
  if port == eve.getConfig("listenPort") and colonIndex ~= nil and message:sub(1, colonIndex-1) == networkPass then
    keyToPerform = message:sub(colonIndex+1)
    eve.say("I'm performing " .. keyToPerform)
  end
end )

local function checkLowPower(percentMod)
  percentMod = percentMod or 0
  if eve.getPowerPercent() <= eve.getConfig("lowPowerPercent")+percentMod then
    keyToPerform = "gotocharging"
    eve.say("LOW POWER: Automatically going to charging station.")
    return true
  end
  return false
end

local function checkInvFull(maxSlot)
  maxSlot = maxSlot or robot.inventorySize()
  if invController.getStackInInternalSlot(maxSlot) ~= nil then
    keyToPerform = "gotostorage"
    eve.say("INV FULL: Automatically storing in storage chest.")
    return true
  end
  return false
end

local validFuncs = {
  ["stop"] = function() os.sleep(5) end,
  ["unloadall"] = function()
    for i=3,robot.inventorySize() do
      robot.select(i)
      robot.dropUp()
    end
    robot.select(1)
    eve.multipleMove(robot.down, 1)
    if not checkLowPower(eve.getConfig("lowPowerPercent")) then
      if eve.savedPosValid(savedPositions["quarry"]) then
        keyToPerform = "gotoquarry"
      else
        keyToPerform = "stop"
      end
    end
  end,
  ["gotostorage"] = function()
    local x, y, z = component.navigation.getPosition()
    if savedPositions["quarry"] ~= nil and savedPositions["quarry"]["y"] == nil then savedPositions["quarry"]["y"] = y end
    while keyToPerform == "gotostorage" do
      if eve.gotoPoint(savedPositions["storage"], false) then
        keyToPerform = "unloadall"
      end
      os.sleep(0)
    end
  end,
  ["gotocharging"] = function()
    local x, y, z = component.navigation.getPosition()
    if savedPositions["quarry"] ~= nil and savedPositions["quarry"]["y"] == nil then savedPositions["quarry"]["y"] = y end
    while keyToPerform == "gotocharging" do
      if eve.gotoPoint(savedPositions["charging"], false) then
        if eve.getPowerPercent() >= 0.995 then
          eve.multipleMove(robot.down, 4)
          if not checkInvFull(math.floor(robot.inventorySize()/2)) then
            if eve.savedPosValid(savedPositions["quarry"]) then
              keyToPerform = "gotoquarry"
            else
              keyToPerform = "stop"
            end
          end
        end
        os.sleep(5)
      end
      os.sleep(0)
    end
  end,
  ["gotoquarry"] = function()
    if eve.savedPosValid(savedPositions["quarry"]) then
      while keyToPerform == "gotoquarry" do
        if eve.gotoPoint(savedPositions["quarry"], true) then
          keyToPerform = "minequarry"
          eve.say("I'm performing minequarry")
        end
        os.sleep(0)
      end
    else
      keyToPerform = "stop"
      eve.say("No saved quarry location found.")
    end
  end,
  ["minequarry"] = function()
    local startPosX, startPosY, startPosZ = component.navigation.getPosition()
    savedPositions["quarry"] = { ["x"] = startPosX, ["z"] = startPosZ, ["facingNum"] = component.navigation.getFacing() }
    
    local magicNumber = eve.getConfig("magicNumber")
    local useLeft = true
    local rowsMined = 0
    while keyToPerform == "minequarry" do
      local numMined = 0
      repeat
        if checkInvFull() or checkLowPower() then os.sleep(0) break end
        local blockBelow = geolyzer.analyze(0)
        local blockBelowName = blockBelow["name"]
        local blockBelowIsLiquid = blockBelow["harvestLevel"] == -1
        if blockBelowName == "minecraft:air" then
          robot.placeDown()
        elseif blockBelowName == "minecraft:dirt" or blockBelowName == "minecraft:gravel" then
          robot.swingDown()
          robot.placeDown()
        elseif blockBelowIsLiquid then
          robot.select(2)
          robot.placeDown()
          robot.swingDown()
          robot.select(1)
          robot.placeDown()
        end
        robot.swingDown()
        numMined = numMined+1
        if numMined < magicNumber then
          eve.multipleMove(robot.forward, 3, true)
        end
        os.sleep(0)
      until(numMined >= magicNumber)
      rowsMined = rowsMined+1
      eve.quarryTurn(useLeft)
      if rowsMined < magicNumber then
        eve.multipleMove(robot.forward, 3, true)
        eve.quarryTurn(useLeft)
        useLeft = not useLeft
      else
        local currX, currY, currZ = component.navigation.getPosition()
        if currY > 6 then
          eve.quarryTurn(useLeft)
          eve.multipleMove(robot.down, 1)
          rowsMined = 0
        else
          savedPositions["quarry"] = nil
          keyToPerform = "gotocharging"
          eve.say("Y5 REACHED: Going back to charging station.")
        end
      end
    end
  end
}

local function perform()
  eve.say("I'm listening..")
  computer.beep()
  
  component.modem.open(eve.getConfig("listenPort"))
  
  while keyToPerform ~= "completestop" do
    validFuncs[keyToPerform]()
    os.sleep(0)
  end
end

perform()