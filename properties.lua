-- Network
table.insert(props, {
  Name  = "IP Address",
  Type  = "string",
  Value = ""
})

table.insert(props, {
  Name  = "MAC Address",
  Type  = "string",
  Value = ""
})

-- SSH credentials
table.insert(props, {
  Name  = "SSH Username",
  Type  = "string",
  Value = "qsyscontrol"
})

table.insert(props, {
  Name  = "SSH Private Key",
  Type  = "string",
  Value = ""
})

-- Windows-side paths
table.insert(props, {
  Name  = "Status File Path",
  Type  = "string",
  Value = [[C:\QSYSControl\status.txt]]
})

-- Polling
table.insert(props, {
  Name  = "Poll Interval",
  Type  = "integer",
  Min   = 5,
  Max   = 300,
  Value = 30
})

-- Pin visibility toggles
table.insert(props, {
  Name  = "Show Power Pins",
  Type  = "boolean",
  Value = true
})

table.insert(props, {
  Name  = "Show Volume Pins",
  Type  = "boolean",
  Value = true
})

table.insert(props, {
  Name  = "Show Status Pins",
  Type  = "boolean",
  Value = true
})

-- Debug
table.insert(props, {
  Name    = "Debug Print",
  Type    = "enum",
  Choices = { "None", "Tx/Rx", "All" },
  Value   = "None"
})
