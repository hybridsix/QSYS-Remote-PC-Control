-- =============================================================
-- pages.lua -- Win PC Control
--
-- Populates the pages table from the PageNames list defined in
-- plugin.lua. Each entry creates one tab in the plugin panel.
--
-- Current pages:
--   Control -- operator-facing buttons, faders, status indicators
--   Setup   -- read-only display of current property values,
--              shown here for reference without opening Properties
-- =============================================================

for ix, name in ipairs(PageNames) do
  table.insert(pages, { name = PageNames[ix] })
end
