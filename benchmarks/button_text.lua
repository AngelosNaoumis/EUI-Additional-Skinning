-- Styled-button text fitting: warm reapplication should measure/write nothing and allocate little.
local root = assert(BENCH_ROOT, 'BENCH_ROOT missing')
local counters = {measure = 0, fonts = 0}

InCombatLockdown = function() return false end
hooksecurefunc = function(object, method, callback)
    local original = object[method]
    object[method] = function(...)
        local values = table.pack(original(...))
        callback(...)
        return table.unpack(values, 1, values.n)
    end
end

local function Label(text)
    local label = {text = text, path = 'eui', size = 12, flags = '', wrap = true, maxLines = 0}
    function label:GetObjectType() return 'FontString' end
    function label:GetText() return self.text end
    function label:SetText(value) self.text = value end
    function label:GetFont() return self.path, self.size, self.flags end
    function label:SetFont(path, size, flags)
        self.path, self.size, self.flags = path, size, flags
        counters.fonts = counters.fonts + 1
    end
    function label:SetFontObject() end
    function label:GetUnboundedStringWidth()
        counters.measure = counters.measure + 1
        return #self.text * self.size * 0.6
    end
    function label:GetStringHeight() return self.size end
    function label:GetWordWrap() return self.wrap end
    function label:SetWordWrap(value) self.wrap = value end
    function label:GetMaxLines() return self.maxLines end
    function label:SetMaxLines(value) self.maxLines = value end
    return label
end

local function Button(text)
    local button = {label = Label(text), width = 140, height = 24}
    function button:GetObjectType() return 'Button' end
    function button:GetFontString() return self.label end
    function button:GetWidth() return self.width end
    function button:GetHeight() return self.height end
    function button:SetText(value) self.label:SetText(value) end
    function button:SetWidth(value) self.width = value end
    function button:SetHeight(value) self.height = value end
    function button:SetSize(width, height) self.width, self.height = width, height end
    return button
end

local automatic = true
local ns = {
    SupportsButtonTypography = function() return true end,
    ResolveButtonFontSize = function(_, original) return 'fixed', original end,
    ButtonFontSelection = function() return 'default' end,
    AutoResizeButtonText = function() return automatic end,
    MinimumAutoFontSize = function() return 8 end,
}
assert(loadfile(root .. '/Widgets.lua'))('EUIAdditionalSkinning', ns)
local S = ns.StyledFacade({
    Button = function() end,
    Font = function(text) text:SetFont('eui', select(2, text:GetFont()), '') end,
}, 'Benchmark')

local buttons = {}
for index = 1, 200 do
    buttons[index] = Button(index % 2 == 0 and 'Localized long label' or 'OK')
    S.Button(buttons[index])
end

counters.measure, counters.fonts = 0, 0
collectgarbage('collect'); collectgarbage('stop')
local heap, started = collectgarbage('count'), os.clock()
for _ = 1, 500 do for _, button in ipairs(buttons) do S.Button(button) end end
local warmTime, warmAllocated = os.clock() - started, collectgarbage('count') - heap
local warmMeasure, warmFonts = counters.measure, counters.fonts
collectgarbage('restart')

local dynamic = buttons[2].label
counters.measure, counters.fonts = 0, 0
collectgarbage('collect'); collectgarbage('stop')
heap, started = collectgarbage('count'), os.clock()
for index = 1, 10000 do dynamic:SetText(index % 2 == 0 and 'Localized long label' or 'OK') end
local dynamicTime, dynamicAllocated = os.clock() - started, collectgarbage('count') - heap
local dynamicMeasure, dynamicFonts = counters.measure, counters.fonts
collectgarbage('restart')

local steady = buttons[1].label
counters.measure, counters.fonts = 0, 0
collectgarbage('collect'); collectgarbage('stop')
heap, started = collectgarbage('count'), os.clock()
for _ = 1, 10000 do steady:SetText('OK') end
local steadyTime, steadyAllocated = os.clock() - started, collectgarbage('count') - heap
local steadyMeasure, steadyFonts = counters.measure, counters.fonts
collectgarbage('restart')

automatic = false
local disabled = {}
for index = 1, 200 do
    disabled[index] = Button('A long label that must never be measured while automatic fitting is off')
    S.Button(disabled[index])
end
counters.measure, counters.fonts = 0, 0
collectgarbage('collect'); collectgarbage('stop')
heap, started = collectgarbage('count'), os.clock()
for index = 1, 10000 do
    local button = disabled[index % #disabled + 1]
    button.label:SetText(index % 2 == 0 and 'Changed long label' or 'OK')
    button:SetWidth(index % 2 == 0 and 80 or 140)
    S.Button(button)
end
local disabledTime, disabledAllocated = os.clock() - started, collectgarbage('count') - heap
local disabledMeasure, disabledFonts = counters.measure, counters.fonts
collectgarbage('restart')

print(string.format('MEASURE warm %.6f %.3f %d %d dynamic %.6f %.3f %d %d steady %.6f %.3f %d %d disabled %.6f %.3f %d %d',
    warmTime, warmAllocated, warmMeasure, warmFonts,
    dynamicTime, dynamicAllocated, dynamicMeasure, dynamicFonts,
    steadyTime, steadyAllocated, steadyMeasure, steadyFonts,
    disabledTime, disabledAllocated, disabledMeasure, disabledFonts))
