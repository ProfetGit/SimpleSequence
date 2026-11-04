local _, SS = ...

local SpellSource = {}
SS.SpellSource = SpellSource

local CATEGORY_ORDER = { "spec", "class", "general", "pet", "trinkets", "bags" }
local cache

local function byName(a, b)
    if a.name == b.name then
        return tostring(a.entry.id) < tostring(b.entry.id)
    end
    return a.name < b.name
end

local function newCategory(map, list, key, title, collapsed)
    local category = map[key]
    if not category then
        category = { key = key, title = title, collapsedByDefault = collapsed or false, entries = {} }
        map[key] = category
        list[#list + 1] = category
    end
    return category
end

local function scanSpellBook(map, list)
    local seen = {}
    local bank = Enum.SpellBookSpellBank.Player
    local spellType = Enum.SpellBookItemType.Spell
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if info and not info.shouldHide and not info.isGuild and not info.offSpecID then
            local category
            if info.specID then
                category = newCategory(map, list, "spec", info.name)
            elseif line == 1 then
                category = newCategory(map, list, "general", "General", true)
            else
                category = newCategory(map, list, "class", info.name)
            end
            for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
                if item and item.itemType == spellType and not item.isPassive and not item.isOffSpec then
                    local spellID = item.spellID or item.actionID
                    if spellID and not seen[spellID] then
                        seen[spellID] = true
                        local subtext = item.subName
                        category.entries[#category.entries + 1] = {
                            entry = { kind = "spell", id = spellID },
                            name = item.name,
                            icon = item.iconID,
                            subtext = (subtext and subtext ~= "") and subtext or nil,
                        }
                    end
                end
            end
        end
    end
end

local function scanPet(map, list)
    local count = C_SpellBook.HasPetSpells()
    if not count or count == 0 then return end
    local bank = Enum.SpellBookSpellBank.Pet
    local category = newCategory(map, list, "pet", "Pet")
    local seen = {}
    for slot = 1, count do
        local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
        if item and item.spellID and not item.isPassive and not seen[item.spellID] then
            seen[item.spellID] = true
            category.entries[#category.entries + 1] = {
                entry = { kind = "pet", id = item.spellID },
                name = item.name,
                icon = item.iconID,
            }
        end
    end
end

local function scanTrinkets(map, list)
    local category
    for slot = 13, 14 do
        local itemID = GetInventoryItemID("player", slot)
        if itemID and C_Item.GetItemSpell(itemID) then
            category = category or newCategory(map, list, "trinkets", "Trinkets")
            category.entries[#category.entries + 1] = {
                entry = { kind = "slot", id = slot },
                name = C_Item.GetItemNameByID(itemID) or ("Trinket " .. (slot - 12)),
                icon = GetInventoryItemTexture("player", slot),
                subtext = "Trinket " .. (slot - 12),
            }
        end
    end
end

local function scanBags(map, list)
    local seen = {}
    local category
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local itemID = info and info.itemID
            if itemID and not seen[itemID] and C_Item.GetItemSpell(itemID) then
                seen[itemID] = true
                category = category or newCategory(map, list, "bags", "Bag items")
                category.entries[#category.entries + 1] = {
                    entry = { kind = "item", id = itemID },
                    name = info.itemName or C_Item.GetItemNameByID(itemID) or ("Item " .. itemID),
                    icon = info.iconFileID,
                }
            end
        end
    end
end

local function scan()
    local map, list = {}, {}
    local steps = { scanSpellBook, scanPet, scanTrinkets, scanBags }
    for _, step in ipairs(steps) do
        local ok, err = pcall(step, map, list)
        if not ok then
            geterrorhandler()(err)
        end
    end
    local ordered = {}
    for _, key in ipairs(CATEGORY_ORDER) do
        local category = map[key]
        if category and #category.entries > 0 then
            table.sort(category.entries, byName)
            ordered[#ordered + 1] = category
        end
    end
    cache = ordered
    SS:Fire("SPELLS_UPDATED")
end

function SpellSource:Refresh()
    SS:Debounce("spellsource", 0.2, scan)
end

function SpellSource:GetCategories(filterText)
    if not cache then
        scan()
    end
    local needle = filterText and filterText:lower() or ""
    if needle == "" then
        return cache
    end
    local out = {}
    for _, category in ipairs(cache) do
        local entries = {}
        for _, item in ipairs(category.entries) do
            if item.name:lower():find(needle, 1, true) then
                entries[#entries + 1] = item
            end
        end
        if #entries > 0 then
            out[#out + 1] = {
                key = category.key,
                title = category.title,
                collapsedByDefault = category.collapsedByDefault,
                entries = entries,
            }
        end
    end
    return out
end

SS:RegisterGameEvent("SPELLS_CHANGED", function() SpellSource:Refresh() end)
SS:RegisterGameEvent("PLAYER_EQUIPMENT_CHANGED", function() SpellSource:Refresh() end)
SS:RegisterGameEvent("BAG_UPDATE_DELAYED", function() SpellSource:Refresh() end)
SS:RegisterUnitGameEvent("UNIT_PET", "player", function() SpellSource:Refresh() end)
SS:On("SPEC_CHANGED", function() SpellSource:Refresh() end)
