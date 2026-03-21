-- =============================================================
-- runtime.lua  —  QSYS WinPC Control
-- Runs inside Q-SYS Core when the plugin is active.
-- =============================================================

-- -----------------------------------------------------------
-- CONFIG (from Properties)
-- -----------------------------------------------------------
local ip            = Properties["IP Address"].Value
local mac           = Properties["MAC Address"].Value
local sshUser       = Properties["SSH Username"].Value
local sshKey        = Properties["SSH Private Key"].Value
local statusPath    = Properties["Status File Path"].Value
local pollInterval  = Properties["Poll Interval"].Value
local debugPrint    = Properties["Debug Print"].Value

-- -----------------------------------------------------------
-- STATE MACHINE
-- States: OFFLINE, BOOTING, ONLINE, SHUTTING_DOWN
-- -----------------------------------------------------------
local State = "OFFLINE"

local function SetState(newState)
  if State == newState then return end
  State = newState
  if debugPrint ~= "None" then
    print("[WinPC] State → " .. newState)
  end

  if newState == "ONLINE" then
    Controls.OnlineStatus.Boolean = true
    Controls.StatusText.String    = "Online"
  elseif newState == "BOOTING" then
    Controls.OnlineStatus.Boolean = false
    Controls.StatusText.String    = "Booting..."
  elseif newState == "SHUTTING_DOWN" then
    Controls.OnlineStatus.Boolean = false
    Controls.StatusText.String    = "Shutting Down..."
  else  -- OFFLINE
    Controls.OnlineStatus.Boolean = false
    Controls.StatusText.String    = "Offline"
    Controls.Volume.Value         = 0
    Controls.Mute.Boolean         = false
  end
end

-- -----------------------------------------------------------
-- DEBUG HELPER
-- -----------------------------------------------------------
local function dbg(dir, msg)
  if debugPrint == "All" or debugPrint == "Tx/Rx" then
    print("[WinPC][" .. dir .. "] " .. msg)
  end
end

-- -----------------------------------------------------------
-- WOL  (Wake-on-LAN magic packet via UDP broadcast)
-- -----------------------------------------------------------
local function SendWOL()
  if mac == "" then
    print("[WinPC] WOL: MAC address not configured")
    return
  end

  -- Parse MAC (accepts XX:XX:XX:XX:XX:XX or XX-XX-XX-XX-XX-XX)
  local bytes = {}
  for byte in mac:gmatch("[%x][%x]") do
    table.insert(bytes, tonumber(byte, 16))
  end
  if #bytes ~= 6 then
    print("[WinPC] WOL: Invalid MAC address: " .. mac)
    return
  end

  -- Build magic packet: 6x 0xFF + 16x MAC
  local packet = string.rep("\xFF", 6)
  local macBytes = string.char(table.unpack(bytes))
  packet = packet .. string.rep(macBytes, 16)

  local udp = UdpSocket.New()
  udp:Open("0.0.0.0", 0)  -- bind any local port
  udp:Send("255.255.255.255", 9, packet)
  udp:Close()

  dbg("Tx", "WOL magic packet → " .. mac)
  SetState("BOOTING")
end

-- -----------------------------------------------------------
-- SSH STUB
-- TODO: Replace with a bundled pure-Lua SSH implementation.
-- Options to evaluate:
--   • luassh (pure Lua, needs audit for Q-SYS compat)
--   • Custom TCP+exec workaround if Core exposes raw sockets
--   • Thin Windows-side agent accepting plain TCP to avoid SSH
--     entirely from the Lua side
--
-- For now this function logs the intended command so the rest
-- of the logic can be written and tested around it.
-- -----------------------------------------------------------
local function ssh_send(cmd)
  dbg("Tx", "SSH [STUB] → " .. cmd)
  -- TODO: open TCP connection to ip:22, authenticate with
  -- sshUser + sshKey, exec cmd, return stdout as string.
  return nil, "SSH not yet implemented"
end

-- -----------------------------------------------------------
-- SSH COMMAND HELPERS
-- -----------------------------------------------------------

