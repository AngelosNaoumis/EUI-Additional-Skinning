local ADDON, ns = ...
-- {{LABEL}}. What is skinned, the frame map and the reasoning: docs/skins/{{ADDON}}.md.
local function DefineSkin()
ns.Skin("{{ADDON}}", {
    label = "{{LABEL}}",
    available = function() return _G.{{GLOBAL}} ~= nil end,
    -- Once at install: register the windows to skin and hook what creates or
    -- redraws them. Modes: "window", "content", "dialog" or "controls".
    setup = function(C)
        C.AddRoot(_G.{{ADDON}}Frame, "window")
        -- C.H.Hook(_G.{{GLOBAL}}, "ShowMainWindow", C.refresh)
    end,
    -- Every frame under a root. Buttons, inputs, checkboxes, dropdowns, scroll
    -- bars and status bars are already styled by kind; style special frames here
    -- and return true to claim them.
    visit = function(C, f, kind)
    end,
})
end
-- Runs once {{ADDON}} is enabled and loaded (Catalog.lua lists it).
ns.RegisterSkinDefinition("{{ADDON}}", DefineSkin)
