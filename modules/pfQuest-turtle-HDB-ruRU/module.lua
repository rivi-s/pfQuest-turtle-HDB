-- Keep a single pre-translation font snapshot shared by all display hooks.
-- Capturing separately after another hook applied Arial loses the real default.
local originalFonts = setmetatable({}, { __mode = "k" })
local function RememberOriginalFont(region)
  local original = originalFonts[region]
  if not original then
    local font, size, flags = region:GetFont()
    original = { font, size, flags }
    originalFonts[region] = original
  end
  return original[1], original[2], original[3]
end
local function SnapshotQuestLogFonts(frame)
  if not frame or not frame.GetRegions then return end
  for _, region in ipairs({frame:GetRegions()}) do
    if region.GetObjectType and region:GetObjectType() == "FontString" then RememberOriginalFont(region) end
  end
  for _, child in ipairs({frame:GetChildren()}) do SnapshotQuestLogFonts(child) end
end
SnapshotQuestLogFonts(QuestLogFrame)
SnapshotQuestLogFonts(getglobal("EQL3_QuestLogFrame"))

-- Optional display translations only: never replace English lookup tables or
-- native client locale, and never change item/creature identity matching.
pfDB.quests.ruRU = pfDB.quests.ruRU or {}
for id, text in pairs(pfDB.quests["ruRU-turtle"] or {}) do
  pfDB.quests.ruRU[id] = text
end
pfDB.quests["ruRU-turtle"] = nil
pfDB.locales.ruRU = "Russian"

local entryOriginals = setmetatable({}, { __mode = "k" })
local regionOriginals = setmetatable({}, { __mode = "k" })
local function Translate(value, russian)
  return russian and (pfQuestRussianUI[value] or value) or value
end
local function TranslateEntries(russian)
  for _, entry in ipairs(pfQuest_defconfig or {}) do
    local original = entryOriginals[entry]
    if not original then
      original = { text = entry.text, tooltip = entry.tooltip }
      entryOriginals[entry] = original
    end
    -- Definitions remain English. Otherwise a newly created settings row
    -- captures Russian as its original text and cannot restore English later.
    -- Translate only the rendered regions and completed hover tooltip.
    entry.text = original.text
    entry.tooltip = original.tooltip
  end
end
local function TranslateRegions(frame, russian)
  -- Confine Cyrillic fonts and label changes to the settings window.
  for _, region in ipairs({frame:GetRegions()}) do
    if region.GetObjectType and region:GetObjectType() == "FontString" then
      local original = regionOriginals[region]
      local current = region:GetText()
      if not original or current ~= original.applied then
        local font, size, flags = RememberOriginalFont(region)
        original = { text = current, font = font, size = size, flags = flags }
        regionOriginals[region] = original
      end
      local translated = Translate(original.text, russian)
      region:SetText(translated)
      original.applied = translated
      region:SetFont(russian and "Fonts\\ARIALN.TTF" or original.font, original.size, original.flags)
    end
  end
  for _, child in ipairs({frame:GetChildren()}) do TranslateRegions(child, russian) end
end
if pfQuestConfig then
  local previous = pfQuestConfig:GetScript("OnShow")
  pfQuestConfig:SetScript("OnShow", function()
    local russian = pfQuest_config and pfQuest_config.translate == "ruRU" or false
    TranslateEntries(russian)
    if previous then previous() end
    TranslateRegions(pfQuestConfig, russian)
  end)
  -- Entries can be rebuilt when changing settings pages while the window is open.
  local create = pfQuestConfig.CreateConfigEntries
  if create then
    function pfQuestConfig:CreateConfigEntries(config)
      local russian = pfQuest_config and pfQuest_config.translate == "ruRU" or false
        TranslateEntries(russian)
      create(self, config)
      TranslateRegions(self, russian)
    end
  end
end

-- Tracker and quest tooltips: change rendered text only. Button identity,
-- metadata, native quest rows and progress parsing remain English.
local function ReplaceLiteral(text, english, russian)
  if not text or not english or english == "" or not russian or russian == "" then return text end
  local start, stop = string.find(text, english, 1, true)
  if not start then return text end
  return string.sub(text, 1, start - 1) .. russian .. string.sub(text, stop + 1)
end
local function RussianQuest(id)
  return pfQuest_config and pfQuest_config.translate == "ruRU"
    and pfDB.quests.ruRU[tonumber(id)] or nil
end
local trackerFonts = setmetatable({}, { __mode = "k" })
local function RenderRussianTitle(button)
  local id = button.questid or button.node and button.node.questid
  local text = RussianQuest(id)
  if not button.text then return end
  if not trackerFonts[button.text] then
    local font, size, flags = RememberOriginalFont(button.text)
    trackerFonts[button.text] = { font, size, flags }
  end
  local original = trackerFonts[button.text]
  if not text or not text.T then
    button.text:SetFont(original[1], original[2], original[3])
    return
  end
  local displayed = button.text:GetText()
  button.text:SetText(ReplaceLiteral(displayed, button.title, text.T))
  local _, size, flags = button.text:GetFont()
  button.text:SetFont("Fonts\\ARIALN.TTF", size, flags)
