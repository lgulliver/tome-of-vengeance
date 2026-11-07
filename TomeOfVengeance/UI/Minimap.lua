local _, ns = ...

local MinimapUI = {}
ns.UI.Minimap = MinimapUI

local function position()
  local angle = math.rad(ns.App.db.settings.minimapAngle or 225)
  local radius = Minimap:GetWidth() / 2 + 8
  MinimapUI.button:ClearAllPoints()
  MinimapUI.button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function MinimapUI.refresh()
  if not MinimapUI.button then return end
  MinimapUI.button:SetShown(ns.App.db.settings.minimap)
  position()
end

function MinimapUI.create()
  if MinimapUI.button or not Minimap then return end
  local button = CreateFrame("Button", "TomeOfVengeanceMinimap", Minimap)
  MinimapUI.button = button
  button:SetSize(32, 32)
  button:SetFrameStrata("MEDIUM")
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
  icon:SetSize(22, 22)
  icon:SetPoint("CENTER")
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(54, 54)
  border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  button:RegisterForClicks("LeftButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetScript("OnClick", function() ns.App.toggle() end)
  button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local x, y = GetCursorPosition()
      local cx, cy = Minimap:GetCenter()
      local scale = Minimap:GetEffectiveScale()
      ns.App.db.settings.minimapAngle = math.deg(math.atan2(y / scale - cy, x / scale - cx))
      position()
    end)
  end)
  button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  button:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
  button:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Tome of Vengeance")
    local total = ns.App.db.total
    GameTooltip:AddLine("Slain: " .. total.kills .. " · Slain by: " .. total.deaths, 1, 0.91, 0.63)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  MinimapUI.refresh()
end
