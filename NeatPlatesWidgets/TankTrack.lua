
------------------------------
-- Tank Aura/Role Tracking
------------------------------

local GetGroupInfo = NeatPlatesUtility.GetGroupInfo

-- Interface Functions...
---------------------------
local RaidTankList = {}
local inRaid = false
local playerTankRole = false
local currentSpec = 0

local cachedAura = false
local cachedRole = false
local TankWatcher



local function IsEnemyTanked(unit)
	if NEATPLATES_IS_CLASSIC then
		local unitid = unit.unitid
		local targetOf = unitid.."target"
		--local targetIsTank = UnitIsUnit(targetOf, "pet") or GetPartyAssignment("MAINTANK", targetOf)
		local targetIsTank = RaidTankList[UnitGUID(targetOf)] or UnitIsUnit(targetOf, "pet")

		return targetIsTank
	else
		local unitid = unit.unitid
		local targetOf = unitid.."target"
		local targetGUID = UnitGUID(targetOf)
		local targetIsGuardian = false
		local guardians = {
			["61146"] = true, 	-- Black Ox Statue(61146)
			["103822"] = true,	-- Treant(103822)
			["61056"] = true, 	-- Primal Earth Elemental(61056)
			["95072"] = true, 	-- Greater Earth Elemental(95072)
		}

		if targetGUID then
			targetGUID = select(6, strsplit("-", UnitGUID(targetOf)))
			targetIsGuardian = guardians[targetGUID]
		end
		-- GetPartyAssignment("MAINTANK", raidid)
		local targetIsTank = UnitIsUnit(targetOf, "pet") or targetIsGuardian or ("TANK" ==  UnitGroupRolesAssigned(targetOf))

		return targetIsTank
	end
end

local function IsPlayerTank()
	return playerTankRole
end

if NEATPLATES_IS_CLASSIC then
	local function UpdatePlayerRole(playerTankAura)
		if not playerTankAura then
			if playerClass == "WARRIOR" then
				playerTankAura = GetShapeshiftForm() == 2 or IsEquippedItemType("Shields") -- Defensive Stance or shield
			elseif playerClass == "DRUID" then
				playerTankAura = GetShapeshiftForm() == 1 -- Bear Form
			elseif playerClass == "PALADIN" then
				for i=1,40 do
					local spellId = select(10, UnitBuff("player",i))
					if spellId == rfSpellId then
						playerTankAura = true
					end
				end
			end
		end

		if playerTankAura then
			playerTankRole = true
		else
			playerTankRole = false
		end
	end
else
	local function UpdatePlayerRole()
		local playerTankAura = false

		-- Look at the Player's Specialization
		local specializationIndex = tonumber(GetSpecialization())

		if specializationIndex and GetSpecializationRole(specializationIndex) == "TANK" then
			playerTankRole = true
		else
			playerTankRole = false
		end
	end
end



if NEATPLATES_IS_CLASSIC then
	------------------------------------------------------------------------
	-- UpdateGroupRoles: Builds a list of tanks and squishies
	------------------------------------------------------------------------
	local function UpdateGroupRoles()

		RaidTankList = wipe(RaidTankList)
		-- If a player is in a dungeon, no need for multi-tanking
		if UnitInRaid("player") then
			inRaid = true

			local groupType, groupSize = GetGroupInfo()
			local raidIndex

			for raidIndex = 1, groupSize do
				local raidid = "raid"..tostring(raidIndex)
				local guid = UnitGUID(raidid)

				local isTank = GetPartyAssignment("MAINTANK", raidid) or ("TANK" == UnitGroupRolesAssigned(raidid))

				if isTank then
					RaidTankList[guid] = true
				end

			end

		-- If not in a raid, try to use guardian pet
		-- as a tank..
		else
			inRaid = false
			if HasPetUI("player") and UnitName("pet") then
				RaidTankList[UnitGUID("pet")] = true
			end
		end

	end

	local function TankWatcherEvents(self, event, ...)
		local tankAura = false
		local triggerUpdate = event ~= "COMBAT_LOG_EVENT_UNFILTERED"

		-- Check for Tank Aura application/removal
		if event == "COMBAT_LOG_EVENT_UNFILTERED" then
			local _,event,_,sourceGUID,sourceName,sourceFlags,_,destGUID,destName,_,_,spellId,spellName = CombatLogGetCurrentEventInfo()
			if (event == "SPELL_AURA_REMOVED" or event == "SPELL_AURA_APPLIED") and sourceGUID == playerGUID and destGUID == playerGUID then
				spellId = select(7, GetSpellInfo(spellName))
				if spellId == rfSpellId then
					if event == "SPELL_AURA_APPLIED" then tankAura = true end
					triggerUpdate = true
				end
			end
		end

		if triggerUpdate then
			UpdateGroupRoles()
			UpdatePlayerRole(tankAura)
		end
	end
else
	local function UpdateGroupRoles()

		if not IsInGroup() then
			RaidTankList = wipe(NeatPlatesWidgetSettings.RaidTankList)
		else

			local groupType, groupSize = GetGroupInfo()
			local raidIndex

			for raidIndex = 1, groupSize do
				local raidid = "raid"..tostring(raidIndex)
				local guid = UnitGUID(raidid)

				local isTank = GetPartyAssignment("MAINTANK", raidid)

				if isTank then
					RaidTankList[guid] = true
				end

			end
		end
	end

	local function TankWatcherEvents(self, event, ...)
		UpdateGroupRoles()
		UpdatePlayerRole()
	end
end

if not TankWatcher then TankWatcher = CreateFrame("Frame") end
TankWatcher:SetScript("OnEvent", TankWatcherEvents)
TankWatcher:RegisterEvent("GROUP_ROSTER_UPDATE")
TankWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
TankWatcher:RegisterEvent("UNIT_PET")
TankWatcher:RegisterEvent("PET_BAR_UPDATE_USABLE")
if not NEATPLATES_IS_CLASSIC then
	TankWatcher:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
	TankWatcher:RegisterEvent("PLAYER_TALENT_UPDATE")
end
TankWatcher:RegisterEvent("UPDATE_SHAPESHIFT_FORM")


NeatPlatesWidgets.IsEnemyTanked = IsEnemyTanked
NeatPlatesWidgets.IsPlayerTank = IsPlayerTank


--[[
local function Dummy() end
NeatPlatesWidgets.EnableTankWatch = Dummy
NeatPlatesWidgets.DisableTankWatch = Dummy
--]]