end
local tooltipFonts = setmetatable({}, { __mode = "k" })
local function DecorateTooltip(tooltip, id, englishTitle, firstLine)
  if not tooltip or not pfQuest_config or pfQuest_config.translate ~= "ruRU" then return end
  local quest = RussianQuest(id)
  local englishObjective = id and pfDatabase.GetQuestObjectiveHDB and pfDatabase:GetQuestObjectiveHDB(id)
  local name = tooltip:GetName()
  if not name then return end
  for index = firstLine or 1, tooltip:NumLines() do
    for _, side in ipairs({"Left", "Right"}) do
      local region = getglobal(name .. "Text" .. side .. index)
      if region and region:GetText() then
        local text = region:GetText()
        if quest then
          text = ReplaceLiteral(text, englishTitle, quest.T)
          if englishObjective and quest.O then
            text = ReplaceLiteral(text, pfDatabase:FormatQuestText(englishObjective), pfDatabase:FormatQuestText(quest.O))
          end
        end
        text = pfQuestRussianUI[text] or text
        region:SetText(text)
        if not tooltipFonts[region] then
          local font, size, flags = RememberOriginalFont(region)
          tooltipFonts[region] = { font, size, flags }
        end
        local original = tooltipFonts[region]
        region:SetFont("Fonts\\ARIALN.TTF", original[2], original[3])
      end
    end
  end
  if not tooltip.pfQuestRussianFontHook then
    local previous = tooltip:GetScript("OnHide")
    tooltip:SetScript("OnHide", function()
      for region, original in pairs(tooltipFonts) do region:SetFont(original[1], original[2], original[3]) end
      if previous then previous() end
    end)
    tooltip.pfQuestRussianFontHook = true
  end
  tooltip:Show()
end
local tracker = pfQuest and pfQuest.tracker
if tracker then
  local event = tracker.ButtonEvent
  tracker.ButtonEvent = function(button)
    button = button or this
    event(button)
    RenderRussianTitle(button)
  end
  local enter = tracker.ButtonEnter
  tracker.ButtonEnter = function()
    enter()
    local id = this.questid or this.node and this.node.questid
    DecorateTooltip(GameTooltip, id, this.title)
  end
end
if pfMap and pfMap.ShowTooltip then
  local show = pfMap.ShowTooltip
  function pfMap:ShowTooltip(meta, tooltip)
    tooltip = tooltip or GameTooltip
    local first = tooltip:NumLines() + 1
    show(self, meta, tooltip)
    local focus = GetMouseFocus and GetMouseFocus()
    if tooltip == WorldMapTooltip or (focus and focus.node) then first = 1 end
    DecorateTooltip(tooltip, meta.questid, meta.quest, first)
  end
end

local languageFrame = CreateFrame("Frame")
languageFrame:RegisterEvent("PLAYER_LOGIN")
languageFrame:SetScript("OnEvent", function()
  local button = pfQuest and pfQuest.buttonLanguage
  if not button then return end
  local previous = button:GetScript("OnUpdate")
  local selected = pfQuest_config.translate
  button:SetScript("OnUpdate", function()
    if previous then previous() end
    if selected ~= pfQuest_config.translate then
      selected = pfQuest_config.translate
      for _, entry in pairs(tracker and tracker.buttons or {}) do entry.contentPending = true end
    end
  end)
  for _, entry in pairs(tracker and tracker.buttons or {}) do entry.contentPending = true end
end)

