local ADDON, ns = ...
-- Every integration this addon ships, in options-page order. A skin's file defines a factory
-- (ns.RegisterSkinDefinition); Core.lua runs it only once a target addon is enabled and loaded.
-- targets: the addon folders that count as installed. integration: not a frame skin (no skin file;
-- Integrations/<Id>/ installs it).
ns.skinCatalog = {
    {id = "Altoholic", label = "Altoholic", targets = {"Altoholic"}},
    {id = "Attune", label = "Attune", targets = {"Attune"}},
    {id = "Auctionator", label = "Auctionator", targets = {"Auctionator"}},
    {id = "BugSack", label = "BugSack", targets = {"BugSack"}},
    {id = "ForeverDungeonJournal", label = "Forever Dungeon Journal", targets = {"ForeverDungeonJournal"}},
    {id = "NaowhForever", label = "Naowh Forever", targets = {"NaowhForever"}, integration = true},
    {id = "OneForAll", label = "OneForAll", targets = {"OneForAll"}},
    {id = "WhatsTraining", label = "What's Training?", targets = {"WhatsTraining"}},
}
ns.skinCatalogByID = {}
for _, entry in ipairs(ns.skinCatalog) do ns.skinCatalogByID[entry.id] = entry end
