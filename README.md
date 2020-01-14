# Minecraft CC
A set of programs and tools for [ComputerCraft](http://www.computercraft.info/) [Minecraft](https://minecraft.net/) Mod.

## Settings
___

### Hosts
The purpose is offer a easy way to send info through modems in a general way.
```lua 
modemHost: {channel:number, replyChannel:number}
rednetHost: { [receiverID:number | hostname:string | nil], protocol:[string|bool] }
option: [modemHost|rednetHost]

settings.set("hosts", {string}:[{string}:option | option]
```
- **Hosts** are split in protocols, for each protocol can exist multiple hosts. If an empty string is provided as a key, all protocols will be sent to this entry.
- There are two options for sending messages to hosts; **modem or rednet**.
- For **modem** requests the parameters required are **channel, replyChannel**.
- For **rednet** the parameters will be different according if the transmission is a **request**, a **lookup** or a **broadcast**. **Protocol** can be specified as a new one, set as true for use the same as hosts key or false for not using any protocol.
- Protocols can output messages through all connected modems or filter by side and type. Valid filters are **side, wired and wireless**.

###### Examples
#
```lua
local hosts = settings.get("hosts", {})
-- all protocols
hosts[""] = {
    -- send messages through top modem at channel 1
    top={ channel=1, replyChannel=2 },
    -- send a ping lookup through all wireless connected modems
    wireless={ protocol="ping" }
}
settings.set("hosts", hosts)
```

```lua
local hosts = settings.get("hosts", {})
-- logs protocol
hosts["logs"] = {
    -- send messages through all wired connected modems at channel 10
    wired={ channel=10, replyChannel=6 },
    -- send messages using logs protocol through bottom modem to computer 16
    bottom={ receiverID=16, protocol=true }
}
settings.set("hosts", hosts)
```

```lua
local hosts = settings.get("hosts", {})
-- gps protocol
hosts["gps"] = {
    -- send a broadcast through wireless connected modems
    wireless={}
}
settings.set("hosts", hosts)
```

```lua
-- sets hosts with a new list with a single protocol (ping)
-- ping outputs through all connected modems at channel 24
settings.set("hosts", {ping = {channel=24, replyChannel=2}})
```
#
___

### Logs
The purpose is offer an easy way to save and send logs in same computer and attached peripherals.
##### Levels:
0. debug (lightGray)
1. info (white)
2. alert (orange)
3. error (red)
#

```lua
write: { format:[string|nil], path:[string|nil], split:bool }
peripheral: { filter:[{number}:string|string|nil], format:[string|nil], [path:[string|nil], split:bool | nil], call:[string|nil] }

settings.set("logs", 
    {number}: { 
        print: [ string | bool | nil ],
        save: [ write | string | bool ],
        send: [ string | bool ],
        peripherals: [ {string}:[peripheral|string] | peripheral | string | nil ]
}
```

- If **logs** are not set, logs will be printed only in same computer at info level without format.
- Each log level can be configured. The last index found will be copy to all levels above.
- **Format** accepts regular expressions. See tables below.
- **Print** is used to define how to print in the same computer logs messages. If nil, prints level 1 (inclusive) to above without format. To disable set to false.
- **Save** is used to write logs in files. If **path** is not set, logs will be written in **"logs"** directory. If **split** is set, folders and files will be created for every program or api.
- **Send** is used to send logs through "logs" protocol that can be set at settings hosts.
- **Peripherals** can by filtered by type.
- **Monitors, printers, drives, etc** can be identified by side, name (regex is valid) or function expression. If side is not matching peripheral but a modem is attached, search all matching peripherals in this side.
- **Peripherals**, when not filtered, can be identified by side and name. If side is modem, search all peripherals in this side. If filter is nil, logs will be send to all peripherals. The field **call** is used to send a call function with message as parameter for all peripherals not implemented.

If message is not found, will be add at the end.
| Format        | Output        |
| ------------- |:-------------:|
%l | level number
%L | level name
%@ | message

###### Minecraft day and time
#
| Format        | Output        |
| ------------- |:-------------:|
%mc_d | day
%mc_D | day and time
%mc_h | hour 24
%mc_i | hour 12
%mc_m | minute
%mc_p | "am" or "pm"
%mc_r | 12h clock
%mc_R | 24h clock
%mc_s | second
%mc_t | time
%mc_T | formated time

###### Computer info
#
| Format        | Output        |
| ------------- |:-------------:|
%cc_c | internal clock
%cc_I | computer ID
%cc_L | computer label
%cc_p | position short
%cc_P | position long
%cc_r | rotation
%cc_R | cardinal
%cc_V | os version
%cc_x | x position
%cc_y | y position
%cc_z | z position

###### Debug info
#
| Info        | Output        |
| ------------- |:-------------:|
%!f | file name
%!l | current line
%!n | program name
%!v | program version
%!t | traceback

###### Examples
#
```lua
-- prints in same computer from info level to above without header
settings.set("logs", nil)
-- Example prints if not advanced
-- 1: Download complete.
-- 3: Invalid URL.
```

```lua
-- prints in same computer from debug level to above
local logs = { print=0 }
settings.set("logs", logs)
```

```lua
-- prints in same computer from alert level to above
-- outputs logs at debug level from top side with time header and level number
local logs = { 
    print={self=2, peripherals={ 
        top={info=0, header="[%T]%l:"} 
        } 
    } 
}
settings.set("logs", logs)
-- Example print in peripheral
-- [11:47:09]2: File already exists.
```

```lua
-- prints in same computer from info level to above
-- save in same computer from debug level to above in logs directory
local logs = { save=0 }
settings.set("logs", logs)
```

```lua
-- prints in same computer from info level to above
-- save in same computer from info level to above with level name header in disk directory
local logs = { 
    save = { level=1, header="%L:", path="disk" }
}
settings.set("logs", logs)
-- Example print in disk
-- Info: Download complete.
-- Warning: File already exists.
```

```lua
-- prints in same computer only errors
-- saves in drive_1 if contains disk from debug level to above with date time and level name header
local logs = { 
    print=3,
    save={ drives={ 
        drive_1={level=0, header="[%D]%L:"} 
        } 
    }
}
settings.set("logs", logs)
-- Example print in disk_1/logs
-- [01/15/2020 11:47:09]Info: Download complete.
-- [01/15/2020 12:01:45]Warning: File already exists.
```

```lua
-- prints in same computer from info level to above
-- send through "logs" protocol debug level logs without header
local logs = {
    send = -200 --0
}
settings.set("logs", logs)
```

```lua
-- prints in same computer from info level to above
-- outputs logs at info level to all printers with time header and level number
-- outputs logs at info debug to all monitors with time header and level number
local logs = {
    print={ peripherals={
            ["printer"] = {level=1, header="%l:"},
            ["monitor"] = {level=0, header="%L:"}
        }
    }
}
settings.set("logs", logs)
```

```lua
-- prints in same computer from info level to above
-- outputs logs at info level to all peripheral with id 1
local logs = {
    print={ peripherals={
            ["^[^_]1$"] = 1
        }
    }
}
settings.set("logs", logs)
``` 

```lua
-- prints in same computer from info level to above
-- outputs logs at info level to all advanced monitors
local logs = {
    print={ monitors={
            ['(name, object) return object.isColor()'] = {level=1, header="%T:"}
        }
    }
}
settings.set("logs", logs)
```

## USEFUL REPOS
- [dan200/ComputerCraft](https://github.com/dan200/ComputerCraft) Programmable Computers for Minecraft 
- [SquidDev-CC/CC-Tweaked](https://github.com/SquidDev-CC/CC-Tweaked) Just another ComputerCraft fork 
- [CCEmuX/CCEmuX](https://github.com/CCEmuX/CCEmuX) A modular ComputerCraft emulator. https://emux.cc/
- [SquidDev-CC/copy-cat](https://github.com/SquidDev-CC/copy-cat) A ComputerCraft emulator for the web https://copy-cat.squiddev.cc/
- [SquidDev-CC/cloud-catcher](https://github.com/SquidDev-CC/cloud-catcher) A web interface for ComputerCraft https://cloud-catcher.squiddev.cc/
- [oeed/CraftOS-Standards](https://github.com/oeed/CraftOS-Standards) Community standard file formats, communication systems, etc. for ComputerCraft and CraftOS 2.0 
- [eric-wieser/computercraft-github](https://github.com/eric-wieser/computercraft-github) A readonly github repository client for computercraft 
- [somesocks/lua-lockbox](https://github.com/somesocks/lua-lockbox) A collection of cryptographic primitives written in pure Lua 
- [benanders/LuaIDE](https://github.com/benanders/LuaIDE) An in-game IDE for ComputerCraft 
- [lyqyd/cc-packman](https://github.com/lyqyd/cc-packman) A package manager for ComputerCraft. 
- [lyqyd/ComputerCraft-LyqydNet](https://github.com/lyqyd/ComputerCraft-LyqydNet) A set of APIs and scripts for ComputerCraft to establish and operate an in-game computer network with routing.
- [SquidDev-CC/mbs](https://github.com/SquidDev-CC/mbs) A Mildly Better Shell for ComputerCraft 
