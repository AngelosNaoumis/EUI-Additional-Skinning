local ADDON, ns = ...
-- /eas dump <FrameName | mouse>: a compact frame map for writing a skin, saved in
-- EUIAdditionalSkinningDB.dumps and printed by scripts/read_dump.py after a /reload. Costs nothing
-- until used. One line per object: key or name, type, size, state, first anchor, art, text,
-- and the frame's own methods (mixin functions: what a skin can hook).
local MAX_DEPTH, MAX_LINES, TEXT, METHODS = 10, 600, 40, 10

local function Plain(value) return not (issecretvalue and issecretvalue(value)) end

-- Restricted frames return secret values (12.x): testing, comparing, formatting or doing
-- arithmetic on one is an error that taints. The dev tools read frames only through Read().
-- ok, ... from pcall: ok only when the call succeeded and every result is plain.
local function Checked(ok, ...)
    if not ok then return false end
    for i = 1, select("#", ...) do
        if not Plain((select(i, ...))) then return false end
    end
    return true, ...
end
local function Call(object, method, ...)
    local fn = object[method]
    if type(fn) ~= "function" then error("no method") end
    return fn(object, ...)
end
-- object:method(...) -> true, results (all plain), or false (no method, error or a secret). The
-- lookup is inside the pcall too: indexing a frame can raise.
local function Read(object, method, ...)
    if type(object) ~= "table" and type(object) ~= "userdata" then return false end
    return Checked(pcall(Call, object, method, ...))
end
-- One plain result or nil.
local function Value(object, method)
    local ok, value = Read(object, method)
    if ok then return value end
end
local function Number(object, method)
    local value = Value(object, method)
    if type(value) == "number" then return value end
end


-- Field names a parent keeps its children and regions under (frame.Inset, frame.Icon, ...).
local function Keys(parent)
    local keys = {}
    for key, value in pairs(parent) do
        if type(key) == "string" and type(value) == "table" and key ~= "parent" and keys[value] == nil then keys[value] = key end
    end
    return keys
end

