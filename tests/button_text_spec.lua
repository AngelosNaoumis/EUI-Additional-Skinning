-- Button typography inheritance, native-font opt-out, reload-stable auto fitting and idempotence.
local T = dofile('tests/support.lua')
EUIAdditionalSkinningDB = {skinSettings = {Attune = {
    buttonFontSize = 12, autoResizeButtonText = true, minimumAutoFontSize = 8,
}}}
local ns = T.Load()
local S = ns.StyledFacade(T.S, 'Altoholic')
local AutoS = ns.StyledFacade(T.S, 'Attune')

local function Upvalue(fn, wanted)
    local index = 1
    while true do
        local name, value = debug.getupvalue(fn, index)
        if not name then return end
        if name == wanted then return value end
        index = index + 1
    end
end

local fittedButtons = assert(Upvalue(ns.FitButtonText, 'fittedButtons'), 'button fit cache not found')
local fittedLabels = assert(Upvalue(ns.FitButtonText, 'fittedLabels'), 'label fit cache not found')
assert(getmetatable(fittedButtons).__mode == 'kv' and getmetatable(fittedLabels).__mode == 'kv',
    'button fit caches can retain key/value cycles on Lua 5.1')

local function Button(text, width, height)
    local button = T.Frame('Button')
    button:SetSize(width or 100, height or 24)
    button.label = T.FontString(button, text)
    button.label:SetFont('native', 12, 'OUTLINE')
    button.label:SetTextColor(0.2, 0.7, 0.9, 0.8)
    return button, button.label
end

