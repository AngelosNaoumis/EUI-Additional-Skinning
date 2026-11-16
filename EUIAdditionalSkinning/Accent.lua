local ADDON, ns = ...

-- Additional Skinning deliberately does not add a top-edge accent to its windows. Keeping the
-- entry point as a no-op lets older skin call sites remain compatible without allocating a
-- texture or a look-change callback. Accent colours elsewhere (text, selections, bars) remain.
function ns.AttachAccent(S, frame)
end
