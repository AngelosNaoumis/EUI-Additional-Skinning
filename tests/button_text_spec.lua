-- Styled buttons fit oversized labels without changing button geometry or unrelated text.
local T = dofile('tests/support.lua')
local ns = T.Load()
local S = ns.StyledFacade(T.S, 'ButtonTextTest')

local function Button(text, width, height)
    local button = T.Frame('Button')
    button:SetSize(width or 100, height or 24)
    button.label = T.FontString(button, text)
    button.label:SetFont('native', 12, 'OUTLINE')
    button.label:SetTextColor(0.2, 0.7, 0.9, 0.8)
    return button, button.label
end

local short, shortLabel = Button('OK', 100)
local shortWidth, shortHeight = short:GetSize()
S.Button(short)
local path, size, flags = shortLabel:GetFont()
assert(path == 'native' and size == 12 and flags == 'OUTLINE', 'short label font changed')
assert(shortLabel:GetWordWrap() and shortLabel:GetMaxLines() == 0, 'short label layout was needlessly changed')
assert(shortWidth == short:GetWidth() and shortHeight == short:GetHeight(), 'button geometry changed')
assert(({shortLabel:GetTextColor()})[1] == 0.2 and ({shortLabel:GetTextColor()})[4] == 0.8,
    'button label colour changed')

local long, longLabel = Button('Localized long label', 140)
S.Button(long)
path, size, flags = longLabel:GetFont()
assert(path == 'native' and size == 10 and flags == 'OUTLINE', 'long label did not shrink to fit')
assert(long.euiasTextFitSize == 10 and not long.euiasTextFitOverflow, 'fit result was not recorded')
local stableWrites = longLabel.fontWrites
S.Button(long); ns.FitButtonText(long)
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
S.Font(longLabel)
path, size, flags = longLabel:GetFont()
assert(path == 'eui' and size == 10 and flags == '', 'EUI font styling lost the intended fit or font properties')
long:SetWidth(220)
assert(select(2, longLabel:GetFont()) == 12, 'EUI font base size was replaced by the fitted size')

local minimum, minimumLabel = Button(('W'):rep(40), 80)
S.Button(minimum)
assert(select(2, minimumLabel:GetFont()) == 9 and minimum.euiasTextFitOverflow,
    'minimum size or unfit exception was not preserved')

local withIcon, iconLabel = Button('Medium label', 112)
withIcon.Icon = T.Texture(withIcon); withIcon.Icon:SetSize(24, 24)
S.Button(withIcon)
assert(select(2, iconLabel:GetFont()) == 9, 'visible icon width was not reserved')

local iconOnly = T.Frame('Button')
iconOnly:SetSize(24, 24); iconOnly.Icon = T.Texture(iconOnly)
S.Button(iconOnly)
assert(iconOnly.euiasTextFitSize == nil, 'icon-only control was treated as a text button')

local multiline, multilineLabel = Button('Intentional multiline label', 90, 42)
multilineLabel:SetWordWrap(true); multilineLabel:SetMaxLines(2)
S.Button(multiline)
assert(select(2, multilineLabel:GetFont()) == 12 and multilineLabel:GetWordWrap()
    and multilineLabel:GetMaxLines() == 2, 'intentional multiline label was altered')

local deferred, deferredLabel = Button('Deferred dimensions', 0, 0)
S.Button(deferred)
assert(select(2, deferredLabel:GetFont()) == 12 and deferred.euiasTextFitSize == nil,
    'invalid dimensions changed the label')
deferred:SetSize(100, 24)
assert(select(2, deferredLabel:GetFont()) == 9, 'valid deferred dimensions did not trigger fitting')

print('PASS: scoped button label fitting, minimum, icons, dynamic text/width, multiline and idempotence')
