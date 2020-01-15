local levelColors = { [0]=colors.lightGray, colors.white, colors.orange, colors.red }
local levelNames = { "Debug", "Info", "Warning", "Error" } -- Translate?
local levels = { debug=0, info=1, warning=2, error=3 }

local function format(level, message, debugInfo, expression)
  if type(expression) ~= "string" then
    return message
  end

  level = type(level) == "string" and levels[level] or level

  local lvl = expression:match("%%l")
  while lvl do
      expression = expression:gsub("%%l", level)
      lvl = expression:match("%%l")
  end
  lvl = expression:match("%%L")
  while lvl do
      expression = expression:gsub("%%L", levelNames[level])
      lvl = expression:match("%%L")
  end

  local mc = expression:match("%%mc_(%a)")
  while mc do
    local e = ""
    if mc == "d" then -- day
      e = tostring(os.day())
    elseif mc == "D" then -- day time
      e = tostring(os.day()).." "..tostring(os.time())
    elseif mc == "h" then --hour 24
      e = string.format("%.2d", math.floor(os.time()))
    elseif mc == "i" then -- hour 12
      e = tostring(math.floor(os.time())%12)
    elseif mc == "m" then -- minute 00
      e = string.format("%.2d", math.floor(os.time()%1 * 60))
    elseif mc == "p" then -- am or pm
      e = os.time() < 12 and "am" or "pm"
    elseif mc == "r" then -- 12h clock
      local t = os.time()
      e = string.format("%.2d:%.2d %.2l", math.floor(t) % 12, math.floor(t%1 * 60), t < 12 and "am" or "pm")
    elseif mc == "R" then -- 24h clock
      local t = os.time()
      e = string.format("%.2d:%.2d", math.floor(t), math.floor(t%1 * 60))
    elseif mc == "s" then -- second 00
      e = string.format("%.2d", math.floor((time%1 * 60)%1 * 60))
    elseif mc == "t" then -- time
      e = tostring(os.time())
    elseif mc == "T" then -- 24h clock with seconds
      local t = os.time()
      e = string.format("%.2d:%.2d:%.2d", math.floor(t) % 12, math.floor(t%1 * 60), math.floor((t%1 * 60)%1 * 60))
    end
    expression = expression:gsub("%%mc_"..mc, e)
    mc = expression:match("%%mc_(%a)")
  end

  local cc = expression:match("%%cc_(%a)")
  local pos, rot
  while cc do
    local e = ""
    if cc == "c" then -- os.clock
      e = tostring(os.clock())
    elseif cc == "C" then -- Computer or Turtle type
      local a = term.native().isColor()
      local t = turtle
      if a and t then
          e = "at" -- Advanced turtle
      elseif a then
          e = "ac" -- Advanced computer
      elseif t then
          e = "tt" -- Turtle
      else
          e = "cc" -- Computer
      end
    elseif cc == "I" then -- Computer ID
      e = tostring(os.getComputerID())
    elseif cc == "L" then -- Computer Label
      e = os.getComputerLabel() or ""
    elseif cc == "p" then -- Position if saved or gps
      pos = pos or settings.get("position")
      e = pos and (pos.x..", "..pos.y..", "..pos.z) or ("xxx, yyy, zzz")
    elseif cc == "P" then -- Position if saved or gps
      pos = pos or settings.get("position")
      e = pos and ("X: "..pos.x..", Y: "..pos.y..", Z: "..pos.z) or ("X: xxx, Y: yyy, Z: zzz")
    elseif cc == "r" then -- Rotation
      rot = rot or settings.get("rotation")
      e = rot or "rr"
    elseif cc == "R" then -- Rotation
      rot = rot or settings.get("rotation")%360
      if rot then
        if rot == 0 then
          e = "South"
        elseif rot == 90 then
          e = "East"
        elseif rot == 180 then
          e = "North"
        elseif rot == 270 then
          e = "West"
        else
          e = "NSEW"
        end
      else
        e = "NSEW"
      end
    elseif cc == "V" then -- OS version
      e = tostring(os.version())
    elseif cc == "x" then -- X position
      pos = pos or settings.get("position")
      e = pos and tostring(pos.x) or "xxx"
    elseif cc == "y" then -- Y position
      pos = pos or settings.get("position")
      e = pos and tostring(pos.y) or "yyy"
    elseif cc == "z" then -- Z position
      pos = pos or settings.get("position")
      e = pos and tostring(pos.z) or "zzz"
    end
    expression = expression:gsub("%%cc_"..cc, e)
    cc = expression:match("%%cc_(%a)")
  end

  local dg = expression:match("%%!(%l)")
  local di = dg and debugInfo
  while dg do
    local e = ""
    if dg == "f" then
      e = di.short_src
    elseif dg == "l" then
      e = tostring(di.current_line)
    elseif dg == "n" then
      e = di.short_src:match("^(%.?[^.]+)")
    elseif dg == "v" then
      e = getfenv(dg.func)._VERSION or ""
    elseif dg == "t" then
      e = dg.traceback()
    end
    expression = expression:gsub("%%!"..dg, e)
    dg = expression:match("%%!(%l)")
  end

  if expression:match("%%@") then
    return os.date(expression:gsub("%%@", message))
  end

  return os.date(expression)..message