local function DisplayTranslation(text)
  if type(text) ~= "string" or not pfQuest_config or pfQuest_config.translate ~= "ruRU" then return text end
  local objectiveKey = string.gsub(text, "%s+", " ")
  objectiveKey = string.gsub(objectiveKey, "^%s*(.-)%s*$", "%1")
  local summary = pfQuestRussianObjectives and pfQuestRussianObjectives[objectiveKey]
  if summary then return pfDatabase:FormatQuestText(summary) end
  local direct = pfQuestRussianUI[text] or pfQuestRussianNames[text]
  if direct then return direct end
  if string.find(text, "\n", 1, true) then
    return string.gsub(text, "[^\n]+", function(line) return DisplayTranslation(line) end)
  end
  local flat = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
  flat = string.gsub(flat, "|r", "")
  if string.find(text, "|H", 1, true) then
    return string.gsub(text, "(|h%[)(.-)(%]|h)", function(open, caption, close)
      return open .. (pfQuestRussianNames[caption] or pfQuestRussianUI[caption] or caption) .. close
    end)
  end
  -- Journal rows carry a timestamp, bracketed title and numeric quest ID.
  -- Translate only the title caption; retain timestamps, IDs and color codes.
  if string.find(flat, "^%s*%d%d:%d%d:%d%d") then
    return string.gsub(text, "(%[)([^%[%]]+)(%])", function(open, caption, close)
      return open .. (pfQuestRussianNames[caption] or caption) .. close
    end)
  end
  local flatDirect = pfQuestRussianUI[flat] or pfQuestRussianNames[flat]
  if flatDirect then
    local _, _, color = string.find(text, "^(|c%x%x%x%x%x%x%x%x)")
    return color and (color .. flatDirect .. "|r") or flatDirect
  end
  local _, _, field, value = string.find(flat, "^(.-):%s*(.*)$")
  if field == "Level" or field == "Type" or field == "Respawn" or field == "Required" or field == "Drop chance" then
    return (pfQuestRussianUI[field] or field) .. ": " .. DisplayTranslation(value)
  end
  local _, _, item, source = string.find(flat, "^Loot %[(.-)%] from (.-)%.?$")
  if item and source then
    source = string.gsub(source, "%.$", "")
    return "Получить [" .. (pfQuestRussianNames[item] or item) .. "] у "
      .. (pfQuestRussianNames[source] or source) .. "."
  end
  local _, _, killed = string.find(flat, "^Kill (.-)%.?$")
  if killed then
    killed = string.gsub(killed, "%.$", "")
    return "Убить " .. (pfQuestRussianNames[killed] or killed) .. "."
  end
  local candidate = string.gsub(flat, "^%s+", "")
  candidate = string.gsub(candidate, "^%-%s*", "")
  candidate = string.gsub(candidate, "^%[[%d%+]+%]%s*", "")
  candidate = string.gsub(candidate, "%s*%([%d%.]+%%%)%s*$", "")
  candidate = string.gsub(candidate, "%s*%([%d%*%-]+%)%s*$", "")
  candidate = string.gsub(candidate, "%s*%[[%d%.]+%%%]%s*$", "")
  local _, _, label = string.find(candidate, "^(.-):")
  candidate = label or candidate
  candidate = string.gsub(candidate, "^%s*(.-)%s*$", "%1")
  local slain = string.find(candidate, " slain$") or string.find(candidate, " killed$")
  local name = slain and string.sub(candidate, 1, slain - 1) or candidate
  local replacement = pfQuestRussianUI[name] or pfQuestRussianNames[name]
  if replacement then
    if slain then replacement = replacement .. " — убито" end
    local translated = ReplaceLiteral(text, candidate, replacement)
    translated = ReplaceLiteral(translated, "(Complete)", "(Выполнено)")
    return translated
  end
  text = string.gsub(text, "Required:", "Требуется:")
  text = string.gsub(text, "(%d+) Days?", "%1 дн.")
  text = string.gsub(text, "(%d+) Hrs?", "%1 ч.")
  text = string.gsub(text, "(%d+) Mins?", "%1 мин.")
  text = string.gsub(text, "(%d+) Secs?", "%1 сек.")
  return text
end
local displayRegions = setmetatable({}, { __mode = "k" })
local function HookDisplayRegions(frame)
  if not frame or not frame.GetRegions then return end
  for _, region in ipairs({frame:GetRegions()}) do
    if region.GetObjectType and region:GetObjectType() == "FontString" and not displayRegions[region] then
      local font, size, flags = RememberOriginalFont(region)
      local state = { font = font, size = size, flags = flags, text = region:GetText(), set = region.SetText }
      displayRegions[region] = state
      region.SetText = function(self, value)
        state.text = value
        local russian = pfQuest_config and pfQuest_config.translate == "ruRU"
        state.rendered = DisplayTranslation(value)
        state.set(self, state.rendered)
        local _, currentSize, currentFlags = self:GetFont()
        self:SetFont(russian and "Fonts\\ARIALN.TTF" or state.font, currentSize or state.size, currentFlags or state.flags)
      end
      region:SetText(state.text)
    elseif displayRegions[region] then
      -- Native button:SetText bypasses a FontString's Lua wrapper. Capture
      -- that fresh English label after a quest-log redraw and repaint it.
      local state = displayRegions[region]
      local current = region:GetText()
      if current ~= state.rendered then state.text = current end
      region:SetText(state.text)
    end
  end
  for _, child in ipairs({frame:GetChildren()}) do HookDisplayRegions(child) end
end
local function HookDisplayRoot(frame)
  if not frame then return end
  local previous = frame:GetScript("OnShow")
  frame:SetScript("OnShow", function()
    if previous then previous() end
    HookDisplayRegions(frame)
  end)
  HookDisplayRegions(frame)
