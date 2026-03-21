-- =============================================================
-- controls.lua -- Win PC Control
--
-- Defines all Q-SYS control objects for this plugin.
-- Controls are the interactive elements the operator sees and
-- uses -- buttons, LEDs, faders, etc.
--
-- Control definitions here set the type, behavior, and whether
-- the control appears as an external pin on the schematic block.
-- The visual layout (position, size, color) lives in layout.lua.
--
-- PinStyle options:
--   "Input"  -- Pin receives signals from external sources
--   "Output" -- Pin sends signals to external destinations
--   "Both"   -- Pin can do either (for knobs/faders)
--
-- UserPin: when true, the control appears as a pin on the block
--   face. Driven by the Show Power/Volume/Status Pins properties
--   so the integrator can hide unused pins.
-- =============================================================


local showPower  = props["Show Power Pins"].Value
local showVolume = props["Show Volume Pins"].Value
local showStatus = props["Show Status Pins"].Value


-- -------------------------------------------------------------
-- POWER CONTROLS
-- Both are momentary buttons (they spring back when released).
-- PowerOn sends a Wake-on-LAN magic packet via UDP.
-- Shutdown sends an HTTP POST command to the Windows server.
-- Both are Input-only pins -- they receive trigger pulses.
-- -------------------------------------------------------------
table.insert(ctrls, {
  Name        = "PowerOn",
  ControlType = "Button",
  ButtonType  = "Momentary",
  Count       = 1,
  UserPin     = showPower,
  PinStyle    = "Input",
  Icon        = "Power"
})

table.insert(ctrls, {
  Name        = "Shutdown",
  ControlType = "Button",
  ButtonType  = "Momentary",
  Count       = 1,
  UserPin     = showPower,
  PinStyle    = "Input",
  Icon        = "Power"
})


-- -------------------------------------------------------------
-- STATUS CONTROLS
-- All Output-only -- they reflect PC state back to Q-SYS.
-- OnlineStatus: Boolean LED (true = online, false = offline)
-- StatusText:   String showing current state (Online, Booting, etc.)
-- LastPoll:     Timestamp string of the last successful /status poll
-- -------------------------------------------------------------
table.insert(ctrls, {
  Name          = "OnlineStatus",
  ControlType   = "Indicator",
  IndicatorType = "LED",
  Count         = 1,
  UserPin       = showStatus,
  PinStyle      = "Output"
})

table.insert(ctrls, {
  Name          = "StatusText",
  ControlType   = "Indicator",
  IndicatorType = "Text",
  Count         = 1,
  UserPin       = showStatus,
  PinStyle      = "Output"
})

table.insert(ctrls, {
  Name          = "LastPoll",
  ControlType   = "Indicator",
  IndicatorType = "Text",
  Count         = 1,
  UserPin       = showStatus,
  PinStyle      = "Output"
})


-- -------------------------------------------------------------
-- AUDIO CONTROLS
-- Volume: Knob/fader, 0-100 percent. PinStyle Both means an
--   external source can drive the volume OR it can be read out.
-- Mute:   Toggle button. PinStyle Both for same reason.
-- Both sync bidirectionally -- the poll timer updates them from
-- the server, and operator changes are sent back to Windows.
-- -------------------------------------------------------------
table.insert(ctrls, {
  Name        = "Volume",
  ControlType = "Knob",
  ControlUnit = "Percent",
  Min         = 0,
  Max         = 100,
  Count       = 1,
  UserPin     = showVolume,
  PinStyle    = "Both"
})

table.insert(ctrls, {
  Name        = "Mute",
  ControlType = "Button",
  ButtonType  = "Toggle",
  Count       = 1,
  UserPin     = showVolume,
  PinStyle    = "Both"
})
