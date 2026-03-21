-- Hide Debug Print when set to None to reduce clutter in the Properties panel.
-- Remove this block if you want Debug Print always visible.
if props["Debug Print"].Value == "None" then
  props["Debug Print"].IsHidden = true
else
  props["Debug Print"].IsHidden = false
end
