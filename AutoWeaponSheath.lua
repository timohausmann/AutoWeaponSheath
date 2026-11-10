--[[--------------------------------------------------------------------
	Auto Weapon Sheath by Nomana-Kingsfall
	ISC License. See LICENSE.txt.

	GetSheathState: 1 = sheathed, 2 = melee out, 3 = ranged out.
----------------------------------------------------------------------]]

local Addon

-- Loot window is open; pending timers must not toggle.
local cancel = false
-- A new attempt invalidates timers from the previous one.
local generation = 0

local debugOn = false

local function log(msg)
	if not debugOn then
		return
	end
	print(string.format("AWS %.2f %s", GetTime(), msg))
end

local function after(delay, fn)
	local gen = generation
	C_Timer.After(delay, function()
		if gen ~= generation or cancel or InCombatLockdown() then
			log(string.format("timer dropped changed=%s cancel=%s combat=%s state=%s", tostring(gen ~= generation), tostring(cancel), tostring(InCombatLockdown()), tostring(GetSheathState())))
			return
		end
		fn()
	end)
end

-- True after the melee toggle, until the second toggle has been sent.
local waiting = false
local lastWatchState
local quietGen = 0

local function stopWatch()
	if waiting then
		log("watch cancelled state=" .. tostring(GetSheathState()))
	end
	waiting = false
	lastWatchState = nil
	quietGen = quietGen + 1
	Addon:SetScript("OnUpdate", nil)
end

local function secondToggle()
	if not waiting then
		return
	end
	local state = GetSheathState()
	log("quiet done state=" .. tostring(state))
	waiting = false
	lastWatchState = nil
	Addon:SetScript("OnUpdate", nil)
	if state ~= 3 then
		log("stop without toggle state=" .. tostring(state))
		return
	end
	log("second toggle, state before=" .. tostring(state))
	ToggleSheath()
	log("second toggle, state after=" .. tostring(GetSheathState()))
end

-- Model events in the log kept arriving for just over a second after state 3.
local function armQuiet()
	quietGen = quietGen + 1
	local q = quietGen
	log("quiet arm " .. tostring(q) .. " state=" .. tostring(GetSheathState()))
	after(1.25, function()
		if q ~= quietGen then
			log("quiet skipped " .. tostring(q))
			return
		end
		secondToggle()
	end)
end

local function onUpdate(self)
	if not waiting or cancel or InCombatLockdown() then
		log(string.format("watch end waiting=%s cancel=%s combat=%s state=%s", tostring(waiting), tostring(cancel), tostring(InCombatLockdown()), tostring(GetSheathState())))
		stopWatch()
		return
	end
	local state = GetSheathState()
	if state == lastWatchState then
		return
	end
	log("watch state " .. tostring(lastWatchState) .. " -> " .. tostring(state))
	lastWatchState = state
	if state == 3 then
		armQuiet()
	end
end

local function sheath()
	local state = GetSheathState()
	local ranged = GetInventoryItemID("player", INVSLOT_RANGED or 18)
	log(string.format("sheath state=%s ranged=%s", tostring(state), tostring(ranged)))
	if state == 1 then
		return
	end
	log("first toggle, state before=" .. tostring(state))
	ToggleSheath()
	log("first toggle, state after=" .. tostring(GetSheathState()))
	-- Sheathe once the ranged weapon is actually out, however long the server takes.
	if state == 2 and ranged then
		waiting = true
		lastWatchState = nil
		log("watch start")
		Addon:SetScript("OnUpdate", onUpdate)
	end
end

Addon = CreateFrame("Frame")

Addon:SetScript("OnEvent", function(self, event, ...)
	return self[event] and self[event](self, ...)
end)

function Addon:UNIT_MODEL_CHANGED(unit)
	local state = GetSheathState()
	log("model unit=" .. tostring(unit) .. " state=" .. tostring(state))
	if waiting and state == 3 then
		armQuiet()
	end
end

Addon:RegisterUnitEvent("UNIT_MODEL_CHANGED", "player")
Addon:RegisterEvent("PLAYER_REGEN_ENABLED")
Addon:RegisterEvent("PLAYER_REGEN_DISABLED")
Addon:RegisterEvent("LOOT_OPENED")
Addon:RegisterEvent("LOOT_CLOSED")

function Addon:PLAYER_REGEN_ENABLED()
	log("regen enabled state=" .. tostring(GetSheathState()))
	generation = generation + 1
	stopWatch()
	-- Too early and the client ignores the toggle.
	after(0.5, sheath)
end

function Addon:PLAYER_REGEN_DISABLED()
	log("regen disabled state=" .. tostring(GetSheathState()))
	generation = generation + 1
	stopWatch()
	cancel = false
end

function Addon:LOOT_OPENED()
	log("loot opened state=" .. tostring(GetSheathState()) .. " combat=" .. tostring(InCombatLockdown()))
	-- Loot already sheathes. Another toggle hides the weapon.
	if not InCombatLockdown() then
		generation = generation + 1
		stopWatch()
		cancel = true
	end
end

function Addon:LOOT_CLOSED()
	log("loot closed state=" .. tostring(GetSheathState()) .. " combat=" .. tostring(InCombatLockdown()))
	-- Empty auto-loot does not sheathe.
	if not InCombatLockdown() then
		cancel = false
		generation = generation + 1
		stopWatch()
		sheath()
	end
end

SLASH_AUTOWEAPONSHEATH1 = "/aws"
function SlashCmdList.AUTOWEAPONSHEATH(msg)
	if (msg or ""):match("^%s*(%S+)") ~= "debug" then
		return
	end
	debugOn = not debugOn
	print("AWS debug " .. (debugOn and "on" or "off"))
end
