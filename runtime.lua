-- =============================================================
-- runtime.lua -- Win PC Control
-- Author: Michael King
--
-- This file contains all live runtime logic that executes inside
-- the Q-SYS Core while the plugin is running. It is NOT used at
-- design time -- only GetControlLayout(), GetProperties(), etc.
-- in plugin.lua run at design time.
--
-- Transport: HTTP via QSYSControlServer.ps1 on the Windows PC.
-- The server listens on a configurable port (default 2207) and
-- accepts GET /status and POST /command requests, protected by
-- a Bearer token stored in C:\QSYSControl\config.txt on the PC.
--
-- Power on uses Wake-on-LAN (UDP magic packet, port 9).
-- Volume and mute use the Windows Core Audio API via inline C#
-- inside QSYSControlServer.ps1.
-- =============================================================


-- =============================================================
-- SECTION 1: CONFIGURATION
-- Pull all user-set property values once at startup. These do
-- not change while the plugin is running -- a re-deploy is
-- required if properties are changed.
-- =============================================================

local host         = Properties["Hostname or IP"].Value
local macProperty  = Properties["MAC Address"].Value
local httpPort     = Properties["HTTP Port"].Value
local authToken    = Properties["Auth Token"].Value
local pollInterval = Properties["Poll Interval"].Value
local debugPrint   = Properties["Debug Print"].Value

-- Build the base URL once so we don't repeat the format call everywhere.
-- Example: "http://192.168.1.50:2207"
local baseUrl    = string.format("http://%s:%d", host, httpPort)

-- Pre-build the auth header table used on every GET /status request.
local authHeader = { Authorization = "Bearer " .. authToken }

-- cachedMac holds the MAC address used for Wake-on-LAN.
-- It is seeded from the MAC Address property if the user set one manually.
-- Once the PC comes online, the server reports its MAC in the /status
-- response and we update cachedMac automatically. This means the user
-- only needs to set the property for the very first WOL before the PC
-- has ever been polled successfully.
local cachedMac = (macProperty ~= "") and macProperty or nil


-- =============================================================
-- SECTION 2: STATE MACHINE
--
-- The plugin tracks which of four states the PC is believed to be in.
-- State drives the status LED, status text, and guards against sending
-- commands to a PC that cannot receive them.
--
-- States:
--   OFFLINE       -- No response from the server. PC is off or unreachable.
--   BOOTING       -- WOL was just sent. Waiting for the server to come up.
--                    Poll failures in this state do NOT flip back to OFFLINE
--                    immediately, because the PC needs time to POST and boot.
--   ONLINE        -- Server responded with HTTP 200. PC is up and running.
--   SHUTTING_DOWN -- Shutdown command was accepted. Waiting for it to drop off.
-- =============================================================

local State = "OFFLINE"

local function SetState(newState)
  -- Skip if already in this state to avoid redundant control updates.
  if State == newState then return end
  State = newState

  if debugPrint ~= "None" then
    print("[WinPC] State -> " .. newState)
  end

  -- Update the Controls to reflect the new state.
  if newState == "ONLINE" then
    Controls.OnlineStatus.Boolean = true
    Controls.StatusText.String    = "Online"

  elseif newState == "BOOTING" then
    Controls.OnlineStatus.Boolean = false
    Controls.StatusText.String    = "Booting..."

  elseif newState == "SHUTTING_DOWN" then
    Controls.OnlineStatus.Boolean = false
    Controls.StatusText.String    = "Shutting Down..."

  else
    -- OFFLINE -- also reset audio controls so they don't show stale values.
    Controls.OnlineStatus.Boolean = false
    Controls.StatusText.String    = "Offline"
    Controls.Volume.Value         = 0
    Controls.Mute.Boolean         = false
  end
end


-- =============================================================
-- SECTION 3: DEBUG HELPER
--
-- Prints Tx/Rx messages to the Q-SYS Core log when Debug Print
-- is set to "Tx/Rx" or "All" in the plugin properties.
-- "dir" should be "Tx" or "Rx" to indicate direction.
-- =============================================================

local function dbg(dir, msg)
  if debugPrint == "All" or debugPrint == "Tx/Rx" then
    print("[WinPC][" .. dir .. "] " .. msg)
  end
end


-- =============================================================
-- SECTION 4: HTTP TRANSPORT
--
-- Two functions wrap HttpClient.Download for our two endpoints.
-- HttpClient is a native Q-SYS v10+ API -- no third-party libs needed.
--
-- All requests include the Bearer token header for authentication.
-- The server returns 401 if the token doesn't match, and 200 on success.
-- =============================================================