end
local questLogDisplayReady = CreateFrame("Frame")
questLogDisplayReady:RegisterEvent("PLAYER_LOGIN")
questLogDisplayReady:SetScript("OnEvent", function()
  HookDisplayRoot(QuestLogFrame)
  HookDisplayRoot(getglobal("EQL3_QuestLogFrame"))
end)
HookDisplayRoot(pfBrowser)
HookDisplayRoot(getglobal("pfQuestLootPanel"))
if tracker then
  local update = tracker.ButtonEvent
  tracker.ButtonEvent = function(button)
    button = button or this
    update(button)
    HookDisplayRegions(button)
  end
end
if pfQuest and pfQuest.route then HookDisplayRoot(pfQuest.route.arrow) end
-- Only pfQuest-created tooltip additions and tracker tooltips are decorated.
-- Native nameplates, game strings, caches and item links are not rewritten.
local decorate = DecorateTooltip
DecorateTooltip = function(tooltip, id, englishTitle, firstLine)
  decorate(tooltip, id, englishTitle, firstLine)
  if not tooltip or not pfQuest_config or pfQuest_config.translate ~= "ruRU" then return end
  local name = tooltip:GetName()
  if not name then return end
  for index = firstLine or 1, tooltip:NumLines() do
    for _, side in ipairs({"Left", "Right"}) do
      local region = getglobal(name .. "Text" .. side .. index)
      if region and region:GetText() then region:SetText(DisplayTranslation(region:GetText())) end
    end
  end
end
-- Repaint existing module-owned regions on language changes without modifying
-- their English source values or forcing any database refresh.
local repaintLanguage = CreateFrame("Frame")
local repaintElapsed, repaintSelected = 0, nil
repaintLanguage:SetScript("OnUpdate", function()
  repaintElapsed = repaintElapsed + (arg1 or 0)
  if repaintElapsed < 0.25 then return end
  repaintElapsed = 0
  local selected = pfQuest_config and pfQuest_config.translate
  if selected == repaintSelected then return end
  repaintSelected = selected
  if pfJournal then pfJournal.dirty = true end
  TranslateEntries(false)
  if pfQuestConfig then TranslateRegions(pfQuestConfig, selected == "ruRU") end
  for region, state in pairs(displayRegions) do region:SetText(state.text) end
  -- The quest list reuses FontStrings and may read their displayed text while
  -- rebuilding. Regenerate native English row text before rendering the new
  -- language, instead of retaining Cyrillic rows under restored English fonts.
  if QuestLogFrame and QuestLogFrame:IsShown() and type(QuestLog_Update) == "function" then
    QuestLog_Update()
    HookDisplayRegions(QuestLogFrame)
  end
end)

-- The native quest-list buttons render through C-side SetText. Refresh their
-- display after each normal quest-log redraw, without altering row identities.
if type(QuestLog_Update) == "function" then
  local redraw = QuestLog_Update
  QuestLog_Update = function()
    redraw()
    if QuestLogFrame and QuestLogFrame:IsShown() then HookDisplayRegions(QuestLogFrame) end
  end
end

HookDisplayRoot(pfQuestMenu)
HookDisplayRoot(getglobal("pfQuestMenuExtended"))
HookDisplayRoot(pfQuest and pfQuest.mapButton)
HookDisplayRoot(pfQuest and pfQuest.mapLevelButton)

-- FontString wrappers do not intercept the native SetText used by buttons.
-- Refresh just the visible quest rows from their saved English display source.
local rowDisplays = setmetatable({}, { __mode = "k" })
local function PaintQuestRows()
  if not QuestLogFrame or not QuestLogFrame:IsShown() then return end
  for index = 1, (QUESTS_DISPLAYED or 20) do
    local button = getglobal("QuestLogTitle" .. index)
    if button and button.GetText and button.SetText then
      local current = button:GetText()
      local state = rowDisplays[button]
      if not state then state = {}; rowDisplays[button] = state end
      if current ~= state.rendered then state.source = current end
      state.rendered = DisplayTranslation(state.source)
      if current ~= state.rendered then button:SetText(state.rendered) end
      local region = button.GetFontString and button:GetFontString()
      if region then
        if not state.font then state.font, state.size, state.flags = RememberOriginalFont(region) end
        local russian = pfQuest_config and pfQuest_config.translate == "ruRU"
        region:SetFont(russian and "Fonts\\ARIALN.TTF" or state.font, state.size, state.flags)
      end
    end
  end
end
local rowsFrame = CreateFrame("Frame")
local rowsElapsed = 0
rowsFrame:SetScript("OnUpdate", function()
  rowsElapsed = rowsElapsed + (arg1 or 0)
  if rowsElapsed < 0.2 then return end
  rowsElapsed = 0
  PaintQuestRows()
  if WorldMapFrame and WorldMapFrame:IsShown() then
    HookDisplayRegions(pfQuest and pfQuest.mapButton)
    HookDisplayRegions(pfQuest and pfQuest.mapLevelButton)
  end
end)

