local eve = {}
local computer = require("computer")
local robot = require("robot")
local component = require("component")

local configVars = require("config")
function eve.getConfig(str)
  return configVars[str]
end

function eve.savedPosValid(posT)
  if posT ~= nil then
    if posT["x"] ~= nil and posT["y"] ~= nil and posT["z"] ~= nil then
      return true
    end
  end
  return false
end

local turnToUse = { [true] = robot.turnLeft, [false] = robot.turnRight }
function eve.quarryTurn(useLeft)
  turnToUse[useLeft]()
end

local facingNums = {
  ["n"] = 2,
  ["e"] = 5,
  ["s"] = 3,
  ["w"] = 4
}
function eve.faceNum(facingNum)
  while component.navigation.getFacing() ~= facingNum do robot.turnRight() end
end
function eve.face(facingStr)
  eve.faceNum(facingNums[facingStr])
end

function eve.multipleMove(moveFunc, times, doBreak, breakFunc)
  doBreak = doBreak or false
  breakFunc = breakFunc or robot.swing
  local amountMoved = 0
  repeat
    if doBreak then breakFunc() end
    if moveFunc() then amountMoved = amountMoved+1 end
  until(amountMoved >= times)
end

local function moveXZ(facingNumNeeded)
  if component.navigation.getFacing() ~= facingNumNeeded then
    robot.turnRight()
  else
    local blockMoveToName = component.geolyzer.analyze(3)["name"]
    if blockMoveToName ~= "OpenComputers:robot" then robot.swing() end
    robot.forward()
  end
end
local function moveY(up)
  if up then
    local blockMoveToName = component.geolyzer.analyze(1)["name"]
    if blockMoveToName ~= "OpenComputers:robot" then robot.swingUp() end
    robot.up()
  else
    local blockMoveToName = component.geolyzer.analyze(0)["name"]
    if blockMoveToName ~= "OpenComputers:robot" then robot.swingDown() end
    robot.down()
  end
end
function eve.gotoPoint(posT, yFirst)
  if eve.savedPosValid(posT) then
    local currPosX, currPosY, currPosZ = component.navigation.getPosition()
    local relX, relY, relZ = posT["x"]-currPosX, posT["y"]-currPosY, posT["z"]-currPosZ
    if relY ~= 0 and yFirst then moveY(relY>0)
    elseif relX > 0 then moveXZ(5)
    elseif relX < 0 then moveXZ(4)
    elseif relZ > 0 then moveXZ(3)
    elseif relZ < 0 then moveXZ(2)
    elseif relY ~= 0 and not yFirst then moveY(relY>0)
    else
      if posT["facingNum"] ~= nil then eve.faceNum(posT["facingNum"]) end
      return true
    end
  else
    return nil
  end
  return false
end

function eve.say(str)
 os.execute("clear")
  print(str)
end

function eve.getPowerPercent()
  local percent = computer.energy() / computer.maxEnergy()
  return percent
end

return eve