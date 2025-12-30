-------------------------------------------------------------------------------
-- Mariano_Addon: Pure Persistent Storage
-- Version: 2 | Structure: SavedVariables only, no combat logic
-------------------------------------------------------------------------------

---@type string
local addonName = ...
---@class ns
local addon = select(2, ...)

-------------------------------------------------------------------------------
-- LOCAL REFERENCES (Performance: avoid repeated _G lookups)
-------------------------------------------------------------------------------
local pairs, type, _G = pairs, type, _G

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------
local ADDON_VERSION = 2

-- CC types tracked by the system
local CC_TYPES = {
    "disorient", "incapacitate", "silence", "stun", "root",
    "disarm", "taunt", "knockback", "grip", "fear", "slow",
}

-- All WoW classes for storage partitioning
local CLASS_NAMES = {
    "DeathKnight", "DemonHunter", "Druid", "Evoker", "Hunter",
    "Mage", "Monk", "Paladin", "Priest", "Rogue",
    "Shaman", "Warlock", "Warrior",
}

-------------------------------------------------------------------------------
-- SCHEMA BUILDERS
-- Generate default tables programmatically (DRY principle)
-------------------------------------------------------------------------------
local function BuildCTTSchema()
    local ctt = {}
    for _, ccType in pairs(CC_TYPES) do
        ctt[ccType] = {}                      -- Success tracking: [npcID] = true
        ctt[ccType .. "ImmuneFound"] = {}     -- Immunity tracking: [npcID] = true
    end
    return ctt
end

local function BuildClassStorage()
    local classes = {}
    for _, className in pairs(CLASS_NAMES) do
        classes[className] = {}
    end
    -- Evoker has special nested structure
    classes.Evoker = { Prescience = {} }
    return classes
end

local function BuildDefaults()
    local defaults = BuildClassStorage()
    defaults.CTT = BuildCTTSchema()
    return defaults
end

-------------------------------------------------------------------------------
-- TABLE UTILITIES
-------------------------------------------------------------------------------
local function DeepCopy(original)
    if type(original) ~= "table" then
        return original
    end
    local copy = {}
    for k, v in pairs(original) do
        copy[k] = DeepCopy(v)
    end
    return copy
end

local function EnsureTable(parent, key)
    if parent[key] == nil then
        parent[key] = {}
    end
    return parent[key]
end

-------------------------------------------------------------------------------
-- INITIALIZATION LOGIC
-------------------------------------------------------------------------------
local function DisableAddonProfiler()
    if C_CVar then
        C_CVar.RegisterCVar("addonProfilerEnabled", "1")
        C_CVar.SetCVar("addonProfilerEnabled", "0")
    end
end

local function GetOrCreateSavedVars()
    local savedVars = _G[addonName]
    
    -- Create fresh if missing or version mismatch
    if not savedVars or savedVars.version ~= ADDON_VERSION then
        savedVars = { version = ADDON_VERSION }
        _G[addonName] = savedVars
    end
    
    return savedVars
end

local function MergeDefaults(target, defaults)
    for key, defaultValue in pairs(defaults) do
        if target[key] == nil then
            target[key] = DeepCopy(defaultValue)
        end
    end
end

local function EnsureCTTIntegrity(ctt)
    if not ctt then return end
    
    for _, ccType in pairs(CC_TYPES) do
        EnsureTable(ctt, ccType)
        EnsureTable(ctt, ccType .. "ImmuneFound")
    end
end

local function InitializeAddon()
    DisableAddonProfiler()
    
    local savedVars = GetOrCreateSavedVars()
    local defaults = BuildDefaults()
    
    -- Expose global reference
    Mariano_Addon = savedVars
    
    -- Populate missing sections
    MergeDefaults(Mariano_Addon, defaults)
    
    -- Defensive: ensure all CTT subtables exist
    EnsureCTTIntegrity(Mariano_Addon.CTT)
end

-------------------------------------------------------------------------------
-- EVENT HANDLING
-------------------------------------------------------------------------------
local function OnAddonLoaded(loadedAddon)
    if loadedAddon ~= addonName then
        return false
    end
    
    InitializeAddon()
    return true  -- Signal to unregister
end

local function OnEvent(frame, event, ...)
    if event == "ADDON_LOADED" then
        if OnAddonLoaded(...) then
            frame:UnregisterEvent("ADDON_LOADED")
        end
    end
end

-------------------------------------------------------------------------------
-- FRAME SETUP
-------------------------------------------------------------------------------
addon.eventFrame = CreateFrame("Frame", addonName .. "EventFrame", UIParent)
addon.eventFrame:RegisterEvent("ADDON_LOADED")
addon.eventFrame:SetScript("OnEvent", OnEvent)