-- Blizzard dropdowns are shared. Translate only pfQuest-owned menus and set
-- fonts on each new button, restoring the native font for unrelated menus.
local activeRussianDropdown
if type(UIDropDownMenu_AddButton) == "function" then
  local add = UIDropDownMenu_AddButton
  local dropdownFonts = setmetatable({}, { __mode = "k" })
  UIDropDownMenu_AddButton = function(info, level)
    local owner = activeRussianDropdown or UIDROPDOWNMENU_INIT_MENU or UIDROPDOWNMENU_OPEN_MENU
    local owned = owner and pfQuest and (owner == pfQuest.mapButton or owner == pfQuest.mapLevelButton)
    local russian = owned and pfQuest_config and pfQuest_config.translate == "ruRU"
    local passed = info
    if russian then
      passed = {}
      for key, value in pairs(info) do passed[key] = value end
      passed.text = DisplayTranslation(info.text)
    end
    add(passed, level)
    for index = 1, (UIDROPDOWNMENU_MAXBUTTONS or 32) do
      local region = getglobal("DropDownList" .. (level or UIDROPDOWNMENU_MENU_LEVEL or 1) .. "Button" .. index .. "NormalText")
      if region then
        if not dropdownFonts[region] then
          local font, size, flags = RememberOriginalFont(region)
          dropdownFonts[region] = {font, size, flags}
        end
        local original = dropdownFonts[region]
        region:SetFont(russian and "Fonts\\ARIALN.TTF" or original[1], original[2], original[3])
      end
    end
  end
end

-- English clients differ in which dropdown owner global they set. Capture
-- the actual ToggleDropDownMenu argument, and repaint its native button labels.
if type(ToggleDropDownMenu) == "function" then
  local toggle = ToggleDropDownMenu
  ToggleDropDownMenu = function(level, value, menu, anchor, x, y)
    activeRussianDropdown = menu
    toggle(level, value, menu, anchor, x, y)
    local owned = menu and pfQuest and (menu == pfQuest.mapButton or menu == pfQuest.mapLevelButton)
    activeRussianDropdown = nil
    if not owned or not pfQuest_config or pfQuest_config.translate ~= "ruRU" then return end
    for index = 1, (UIDROPDOWNMENU_MAXBUTTONS or 32) do
      local button = getglobal("DropDownList" .. (level or 1) .. "Button" .. index)
      if button and button.GetText and button.SetText then
        button:SetText(DisplayTranslation(button:GetText()))
        local region = button.GetFontString and button:GetFontString()
        if region then
          local _, size, flags = region:GetFont()
          region:SetFont("Fonts\\ARIALN.TTF", size, flags)
        end
      end
    end
  end
end

-- Config tooltips live in GameTooltip rather than under pfQuestConfig.
-- Apply fonts after its normal OnShow handler, only for owners inside settings.
if GameTooltip then
  local previous = GameTooltip:GetScript("OnShow")
  GameTooltip:SetScript("OnShow", function()
    if previous then previous() end
    if not pfQuest_config or pfQuest_config.translate ~= "ruRU" then return end
    local owner = GameTooltip.GetOwner and GameTooltip:GetOwner()
    local depth = 0
    while owner and depth < 20 do
      if owner == pfQuestConfig then
        DecorateTooltip(GameTooltip, nil, nil)
        return
      end
      owner = owner.GetParent and owner:GetParent()
      depth = depth + 1
    end
  end)
end

-- Hook the actual settings hover handlers: SetText may show GameTooltip before
-- AddLine adds the body, so OnShow alone cannot format all of its lines.
local configHoverHooks = setmetatable({}, { __mode = "k" })
local function HookConfigHovers(frame)
  if not frame then return end
  local enter = frame:GetScript("OnEnter")
  if enter and not configHoverHooks[frame] then
    configHoverHooks[frame] = true
    frame:SetScript("OnEnter", function()
      if pfQuest_config and pfQuest_config.translate == "ruRU" then
        for index = 1, 30 do
          for _, side in ipairs({"Left", "Right"}) do
            local region = getglobal("GameTooltipText" .. side .. index)
            if region then
              if not tooltipFonts[region] then
                local font, size, flags = RememberOriginalFont(region)
                tooltipFonts[region] = {font, size, flags}
              end
              local original = tooltipFonts[region]
              region:SetFont("Fonts\\ARIALN.TTF", original[2], original[3])
            end
          end
        end
      end
      enter()
      DecorateTooltip(GameTooltip, nil, nil)
    end)
  end
  for _, child in ipairs({frame:GetChildren()}) do HookConfigHovers(child) end
end
if pfQuestConfig then
  local create = pfQuestConfig.CreateConfigEntries
  if create then
    function pfQuestConfig:CreateConfigEntries(config)
      create(self, config)
      HookConfigHovers(self)
    end
  end
  HookConfigHovers(pfQuestConfig)
end

