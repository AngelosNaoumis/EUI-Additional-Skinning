-- BugSack: window shelled (76px footer, no accent bar), its tabs follow PanelTemplates selection, nav buttons flat and laid out, OpenSack repaints at once, warm passes create nothing.
local T = dofile('tests/support.lua')
local ns = T.Load('Skins/BugSack.lua')

local opened = 0
BugSack = {OpenSack = function() opened = opened + 1 end, OpenConfig = function() end, CreateOptionsTab = function() end}
PanelTemplates_SelectTab = function() end
PanelTemplates_DeselectTab = function() end
local window = T.Frame('Frame', nil, 'BugSackFrame')
local tabs = {}
for _, name in ipairs({'BugSackTabAll', 'BugSackTabSession', 'BugSackTabLast'}) do
    local tab = T.Frame('Button', window, name); tab.label = T.FontString(tab, name); tabs[#tabs + 1] = tab
end
local next = T.Frame('Button', window, 'BugSackNextButton'); next.label = T.FontString(next, 'Next')

local geometry = 0
local function WatchGeometry(control)
    for _, method in ipairs({'ClearAllPoints', 'SetPoint', 'SetSize'}) do
        local original = control[method]
        control[method] = function(self, ...)
            geometry = geometry + 1
            return original(self, ...)
        end
    end
end
for _, control in ipairs({tabs[1], tabs[2], tabs[3], next}) do WatchGeometry(control) end

T.Install('BugSack')
assert(window.skin.Shell and window.skin.Shell.bottomBar == 76 and window.skin.Shell.noAccent, 'window shell options')
for _, r in ipairs(window.regions) do assert(r.height ~= 2, 'accent bar attached despite noAccent') end
assert(tabs[1].skin.Tab, 'tabs not styled')
assert(next.skin.Button and next.width == 110 and next.height == 28, 'nav button not flat or laid out')

-- A tab created after the first pass is laid out once after the existing chain.
local options = T.Frame('Button', window, 'BugSackTabOptions'); options.label = T.FontString(options, 'Options')
tabs[4] = options; WatchGeometry(options)
BugSack.CreateOptionsTab(); T.Flush()
assert(options.points[1][2] == tabs[3], 'late options tab did not follow the existing tab chain')
local initialGeometry = geometry

-- Selecting a tab through Blizzard's template marks only that tab selected.
PanelTemplates_SelectTab(tabs[2]); T.Flush()
assert(tabs[2].selected == true and tabs[1].selected == false, 'tab selection not followed')
-- OpenSack repaints within the same call (immediate, no queued frame) and still runs.
BugSack.OpenSack()
assert(opened == 1, 'OpenSack original not run')

local regions = #window.regions
T.Refresh('BugSack'); T.Refresh('BugSack')
assert(#window.regions == regions, 'warm pass created regions')
assert(geometry == initialGeometry, 'tab navigation or warm refresh repeated unchanged control geometry')
print('PASS: BugSack shell, PanelTemplates tab selection, one-time flat nav layout, immediate OpenSack repaint, warm passes')
