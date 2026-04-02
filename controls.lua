-- =============================================================
-- controls.lua -- Remote PC Control
--
-- All Q-SYS control objects for this plugin. Types, behaviors,
-- and pin visibility are defined here; visual layout is in
-- layout.lua.
-- =============================================================


-- UserPin=true puts the control in the Properties panel
-- Control Pins checklist. PinStyle sets the default:
-- a real direction ("Input"/"Output"/"Both") = checked/visible,
-- "None" = available but unchecked.


-- Power buttons (WOL + shutdown)
table.insert(ctrls, {
  Name        = "PowerOn",
  ControlType = "Button",
  ButtonType  = "Momentary",
  Count       = 1,
  UserPin     = true,
  PinStyle    = "Input",
  Icon        = "Power"
})

table.insert(ctrls, {
  Name        = "Shutdown",
  ControlType = "Button",
  ButtonType  = "Momentary",
  Count       = 1,
  UserPin     = true,
  PinStyle    = "Input",
  Icon        = "Power"
})


-- Status indicators (output-only, reflect PC state)
table.insert(ctrls, {
  Name          = "OnlineStatus",
  ControlType   = "Indicator",
  IndicatorType = "LED",
  Count         = 1,
  UserPin       = true,
  PinStyle      = "Output"
})

table.insert(ctrls, {
  Name          = "StatusText",
  ControlType   = "Indicator",
  IndicatorType = "Text",
  Count         = 1,
  UserPin       = true,
  PinStyle      = "Output"
})

table.insert(ctrls, {
  Name          = "LastPoll",
  ControlType   = "Indicator",
  IndicatorType = "Text",
  Count         = 1,
  UserPin       = true,
  PinStyle      = "Output"
})


-- Audio controls -- kept in sync with the PC via the poll timer
table.insert(ctrls, {
  Name        = "Volume",
  ControlType = "Knob",
  ControlUnit = "Integer",
  Min         = 0,
  Max         = 100,
  Count       = 1,
  UserPin     = true,
  PinStyle    = "Both"
})

table.insert(ctrls, {
  Name        = "VolumeMin",
  ControlType = "Knob",
  ControlUnit = "Integer",
  Min         = 0,
  Max         = 100,
  Count       = 1,
  UserPin     = false,
  PinStyle    = "None"
})

table.insert(ctrls, {
  Name        = "VolumeMax",
  ControlType = "Knob",
  ControlUnit = "Integer",
  Min         = 0,
  Max         = 100,
  Count       = 1,
  UserPin     = false,
  PinStyle    = "None"
})

table.insert(ctrls, {
  Name          = "VolumeWarning",
  ControlType   = "Indicator",
  IndicatorType = "LED",
  Count         = 1,
  UserPin       = false,
  PinStyle      = "None"
})

table.insert(ctrls, {
  Name        = "Mute",
  ControlType = "Button",
  ButtonType  = "Toggle",
  Count       = 1,
  UserPin     = true,
  PinStyle    = "Both"
})


-- Digit box so the user can type an exact volume %
table.insert(ctrls, {
  Name        = "VolumeEntry",
  ControlType = "Knob",
  ControlUnit = "Integer",
  Min         = 0,
  Max         = 100,
  Count       = 1,
  UserPin     = false,
  PinStyle    = "None"
})


-- Hostname reported by the PC in /status responses
table.insert(ctrls, {
  Name          = "DiscoveredName",
  ControlType   = "Indicator",
  IndicatorType = "Text",
  Count         = 1,
  UserPin       = false,
  PinStyle      = "None"
})


-- Setup page fields -- these mirror Properties so the integrator
-- can tweak config at runtime without reopening the Properties panel.
-- CfgUpdate writes them all back when pressed.
table.insert(ctrls, {
  Name          = "CfgComputerName",
  ControlType   = "Indicator",
  IndicatorType = "Text",
  Count         = 1,
  UserPin       = false,
  PinStyle      = "None"
})

table.insert(ctrls, {
  Name          = "CfgHostname",
  ControlType   = "Indicator",
  IndicatorType = "Text",
  Count         = 1,
  UserPin       = false,
  PinStyle      = "None"
})

table.insert(ctrls, {
  Name          = "MacDisplay",
  ControlType   = "Indicator",
  IndicatorType = "Text",
  Count         = 1,
  UserPin       = false,
  PinStyle      = "None"
})

table.insert(ctrls, {
  Name        = "CfgHttpPort",
  ControlType = "Knob",
  ControlUnit = "Integer",
  Min         = 1024,
  Max         = 65535,
  Count       = 1,
  UserPin     = false,
  PinStyle    = "None"
})

table.insert(ctrls, {
  Name        = "CfgPollInterval",
  ControlType = "Knob",
  ControlUnit = "Integer",
  Min         = 5,
  Max         = 300,
  Count       = 1,
  UserPin     = false,
  PinStyle    = "None"
})

table.insert(ctrls, {
  Name          = "CfgAuthToken",
  ControlType   = "Indicator",
  IndicatorType = "Text",
  Count         = 1,
  UserPin       = false,
  PinStyle      = "None"
})

table.insert(ctrls, {
  Name        = "CfgUpdate",
  ControlType = "Button",
  ButtonType  = "Momentary",
  Count       = 1,
  UserPin     = false,
  PinStyle    = "None"
})