-- Core dropdown scripts can hold cached Blizzard function references. Hook
-- their real click handlers and repaint native NormalText after they finish.
local function PaintOpenMapDropdown()
  if not pfQuest_config or pfQuest_config.translate ~= "ruRU" then return end
  for level = 1, 2 do
    local list = getglobal("DropDownList" .. level)
    if list and list:IsShown() then
      for index = 1, (UIDROPDOWNMENU_MAXBUTTONS or 32) do
        local region = getglobal("DropDownList" .. level .. "Button" .. index .. "NormalText")
        if region and region:GetText() then
          local _, size, flags = region:GetFont()
          region:SetFont("Fonts\\ARIALN.TTF", size, flags)
          region:SetText(DisplayTranslation(region:GetText()))
        end
      end
    end
  end
end
local function HookMapDropdownClick(frame)
  if not frame then return end
  -- OnClick is a Button script, not a generic Frame script. Asking the
  -- dropdown container for it can abort module initialization in 1.12.
  local isButton = frame.GetObjectType and (frame:GetObjectType() == "Button" or frame:GetObjectType() == "CheckButton")
  local click = isButton and frame:GetScript("OnClick")
  if click then
    frame:SetScript("OnClick", function()
      click()
      PaintOpenMapDropdown()
    end)
  end
  for _, child in ipairs({frame:GetChildren()}) do HookMapDropdownClick(child) end
end
HookMapDropdownClick(pfQuest and pfQuest.mapButton)
HookMapDropdownClick(pfQuest and pfQuest.mapLevelButton)
-- Map controls are created during login, after dependent addons load.
local delayedMapHooks = CreateFrame("Frame")
delayedMapHooks:SetScript("OnUpdate", function()
  if not pfQuest or not pfQuest.mapButton or not pfQuest.mapLevelButton then return end
  if not delayedMapHooks.installed then
    HookDisplayRoot(pfQuest.mapButton)
    HookDisplayRoot(pfQuest.mapLevelButton)
    HookMapDropdownClick(pfQuest.mapButton)
    HookMapDropdownClick(pfQuest.mapLevelButton)
    delayedMapHooks.installed = true
  end
  delayedMapHooks:SetScript("OnUpdate", nil)
end)

-- Some map addons replace the stock dropdown frames and row names. Locate
-- the visible menu through its hovered frame rather than assuming globals.
-- Only the two pfQuest map menus' known labels are eligible for this pass.
local mapMenuLabels = {
  ["All Quests"] = true, ["Tracked Quests"] = true,
  ["Manual Selection"] = true, ["Hide Quests"] = true,
  ["Current Zone Only"] = true, ["Red & Lower"] = true,
  ["Orange & Lower"] = true, ["Yellow & Lower"] = true,
  ["Green & Lower"] = true, ["Grey & Lower"] = true,
}
local function PaintMapMenuRegions(frame)
  for _, region in ipairs({frame:GetRegions()}) do
    if region.GetObjectType and region:GetObjectType() == "FontString" then
      local text = region:GetText()
      local plain = text and string.gsub(string.gsub(text, "|c%x%x%x%x%x%x%x%x", ""), "|r", "")
      if plain and mapMenuLabels[plain] then
        local _, size, flags = region:GetFont()
        region:SetFont("Fonts\\ARIALN.TTF", size, flags)
        region:SetText(DisplayTranslation(text))
      end
    end
  end
  for _, child in ipairs({frame:GetChildren()}) do PaintMapMenuRegions(child) end
end
local visibleMapMenu = CreateFrame("Frame")
local visibleMenuElapsed = 0
visibleMapMenu:SetScript("OnUpdate", function()
  visibleMenuElapsed = visibleMenuElapsed + (arg1 or 0)
  if visibleMenuElapsed < 0.1 then return end
  visibleMenuElapsed = 0
  if not pfQuest_config or pfQuest_config.translate ~= "ruRU"
      or not WorldMapFrame or not WorldMapFrame:IsShown() then return end
  local focus = GetMouseFocus and GetMouseFocus()
  for depth = 1, 6 do
    if not focus or focus == UIParent or focus == WorldMapFrame then return end
    local name = focus.GetName and focus:GetName()
    if name and string.find(string.lower(name), "dropdown", 1, true) then
      -- Paint this row and its container, covering unnamed custom menu rows.
      local parent = focus.GetParent and focus:GetParent()
      local parentName = parent and parent.GetName and parent:GetName()
      local menuParent = parentName and string.find(string.lower(parentName), "dropdown", 1, true)
      PaintMapMenuRegions(menuParent and parent or focus)
      return
    end
    focus = focus.GetParent and focus:GetParent()
  end
end)


-- The same complete-hover formatting applies to pfQuest's own map/minimap
-- controls. Scope the hook to their frames; never translate general UI hovers.
HookConfigHovers(pfQuestIcon)
local controlTooltipHooks = CreateFrame("Frame")
controlTooltipHooks:SetScript("OnUpdate", function()
  if not pfQuest or not pfQuest.mapButton or not pfQuest.mapLevelButton then return end
  HookConfigHovers(pfQuest.mapButton)
  HookConfigHovers(pfQuest.mapLevelButton)
  HookConfigHovers(pfQuestIcon)
  controlTooltipHooks:SetScript("OnUpdate", nil)
end)