-- Write a command to the Windows Event Log (9001) so the
-- Scheduled Task picks it up and dispatches to QSYSControl.ps1
local function WriteEventLog(command)
  local ps = string.format(
    [[powershell -NonInteractive -Command "Write-EventLog -LogName Application -Source QSYSControl -EventId 9001 -Message '%s'"]],
    command
  )
  dbg("Tx", "EventLog cmd: " .. command)
  local result, err = ssh_send(ps)
  return result, err
end

local function SendShutdown()
  dbg("Tx", "Sending shutdown command")
  local _, err = ssh_send("shutdown /s /t 0")
  if err then
    print("[WinPC] Shutdown error: " .. err)
  else
    SetState("SHUTTING_DOWN")
  end
end

local function SendVolume(pct)
  WriteEventLog("VOLUME:" .. tostring(math.floor(pct)))
end

local function SendMute(muted)
  WriteEventLog("MUTE:" .. (muted and "1" or "0"))
end

-- Read status.txt over SSH and return parsed table or nil
local function ReadStatusFile()
  local cmd = string.format([[powershell -NonInteractive -Command "Get-Content '%s'"]], statusPath)
  local result, err = ssh_send(cmd)
  if err or not result then return nil end

  local status = {}
  for line in result:gmatch("[^\r\n]+") do
    local k, v = line:match("^(%a+):(.+)$")
    if k and v then
      status[k] = v:match("^%s*(.-)%s*$")  -- trim whitespace
    end
  end
  return status
end

-- -----------------------------------------------------------
-- TCP POLL  (probe port 3389 / RDP to determine online state)
-- -----------------------------------------------------------
local pollTimer = Timer.New()

local function UpdateLastPoll()
  -- Q-SYS API: os.date is available in runtime
  Controls.LastPoll.String = os.date("%Y-%m-%d %H:%M:%S")
end

local function DoPoll()
  if ip == "" then return end

  local sock = TcpSocket.New()
  sock.ReadTimeout  = 3
  sock.WriteTimeout = 3

  sock.Connected = function()
    sock:Disconnect()
    if State ~= "ONLINE" then
      SetState("ONLINE")
    end

    -- Now fetch status file for volume/mute feedback
    local status = ReadStatusFile()
    if status then
      if status.VOLUME then
        local v = tonumber(status.VOLUME)
        if v then Controls.Volume.Value = v end
      end
      if status.MUTE then
        Controls.Mute.Boolean = (status.MUTE == "1")
      end
      UpdateLastPoll()
      dbg("Rx", "Status: " .. (status.VOLUME or "?") .. "% mute=" .. (status.MUTE or "?"))
    end
  end

  sock.Reconnect = function()
    -- Connection refused or timed out — PC is offline
    if State ~= "SHUTTING_DOWN" then
      SetState("OFFLINE")
    end
  end

  sock.Error = function(_, err)
    if State ~= "SHUTTING_DOWN" then
      SetState("OFFLINE")
    end
    if debugPrint ~= "None" then
      print("[WinPC] TCP probe error: " .. tostring(err))
    end
  end

  sock:Connect(ip, 3389)
end

pollTimer.EventHandler = DoPoll

-- Guard: don't send audio commands when PC isn't up
local function RequireOnline(label)
  if State ~= "ONLINE" then
    print("[WinPC] " .. label .. " ignored — PC is " .. State)
    return false
  end
  return true
end

-- -----------------------------------------------------------
-- CONTROL EVENT HANDLERS
-- -----------------------------------------------------------
Controls.PowerOn.EventHandler = function()
  SendWOL()
end

Controls.Shutdown.EventHandler = function()
  if not RequireOnline("Shutdown") then return end
  SendShutdown()
end

Controls.Volume.EventHandler = function()
  if not RequireOnline("Volume") then return end
  SendVolume(Controls.Volume.Value)
end

Controls.Mute.EventHandler = function()
  if not RequireOnline("Mute") then return end
  SendMute(Controls.Mute.Boolean)
end

-- -----------------------------------------------------------
-- STARTUP
-- -----------------------------------------------------------
SetState("OFFLINE")
pollTimer:Start(pollInterval)
print("[WinPC] Plugin started — polling every " .. pollInterval .. "s → " .. (ip ~= "" and ip or "(no IP)"))