local function Describe(object, keys, index)
    local kind = Value(object, "GetObjectType") or "?"
    local name = Value(object, "GetName")
    if type(name) ~= "string" then name = nil end
    local label = keys[object] or name or ("#" .. index)
    local parts = {label, kind}
    local w, h = Number(object, "GetWidth"), Number(object, "GetHeight")
    if w and h then parts[#parts + 1] = string.format("%dx%d", math.floor(w + 0.5), math.floor(h + 0.5)) end
    local ok, shown = Read(object, "IsShown")
    if ok and shown == false then parts[#parts + 1] = "hidden"
    elseif not ok and object.IsShown then parts[#parts + 1] = "shown=?" end
    if Value(object, "IsProtected") then parts[#parts + 1] = "protected" end
    if name and keys[object] then parts[#parts + 1] = "name=" .. name end
    local isRegion = type(object.GetDrawLayer) == "function"
    if isRegion then
        local layer = Value(object, "GetDrawLayer")
        parts[#parts + 1] = type(layer) == "string" and layer or "layer=?"
    end
    local points = Number(object, "GetNumPoints")
    if not isRegion and points and points > 0 then
        local okPoint, point, relative, relativePoint, x, y = Read(object, "GetPoint", 1)
        if okPoint and (x == nil or type(x) == "number") and (y == nil or type(y) == "number") then
            local to = "screen"
            if relative then
                local relName = Value(relative, "GetName")
                to = rawequal(relative, Value(object, "GetParent")) and "parent" or (type(relName) == "string" and relName) or "?"
            end
            parts[#parts + 1] = string.format("@%s>%s.%s(%d,%d)", tostring(point), to, tostring(relativePoint or point),
                math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5))
        end
    end
    -- Own functions are mixin methods; the widget API lives on the metatable and is not listed.
    if not isRegion then
        local methods = {}
        for key, value in pairs(object) do
            if type(key) == "string" and type(value) == "function" then methods[#methods + 1] = key end
        end
        if #methods > 0 then
            table.sort(methods)
            local listed = {}
            for i = 1, math.min(#methods, METHODS) do listed[i] = methods[i] end
            parts[#parts + 1] = "fn=" .. table.concat(listed, ",") .. (#methods > METHODS and (",+" .. (#methods - METHODS)) or "")
        end
    end
    if kind == "Texture" or kind == "MaskTexture" then
        local atlas = Value(object, "GetAtlas")
        local path = Value(object, "GetTexture")
        if type(atlas) == "string" and atlas ~= "" then parts[#parts + 1] = "atlas=" .. atlas
        elseif type(path) == "string" or type(path) == "number" then parts[#parts + 1] = "tex=" .. tostring(path) end
        local alpha = Number(object, "GetAlpha")
        if alpha and alpha < 1 then parts[#parts + 1] = string.format("alpha=%.2f", alpha) end
    elseif kind == "FontString" or kind == "Button" or kind == "EditBox" then
        local text = Value(object, "GetText")
        if type(text) == "string" and text ~= "" then
            parts[#parts + 1] = string.format("%q", text:sub(1, TEXT))
        end
    end
    return table.concat(parts, " ")
end

local function Dump(root)
    local lines = {}
    local function Walk(f, depth, keys, index)
        if #lines >= MAX_LINES then return end
        lines[#lines + 1] = string.rep("  ", depth) .. Describe(f, keys, index)
        local readable, forbidden = Read(f, "IsForbidden")
        if depth >= MAX_DEPTH or not readable or forbidden then return end
        local own = Keys(f)
        local regions = {Read(f, "GetRegions")}
        for i = 2, #regions do
            if #lines >= MAX_LINES then break end
            lines[#lines + 1] = string.rep("  ", depth + 1) .. Describe(regions[i], own, i - 1)
        end
        local children = {Read(f, "GetChildren")}
        for i = 2, #children do Walk(children[i], depth + 1, own, i - 1) end
    end
    Walk(root, 0, {}, 1)
    if #lines >= MAX_LINES then lines[#lines + 1] = "... truncated at " .. MAX_LINES .. " lines" end
    return lines
end

local function MouseFrame()
    local foci = GetMouseFoci and GetMouseFoci()
    if type(foci) == "table" then return foci[1] end
    return GetMouseFocus and GetMouseFocus()
end

ns.SlashCommands = ns.SlashCommands or {}
-- The dev commands answer only while Debug Mode is on (Skins page); otherwise they do no work.
local function DebugOnly(command)
    return function(argument, Print)
        if not ns.DebugMode() then
            return Print("Debug Mode is off: turn on Enable Debug Mode on the Skins page (/eas options).")
        end
        return command(argument, Print)
    end
end
ns.SlashCommands.dump = DebugOnly(function(argument, Print)
    if argument == "clear" then
        ns.DB().dumps = nil
        return Print("Saved dumps cleared.")
    end
    local target = argument == "mouse" and MouseFrame() or _G[argument or ""]
    if type(target) ~= "table" or not target.GetObjectType then
        return Print("Usage: /eas dump <GlobalFrameName>, dump mouse, or dump clear")
    end
    local name = argument == "mouse" and (target.GetName and target:GetName() or "mouse") or argument
    local db = ns.DB()
    db.dumps = db.dumps or {}
    local lines = Dump(target)
    db.dumps[name] = {time = time and time() or 0, lines = lines}
    Print(string.format("Dumped %s (%d lines). /reload, then: python scripts/read_dump.py %s", name, #lines, name))
end)

-- /eas probe <FrameName | mouse>: which textures draw over a window (or under the cursor), top
-- first in draw order: strata, frame level, draw layer and sublevel, then alpha, colour, art and
-- owner (GetDebugName; GetSourceLocation where the client has it). For finding an overlay that
-- dims a window. Scans every frame once, on demand only; saved as dumps["probe <target>"].
-- Every value read from a frame goes through Read(), which hands back only plain values; a secret
-- or failing read is "unknown" ("?" in the report).
-- A texture whose draw order is not fully known is listed after the ordered ones, marked order=?.
local STRATA = {BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6,
    FULLSCREEN_DIALOG = 7, TOOLTIP = 8}
local LAYER = {BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5}
local PROBE_CHAT, PROBE_SAVED, COVER = 12, 80, 0.5

-- A rectangle in screen pixels (left, bottom, right, top), or nil (before layout, or secret).
local function ScreenRect(object, scale)
    local ok, l, b, w, h = Read(object, "GetRect")
    if not (ok and type(l) == "number" and type(b) == "number" and type(w) == "number" and type(h) == "number") then return nil end
    return l * scale, b * scale, (l + w) * scale, (b + h) * scale
end

local function Owner(object)
    local name = Value(object, "GetDebugName")
    if type(name) ~= "string" then
        local parentName = Value(Value(object, "GetParent"), "GetName")
        name = (type(parentName) == "string" and parentName or "?") .. "." .. tostring(Value(object, "GetObjectType") or "?")
    end
    local source = Value(object, "GetSourceLocation")
    if type(source) == "string" then name = name .. " from " .. source end
    return name
end

-- The frame that owns a texture: up to four levels of global name or parent key, then its type,
-- size, level, backdrop file and, for a panel one of our scoped skins painted, the rule.
local function KeyOf(f, parent)
    for key, value in pairs(parent) do
        if Plain(key) and Plain(value) and type(key) == "string" and rawequal(value, f) then return key end
    end
end
local function Frame(f)
    if type(f) ~= "table" then return "frame=?" end
    local path, node = {}, f
    for _ = 1, 4 do
        local name = Value(node, "GetName")
        if type(name) == "string" then table.insert(path, 1, name); break end
        local parent = Value(node, "GetParent")
        table.insert(path, 1, type(parent) == "table" and KeyOf(node, parent) or "?")
        if type(parent) ~= "table" then break end
        node = parent
    end
    local parts = {"frame=" .. table.concat(path, "."), tostring(Value(f, "GetObjectType") or "?")}
    local w, h = Number(f, "GetWidth"), Number(f, "GetHeight")
    if w and h then parts[#parts + 1] = string.format("%dx%d", math.floor(w + 0.5), math.floor(h + 0.5)) end
    local ok, backdrop = Read(f, "GetBackdrop")
    if ok and type(backdrop) == "table" and Plain(backdrop.bgFile) and type(backdrop.bgFile) == "string" then
        parts[#parts + 1] = "bgFile=" .. backdrop.bgFile
    end
    local source = ns.PanelSources and ns.PanelSources[f]
    if source then parts[#parts + 1] = "painted=" .. source end
    return table.concat(parts, " ")
end

local function Fmt(pattern, value) return type(value) == "number" and string.format(pattern, value) or "?" end

-- Every frame once: EnumerateFrames where the client has it, else the target's tree.
local function AllFrames(target)
    local frames = {}
    if EnumerateFrames then
        local ok, f = pcall(EnumerateFrames)
        while ok and f do
            frames[#frames + 1] = f
            ok, f = pcall(EnumerateFrames, f)
        end
    else
        local function Walk(f)
            frames[#frames + 1] = f
            local packed = {Read(f, "GetChildren")}
            if packed[1] then for i = 2, #packed do Walk(packed[i]) end end
        end
        Walk(target)
    end
    return frames
end

-- The textures of one frame worth listing, added to hits; returns what was skipped and why.
local function Collect(f, area, hits, skipped, window, cursor)
    local readable, forbidden = Read(f, "IsForbidden")
    if not readable then skipped.restricted = skipped.restricted + 1; return end
    if forbidden then return end
    local visible = Value(f, "IsVisible")
    if visible == false then return end
    local packed = {Read(f, "GetRegions")}
    if not packed[1] or #packed < 2 then return end
    local scale = Number(f, "GetEffectiveScale") or 1
    local strata = Value(f, "GetFrameStrata")
    local level = Number(f, "GetFrameLevel")
    local frameAlpha = Number(f, "GetEffectiveAlpha")
    local tl, tb, tr, tt = window[1], window[2], window[3], window[4]
    for i = 2, #packed do
        local region = packed[i]
        if Value(region, "GetObjectType") == "Texture" then
            local shown = Value(region, "IsVisible")
            local l, b, r, t = ScreenRect(region, scale)
            local alpha = Number(region, "GetAlpha")
            if alpha and frameAlpha then alpha = alpha * frameAlpha else alpha = nil end
            local keep = shown ~= false and (alpha == nil or alpha > 0.05)
            if keep and not l then
                skipped.geometry = skipped.geometry + 1
                keep = false
            elseif keep and cursor then
                keep = cursor[1] >= l and cursor[1] <= r and cursor[2] >= b and cursor[2] <= t
            elseif keep then
                local w = math.min(r, tr) - math.max(l, tl)
                local h = math.min(t, tt) - math.max(b, tb)
                keep = w > 0 and h > 0 and w * h >= area * COVER
            end
            if keep then
                local ok, layer, sub = Read(region, "GetDrawLayer")
                if not ok then layer, sub = nil, nil end
                local order = STRATA[strata] and level and LAYER[layer] and type(sub) == "number"
                hits[#hits + 1] = {region = region, strata = strata, level = level, layer = layer, sub = sub,
                    alpha = alpha, size = (r - l) * (t - b), known = order and true or false,
                    visible = shown == true and visible == true}
            end
        end
    end
end

-- Top first; anything with an unknown part of its order after all ordered ones (largest first).
local function Above(a, b)
    if a.known ~= b.known then return a.known end
    if not a.known then return a.size > b.size end
    if a.strata ~= b.strata then return STRATA[a.strata] > STRATA[b.strata] end
    if a.level ~= b.level then return a.level > b.level end
    if a.layer ~= b.layer then return LAYER[a.layer] > LAYER[b.layer] end
    if a.sub ~= b.sub then return a.sub > b.sub end
    return a.size > b.size
end

local function Line(i, hit)
    local region = hit.region
    local ok, cr, cg, cb, ca = Read(region, "GetVertexColor")
    local color = (ok and type(cr) == "number" and type(cg) == "number" and type(cb) == "number")
        and string.format("rgba=%.2f,%.2f,%.2f,%.2f", cr, cg, cb, type(ca) == "number" and ca or 1) or "rgba=?"
    local art = Value(region, "GetAtlas")
    if type(art) == "string" and art ~= "" then art = "atlas=" .. art
    else
        art = Value(region, "GetTexture")
        art = (type(art) == "string" or type(art) == "number") and ("tex=" .. tostring(art)) or "color"
    end
    local layer = type(hit.layer) == "string" and hit.layer or "?"
    return string.format("%d. %s %s %s%s alpha=%s %s %s%s%s %s | %s", i, type(hit.strata) == "string" and hit.strata or "?",
        Fmt("%d", hit.level), layer, Fmt("%+d", hit.sub), Fmt("%.2f", hit.alpha), color, art,
        hit.known and "" or " order=?", hit.visible and "" or " vis=?", Owner(region), Frame(Value(region, "GetParent")))
end

local function Probe(target, mouse)
    local window = {ScreenRect(target, Number(target, "GetEffectiveScale") or 1)}
    if not window[1] then return nil, "target has no readable position (not laid out yet, or restricted)" end
    local cursor
    if mouse then
        local x, y
        if GetCursorPosition then x, y = GetCursorPosition() end
        if not (type(x) == "number" and type(y) == "number" and Plain(x) and Plain(y)) then return nil, "cursor position unavailable" end
        cursor = {x, y}
    end
    local area = (window[3] - window[1]) * (window[4] - window[2])
    local hits, skipped = {}, {restricted = 0, geometry = 0, errors = 0}
    for _, f in ipairs(AllFrames(target)) do
        -- A last guard: one unreadable frame is counted, never ends the probe.
        if not pcall(Collect, f, area, hits, skipped, window, cursor) then skipped.errors = skipped.errors + 1 end
    end
    table.sort(hits, Above)
    local lines = {}
    for i = 1, math.min(#hits, PROBE_SAVED) do lines[i] = Line(i, hits[i]) end
    return lines, nil, skipped, #hits
end

-- The window under the cursor: the focused frame's top-level frame below UIParent.
local function TopLevel(f)
    for _ = 1, 64 do
        local parent = Value(f, "GetParent")
        if not parent or rawequal(parent, UIParent) then return f end
        f = parent
    end
    return f
end

ns.SlashCommands.probe = DebugOnly(function(argument, Print)
    local mouse = argument == "mouse"
    local target = mouse and MouseFrame() or _G[argument or ""]
    if mouse and target then target = TopLevel(target) end
    if type(target) ~= "table" or type(target.GetRect) ~= "function" then
        return Print("Usage: /eas probe <GlobalFrameName> (textures covering that window) or probe mouse (under the cursor)")
    end
    local lines, why, skipped, total = Probe(target, mouse)
    if not lines then return Print("Probe: " .. why) end
    local name = "probe " .. (mouse and "mouse" or argument)
    local note = string.format("skipped: %d restricted frames, %d textures without readable geometry, %d unreadable frames",
        skipped.restricted, skipped.geometry, skipped.errors)
    local saved = {note}
    for i = 1, #lines do saved[i + 1] = lines[i] end
    local db = ns.DB()
    db.dumps = db.dumps or {}
    db.dumps[name] = {time = time and time() or 0, lines = saved}
    Print(string.format("Probe %s: %d textures, top first%s", mouse and "under the cursor" or argument, total,
        #lines > PROBE_CHAT and string.format(" (first %d; %d saved, read_dump.py \"%s\")", PROBE_CHAT, #lines, name) or ""))
    for i = 1, math.min(#lines, PROBE_CHAT) do Print(lines[i]) end
    if skipped.restricted + skipped.geometry + skipped.errors > 0 then Print(note) end
end)

-- /eas perf [off|reset]: time every skin pass in game (count, average and worst ms), plus
-- WoW's own addon CPU metric where the client has it. Off by default; then a pass costs one check.
local stats = {}
function ns.RecordPass(id, ms)
    local entry = stats[id]
    if not entry then entry = {count = 0, total = 0, worst = 0}; stats[id] = entry end
    entry.count, entry.total = entry.count + 1, entry.total + ms
    if ms > entry.worst then entry.worst = ms end
end
ns.SlashCommands.perf = DebugOnly(function(argument, Print)
    if argument == "off" then ns.profiling = false; return Print("Pass timing off.") end
    if argument == "reset" then wipe(stats); return Print("Pass timings cleared.") end
    if not ns.profiling then
        ns.profiling = true
        return Print("Pass timing on: use the addons' windows, then /eas perf to read it (off, reset).")
    end
    local any = false
    for id, entry in pairs(stats) do
        any = true
        Print(string.format("%s: %d passes, %.2f ms average, %.2f ms worst", id, entry.count, entry.total / entry.count, entry.worst))
    end
    if not any then Print("No skin passes timed yet.") end
    local profiler = C_AddOnProfiler and C_AddOnProfiler.GetAddOnMetric
    local metric = Enum and Enum.AddOnProfilerMetric
    if profiler and metric and metric.RecentAverageTime then
        local recent = profiler(ADDON, metric.RecentAverageTime)
        local peak = metric.PeakTime and profiler(ADDON, metric.PeakTime)
        if recent and Plain(recent) then
            Print(string.format("Addon CPU (WoW profiler): %.3f ms recent average%s", recent,
                peak and Plain(peak) and string.format(", %.2f ms peak", peak) or ""))
        end
    end
end)