-- Browser UI and result rows are created lazily. Install the root hook when
-- it exists, and attach new rows in bounded batches while the browser is open.
local browserTranslations = CreateFrame("Frame")
local browserElapsed, browserHooked = 0, nil
local browserPositions = {}
browserTranslations:SetScript("OnUpdate", function()
  browserElapsed = browserElapsed + (arg1 or 0)
  if browserElapsed < 0.15 then return end
  browserElapsed = 0
  if not pfBrowser then return end
  if not browserHooked then
    HookDisplayRoot(pfBrowser)
    HookConfigHovers(pfBrowser)
    browserHooked = true
  end
  if not pfBrowser:IsShown() then return end
  for key, tab in pairs(pfBrowser.tabs or {}) do
    local button = tab.button
    if button and button.GetText then
      local text = button:GetText()
      local state = rowDisplays[button]
      if not state then state = {}; rowDisplays[button] = state end
      if text ~= state.rendered then state.source = text end
      state.rendered = DisplayTranslation(state.source)
      if state.rendered ~= text then button:SetText(state.rendered) end
      local region = button.GetFontString and button:GetFontString()
      if region then
        if not state.font then state.font, state.size, state.flags = RememberOriginalFont(region) end
        local russian = pfQuest_config and pfQuest_config.translate == "ruRU"
        region:SetFont(russian and "Fonts\\ARIALN.TTF" or state.font, state.size, state.flags)
      end
    end
    local rows = tab.buttons or {}
    local total = table.getn(rows)
    local position = browserPositions[key] or 1
    for step = 1, math.min(total, 8) do
      if position > total then position = 1 end
      local row = rows[position]
      if row then HookDisplayRegions(row); HookConfigHovers(row) end
      position = position + 1
    end
    browserPositions[key] = position
  end
  -- Tooltip writes are translated synchronously by the browser-owned
  -- SetText/AddLine/AddDoubleLine hooks below; no delayed tooltip repaint.

end)

-- Browser tooltip text must be translated before native tooltip measurement,
-- not by the later display refresh (which causes a visible resize).
local function IsRussianBrowserTooltip(tooltip)
  if not pfQuest_config or pfQuest_config.translate ~= "ruRU" then return false end
  local owner = tooltip.GetOwner and tooltip:GetOwner()
  for depth = 1, 12 do
    if not owner then break end
    if owner.node or owner.pfResultButton or owner == (pfQuest and pfQuest.tracker) then return true end
    if owner == pfBrowser or owner == pfJournal or owner == pfQuestInit
        or owner == getglobal("pfQuestLootPanel") then return true end
    owner = owner.GetParent and owner:GetParent()
  end
  local focus = GetMouseFocus and GetMouseFocus()
  return focus and (focus.node or focus.pfResultButton) and true or false
end
local function PrepareBrowserTooltipFonts(tooltip)
  local name = tooltip:GetName()
  if not name then return end
  for index = 1, 30 do
    for _, side in ipairs({"Left", "Right"}) do
      local region = getglobal(name .. "Text" .. side .. index)
      if region then
        if not tooltipFonts[region] then
          local font, size, flags = RememberOriginalFont(region)
          tooltipFonts[region] = {font, size, flags}
        end
        local original = tooltipFonts[region]
        region:SetFont("Fonts\\ARIALN.TTF", original[2], original[3])
      end
    end
  end
end
local function HookPfQuestTooltipWrites(tooltip)
  if not tooltip or tooltip.pfQuestRussianWrites then return end
  tooltip.pfQuestRussianWrites = true
  local setText, addLine, addDoubleLine = tooltip.SetText, tooltip.AddLine, tooltip.AddDoubleLine
  -- Lua 5.0's arg.n retains optional arguments and nil holes exactly.
  tooltip.SetText = function(self, ...)
    if IsRussianBrowserTooltip(self) then
      PrepareBrowserTooltipFonts(self)
      arg[1] = DisplayTranslation(arg[1])
    end
    return setText(self, unpack(arg, 1, arg.n))
  end
  tooltip.AddLine = function(self, ...)
    if IsRussianBrowserTooltip(self) then
      PrepareBrowserTooltipFonts(self)
      arg[1] = DisplayTranslation(arg[1])
    end
    return addLine(self, unpack(arg, 1, arg.n))
  end
  tooltip.AddDoubleLine = function(self, ...)
    if IsRussianBrowserTooltip(self) then
      PrepareBrowserTooltipFonts(self)
      arg[1], arg[2] = DisplayTranslation(arg[1]), DisplayTranslation(arg[2])
    end
    return addDoubleLine(self, unpack(arg, 1, arg.n))
  end
end

