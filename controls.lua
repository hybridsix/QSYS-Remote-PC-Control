local showPower  = props["Show Power Pins"].Value
local showVolume = props["Show Volume Pins"].Value
local showStatus = props["Show Status Pins"].Value

-- ---- Power ---------------------------------------------------------------
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

-- ---- Status --------------------------------------------------------------
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

-- ---- Audio ---------------------------------------------------------------
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
