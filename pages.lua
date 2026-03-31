-- =============================================================
-- pages.lua -- Remote PC Control
--
-- Populates the pages table from the PageNames list defined in
-- plugin.lua. Each entry creates one tab in the plugin panel.
--
-- Current pages:
--   Control -- operator-facing buttons, faders, status indicators
--   Setup   -- editable configuration fields for runtime changes
--              without reopening the Properties panel
-- =============================================================

for ix, name in ipairs(PageNames) do
  table.insert(pages, { name = PageNames[ix] })
end