-- http_post(cmd, callback)
--   Sends a POST request to /command with a plain-text body.
--   "cmd" is a string like "SHUTDOWN", "VOLUME:75", or "MUTE:1".
--   "callback" is optional -- called as callback(httpCode, body, errMsg).
--   If no callback is needed (fire and forget), pass nil.
local function http_post(cmd, callback)
  -- Refuse to send if no token is configured. The server will reject it
  -- anyway, but this gives a clearer message in the log.
  if authToken == "" then
    print("[WinPC] WARNING: Auth Token not set in plugin properties. Run install.ps1 on the PC first.")
    return
  end

  dbg("Tx", "POST /command  body: " .. cmd)

  HttpClient.Download {
    Url     = baseUrl .. "/command",
    Headers = {
      Authorization    = "Bearer " .. authToken,
      ["Content-Type"] = "text/plain"
    },
    Method  = "POST",
    Body    = cmd,
    Timeout = 5,
    EventHandler = function(tbl, code, data, err)
      dbg("Rx", "POST /command  HTTP " .. tostring(code))
      if callback then callback(code, data, err) end
    end
  }
end


-- http_get_status(callback)
--   Sends a GET request to /status.
--   The server responds with a plain-text body like:
--     VOLUME:75
--     MUTE:0
--     MAC:AA:BB:CC:DD:EE:FF
--     UPDATED:2026-03-20 14:30:00
--   "callback" is called as callback(httpCode, body, errMsg).
local function http_get_status(callback)
  -- If no token is set, don't bother sending -- it will always fail.
  if authToken == "" then return end

  dbg("Tx", "GET /status")

  HttpClient.Download {
    Url     = baseUrl .. "/status",
    Headers = authHeader,
    Timeout = 5,
    EventHandler = function(tbl, code, data, err)
      dbg("Rx", "GET /status  HTTP " .. tostring(code))
      callback(code, data, err)
    end
  }
end


-- =============================================================
-- SECTION 5: WAKE-ON-LAN
--
-- Sends a standard WOL magic packet to the global UDP broadcast
-- address (255.255.255.255) on port 9.
--
-- Magic packet format:
--   6 bytes of 0xFF, followed by the target MAC address repeated 16 times.
--   Total: 102 bytes.
--
-- Requirements:
--   - The PC must have "Wake on LAN" enabled in its BIOS/UEFI.
--   - The NIC must have WOL enabled in Windows Device Manager.
--   - The Q-SYS Core and the PC must be on the same Layer 2 network
--     segment (or the router must forward directed broadcasts).
-- =============================================================

local function SendWOL()
  local mac = cachedMac

  -- Can't send WOL without knowing the MAC address.
  -- Once the PC has been online at least once, cachedMac will be
  -- populated automatically from the /status response. Until then,
  -- the user can set the MAC Address property manually.
  if not mac or mac == "" then
    print("[WinPC] WOL: MAC address not known yet.")
    print("[WinPC] WOL: Either set the MAC Address property manually,")
    print("[WinPC] WOL: or bring the PC online once so it can be discovered.")
    return
  end

  -- Parse the MAC string (accepts either ":" or "-" as separator)
  -- into an array of six integer byte values.
  local bytes = {}
  for byte in mac:gmatch("[%x][%x]") do
    table.insert(bytes, tonumber(byte, 16))
  end

  if #bytes ~= 6 then
    print("[WinPC] WOL: MAC address is not valid (expected 6 bytes): " .. mac)
    return
  end

  -- Build the magic packet: 6x 0xFF then the 6-byte MAC repeated 16 times.
  local macBytes = string.char(table.unpack(bytes))
  local packet   = string.rep("\xFF", 6) .. string.rep(macBytes, 16)

  -- Send via UDP broadcast. Port 9 is the standard WOL port.
  local udp = UdpSocket.New()
  udp:Open("0.0.0.0", 0)
  udp:Send("255.255.255.255", 9, packet)
  udp:Close()

  dbg("Tx", "WOL magic packet sent to " .. mac)

  -- Optimistically move to BOOTING state. Poll failures will be tolerated
  -- until the PC comes up and responds with HTTP 200.
  SetState("BOOTING")
end


-- =============================================================
-- SECTION 6: COMMAND SENDERS
--
-- These functions translate button presses and control changes
-- into HTTP POST commands to the Windows server.
-- Command strings must match what QSYSControlServer.ps1 expects.
-- =============================================================

-- Tell the PC to shut down. If the server confirms with 200, we move
-- to SHUTTING_DOWN state so polls don't immediately flip back to OFFLINE.
local function SendShutdown()
  dbg("Tx", "Sending SHUTDOWN command")
  http_post("SHUTDOWN", function(code, _, err)
    if code == 200 then
      SetState("SHUTTING_DOWN")
    else
      print("[WinPC] Shutdown command failed. HTTP " .. tostring(code) .. " / " .. tostring(err))
    end
  end)
end

-- Send volume as an integer 0-100. The server maps this to the
-- Windows master volume via the Core Audio API.
local function SendVolume(pct)
  http_post("VOLUME:" .. tostring(math.floor(pct)))
end

-- Send mute state as "1" (muted) or "0" (not muted).
local function SendMute(muted)
  http_post("MUTE:" .. (muted and "1" or "0"))
end


-- =============================================================
-- SECTION 7: POLL TIMER
--
-- A Timer fires every N seconds (set by the Poll Interval property)
-- and sends a GET /status to check whether the PC is up and to
-- sync volume/mute values back to Q-SYS.
--
-- The response body is plain text with one KEY:VALUE pair per line.
-- ParseStatus() converts that into a Lua table for easy access.
-- =============================================================