end

local function getLines(sText, width)
  local lines = {}
  local line = ""
  local x = 1
 
  local newLine = function ()
    lines[#lines+1] = line
    line = ""
    x = 2
  end
 
  local write = function (text)
    line = line..text
    x = x + #text
  end
 
  while #sText > 0 do
    local whitespace = sText:match("^[ \t]+")
    if whitespace then
      write( whitespace )
      sText = sText:sub(#whitespace + 1)
    end
 
    local newline = sText:match("^\n")
    if newline then
      newLine()
      sText = sText:sub(2)
    end
 
    local text = sText:match("^[^ \t\n]+")
    if text then
      sText = sText:sub(#text + 1)
      if #text > width then
        while #text > 0 do
          if x > width then
            newLine()
          end
          line = line..text
          text = text:sub(width - x + 2)
          x = x + #text
        end
      else
        if x + #text - 1 > width then
          newLine()
        end
        write(text)
      end
    end
  end
 
  if line:len() > 0 then
    lines[#lines+1] = line
  end
 
  return lines
end

local function show(terminal, level, message)
  local lastColor = nil
  if term.isColor() then
    lastColor = terminal.getTextColor()
    terminal.setTextColor(levelColors[level])
  end

  local width, height = terminal.getSize()
  local x, y = terminal.getCursorPos()

  local newLine = function()
    if y + 1 > height then
      terminal.scroll(1)
      y = height
    else
      y = y + 1
    end
  end

  if terminal.setTextScale and x > 1 then
    newLine()
  end

  local lines = getLines(message, width)
  terminal.setCursorPos(1, y)
  terminal.write(lines[1])
  for l=2, #lines do
    newLine()
    terminal.setCursorPos(2, y)
    terminal.write(lines[l])
  end

  if not terminal.setTextScale then
    newLine()
    terminal.setCursorPos(1, y)
  else
    terminal.setCursorBlink(false)
  end

  if lastColor then
    terminal.setTextColor(lastColor)
  end
end

local function print(name, message)
  local printer = peripheral.wrap(name)
  local today = os.date("%Y%m%d")
  local data = settings.get("printData", { [name]= {started=false, date=today, page=0} })
  local width, height, x, y

  local newPage = function (s, last)
    if data[name].started then
      data[name].started = false
      printer.endPage()
    end

    if last or printer.getInkLevel() == 0 or printer.getPaperLevel() == 0 then
      return false
    end

    data[name].page = today == data[name].date and data[name].page + 1 or 1
    data[name].date = today
    data[name].started = true
    printer.newPage()
    printer.setPageTitle(today..string.format("_%.3d", data[name].page))
    printer.setCursorPos(s or 1, 1)
    width, height = printer.getPageSize()
    x, y = printer.getCursorPos()
    return true
  end

  local function newLine(s, last)
    if y + 1 > height then
      return newPage(s, last)
    end
    printer.setCursorPos(s or 1, y+1)
    x, y = printer.getCursorPos()
    return true
  end

  if not data[name].started or data[name].date ~= today then
    if not newPage() then
      return
    end
  else
    width, height = printer.getPageSize()
    x, y = printer.getCursorPos()
  end

  local lines = getLines(message, width)
  printer.setCursorPos(1, y)
  printer.write(lines[1])
  for l=2, #lines do
    if not newLine(2) then return end
    printer.setCursorPos(2, y)
    printer.write(lines[l])
  end
  newLine(1, true)

  settings.set("printData", data)
end

local function save(drive, message, path, src)
  local append = function(p)
    local date = os.date("%Y%m%d")
    if not p then
      p = "logs/"
    elseif not p:match("/$") then
      p = p.."/"
    end
    local file = fs.open(p..date..".log", "a")
    file.writeLine(message)
    file.close()
  
    if src then
      local folder = "/"..src:match("^(%.?[^.]+)").."/"
      file = fs.open(p..folder..date..".log", "a")
      file.writeLine(message)
      file.close()
    end
  end

  if not drive then
    append(path)
    return
  end

  if not drive.isDiskPresent() then
    return
  end

  if not path then
    path = "/"
  elseif path:sub(1, 1) ~= "/" then
    path = "/"..path
  end

  append(drive.getMountPath()..path)
end

local function send(message)
  --settings.get("hosts")
end

local function distribute(level, message, ...)
  local args = {...}
  local tryFormat = function()
    message = tostring(message):format(unpack(args))
  end
  if not pcall(tryFormat) then
    message = tostring(message)
  end

  local data = settings.get("logs")
  local debugInfo = debug.getinfo(3)

  if not data then
    if level > 0 then
      show(term, level, format(level, message, debugInfo))
    end
    return
  end

  local group = nil
  for i=0, level do
    group = data[i] or group
  end

  if not group then
    return
  end

  if group.print ~= false then
    show(term, level, format(level, message, debugInfo, group.print))
  end

  if group.save then
    if type(group.save) == "table" then
      save(nil, format(level, message, debugInfo, group.save.format), group.save.path, group.save.split and debugInfo.short_src)
    else
      save(nil, format(level, message, debugInfo, group.save))
    end
  end

  if group.send then
    send(format(level, message, debugInfo, group.send))
  end

  local filteredByFunction = function(p, t, ft)
    local f = loadstring("return function"..p.filter.."end")
    local peripherals = {peripheral.find(t, f())}
    for _, prl in ipairs(peripherals) do
      if t == "monitor" then
        show(prl, level, ft)
      elseif t == "drive" then
        save(prl, ft, p.path, p.split and debugInfo.short_src)
      elseif t == "printer" then
        for _, pn in pairs(peripheral.getNames()) do
          if prl == peripheral.wrap(pn) then
            print(pn, ft)
            break
          end
        end
      elseif p.call then
        for _, pn in pairs(peripheral.getNames()) do
          if prl == peripheral.wrap(pn) then
            pcall(function() peripheral.call(pn, p.call, ft) end)
            break
          end
        end
      end
    end
  end

  local redirect = function(p, sType, name, ft)
    if sType == "monitor" then
      show(peripheral.wrap(name), level, ft)
    elseif sType == "drive" then
      save(peripheral.wrap(name), ft, p.path, p.split and debugInfo.short_src)
    elseif sType == "printer" then
      print(name, ft)
    else
      return false
    end
    return true
  end

  local filteredByName = function (p, sType, ft)

    local select = function (name)
      local t = peripheral.getType(name)
      if t == sType then
        if not redirect(p, t, name, ft) and p.call then
          pcall(function() peripheral.call(name, p.call, ft) end)
        end
      elseif t == "modem" then
        local remotes = peripheral.call(name, "getNamesRemote")
        for _, remote in ipairs(remotes) do
          if peripheral.getType(remote) == sType then
            if not redirect(p, sType, remote, ft) and p.call then
              pcall(function() peripheral.call(remote, p.call, ft) end)
            end
          end
        end
      end
    end

    if type(p.filter) == "table" then
      for _, name in ipairs(p.filter) do
        select(name)
      end
    elseif p.filter and peripheral.isPresent(p.filter) then
      select(p.filter)
    else
      for _, name in ipairs(peripheral.getNames()) do
        local t = peripheral.getType(name)
        if t == sType and (not p.filter or name:match(p.filter)) then
          if not redirect(p, t, name, ft) and p.call then
            pcall(function() peripheral.call(name, p.call, ft) end)
          end
        end
      end
    end
  end

  local sendPerType = function(p)
    for t, data in pairs(p) do
      if type(data) == "string" then
        data = {format=data}
      end
      local ft = format(level, message, debugInfo, data.format)
      if data.filter and type(data.filter) == "string" and data.filter:find("^%(name, object%).+return") then
        filteredByFunction(data, t, ft)
      else
        filteredByName(data, t, ft)
      end
    end
  end

  local sendToAll = function (p)
    local ft = format(level, message, debugInfo, p.format)

    if not p.filter then
      for _, name in ipairs(peripheral.getNames()) do
        if not redirect(p, peripheral.getType(name), name, ft) and p.call then
          pcall(function() peripheral.call(name, p.call, ft) end)
        end
      end
      return
    end
     
    local select = function (name)
      local t = peripheral.getType(name)
      if not t then return end
      if t == "modem" then
        local remote = peripheral.call(name, "getNamesRemote")
        for _, n in ipairs(remote) do
          if not redirect(p, peripheral.getType(n), n, ft) then
            pcall(function() peripheral.call(n, p.call, ft) end)
          end
        end
      elseif not redirect(p, t, name, ft) and p.call then
        pcall(function() peripheral.call(name, p.call, ft) end)
      end
    end

    if type(p.filter) == "table" then
      for _, name in ipairs(p.filter) do
        select(name)
      end
    elseif peripheral.isPresent(p.filter) then
        select(p.filter)
    else
      for _, name in ipairs(peripheral.getNames()) do
        if name:match(p.filter) then
          local t = peripheral.getType(name)
          if not redirect(p, t, name, ft) and p.call then
            pcall(function() peripheral.call(name, p.call, ft) end)
          end
        end
      end
    end

  end

  if group.peripherals then
    local p, single = group.peripherals

    if type(p) == "string" then
      p = {format=p}
      single = true
    else
      local empty = true
      for _ in pairs(p) do
        empty = false
        break
      end
      single = empty or p.filter or p.format or p.path or p.split or p.call
    end

    if single then
      sendToAll(p)
    else
      sendPerType(p)
    end
  end
end

local log = {}

function log.debug(msg, ...) distribute(0, msg, ...) end
function log.info(msg, ...) distribute(1, msg, ...) end
function log.alert(msg, ...) distribute(2, msg, ...) end
function log.error(msg, ...) distribute(3, msg, ...) end

function assert(func, msg, ...)
    
end

return log