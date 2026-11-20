local ADDON, ns = ...
-- Every integration this addon ships, in options-page order. A skin's file defines a factory
-- (ns.RegisterSkinDefinition); Core.lua runs it only once a target addon is enabled and loaded.
-- targets: the addon folders that count as installed. integration: not a frame skin (no skin file;
-- Integrations/<Id>/ installs it).
ns.skinCatalog = {
    {id = "AnglersFieldGuide", label = "Angler's Field Guide", targets = {"AnglersFieldGuide"}, buttons = true, typography = true},
    {id = "Altoholic", label = "Altoholic", targets = {"Altoholic"}, buttons = true, typography = true},
    {id = "Attune", label = "Attune", targets = {"Attune"}, buttons = true, typography = true},
    {id = "Auctionator", label = "Auctionator", targets = {"Auctionator"}, buttons = true, typography = true},
    {id = "BugSack", label = "BugSack", targets = {"BugSack"}, buttons = true, typography = true},
    {id = "ForeverDungeonJournal", label = "Forever Dungeon Journal", targets = {"ForeverDungeonJournal"}, buttons = true, typography = true},
    {id = "NaowhForever", label = "Naowh Forever", targets = {"NaowhForever"}, integration = true, buttons = true},
    {id = "OneForAll", label = "OneForAll", targets = {"OneForAll"}, buttons = true, typography = true},
    {id = "WhatsTraining", label = "What's Training?", targets = {"WhatsTraining"}, buttons = true, typography = true},
    {id = "GearQuestForever", label = "GearQuest Forever", targets = {"GearQuestForever"}, buttons = true, typography = true},
    {id = "HuntersFieldGuide", label = "Hunter's Field Guide", targets = {"HuntersFieldGuide"}, buttons = true, typography = true},
    {id = "BattlegroundEnemiesFixed", label = "BattlegroundEnemiesFixed", targets = {"BattleGroundEnemiesFixed"}, features = {
        {key = "frames", label = "Unit-frame borders", tooltip = "Draw the configured EUI border around every enemy unit frame."},
        {key = "dividers", label = "Health/Power dividers", tooltip = "Draw a matching divider between each visible enemy Health and Power bar."},
        {key = "auras", label = "Buff/debuff borders", tooltip = "Border BattlegroundEnemiesFixed's shared class/spec and crowd-control debuff surface."},
        {key = "icons", label = "Additional icon borders", tooltip = "Border visible trinket, objective, respawn, DR and combat status icons."},
    }},
    {id = "DeadlyBossMods", label = "Deadly Boss Mods", targets = {"DBM-StatusBarTimers"}, features = {
        {key = "bars", label = "Unified timer border", tooltip = "Draw one configured border around each DBM timer bar and its visible icons."},
        {key = "icons", label = "Icon/bar dividers", tooltip = "Draw matching dividers between visible DBM timer icons and the bar."},
    }},
    {id = "LagBuddy", label = "LagBuddy", targets = {"LagBuddy"}, buttons = true, typography = true},
}
ns.skinCatalogByID = {}
for _, entry in ipairs(ns.skinCatalog) do ns.skinCatalogByID[entry.id] = entry end