HookPfQuestTooltipWrites(GameTooltip)
HookPfQuestTooltipWrites(WorldMapTooltip)

-- Complete remaining standalone systems without replacing their game data.
local translatedRoots = setmetatable({}, { __mode = "k" })
local function InstallOptionalRoot(root)
  if not root or translatedRoots[root] then return end
  translatedRoots[root] = true
  HookDisplayRoot(root)
  HookConfigHovers(root)
end
local systemsFrame = CreateFrame("Frame")
local systemsElapsed = 0
systemsFrame:SetScript("OnUpdate", function()
  systemsElapsed = systemsElapsed + (arg1 or 0)
  if systemsElapsed < 0.25 then return end
  systemsElapsed = 0
  HookPfQuestTooltipWrites(getglobal("pfQuestLootItemTooltip"))
  InstallOptionalRoot(pfQuest and pfQuest.tracker)
  InstallOptionalRoot(pfQuestInit)
  InstallOptionalRoot(pfJournal)
  InstallOptionalRoot(getglobal("pfQuestLootPanel"))
  InstallOptionalRoot(getglobal("pfQuestChangelogWindow"))
  InstallOptionalRoot(getglobal("pfQuestConfigResizeGrip"))
  if pfQuest and pfQuest.tracker then InstallOptionalRoot(pfQuest.tracker.btnsort) end
  if pfJournal and pfJournal.entries and not pfJournal.entries.pfQuestRussianReload then
    local reload = pfJournal.entries.ReloadJournal
    pfJournal.entries.ReloadJournal = function(self)
      reload(self)
      HookDisplayRegions(self)
      HookConfigHovers(self)
    end
    pfJournal.entries.pfQuestRussianReload = true
  end
  -- Journal rows are recycled by paging and by asynchronous HDB title loads.
  if pfJournal and pfJournal:IsShown() then
    HookDisplayRegions(pfJournal)
    HookConfigHovers(pfJournal)
  end
  if pfQuestInit and pfQuestInit:IsShown() then HookDisplayRegions(pfQuestInit) end
end)

-- Extended journal/browser descriptions are shortened by the English HDB
-- renderer. Resolve the translated paragraph by quest ID before final Show,
-- rather than trying to match its already-truncated English prefix.
local function ShortRussianDescription(text, maximum)
  local count, index = 0, 1
  while index <= string.len(text) and count < maximum do
    local byte = string.byte(text, index)
    local width = byte < 128 and 1 or byte < 224 and 2 or byte < 240 and 3 or 4
    index, count = index + width, count + 1
  end
  if index <= string.len(text) then return string.sub(text, 1, index - 1) .. "..." end
  return text
end
if pfDatabase and type(pfDatabase.ShowExtendedTooltipHDB) == "function" then
  local extended = pfDatabase.ShowExtendedTooltipHDB
  function pfDatabase:ShowExtendedTooltipHDB(id, tooltip, parent, anchor, offx, offy, postRender)
    return extended(self, id, tooltip, parent, anchor, offx, offy, function(rendered)
      if postRender then postRender(rendered) end
      local translated = RussianQuest(id)
      if not translated or not translated.D or translated.D == "" then return end
      local name = rendered:GetName()
      if not name then return end
      for index = 1, rendered:NumLines() do
        local region = getglobal(name .. "TextLeft" .. index)
        if region and region:GetText() and string.len(region:GetText()) > 40 then
          local red, green, blue = region:GetTextColor()
          -- This is the renderer's description style, not level/progress text.
          if math.abs(red - 0.6) < 0.01 and math.abs(green - 0.6) < 0.01 and math.abs(blue - 0.6) < 0.01 then
            local _, size, flags = RememberOriginalFont(region)
            region:SetFont("Fonts\\ARIALN.TTF", size, flags)
            region:SetText(ShortRussianDescription(pfDatabase:FormatQuestText(translated.D), 500))
            break
          end
        end
      end
    end)
  end
end
local function PaintJournalQuestIDs()
  if not pfJournal or not pfJournal.entries or not pfQuest_config or pfQuest_config.translate ~= "ruRU" then return end
  for index = 1, 100 do
    local row = pfJournal.entries[index]
    if not row then break end
    local translated = row.id and RussianQuest(row.id)
    if translated and translated.T and row.text then
      local text = row.text:GetText()
      if text then
        row.text:SetText(string.gsub(text, "(%[)([^%[%]]+)(%])", function(open, caption, close)
          return open .. translated.T .. close
        end))
      end
    end
  end
end
local journalIdentityFrame = CreateFrame("Frame")
local journalIdentityElapsed = 0
journalIdentityFrame:SetScript("OnUpdate", function()
  journalIdentityElapsed = journalIdentityElapsed + (arg1 or 0)
  if journalIdentityElapsed < 0.25 then return end
  journalIdentityElapsed = 0
  if pfJournal and pfJournal:IsShown() then PaintJournalQuestIDs() end
end)
