# ForeverRealsReminder handoff

Goal: after a level 55+ dungeon boss kill at player level 60, show the Tarnished Undermine Real (currency 3469)
icon at the top of the screen until the Real is looted or 30 s pass.

## Files
- `Rules.lua`: dungeon list (instance IDs 230/229/429/289/329, names for Blackmaw Hold / Shaper's Terrace,
  learned IDs), boss level >= 55 rule, per-character daily lockout per encounter, cap. Pure, tested.
- `Reminder.lua`: the frame (icon from `C_CurrencyInfo.GetCurrencyInfo(3469).iconFileID`), countdown, unlock/drag.
- `ForeverRealsReminder.lua`: ENCOUNTER_START (reads boss1-5 UnitLevel after 1 s, cached per encounter),
  ENCOUNTER_END (success == 1), CURRENCY_DISPLAY_UPDATE (quantityChange > 0 hides, marks the boss looted
  until `C_DateAndTime.GetSecondsUntilDailyReset`).

Drop rules come from forg.gg and conquestcapped.com (Nov 2026); Wowhead's pages had no drop details.

## Still to verify in game
- Do Forever's Classic dungeons fire ENCOUNTER_START/END for every boss? (`/frr debug` after a kill)
- Classic instance IDs: check with `/frr debug` inside each dungeon.
- Is `UnitLevel("boss1")` readable in dungeons? If not, early BRD bosses (<55) will still show a reminder.
- Does CURRENCY_DISPLAY_UPDATE carry quantityChange when looting a Real?