local function Count(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- Automatic fitting is off by default. Fixed mode applies the skin's configured size directly.
local fixedDefault, fixedDefaultLabel = Button('A very long default label', 70)
local disabledMeasurements = 0
local disabledMeasure = fixedDefaultLabel.GetUnboundedStringWidth
function fixedDefaultLabel:GetUnboundedStringWidth()
    disabledMeasurements = disabledMeasurements + 1
    return disabledMeasure(self)
end
S.Button(fixedDefault)
assert(select(2, fixedDefaultLabel:GetFont()) == 8 and fixedDefault.euiasTextFitSize == nil
    and not fixedDefault.euiasTextFitOverflow, 'default button size is not fixed at 8 with fitting off')
assert(not fittedButtons[fixedDefault] and not fittedLabels[fixedDefaultLabel] and disabledMeasurements == 0,
    'Auto Resize OFF entered the fitting engine or measured text')
fixedDefaultLabel:SetText('A different and much longer localized label')
fixedDefault:SetSize(45, 18); fixedDefault:Hide(); fixedDefault:Show(); S.Button(fixedDefault)
assert(disabledMeasurements == 0 and select(2, fixedDefaultLabel:GetFont()) == 8
    and not fittedButtons[fixedDefault],
    'Auto Resize OFF measured, fitted or allocated state after text/size/show/reapply changes')
assert(not ns.AutoResizeButtonText('Altoholic') and ns.ButtonFontSelection('Altoholic') == 'default'
    and ns.DefaultButtonFontSize() == 8
    and ns.MinimumAutoFontSize('ButtonTextTest') == 8, 'typography defaults are wrong')

-- The remaining cases opt this skin into automatic fitting with a 12px preferred size.
local buttonsBefore, labelsBefore = Count(fittedButtons), Count(fittedLabels)
local function FitTemporaryButton()
    local button = Button('Temporary long localized label', 100)
    AutoS.Button(button)
end
FitTemporaryButton()
assert(Count(fittedButtons) == buttonsBefore + 1 and Count(fittedLabels) == labelsBefore + 1,
    'temporary fitted control was not tracked')
collectgarbage('collect'); collectgarbage('collect')
assert(Count(fittedButtons) == buttonsBefore and Count(fittedLabels) == labelsBefore,
    'dead fitted control state was retained')

local short, shortLabel = Button('OK', 100)
local shortWidth, shortHeight = short:GetSize()
AutoS.Button(short)
local path, size, flags = shortLabel:GetFont()
assert(path == 'native' and size == 12 and flags == 'OUTLINE', 'short label did not use its preferred size')
assert(shortLabel:GetWordWrap() and shortLabel:GetMaxLines() == 0, 'short label layout was needlessly changed')
assert(shortWidth == short:GetWidth() and shortHeight == short:GetHeight(), 'button geometry changed')
assert(({shortLabel:GetTextColor()})[1] == 0.2 and ({shortLabel:GetTextColor()})[4] == 0.8,
    'button label colour changed')

local long, longLabel = Button('Localized long label', 140)
AutoS.Button(long)
path, size, flags = longLabel:GetFont()
assert(path == 'native' and size == 10 and flags == 'OUTLINE', 'long label did not shrink to fit')
assert(long.euiasTextFitSize == 10 and not long.euiasTextFitOverflow, 'fit result was not recorded')
local stableWrites = longLabel.fontWrites
AutoS.Button(long); ns.FitButtonText(long)
assert(longLabel:GetFont() == 'native' and select(2, longLabel:GetFont()) == 10,
    'repeated application cumulatively shrank the label')
assert(longLabel.fontWrites == stableWrites, 'unchanged label was recalculated')

longLabel:SetText('OK')
assert(select(2, longLabel:GetFont()) == 12, 'short dynamic label did not regain intended size')
assert(longLabel:GetWordWrap() and longLabel:GetMaxLines() == 0,
    'short dynamic label did not regain its original layout')
longLabel:SetText('Localized long label')
assert(select(2, longLabel:GetFont()) == 10, 'long dynamic label did not refit')
assert(not longLabel:GetWordWrap() and longLabel:GetMaxLines() == 1, 'long label was allowed to wrap')
long:SetWidth(220)
assert(select(2, longLabel:GetFont()) == 12, 'wider button did not restore intended size')
stableWrites = longLabel.fontWrites
long:SetWidth(220)
assert(longLabel.fontWrites == stableWrites, 'unchanged available width rewrote the font')
long:SetWidth(140)
assert(select(2, longLabel:GetFont()) == 10, 'narrower button did not refit')

-- Applying the shared EUI font after an earlier fit must use the intended 12px size as its base,
-- not the already-shrunk size. This is the normal S.Button then S.Font skin path.
AutoS.Font(longLabel)
path, size, flags = longLabel:GetFont()
assert(path == 'eui' and size == 10 and flags == '', 'EUI font styling lost the intended fit or font properties')
long:SetWidth(220)
assert(select(2, longLabel:GetFont()) == 12, 'EUI font base size was replaced by the fitted size')

local minimum, minimumLabel = Button(('W'):rep(40), 80)
AutoS.Button(minimum)
assert(select(2, minimumLabel:GetFont()) == 8 and minimum.euiasTextFitOverflow,
    'minimum size or unfit exception was not preserved')

local withIcon, iconLabel = Button('Medium label', 112)
withIcon.Icon = T.Texture(withIcon); withIcon.Icon:SetSize(24, 24)
AutoS.Button(withIcon)
assert(select(2, iconLabel:GetFont()) == 9, 'visible icon width was not reserved')

local iconOnly = T.Frame('Button')
iconOnly:SetSize(24, 24); iconOnly.Icon = T.Texture(iconOnly)
AutoS.Button(iconOnly)
assert(iconOnly.euiasTextFitSize == nil, 'icon-only control was treated as a text button')

local multiline, multilineLabel = Button('Intentional multiline label', 90, 42)
multilineLabel:SetWordWrap(true); multilineLabel:SetMaxLines(2)
AutoS.Button(multiline)
assert(select(2, multilineLabel:GetFont()) == 12 and multilineLabel:GetWordWrap()
    and multilineLabel:GetMaxLines() == 2, 'intentional multiline label was altered')

local deferred, deferredLabel = Button('Deferred dimensions', 0, 0)
AutoS.Button(deferred)
assert(select(2, deferredLabel:GetFont()) == 12 and deferred.euiasTextFitSize == nil,
    'invalid dimensions changed the label')
deferred:SetSize(100, 24)
assert(select(2, deferredLabel:GetFont()) == 8, 'valid deferred dimensions did not trigger fitting')

local steady, steadyLabel = Button('Unchanged status', 160)
local measurements = 0
local getWidth = steadyLabel.GetUnboundedStringWidth
function steadyLabel:GetUnboundedStringWidth()
    measurements = measurements + 1
    return getWidth(self)
end
AutoS.Button(steady)
measurements = 0
for _ = 1, 1000 do steadyLabel:SetText('Unchanged status') end
assert(measurements == 0, 'unchanged repeated text was remeasured')

-- Automatic mode never enlarges beyond the target's original size, and an original smaller than
-- the configured minimum stays smaller. Fixed mode may enlarge only after an explicit choice.
EUIAdditionalSkinningDB.skinSettings.Attune.buttonFontSize = 18
local capped, cappedLabel = Button('OK', 100)
AutoS.Button(capped)
assert(select(2, cappedLabel:GetFont()) == 12, 'automatic mode enlarged past the original font size')
local tiny, tinyLabel = Button('OK', 100)
tinyLabel:SetFont('native', 6, 'OUTLINE')
AutoS.Button(tiny)
assert(select(2, tinyLabel:GetFont()) == 6, 'minimum auto size enlarged an originally smaller font')
cappedLabel:SetFont('replacement-font', 10, 'THICKOUTLINE')
local changedPath, changedSize, changedFlags = cappedLabel:GetFont()
assert(changedPath == 'replacement-font' and changedSize == 10 and changedFlags == 'THICKOUTLINE',
    'a target font change was enlarged or lost its font properties')
EUIAdditionalSkinningDB.skinSettings.Auctionator = {buttonFontSize = 14}
local FixedS = ns.StyledFacade(T.S, 'Auctionator')
local fixed, fixedLabel = Button('Fixed', 100)
FixedS.Button(fixed)
assert(select(2, fixedLabel:GetFont()) == 14, 'explicit fixed mode did not allow a selected larger size')
EUIAdditionalSkinningDB.skinSettings.Auctionator.buttonFontSize = 10
ns.RefreshButtonTypography('Auctionator')
assert(select(2, fixedLabel:GetFont()) == 10, 'explicit fixed-size change was not applied live')

-- Addon's Font Size restores the captured native font and then observes later native changes
-- without reapplying a global or fixed size.
EUIAdditionalSkinningDB.skinSettings.BugSack = {buttonFontSize = 'addon'}
local NativeS = ns.StyledFacade(T.S, 'BugSack')
local native, nativeLabel = Button('Native', 100)
NativeS.Button(native)
assert(nativeLabel:GetFont() == 'native' and select(2, nativeLabel:GetFont()) == 12,
    'Add-on font mode did not restore native typography')
nativeLabel:SetFont('addon-updated', 13, 'THICKOUTLINE')
assert(nativeLabel:GetFont() == 'addon-updated' and select(2, nativeLabel:GetFont()) == 13,
    'Add-on font mode interfered with a later native font update')

-- A global change repaints only inheriting fixed buttons. Explicit, automatic and native choices
-- retain their independent behavior.
ns.SetDefaultButtonFontSize(9)
ns.RefreshInheritedButtonTypography()
assert(select(2, fixedDefaultLabel:GetFont()) == 9, 'inheriting button ignored the new global default')
assert(select(2, fixedLabel:GetFont()) == 10 and select(2, nativeLabel:GetFont()) == 13,
    'global default changed an explicit or native-font skin')
EUIAdditionalSkinningDB.skinSettings.Attune.autoResizeButtonText = nil
assert(ns.AutoResizeButtonText('Attune') and not ns.ConfiguredAutoResizeButtonText('Attune')
    and ns.ButtonFontSelectionLocked('Attune'),
    'Reload Later partially disabled automatic fitting or unlocked its fixed selector')

-- Protected buttons created during combat are untouched, then updated by Core's existing
-- combat-end event without a timer or global scan.
local protected, protectedLabel = Button('Protected', 100)
protected.protected = true
T.combat = true
FixedS.Button(protected)
assert(select(2, protectedLabel:GetFont()) == 12, 'protected button font changed in combat')
T.combat = false
T.Fire('PLAYER_REGEN_ENABLED')
assert(select(2, protectedLabel:GetFont()) == 10, 'protected button font was not deferred to combat end')

print('PASS: global/default/explicit/native typography, reload-stable fitting, original cap and idempotence')
