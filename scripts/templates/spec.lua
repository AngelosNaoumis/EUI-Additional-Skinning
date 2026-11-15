-- {{LABEL}}: TODO what the skin must do; one assert per behaviour, built from the real frame layout.
local T = dofile('tests/support.lua')
local ns = T.Load('Skins/{{ADDON}}.lua')

-- Mirror the target's frames (names and keys from /fstack).
_G.{{GLOBAL}} = {}
local window = T.Frame('Frame', nil, '{{ADDON}}Frame')
local button = T.Frame('Button', window); button.label = T.FontString(button, 'OK')

T.Install('{{ADDON}}')
assert(window.skin.Shell, 'window not shelled')
assert(button.skin.Button, 'button not styled')

-- Warm refreshes must not create UI objects or restyle what is already styled.
local regions = #window.regions
T.Refresh('{{ADDON}}'); T.Refresh('{{ADDON}}')
assert(#window.regions == regions, 'warm refresh created UI objects')
print('PASS: {{LABEL}} window, controls and warm refreshes')
