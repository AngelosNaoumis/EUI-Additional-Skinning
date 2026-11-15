local ADDON, ns = ...

-- ns.Skin(id, spec) is how every skin here is written. The spec says what to style;
-- this runs it the same way for every skin: one coalesced pass per frame, deferred
-- through combat, hidden roots walked once and then only while visible, windows
-- shelled by mode, refreshed on EUI look changes. SKIN-DEVELOPMENT.md documents each field.
--
-- Root modes: "controls" (default; controls only), "window" (themed shell),
-- "content" (shell without the title strip), "dialog" (shell with a footer strip).
local SHELLS = {window = {}, content = {noTopBar = true}, dialog = {bottomBar = 32}}
local NONE = {}

function ns.Skin(id, spec)
    local entry = ns.skinCatalogByID and ns.skinCatalogByID[id]
    ns.RegisterModule(id, spec.label or entry and entry.label or id, spec.available, function(S, module)
        S = spec.style and spec.style(S, module) or S
        local H = ns.CreateSkinHelper(S, module)
        local C = {S = S, H = H, module = module}
        local roots, shelled, walked = {}, {}, {}
        local waiting, Apply, h = false, nil, nil

        function C.refresh() H.Queue(module, Apply) end
        -- Persistent roots, walked every pass. Re-adding a root may change its mode;
        -- adding without a mode keeps the current one ("controls" for a new root).
        function C.AddRoot(f, mode)
            if f and f.GetObjectType then roots[f] = mode or roots[f] or "controls" end
        end

        -- Small skins put handlers on the spec; larger ones return them from
        -- build(C) so their helpers can share locals. Spec fields fill the gaps.
        h = spec.build and spec.build(C) or {}
        for key, value in pairs(spec) do if h[key] == nil then h[key] = value end end
        local visit = h.visit
        local function Visit(f, kind)
            if h.ace and H.Ace(f, C.refresh) then return true end
            if visit then return visit(C, f, kind) end
        end

        local function Walk(f, mode)
            if not H.Allowed(f) then return end
            if mode ~= "controls" and SHELLS[mode] and not shelled[f] then
                shelled[f] = true
                H.Shell(f, C.refresh, SHELLS[mode])
            end
            -- A hidden root is walked once, which hooks its controls' OnShow; after
            -- that only visible roots: hidden ones cannot change the look, and
            -- showing one queues its own refresh.
            if not walked[f] or not f.IsVisible or f:IsVisible() then
                walked[f] = true
                H.Scan(f, C.refresh, (visit or h.ace) and Visit)
            end
        end

        local function Pass()
            if InCombatLockdown and InCombatLockdown() then waiting = true; return end
            waiting = false
            if h.active and not h.active(C) then return end
            if h.before then h.before(C) end
            for f, mode in pairs(roots) do Walk(f, mode) end
            for _, entry in ipairs(h.roots and h.roots(C) or NONE) do
                if entry.GetObjectType then Walk(entry, "controls") else Walk(entry.frame, entry.mode or "controls") end
            end
            if h.after then h.after(C) end
            if S.RefreshSoftBorders then S.RefreshSoftBorders() end
        end
        -- Timed only while /eas perf is on (Dev.lua); otherwise one check per pass.
        Apply = function()
            if not ns.profiling then return Pass() end
            local started = debugprofilestop()
            Pass()
            ns.RecordPass(id, debugprofilestop() - started)
        end

        local events = CreateFrame("Frame")
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        for _, event in ipairs(h.events or NONE) do events:RegisterEvent(event) end
        events:SetScript("OnEvent", function(_, event, ...)
            if h.event then h.event(C, event, ...) end
            -- After combat only work that was deferred resumes.
            if ns.IsEnabled(module) and (event ~= "PLAYER_REGEN_ENABLED" or waiting) then C.refresh() end
        end)
        if h.setup then h.setup(C) end
        module.refresh = C.refresh
        if S.OnLooksChanged then S.OnLooksChanged(C.refresh) end
        C.refresh()
    end)
end
