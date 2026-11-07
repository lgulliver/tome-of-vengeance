std = "lua51"
max_line_length = false
-- WoW callbacks and hook stubs have fixed signatures, so unused arguments are expected.
unused_args = false

globals = {
  "TomeOfVengeanceDB",
  "SLASH_TOMEOFVENGEANCE1",
  "SLASH_TOMEOFVENGEANCE2",
  "SlashCmdList",
  "StaticPopupDialogs",
  "TomeOfVengeance_OnCompartmentClick",
}

read_globals = {
  "bit", "WOW_PROJECT_ID", "WOW_PROJECT_MAINLINE", "GetClientDisplayExpansionLevel",
  "GetBuildInfo", "UnitGUID", "UnitName", "GetRealmName", "UnitFactionGroup",
  "GetPlayerInfoByGUID", "UnitIsVisible", "UnitLevel", "GetGuildInfo", "IsInInstance",
  "GetRealZoneText", "GetSubZoneText", "time", "GetTime", "issecretvalue",
  "PlaySound", "SOUNDKIT", "CreateFrame", "Ambiguate", "UnitIsPlayer", "UnitCanAttack",
  "CombatLogGetCurrentEventInfo", "StaticPopup_Show", "hooksecurefunc", "StartDuel",
}
