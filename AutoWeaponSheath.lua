--[[--------------------------------------------------------------------
	Auto Weapon Sheath by Nomana-Kingsfall
	CC BY 2.0 (https://creativecommons.org/licenses/by/2.0/)

	Forever uses the Mainline addon API. GetSheathState / ToggleSheath
	are still the calls; the timer is C_Timer.After.
	GetSheathState: 1 = sheathed, 2 = melee out, 3 = ranged out.
----------------------------------------------------------------------]]

-- Set while a loot window is open, so a pending sheath does not toggle twice.
local cancel = false

local function sheath()
	-- ToggleSheath during combat lockdown is rejected by the client.
	-- Leaving combat schedules a fresh attempt.
	if cancel or InCombatLockdown() then
		return
	end
	if GetSheathState() ~= 1 then
		ToggleSheath()
		-- One toggle is sometimes ignored while the model is still updating.
		C_Timer.After(0.5, sheath)
	end
end

local Addon = CreateFrame("Frame")

Addon:SetScript("OnEvent", function(self, event, ...)
	return self[event] and self[event](self, ...)
end)

Addon:RegisterEvent("PLAYER_REGEN_ENABLED")
Addon:RegisterEvent("PLAYER_REGEN_DISABLED")
Addon:RegisterEvent("LOOT_OPENED")
Addon:RegisterEvent("LOOT_CLOSED")

function Addon:PLAYER_REGEN_ENABLED()
	C_Timer.After(0.5, sheath)
end

function Addon:PLAYER_REGEN_DISABLED()
	cancel = false
end

function Addon:LOOT_OPENED()
	-- Looting sheathes on its own. A second toggle makes the weapon vanish.
	if not InCombatLockdown() then
		cancel = true
	end
end

function Addon:LOOT_CLOSED()
	-- Auto-loot on an empty corpse never sheathes. Do it when the window closes.
	if not InCombatLockdown() then
		cancel = false
		sheath()
	end
end