local pollTimer = Timer.New()

-- ParseStatus(body)
--   Converts the plain-text status body into a key/value table.
--   Input example:
--     "VOLUME:75\r\nMUTE:0\r\nMAC:AA:BB:CC:DD:EE:FF\r\nUPDATED:2026-03-20 14:30:00"
--   Output example:
--     { VOLUME="75", MUTE="0", MAC="AA:BB:CC:DD:EE:FF", UPDATED="2026-03-20 14:30:00" }
local function ParseStatus(body)
  local status = {}
  for line in body:gmatch("[^\r\n]+") do
    local k, v = line:match("^(%u+):(.+)$")
    if k and v then
      -- Trim any leading/trailing whitespace from the value.
      status[k] = v:match("^%s*(.-)%s*$")
    end
  end
  return status
end

-- DoPoll()
--   Called by pollTimer every N seconds.
--   On success: updates state to ONLINE and syncs volume/mute/MAC.
--   On failure: handles BOOTING tolerance and OFFLINE transition.
local function DoPoll()
  -- Don't bother polling if the hostname was never configured.
  if host == "" then return end

  http_get_status(function(code, data, err)
    if code == 200 and data then
      -- PC is responding. Move to ONLINE if we weren't already.
      if State ~= "ONLINE" then SetState("ONLINE") end

      local status = ParseStatus(data)

      -- Sync volume from server to Q-SYS fader.
      if status.VOLUME then
        local v = tonumber(status.VOLUME)
        if v then Controls.Volume.Value = v end
      end

      -- Sync mute state from server to Q-SYS button.
      if status.MUTE then
        Controls.Mute.Boolean = (status.MUTE == "1")
      end

      -- If the server sent a MAC address, cache it for future WOL use.
      -- This is how auto-discovery works -- no manual entry needed after
      -- the first successful poll.
      if status.MAC and status.MAC ~= "" then
        cachedMac = status.MAC
        dbg("Rx", "MAC auto-discovered and cached: " .. cachedMac)
      end

      -- Record the timestamp of the last successful poll.
      Controls.LastPoll.String = os.date("%Y-%m-%d %H:%M:%S")
      dbg("Rx", "Vol=" .. (status.VOLUME or "?") .. "  Mute=" .. (status.MUTE or "?"))

    else
      -- No HTTP 200 -- the PC is not responding.
      if State == "BOOTING" then
        -- WOL was recently sent. Stay in BOOTING and keep waiting.
        -- The PC may take 30-60 seconds to fully boot and start the server.
        dbg("Rx", "Still booting... (" .. tostring(err or code) .. ")")

      elseif State == "SHUTTING_DOWN" then
        -- We expected this -- the shutdown command was accepted and the
        -- PC is now powering off. Move to OFFLINE.
        SetState("OFFLINE")

      else
        -- Unexpected failure. Mark offline.
        SetState("OFFLINE")
      end

      if debugPrint ~= "None" then
        print("[WinPC] Poll failed: " .. tostring(err or code))
      end
    end
  end)
end

-- Wire up the timer callback and we're ready to start it at the bottom.
pollTimer.EventHandler = DoPoll


-- =============================================================
-- SECTION 8: GUARD FUNCTION
--
-- Prevents sending audio/power commands when the PC is not ONLINE.
-- Returns true if the command should proceed, false if it should be
-- silently dropped (with a log message for debugging).
-- =============================================================

local function RequireOnline(label)
  if State ~= "ONLINE" then
    print("[WinPC] Command ignored (" .. label .. ") -- PC is currently: " .. State)
    return false
  end
  return true
end


-- =============================================================
-- SECTION 9: CONTROL EVENT HANDLERS
--
-- These wire up the Q-SYS Controls (buttons, knobs) to the
-- functions above. Each handler fires when the operator interacts
-- with the control on a UCI or the schematic.
-- =============================================================

-- PowerOn: Sends a Wake-on-LAN magic packet.
-- This works even when the PC is OFFLINE -- that's the whole point.
Controls.PowerOn.EventHandler = function()
  SendWOL()
end

-- Shutdown: Tells the server to initiate a Windows shutdown.
-- Only works when ONLINE -- guard prevents blind commands.
Controls.Shutdown.EventHandler = function()
  if not RequireOnline("Shutdown") then return end
  SendShutdown()
end

-- Volume: Syncs the fader value to Windows master volume (0-100).
Controls.Volume.EventHandler = function()
  if not RequireOnline("Volume") then return end
  SendVolume(Controls.Volume.Value)
end

-- Mute: Syncs the toggle button to Windows master mute.
Controls.Mute.EventHandler = function()
  if not RequireOnline("Mute") then return end
  SendMute(Controls.Mute.Boolean)
end


-- =============================================================
-- SECTION 10: STARTUP
--
-- Set initial state and start the poll timer.
-- This code runs once when the Q-SYS Core loads the plugin.
-- =============================================================

SetState("OFFLINE")
pollTimer:Start(pollInterval)
print("[WinPC] Plugin started. Polling " .. (host ~= "" and host or "(no hostname set)") .. " every " .. pollInterval .. "s.")

