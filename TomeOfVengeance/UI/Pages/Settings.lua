local _, ns = ...

local Book, Theme = ns.UI.Book, ns.UI.Theme
local Page = {}
ns.UI.Settings = Page

local function button(host, label, y, click)
  local control = Book.region(host, "Button")
  control:SetSize(350, 28)
  control:SetPoint("TOPLEFT", host, "TOPLEFT", 12, y)
  control.label = Book.text(control, label, -3, 15, Theme.BLOOD)
  control:SetScript("OnClick", click)
  return control
end

function Page.create()
  if Page.category or not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then return end
  local panel = CreateFrame("Frame")
  panel:SetSize(390, 420)
  Book.text(panel, "Tome of Vengeance", -20, 20, Theme.BLOOD)
  panel.launch = button(panel, "Open the Tome settings", -65, function() Book.open("settings") end)
  Page.category = Settings.RegisterCanvasLayoutCategory(panel, "Tome of Vengeance")
  Settings.RegisterAddOnCategory(Page.category)
end

Book.registerSection("settings", {
  label = "settings", order = 6,
  buildIndex = function(host, db)
    Book.text(host, "Preferences", 0, 20, Theme.BLOOD)
    host.controls = {}
    for i, entry in ipairs({ { "alerts", "Nemesis alerts" }, { "sound", "Alert sounds" }, { "minimap", "Minimap button" } }) do
      local key = entry[1]
      local control = Book.region(host, "CheckButton")
      control:SetSize(24, 24)
      control:SetPoint("TOPLEFT", host, "TOPLEFT", 12, -40 - (i - 1) * 38)
      control:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
      control:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
      control:SetChecked(db.settings[key])
      local label = Book.text(host, entry[2], -43 - (i - 1) * 38)
      label:SetPoint("TOPLEFT", control, "TOPRIGHT", 8, -3)
      label:SetWidth(300)
      control:SetScript("OnClick", function(self)
        ns.App.db.settings[key] = not not self:GetChecked()
        if key == "minimap" then ns.UI.Minimap.refresh() end
      end)
      host.controls[key] = control
    end
    local label = Book.text(host, "Nemesis threshold: " .. db.settings.nemesisThreshold, -174)
    local slider = Book.region(host, "Slider")
    slider:SetSize(330, 20)
    slider:SetPoint("TOPLEFT", host, "TOPLEFT", 20, -210)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(2, 10)
    slider:SetValueStep(1)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local track = Book.region(slider, "Texture")
    track:SetAllPoints()
    track:SetColorTexture(unpack(Theme.PARCHMENT_DARK))
    slider:SetScript("OnValueChanged", nil)
    slider:SetValue(db.settings.nemesisThreshold)
    slider:SetScript("OnValueChanged", function(_, value)
      local threshold = math.max(2, math.min(10, math.floor(value + 0.5)))
      ns.App.db.settings.nemesisThreshold = threshold
      label:SetText("Nemesis threshold: " .. threshold)
    end)
    host.controls.threshold = slider
    Book.text(host, "2                                              10", -240, 12)
  end,
  buildEntry = function(host, db)
    Book.text(host, "Sounds & Records", 0, 20, Theme.BLOOD)
    host.sounds = {}
    for i, kind in ipairs({ "unlock", "title", "nemesis" }) do
      local y = -38 - (i - 1) * 90
      Book.text(host, kind:sub(1, 1):upper() .. kind:sub(2), y, 16)
      local list = ns.Data.Sounds.LIST[kind]
      local function selected()
        local key = ns.Data.Sounds.forKind(kind, ns.App.db.settings)
        for index, entry in ipairs(list) do if entry.key == key then return index end end
        return 1
      end
      local selectButton
      selectButton = button(host, list[selected()].label .. " ›", y - 25, function()
        local index = selected() % #list + 1
        ns.App.db.settings.sounds[kind] = list[index].key
        selectButton.label:SetText(list[index].label .. " ›")
      end)
      selectButton:SetWidth(255)
      selectButton.label:SetWidth(245)
      local play = button(host, "Play", y - 25, function()
        ns.Compat.playSound(ns.Data.Sounds.forKind(kind, ns.App.db.settings))
      end)
      play:SetPoint("TOPLEFT", host, "TOPLEFT", 292, y - 25)
      play:SetWidth(74)
      play.label:SetWidth(64)
      host.sounds[kind] = { select = selectButton, play = play }
    end
    host.erase = button(host, "Erase the Tome", -344, function()
      if StaticPopup_Show then StaticPopup_Show("TOMEOFVENGEANCE_RESET") end
    end)
  end,
})
