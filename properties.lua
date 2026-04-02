-- =============================================================
-- properties.lua -- Win PC Control
--
-- User-configurable properties shown in the Properties panel
-- in Q-SYS Designer.  Read at runtime via Properties["Name"].Value
-- =============================================================


-- Friendly name shown on the schematic block face.
-- Cosmetic only -- doesn't affect connectivity.
table.insert(props, {
  Name  = "Computer Name",
  Type  = "string",
  Value = ""
})


-- Where to find the PC on the network.
-- Hostname is preferred over IP since it survives DHCP changes
-- (assuming DNS/mDNS works on the network).
table.insert(props, {
  Name  = "Hostname or IP",
  Type  = "string",
  Value = ""
})

-- MAC address used for Wake-on-LAN.
-- This field is OPTIONAL. If left blank, the MAC will be
-- auto-discovered the first time the PC is polled successfully
-- (the server reports it in every /status response).
-- Only required if you need to WOL the PC before it has ever
-- been seen online by this plugin instance.
-- Format: "AA:BB:CC:DD:EE:FF" or "AA-BB-CC-DD-EE-FF"
table.insert(props, {
  Name  = "MAC Address",
  Type  = "string",
  Value = ""
})


-- HTTP port + auth token -- must match what install.ps1 put
-- into C:\QSYS Remote PC Control\config.txt on the target PC.
table.insert(props, {
  Name  = "HTTP Port",
  Type  = "integer",
  Min   = 1024,
  Max   = 65535,
  Value = 2207     -- Default port chosen to avoid IANA conflicts
})

table.insert(props, {
  Name  = "Auth Token",
  Type  = "string",
  Value = ""
})


-- Poll rate in seconds. 5s is snappy for audio; the plugin
-- backs off automatically when the PC stays offline a while.
table.insert(props, {
  Name  = "Poll Interval (s)",
  Type  = "integer",
  Min   = 1,
  Max   = 300,
  Value = 5
})

