include("IconSupport")
include("InstanceManager")
include("InfoTooltipInclude")
include("SupportFunctions")
include("NewSaveUtils")
--------------------------------------------------------------
-- debug output routine
-- Another useful idiom is (a and b) or c (or simply a and b or c, because and has a higher precedence than or), which is equivalent to the C expression a ? b : c
function dprint(sStr,p1,p2,p3,p4,p5,p6)
	local s = sStr;
	if p1 ~= nil then s = s.." [1] "..tostring(p1); end
	if p2 ~= nil then s = s.." [2] "..tostring(p2); end
	if p3 ~= nil then s = s.." [3] "..tostring(p3); end
	if p4 ~= nil then s = s.." [4] "..tostring(p4); end
	if p5 ~= nil then s = s.." [5] "..tostring(p5); end
	if p6 ~= nil then s = s.." [6] "..tostring(p6); end
	print(os.clock(), Game.GetGameTurn(), s);
end
--------------------------------------------------------------
local L = Locale.ConvertTextKey

local g_PlannerIM = InstanceManager:new("WonderPlanner", "Wonder", Controls.PlannerStack)
local g_BuiltIM = InstanceManager:new("WonderPlanner", "Wonder", Controls.BuiltStack)

local g_tSortTable = {}
local g_eActiveSort = "needed"
local g_bReverseSort = false
local g_iSortTier0, g_iSortTier1, g_iSortTier2, g_iSortTier3, g_iSortTier4, g_iSortTier5 = 100000, 10000, 1000, 100, 10, 1

local g_tCivs = {}
local g_tWonders = {init = false}
local g_iEraLimit = -1
local g_iMaxEraLimit = -1

for era in DB.Query("SELECT Eras.ID, Eras.Type FROM Eras") do
	if g_iMaxEraLimit < era.ID then
		g_iMaxEraLimit = era.ID
	end
end

local g_tLeagueBuildings = {}

for rowLeagueProject in GameInfo.LeagueProjectRewards() do
	if rowLeagueProject.Building ~= nil then
		table.insert(g_tLeagueBuildings, rowLeagueProject.Building)
	end
end

local g_tSettlers = {}

for unit in GameInfo.Units() do
	if unit.Found then
		g_tSettlers[unit.ID] = unit.Type
	end
end

local g_sColorHoly = '[COLOR_MENU_BLUE]'
local g_sColorIdeology = '[COLOR_YELLOW]'
local g_sColorPolicyFinisher = '[COLOR_MAGENTA]'
local g_sColorPolicy = '[COLOR:255:170:255:255]' 	-- Policies not being Policy Branch Finishers
local g_sColorCorporation = '[COLOR_YIELD_FOOD]'
local g_sColorCongress = '[COLOR:45:150:50:255]'
local g_sColorUniqueCs = '[COLOR:140:140:140:255]'	-- Lhasa
local g_sColorUniqueCiv = '[COLOR:45:90:170:255]'	-- America

local g_sColorGold = '[COLOR_YIELD_GOLD]'
local g_sColorOrange = '[COLOR_YIELD_FOOD]'

local g_sDestroyed = L("TXT_KEY_WONDERPLANNER_DESTROYED")
local g_sPolicyLhasa = "POLICY_LHASA"
--------------------------------------------------------------
local g_tAvailableSpecialists = {
	'SPECIALIST_ENGINEER',
	'SPECIALIST_MERCHANT',
	'SPECIALIST_SCIENTIST',
	'SPECIALIST_ARTIST',
	'SPECIALIST_WRITER',
	'SPECIALIST_MUSICIAN',
	'SPECIALIST_CIVIL_SERVANT'
}

local g_tGreatPeopleUnits = {
	['UNIT_ENGINEER'] 		= 1,
	['UNIT_MERCHANT'] 		= 2,
	['UNIT_SCIENTIST'] 		= 3,
	['UNIT_ARTIST'] 		= 4,
	['UNIT_WRITER'] 		= 5,
	['UNIT_MUSICIAN'] 		= 6,
	['UNIT_GREAT_DIPLOMAT'] = 7,
	['UNIT_GREAT_GENERAL'] 	= 8,
	['UNIT_GREAT_ADMIRAL'] 	= 9,
	['UNIT_PROPHET'] 		= 10
}

local g_tGreatPersonTypes = {
	['GREATPERSON_ENGINEER'] 	= 1,
	['GREATPERSON_MERCHANT'] 	= 2,
	['GREATPERSON_SCIENTIST'] 	= 3,
	['GREATPERSON_ARTIST'] 		= 4,
	['GREATPERSON_WRITER'] 		= 5,
	['GREATPERSON_MUSICIAN'] 	= 6,
	['GREATPERSON_DIPLOMAT'] 	= 7,
	['GREATPERSON_GENERAL'] 	= 8,
	['GREATPERSON_ADMIRAL'] 	= 9,
	['GREATPERSON_PROPHET'] 	= 10
}

local g_tGreatPeopleIcons = {
	'[ICON_GREAT_WORK]',
	'[ICON_GREAT_ENGINEER]',
	'[ICON_GREAT_MERCHANT]',
	'[ICON_GREAT_SCIENTIST]',
	'[ICON_GREAT_ARTIST]',
	'[ICON_GREAT_WRITER]',
	'[ICON_GREAT_MUSICIAN]',
	'[ICON_DIPLOMAT]',
	'[ICON_GREAT_GENERAL]',
	'[ICON_GREAT_ADMIRAL]',
	'[ICON_PROPHET]',
	'[ICON_GREAT_PEOPLE]'
}
--------------------------------------------------------------	
function OnSort(sort)
	if sort then
		if sort == g_eActiveSort then
			g_bReverseSort = not g_bReverseSort
		else
			g_bReverseSort = false
		end

		g_eActiveSort = sort
	end

	Controls.PlannerStack:SortChildren(SortByValue)
	Controls.BuiltStack:SortChildren(SortByValue)
end
Controls.SortPlannerName:RegisterCallback(Mouse.eLClick, function() OnSort("name") end)
Controls.SortPlannerTech:RegisterCallback(Mouse.eLClick, function() OnSort("tech") end)
Controls.SortPlannerTechsNeeded:RegisterCallback(Mouse.eLClick, function() OnSort("needed") end)
Controls.SortPlannerFood:RegisterCallback(Mouse.eLClick, function() OnSort("food") end)
Controls.SortPlannerConstruction:RegisterCallback(Mouse.eLClick, function() OnSort("construction") end)
Controls.SortPlannerGold:RegisterCallback(Mouse.eLClick, function() OnSort("gold") end)
Controls.SortPlannerTrade:RegisterCallback(Mouse.eLClick, function() OnSort("trade") end)
Controls.SortPlannerGoldenAge:RegisterCallback(Mouse.eLClick, function() OnSort("goldenage") end)
Controls.SortPlannerScience:RegisterCallback(Mouse.eLClick, function() OnSort("science") end)
Controls.SortPlannerCulture:RegisterCallback(Mouse.eLClick, function() OnSort("culture") end)
Controls.SortPlannerGreatPeople:RegisterCallback(Mouse.eLClick, function() OnSort("greatpeople") end)
Controls.SortPlannerTourism:RegisterCallback(Mouse.eLClick, function() OnSort("tourism") end)
Controls.SortPlannerFaith:RegisterCallback(Mouse.eLClick, function() OnSort("faith") end)
Controls.SortPlannerHappy:RegisterCallback(Mouse.eLClick, function() OnSort("happy") end)
Controls.SortPlannerOffense:RegisterCallback(Mouse.eLClick, function() OnSort("offense") end)
Controls.SortPlannerFreeUnit:RegisterCallback(Mouse.eLClick, function() OnSort("freeunit") end)
Controls.SortPlannerExpansion:RegisterCallback(Mouse.eLClick, function() OnSort("expansion") end)
Controls.SortPlannerDefense:RegisterCallback(Mouse.eLClick, function() OnSort("defense") end)
Controls.SortPlannerEspionage:RegisterCallback(Mouse.eLClick, function() OnSort("espionage") end)

Controls.SortBuiltName:RegisterCallback(Mouse.eLClick, function() OnSort("name") end)
Controls.SortBuiltCity:RegisterCallback(Mouse.eLClick, function() OnSort("city") end)
Controls.SortBuiltYear:RegisterCallback(Mouse.eLClick, function() OnSort("year") end)
Controls.SortBuiltFood:RegisterCallback(Mouse.eLClick, function() OnSort("food") end)
Controls.SortBuiltConstruction:RegisterCallback(Mouse.eLClick, function() OnSort("construction") end)
Controls.SortBuiltGold:RegisterCallback(Mouse.eLClick, function() OnSort("gold") end)
Controls.SortBuiltTrade:RegisterCallback(Mouse.eLClick, function() OnSort("trade") end)
Controls.SortBuiltGoldenAge:RegisterCallback(Mouse.eLClick, function() OnSort("goldenage") end)
Controls.SortBuiltScience:RegisterCallback(Mouse.eLClick, function() OnSort("science") end)
Controls.SortBuiltCulture:RegisterCallback(Mouse.eLClick, function() OnSort("culture") end)
Controls.SortBuiltGreatPeople:RegisterCallback(Mouse.eLClick, function() OnSort("greatpeople") end)
Controls.SortBuiltTourism:RegisterCallback(Mouse.eLClick, function() OnSort("tourism") end)
Controls.SortBuiltFaith:RegisterCallback(Mouse.eLClick, function() OnSort("faith") end)
Controls.SortBuiltHappy:RegisterCallback(Mouse.eLClick, function() OnSort("happy") end)
Controls.SortBuiltOffense:RegisterCallback(Mouse.eLClick, function() OnSort("offense") end)
Controls.SortBuiltFreeUnit:RegisterCallback(Mouse.eLClick, function() OnSort("freeunit") end)
Controls.SortBuiltExpansion:RegisterCallback(Mouse.eLClick, function() OnSort("expansion") end)
Controls.SortBuiltDefense:RegisterCallback(Mouse.eLClick, function() OnSort("defense") end)
Controls.SortBuiltEspionage:RegisterCallback(Mouse.eLClick, function() OnSort("espionage") end)
--------------------------------------------------------------
function SortByValue(a, b)
	local entryA = g_tSortTable[tostring(a)]
	local entryB = g_tSortTable[tostring(b)]

	if entryA == nil or entryB == nil then
		return tostring(a) < tostring(b)
	end

	local valueA = entryA[g_eActiveSort]
	local valueB = entryB[g_eActiveSort]

	if g_bReverseSort then
		valueA = entryB[g_eActiveSort]
		valueB = entryA[g_eActiveSort]
	end

	if valueA == valueB then
		if entryA.needed ~= nil then
			valueA = entryA.needed
			valueB = entryB.needed
		else
			valueA = entryA.name
			valueB = entryB.name
		end
	end

	if valueA == nil or valueB == nil then
		return tostring(a) < tostring(b)
	end

	return valueA < valueB
end
--------------------------------------------------------------
function OnWonderConstruction(ePlayer, eCity, eBuilding, bGold, bFaith)
	for building in GameInfo.Buildings{ID=eBuilding} do
		SetPersistentProperty(tostring(building.ID), Game.GetGameTurnYear())
		break
	end
end
GameEvents.CityConstructed.Add(OnWonderConstruction)

function OnLeagueWonderGranted(ePlayer)
	local pPlayer = Players[ePlayer]
	
	for _, leagueWonder in ipairs(g_tLeagueBuildings) do
		if not GetPersistentProperty(leagueWonder) then
			for city in pPlayer:Cities() do
				eBuilding = GameInfo.Buildings[leagueWonder].ID

				if city:IsHasBuilding(eBuilding) then
					SetPersistentProperty(leagueWonder, true)
					SetPersistentProperty(tostring(eBuilding), Game.GetGameTurnYear())
				end
			end
		end
	end
end
GameEvents.PlayerDoTurn.Add(OnLeagueWonderGranted)
--------------------------------------------------------------
function UpdateData(ePlayer)
	local pPlayer = Players[ePlayer]
	CivIconHookup(ePlayer, 64, Controls.Icon, Controls.CivIconBG, Controls.CivIconShadow, false, true)

	local tPlayerTechs = GetTechs(ePlayer)
  
	g_PlannerIM:ResetInstances()
	g_BuiltIM:ResetInstances()
	g_tSortTable = {}

	for wonderID, wonder in pairs(UpdateWonders(g_tWonders)) do
		if wonder.eTechnology ~= -1 then
			AddWonder(ePlayer, tPlayerTechs, wonderID, wonder)
		end
	end

	Controls.PlannerStack:SortChildren(SortByValue)
	Controls.PlannerStack:CalculateSize()
	Controls.PlannerScrollPanel:CalculateInternalSize()

	Controls.BuiltStack:SortChildren(SortByValue)
	Controls.BuiltStack:CalculateSize()
	Controls.BuiltScrollPanel:CalculateInternalSize()
end

function AddWonder(ePlayer, tPlayerTechs, eWonder, tWonder)
	local instance = (tWonder.ePlayer == -1) and g_PlannerIM:GetInstance() or g_BuiltIM:GetInstance()
	tWonder.instance = instance
	
	local sort = {}
	g_tSortTable[tostring(instance.Wonder)] = sort

	if IconHookup(tWonder.ePortraitIndex, 45, tWonder.pIconAtlas, instance.Icon) then
		instance.Icon:SetHide(false)
		instance.Icon:SetToolTipString(tWonder.sNameWithColor)
	else
		instance.Icon:SetHide(true)
	end

	sort.name = tWonder.sName
	TruncateString(instance.Name, 260, tWonder.sNameWithColor)
	instance.Name:SetToolTipString(tWonder.sTooltip)

	local pActivePlayer = Players[Game.GetActivePlayer()]
	
	local iAvailableCities, iAvailableCitiesHidden = 0, 0
	local sAvailableCity, sAvailableCityTT = "", ""
	local bAvailableCity, bAvailableCityHidden = false, false
	local sMainTextColor = g_sColorOrange
	local sFinalText = ""
	local bMaxEra = false
	local iTrueTechNeeded
	
	if tWonder.ePlayer == -1 then
		local pTeam = Teams[pActivePlayer:GetTeam()]
		local eCurrentEra = pTeam:GetCurrentEra()
		local eMaxStartEra = tWonder.eMaxStartEra

		if eCurrentEra > eMaxStartEra then
			instance.WonderOutdated:SetHide(false)
			bMaxEra = true
		else
			instance.WonderOutdated:SetHide(true)

			for city in pActivePlayer:Cities() do
				if city:CanConstruct(eWonder, 0, 0, 0) then
					instance.WonderAvailable:SetHide(false)
					iAvailableCities = iAvailableCities + 1
					bAvailableCity = true
					
					if iAvailableCities == 1 then
						sAvailableCityTT = L("TXT_KEY_WONDERPLANNER_CITIES_LIST", tWonder.sName) .. city:GetName()
					elseif iAvailableCities >= 2 then
						sAvailableCityTT = sAvailableCityTT .. "[NEWLINE][ICON_BULLET]" .. city:GetName()
					end
				end
			end

			for city in pActivePlayer:Cities() do
				if city:CanConstruct(eWonder, 0, 1, 0) and not city:CanConstruct(eWonder, 0, 0, 0) then
					instance.WonderAvailable:SetHide(false)
					iAvailableCitiesHidden = iAvailableCitiesHidden + 1
					bAvailableCityHidden = true
					
					if city:GetProductionBuilding() == eWonder then
						sFinalText = L("TXT_KEY_WONDERPLANNER_CITY_TT_CONSTRUCTING", g_sColorGold, city:GetName())
						sMainTextColor = g_sColorGold
					else
						sFinalText = L("TXT_KEY_WONDERPLANNER_CITY_TT_BLOCKED", g_sColorOrange, city:GetName())
					end

					if iAvailableCitiesHidden == 1 then
						sAvailableCityTT = L("TXT_KEY_WONDERPLANNER_CITIES_LIST", tWonder.sName) .. sFinalText
					elseif iAvailableCitiesHidden >= 2 then
						sAvailableCityTT = sAvailableCityTT .. "[NEWLINE][ICON_BULLET]" .. sFinalText
					end
				end
			end
			
			if iAvailableCities == 0 and iAvailableCitiesHidden == 0 and not bMaxEra then
				instance.WonderAvailable:SetHide(true)
			elseif iAvailableCities == 1 and iAvailableCitiesHidden == 0 then
				sAvailableCity = L("TXT_KEY_WONDERPLANNER_CITY")
			elseif iAvailableCities > 1 and iAvailableCitiesHidden == 0 then
				sAvailableCity = L("TXT_KEY_WONDERPLANNER_CITIES", iAvailableCities)
			elseif iAvailableCities == 1 and iAvailableCitiesHidden == 1 then
				sAvailableCity = L("TXT_KEY_WONDERPLANNER_CITY_HIDDEN_ONE", sMainTextColor)
			elseif iAvailableCities == 1 and iAvailableCitiesHidden ~= 1 then
				sAvailableCity = L("TXT_KEY_WONDERPLANNER_CITY_HIDDEN_MORE", sMainTextColor, iAvailableCitiesHidden)
			elseif iAvailableCities ~= 1 and iAvailableCitiesHidden == 1 then
				sAvailableCity = L("TXT_KEY_WONDERPLANNER_CITIES_HIDDEN_ONE", iAvailableCities, sMainTextColor)
			elseif iAvailableCities ~= 1 and iAvailableCitiesHidden ~= 1 then
				sAvailableCity = L("TXT_KEY_WONDERPLANNER_CITIES_HIDDEN_MORE", iAvailableCities, sMainTextColor, iAvailableCitiesHidden)
			end
		end
		-----------------------
		iTrueTechNeeded = Players[ePlayer]:FindPathLength(GameInfoTypes[tWonder.sTechType], false)
				
		-- if any player discovered that the prereq tech then the project is available for World Congress
		ePrereqTechType = GameInfo.Technologies{Type=tWonder.sTechType}().ID
		
		for eplayer = 0, GameDefines.MAX_MAJOR_CIVS - 1, 1 do
			local pTeam = Teams[Players[eplayer]:GetTeam()]
			
			if pTeam:IsHasTech(ePrereqTechType) then iTrueTechNeeded = 0 end
		end
		
		if bMaxEra then
			sort.needed = 1000;			
		else
			sort.needed = iTrueTechNeeded			
		end
		instance.TechsNeeded:SetHide(false)		

		local bLocked, sReason = IsLocked(tWonder, ePlayer)
	
		if bLocked then
			instance.TechsNeeded:SetText("[ICON_LOCKED]")
			instance.TechsNeeded:SetToolTipString(sReason)
		elseif iTrueTechNeeded == 0 then
			instance.TechsNeeded:SetText(nil)
			instance.TechsNeeded:SetToolTipString(nil)
		else	
			instance.TechsNeeded:SetText(iTrueTechNeeded)
			instance.TechsNeeded:SetToolTipString(nil)
		end
		-----------------------
		local pTech = GameInfo.Technologies[tWonder.sTechType]
		
		if IconHookup(pTech.PortraitIndex, 45, pTech.IconAtlas, instance.TechIcon) then
			if iTrueTechNeeded > 0 then
				instance.TechIcon:SetHide(false)
				instance.TechIcon:SetToolTipString(tWonder.sTechName)
			else
				instance.TechIcon:SetHide(true)
			end
		else
			instance.TechIcon:SetHide(true)
		end
		-----------------------
		local sTrueTechName = ""
		
		instance.Tech:SetOffsetVal(0, 0)
		
		if bMaxEra then
			sort.tech = L("TXT_KEY_WONDERPLANNER_SORT_BOTTOM")
			sTrueTechName = L("TXT_KEY_WONDERPLANNER_LOCKED_OUTDATED")
			instance.Tech:SetOffsetVal(60, 0)
		elseif bAvailableCity or bAvailableCityHidden then
			sort.tech = L("TXT_KEY_WONDERPLANNER_SORT_TOP") .. sAvailableCity
			sTrueTechName = sAvailableCity
			instance.Tech:SetOffsetVal(-30, 0)
		elseif iTrueTechNeeded == 0 then
			sort.tech = L("TXT_KEY_WONDERPLANNER_SORT_ALMOST_TOP")
			sTrueTechName = ""
		else
			sort.tech = tWonder.sTechName
			sTrueTechName = sort.tech
		end
		
		instance.Tech:SetText(sTrueTechName)
		
		if bAvailableCity or bAvailableCityHidden then
			instance.Tech:SetToolTipString(sAvailableCityTT)
		else
			instance.Tech:SetToolTipString(tWonder.sEraName)
		end
		-----------------------
		instance.Year:SetHide(true)
		instance.Wonder:SetHide(tWonder.eEra > g_iEraLimit)
	else
		instance.TechsNeeded:SetText("")
		instance.TechIcon:SetToolTipString(tWonder.sPlayer)
    		
		if tWonder.ePlayer == -2 then
			instance.TechIcon:SetHide(IconHookup(5, 45, "KRIS_SWORDSMAN_PROMOTION_ATLAS", instance.TechIcon) == false)
		else
			local pCiv = g_tCivs[tWonder.ePlayer]
			
			instance.TechIcon:SetHide(IconHookup(pCiv.PortraitIndex, 45, pCiv.IconAtlas, instance.TechIcon) == false)
		end
		-----------------------
		if tWonder.ePlayer ~= GameDefines.MAX_PLAYERS then
			sort.city = tWonder.sPlayer .. tWonder.sCity
			TruncateString(instance.Tech, 150, tWonder.sCity)
			instance.Tech:SetToolTipString(tWonder.sPlayer)
		else
			sort.city = L("TXT_KEY_WONDERPLANNER_LOCKED_DESTROYED") .. eWonder
			instance.Tech:SetText(g_sDestroyed)
			instance.Tech:SetToolTipString(g_sDestroyed)
		end
		-----------------------
		sort.year = GetPersistentProperty(eWonder) or -10000
		local sBetterYearName = ""
		if sort.year < 0 and sort.year == -10000 then
			sBetterYearName = L("TXT_KEY_WONDERPLANNER_GRANTED")
		elseif sort.year < 0 and sort.year ~= -10000 then	
			sBetterYearName = -sort.year .. " " .. L("TXT_KEY_WONDERPLANNER_YEAR_BC")
		else
			sBetterYearName = sort.year .. " " .. L("TXT_KEY_WONDERPLANNER_YEAR_AD")
		end
		instance.Year:SetHide(false)
		instance.Year:SetText(sBetterYearName)
		-----------------------
		instance.Wonder:SetHide(false)
	end

	local tIsThemeFound = {}
	tIsThemeFound[1] =	tWonder.isFood			== -1
	tIsThemeFound[2] =	tWonder.isConstruction	== -1
	tIsThemeFound[3] =	tWonder.isGold			== -1
	tIsThemeFound[4] =	tWonder.isTrade			== -1
	tIsThemeFound[5] =	tWonder.isGoldenAge		== -1
	tIsThemeFound[6] =	tWonder.isScience		== -1
	tIsThemeFound[7] =	tWonder.isCulture		== -1
	tIsThemeFound[8] =	nil
	tIsThemeFound[9] =	tWonder.isTourism		== -1
	tIsThemeFound[10] = tWonder.isFaith			== -1
	tIsThemeFound[11] = tWonder.isHappy			== -1
	tIsThemeFound[12] = tWonder.isOffense		== -1
	tIsThemeFound[13] = nil
	tIsThemeFound[14] = tWonder.isExpansion		== -1
	tIsThemeFound[15] = tWonder.isDefense		== -1
	tIsThemeFound[16] = tWonder.isEspionage		== -1
	
	bNoTechNeeded = iTrueTechNeeded == 0

	instance.IsFood:SetHide(not tIsThemeFound[1])
	sort.food = SetSortValuesByFour(bMaxEra, tIsThemeFound[1], bNoTechNeeded)
	instance.IsConstruction:SetHide(not tIsThemeFound[2])
	sort.construction = SetSortValuesByFour(bMaxEra, tIsThemeFound[2], bNoTechNeeded)
	instance.IsGold:SetHide(not tIsThemeFound[3])
	sort.gold = SetSortValuesByFour(bMaxEra, tIsThemeFound[3], bNoTechNeeded)
	instance.IsTrade:SetHide(not tIsThemeFound[4])
	sort.trade = SetSortValuesByFour(bMaxEra, tIsThemeFound[4], bNoTechNeeded)
	instance.IsGoldenAge:SetHide(not tIsThemeFound[5])
	sort.goldenage = SetSortValuesByFour(bMaxEra, tIsThemeFound[5], bNoTechNeeded)
	instance.IsScience:SetHide(not tIsThemeFound[6])
	sort.science = SetSortValuesByFour(bMaxEra, tIsThemeFound[6], bNoTechNeeded)
	instance.IsCulture:SetHide(not tIsThemeFound[7])
	sort.culture = SetSortValuesByFour(bMaxEra, tIsThemeFound[7], bNoTechNeeded)
	
	local iMainSortingValue = tWonder.isGreatPeople
	local iSecondarySortingValue = tWonder.isGreatPeopleRateChange
	local sGreatPeopleTooltip = tWonder.isGreatPeopleTooltip
	instance.IsGreatPeople:SetHide(sort.greatpeople == 0)
	instance.IsGreatPeople:SetText(g_tGreatPeopleIcons[#g_tGreatPeopleIcons + iMainSortingValue + 1])
	if sGreatPeopleTooltip then instance.IsGreatPeople:SetToolTipString(sGreatPeopleTooltip) end
	local iSortingValue = (iMainSortingValue * g_iSortTier0) + iSecondarySortingValue
	sort.greatpeople = bMaxEra and 1000 or iSortingValue

	instance.IsTourism:SetHide(not tIsThemeFound[9])
	sort.tourism = SetSortValuesByFour(bMaxEra, tIsThemeFound[9], bNoTechNeeded)
	instance.IsFaith:SetHide(not tIsThemeFound[10])
	sort.faith = SetSortValuesByFour(bMaxEra, tIsThemeFound[10], bNoTechNeeded)
	instance.IsHappy:SetHide(not tIsThemeFound[11])
	sort.happy = SetSortValuesByFour(bMaxEra, tIsThemeFound[11], bNoTechNeeded)
	instance.IsOffense:SetHide(not tIsThemeFound[12])
	sort.offense = SetSortValuesByFour(bMaxEra, tIsThemeFound[12], bNoTechNeeded)
	
	local sFreeUnitTooltip = tWonder.isFreeUnit
	instance.IsFreeUnit:SetHide(not sFreeUnitTooltip)
	instance.IsFreeUnit:SetToolTipString(sFreeUnitTooltip)
	sort.freeunit = bMaxEra and L("TXT_KEY_WONDERPLANNER_SORT_BOTTOM") or sFreeUnitTooltip
	
	instance.IsExpansion:SetHide(not tIsThemeFound[14])
	sort.expansion = SetSortValuesByFour(bMaxEra, tIsThemeFound[14], bNoTechNeeded)
	instance.IsDefense:SetHide(not tIsThemeFound[15])
	sort.defense = SetSortValuesByFour(bMaxEra, tIsThemeFound[15], bNoTechNeeded)
	instance.IsEspionage:SetHide(not tIsThemeFound[16])
	sort.espionage = SetSortValuesByFour(bMaxEra, tIsThemeFound[16], bNoTechNeeded)
end

function SetSortValuesByThree(iFirstCondition, iSecondCondition)
	-- function sets three sorting values
	return iFirstCondition and L("TXT_KEY_WONDERPLANNER_SORT_BOTTOM") or (iSecondCondition and L("TXT_KEY_WONDERPLANNER_SORT_TOP") or L("TXT_KEY_WONDERPLANNER_SORT_ALMOST_TOP"))
end

function SetSortValuesByFour(iFirstCondition, iSecondCondition, iThirdCondition)
	-- function sets three sorting values
	return iFirstCondition and L("TXT_KEY_WONDERPLANNER_SORT_BOTTOM") or (iSecondCondition and (iThirdCondition and L("TXT_KEY_WONDERPLANNER_SORT_TOP") or L("TXT_KEY_WONDERPLANNER_SORT_ALMOST_TOP")) or L("TXT_KEY_WONDERPLANNER_SORT_MIDDLE"))
end

function GetCivs()
	for ePlayer = 0, GameDefines.MAX_MAJOR_CIVS - 1, 1 do
		local pPlayer = Players[ePlayer]
		
		if pPlayer:IsEverAlive() then
			local pCiv = GameInfo.Civilizations[pPlayer:GetCivilizationType()]
			
			g_tCivs[ePlayer] = {
				IconAtlas     = pCiv.IconAtlas,
				PortraitIndex = pCiv.PortraitIndex
			}
		end
	end

	local pCiv = GameInfo.Civilizations["CIVILIZATION_BARBARIAN"]
  
	g_tCivs[GameDefines.MAX_PLAYERS] = {
		IconAtlas     = pCiv.IconAtlas,
		PortraitIndex = pCiv.PortraitIndex
	}
end

function GetWonders(tWonders)
	for potentialWonder in GameInfo.Buildings() do
		if IsWonder(potentialWonder) then
			local eWonder = potentialWonder.ID
			local pWonder = potentialWonder
			local pWonderDummy
			local sWonderDummy = pWonder.Type .. '_DUMMY'

			for row in GameInfo.Buildings{Type=sWonderDummy} do
				pWonderDummy = row
			end

			local sNameWithColor
			local sNameWithoutColor = L(pWonder.Description)
			local sPolicyTag = pWonder.PolicyType
			local bFromLhasa = sPolicyTag == g_sPolicyLhasa
			
			-- setting colors to names
			if pWonder.HolyCity then
				sNameWithColor = L("TXT_KEY_WONDERPLANNER_COLORED_NAME_HOLY", g_sColorHoly, sNameWithoutColor)
			elseif pWonder.PolicyBranchType then
				local sIdeologyName = L('TXT_KEY_' .. pWonder.PolicyBranchType)
				sNameWithColor = L("TXT_KEY_WONDERPLANNER_COLORED_NAME", g_sColorIdeology, sNameWithoutColor, sIdeologyName)
			elseif sPolicyTag and not bFromLhasa and GameInfo.PolicyBranchTypes{FreeFinishingPolicy=sPolicyTag}() then
				local sPolicyBranchName = L('TXT_KEY_' .. string.gsub(string.gsub(pWonder.PolicyType, '_FINISHER', ''), 'POLICY_', 'POLICY_BRANCH_'))
				sNameWithColor = L("TXT_KEY_WONDERPLANNER_COLORED_NAME", g_sColorPolicyFinisher, sNameWithoutColor, sPolicyBranchName)
			elseif sPolicyTag and not bFromLhasa and not GameInfo.PolicyBranchTypes{FreeFinishingPolicy=sPolicyTag}() then
				sNameWithoutColor = string.gsub(sNameWithoutColor, '%[COLOR_MAGENTA%].-%[ENDCOLOR%] ', '')
				local sPolicyName = L('TXT_KEY_' .. pWonder.PolicyType)
				sNameWithColor = L("TXT_KEY_WONDERPLANNER_COLORED_NAME", g_sColorPolicy, sNameWithoutColor, sPolicyName)
			elseif pWonder.EventChoiceRequiredActive then
				local sUniqueCSName = L(GameInfo.EventChoices{Type=pWonder.EventChoiceRequiredActive}().Description)
				sNameWithColor = L("TXT_KEY_WONDERPLANNER_COLORED_NAME", g_sColorUniqueCs, sNameWithoutColor, sUniqueCSName)
			elseif pWonder.CivilizationRequired then
				local sUniqueCivName = L(GameInfo.Civilizations{Type=pWonder.CivilizationRequired}().ShortDescription)
				sNameWithColor = L("TXT_KEY_WONDERPLANNER_COLORED_NAME", g_sColorUniqueCiv, sNameWithoutColor, sUniqueCivName)
			elseif pWonder.PrereqTech == nil and pWonder.UnlockedByLeague then
				for reward in GameInfo.LeagueProjectRewards{Building=pWonder.Type} do
					for project in GameInfo.LeagueProjects() do
						if project.RewardTier1 == reward.Type or project.RewardTier2 == reward.Type or project.RewardTier3 == reward.Type then
							local sProjectName = L(project.Description)
							sNameWithColor = L("TXT_KEY_WONDERPLANNER_COLORED_NAME", g_sColorCongress, sNameWithoutColor, sProjectName)
						end
					end
				end
			elseif pWonder.PrereqTech == nil and not pWonder.UnlockedByLeague then
				sNameWithoutColor = string.gsub(sNameWithoutColor, 'Headquarters', '(HQ)')
				sNameWithColor = L("TXT_KEY_WONDERPLANNER_COLORED_NAME_CORPO", g_sColorCorporation, sNameWithoutColor)
			else
				sNameWithColor = sNameWithoutColor
			end
			
			local bPrereqTechFound, ePrereqTechType, sPrereqTechType
			
			-- setting techs for wonders which do not have ones
			if pWonder.PrereqTech == nil and pWonder.UnlockedByLeague then
				for rowLeagueRewards in GameInfo.LeagueProjectRewards{Building=pWonder.Type} do
					for rowLeagueProject in GameInfo.LeagueProjects() do
						if rowLeagueProject.RewardTier1 == rowLeagueRewards.Type or rowLeagueProject.RewardTier2 == rowLeagueRewards.Type or rowLeagueProject.RewardTier3 == rowLeagueRewards.Type then
							for rowResolution in GameInfo.Resolutions{LeagueProjectEnabled=rowLeagueProject.Type} do
								sPrereqTechType = rowResolution.TechPrereqAnyMember or 'TECH_PRINTING_PRESS'
								bPrereqTechFound = true
								break
							end
				
							if bPrereqTechFound then break end
						end
					end	

					if bPrereqTechFound then break end
				end
			elseif pWonder.PrereqTech == nil and not pWonder.UnlockedByLeague and not pWonder.PolicyType then
				sPrereqTechType = 'TECH_CORPORATIONS'
			elseif pWonder.PrereqTech == nil and pWonder.PolicyType then
				sPrereqTechType = 'TECH_AGRICULTURE'
			else
				sPrereqTechType = pWonder.PrereqTech
			end
			
			-- creating wonder table
			if pWonderDummy ~= nil then
				tWonders[eWonder] = {
					eWonder					= eWonder,
					sType					= pWonder.Type,
					eClass					= GameInfoTypes[pWonder.BuildingClass], 
					sName					= L(pWonder.Description),
					sNameWithColor			= sNameWithColor,
					sTooltip				= GetHelpTextForBuilding(eWonder, false, false, false),
					eTechnology				= CheckWonderMaxEraOnStart(pWonder, sPrereqTechType),
					sTechName				= L(GameInfo.Technologies[sPrereqTechType].Description),
					sTechType				= sPrereqTechType,
					eEra					= GameInfoTypes[GameInfo.Technologies[sPrereqTechType].Era],
					sEraName				= L(GameInfo.Eras[GameInfo.Technologies[sPrereqTechType].Era].Description),
					eMaxStartEra			= GameInfoTypes[pWonder.MaxStartEra] or 10,
				
					pIconAtlas     			= pWonder.IconAtlas,
					ePortraitIndex 			= pWonder.PortraitIndex,
				
					eBuildingClass			= GameInfoTypes[pWonder.BuildingClass],
					sIdeologyBranch			= pWonder.PolicyBranchType,
					sPolicyType				= GameInfo.Buildings[eWonder].PolicyType ~= g_sPolicyLhasa and pWonder.PolicyType or nil,
					bHoly					= pWonder.HolyCity,
					bLeagueProject			= pWonder.UnlockedByLeague,
					sCivilization			= pWonder.CivilizationRequired,
					sEvent					= pWonder.EventChoiceRequiredActive,

					isFood        			= ((IsFood(pWonder)				or IsFood(pWonderDummy))			and -1 or 0),
					isConstruction  		= ((IsConstruction(pWonder)		or IsConstruction(pWonderDummy))	and -1 or 0),
					isGold        			= ((IsGold(pWonder)				or IsGold(pWonderDummy))			and -1 or 0),
					isTrade  				= ((IsTrade(pWonder)			or IsTrade(pWonderDummy))			and -1 or 0),
					isGoldenAge  			= ((IsGoldenAge(pWonder)		or IsGoldenAge(pWonderDummy))		and -1 or 0),
					isScience     			= ((IsScience(pWonder)			or IsScience(pWonderDummy))			and -1 or 0),
					isCulture     			= ((IsCulture(pWonder)			or IsCulture(pWonderDummy))			and -1 or 0),
					isGreatPeople			= ((IsGreatPeople(pWonder)[1]	or IsGreatPeople(pWonderDummy)[1])	or 0),
					isGreatPeopleRateChange	= ((IsGreatPeople(pWonder)[2]	or IsGreatPeople(pWonderDummy)[2])	or 0),
					isGreatPeopleTooltip	= (IsGreatPeople(pWonder)[3]	or IsGreatPeople(pWonderDummy)[3])	,
					isTourism     			= ((IsTourism(pWonder)			or IsTourism(pWonderDummy))			and -1 or 0),
					isFaith       			= ((IsFaith(pWonder)			or IsFaith(pWonderDummy))			and -1 or 0),
					isHappy       			= ((IsHappy(pWonder)			or IsHappy(pWonderDummy))			and -1 or 0),
					isOffense     			= ((IsOffense(pWonder)			or IsOffense(pWonderDummy))			and -1 or 0),
					isExpansion   			= ((IsExpansion(pWonder)		or IsExpansion(pWonderDummy))		and -1 or 0),
					isFreeUnit    			= (IsFreeUnit(pWonder)			or IsFreeUnit(pWonderDummy))		,
					isDefense     			= ((IsDefense(pWonder)			or IsDefense(pWonderDummy))			and -1 or 0),
					isEspionage   			= ((IsEspionage(pWonder)		or IsEspionage(pWonderDummy))		and -1 or 0),
					
					ePlayer = -1
				}
			else
				tWonders[eWonder] = {
					eWonder					= eWonder,
					sType					= pWonder.Type,
					eClass					= GameInfoTypes[pWonder.BuildingClass], 
					sName					= L(pWonder.Description),
					sNameWithColor			= sNameWithColor,
					sTooltip				= GetHelpTextForBuilding(eWonder, false, false, false),
					eTechnology				= CheckWonderMaxEraOnStart(pWonder, sPrereqTechType),
					sTechName				= L(GameInfo.Technologies[sPrereqTechType].Description),
					sTechType				= sPrereqTechType,
					eEra					= GameInfoTypes[GameInfo.Technologies[sPrereqTechType].Era],
					sEraName				= L(GameInfo.Eras[GameInfo.Technologies[sPrereqTechType].Era].Description),
					eMaxStartEra			= GameInfoTypes[pWonder.MaxStartEra] or 10,

					pIconAtlas     			= pWonder.IconAtlas,
					ePortraitIndex 			= pWonder.PortraitIndex,
				
					eBuildingClass			= GameInfoTypes[pWonder.BuildingClass],
					sIdeologyBranch			= pWonder.PolicyBranchType,
					sPolicyType				= GameInfo.Buildings[eWonder].PolicyType ~= g_sPolicyLhasa and pWonder.PolicyType or nil,
					bHoly					= pWonder.HolyCity,
					bLeagueProject			= pWonder.UnlockedByLeague,
					sCivilization			= pWonder.CivilizationRequired,
					sEvent					= pWonder.EventChoiceRequiredActive,

					-- We use -1 for true and 0 for false as it makes sorting easier
					isFood        			= (IsFood(pWonder) 				and -1 or 0),
					isConstruction  		= (IsConstruction(pWonder) 		and -1 or 0),
					isGold        			= (IsGold(pWonder) 				and -1 or 0),
					isTrade  				= (IsTrade(pWonder) 			and -1 or 0),
					isGoldenAge  			= (IsGoldenAge(pWonder) 		and -1 or 0),
					isScience     			= (IsScience(pWonder) 			and -1 or 0),
					isCulture     			= (IsCulture(pWonder) 			and -1 or 0),
					isGreatPeople			= (IsGreatPeople(pWonder)[1] 	or 0),
					isGreatPeopleRateChange	= (IsGreatPeople(pWonder)[2] 	or 0),
					isGreatPeopleTooltip	= IsGreatPeople(pWonder)[3]		,
					isTourism     			= (IsTourism(pWonder) 			and -1 or 0),
					isFaith       			= (IsFaith(pWonder) 			and -1 or 0),
					isHappy       			= (IsHappy(pWonder)				and -1 or 0),
					isOffense     			= (IsOffense(pWonder) 			and -1 or 0),
					isFreeUnit    			= IsFreeUnit(pWonder)			,
					isExpansion   			= (IsExpansion(pWonder) 		and -1 or 0),
					isDefense     			= (IsDefense(pWonder) 			and -1 or 0),
					isEspionage   			= (IsEspionage(pWonder) 		and -1 or 0),
					
					ePlayer = -1
				}
			end
		end
	end
end

function UpdateWonders(tWonders)
	-- initializing the table and reseting owners
	if tWonders.init == false then
		tWonders.init = nil
		GetWonders(tWonders)
	else
		for _, wonder in pairs(tWonders) do
			wonder.ePlayer = -1
		end
	end

	-- setting wonder locations and players who owe them (checking if active player met them)
	for playerID = 0, GameDefines.MAX_MAJOR_CIVS-1, 1 do
		local pPlayer = Players[playerID]

		if pPlayer:IsAlive() then
			local sPlayerName = pPlayer:GetName()
			local pTeam = Teams[pPlayer:GetTeam()]
			local bPlayerMet = false

			if playerID == Game.GetActivePlayer() then
				bPlayerMet = true	-- active player
			elseif not pTeam:IsHasMet(Game.GetActiveTeam()) then
				bPlayerMet = false	-- haven't yet met this player
			else
				bPlayerMet = true	-- met players
			end 
	  
			for city in pPlayer:Cities() do
				if city:GetNumWorldWonders() > 0 then
					for wonderID, wonder in pairs(tWonders) do
						if city:IsHasBuilding(wonderID) then
							if bPlayerMet then
								wonder.ePlayer = playerID
								wonder.sPlayer = sPlayerName
								wonder.iCity = city:GetID()
								wonder.sCity = city:GetName()
							else
								wonder.ePlayer = -2
								wonder.sPlayer = L("TXT_KEY_WONDERPLANNER_UNKNOWN")
								wonder.iCity = -2
								wonder.sCity = L("TXT_KEY_WONDERPLANNER_UNKNOWN")
							end
						end
					end
				end	
			end
		end
	end

	-- destroyed wonders
	for _, wonder in pairs(tWonders) do
		if wonder.ePlayer == -1 and Game.IsBuildingClassMaxedOut(wonder.eClass) then
			wonder.ePlayer = GameDefines.MAX_PLAYERS
			wonder.sPlayer = g_sDestroyed
		end
	end

	return tWonders
end

function IsWonder(pBuilding)
	if pBuilding.PrereqTech == nil and pBuilding.UnlockedByLeague == 0 then return false end
	
	if GameInfo.BuildingClasses[pBuilding.BuildingClass].MaxGlobalInstances == 1 then
		return true
	end

	return false
end
--------------------------------------------------------------
-- Icon markings
function IsFood(pBuilding)
	return (IsYield(pBuilding, "YIELD_FOOD") or pBuilding.AddsFreshWater == true or pBuilding.AllowsFoodTradeRoutesGlobal == true
		or pBuilding.GlobalPopulationChange ~= 0 or pBuilding.PopulationChange ~= 0
		or pBuilding.FoodBonusPerCityMajorityFollower ~= 0 or pBuilding.FoodKept ~= 0)
end
	
function IsConstruction(pBuilding)
	for row in GameInfo.Building_DomainProductionModifiers{BuildingType=pBuilding.Type} do
		if row.Modifier ~= 0 then
			return true
		end
	end

	for row in GameInfo.Building_UnitCombatProductionModifiers{BuildingType=pBuilding.Type} do
		if row.Modifier ~= 0 then
			return true
		end
	end
	for row in GameInfo.Building_UnitCombatProductionModifiersGlobal{BuildingType=pBuilding.Type} do
		if row.Modifier ~= 0 then
			return true
		end
	end
		
	return (IsYield(pBuilding, "YIELD_PRODUCTION") or pBuilding.AllowsProductionTradeRoutesGlobal == true
		or pBuilding.WonderProductionModifier ~= 0 or pBuilding.BuildingProductionModifier ~= 0
		or pBuilding.WorkerSpeedModifier ~= 0 or pBuilding.GlobalMilitaryProductionModPerMajorWar ~= 0
		or pBuilding.MilitaryProductionModifier ~= 0 or pBuilding.CityStateTradeRouteProductionModifier ~= 0)
end

function IsGold(pBuilding)
	return (IsYield(pBuilding, "YIELD_GOLD") or IsHurry(pBuilding, "HURRY_GOLD") or pBuilding.GreatPersonExpendGold ~= 0 
		or pBuilding.CityConnectionGoldModifier ~= 0 or pBuilding.CityConnectionTradeRouteModifier ~= 0
		or pBuilding.GlobalBuildingGoldMaintenanceMod ~= 0 or pBuilding.Gold ~= 0
		or pBuilding.TradeRouteSeaGoldBonus ~= 0 or pBuilding.TradeRouteLandGoldBonus ~= 0)
end

function IsScience(pBuilding)
	return (IsYield(pBuilding, "YIELD_SCIENCE") or pBuilding.FreeTechs ~= 0
		 or pBuilding.GlobalSpaceProductionModifier ~= 0 or pBuilding.SpaceProductionModifier ~= 0
		 or pBuilding.MedianTechPercentChange ~= 0
		 or pBuilding.GreatScientistBeakerModifier ~= 0)
end
	
function IsCulture(pBuilding)
	for row in GameInfo.Building_ResourceCultureChanges{BuildingType=pBuilding.Type} do
		if row.CultureChange ~= 0 then
			return true
		end
	end
		
	return (IsYield(pBuilding, "YIELD_CULTURE") or pBuilding.FreePolicies ~= 0 or pBuilding.FreeArtifacts ~= 0 
		or pBuilding.GlobalCultureRateModifier ~= 0 or pBuilding.CultureRateModifier ~= 0 or pBuilding.PolicyCostModifier ~= 0
		or pBuilding.SpecialistExtraCulture ~= 0)
end
	
function IsFaith(pBuilding)
	for row in GameInfo.Building_ResourceFaithChanges{BuildingType=pBuilding.Type} do
		if row.FaithChange ~= 0 then
			return true
		end
	end
		
	return (IsYield(pBuilding, "YIELD_FAITH") or pBuilding.HolyCity == true 
		or pBuilding.ReligiousPressureModifier == true or pBuilding.ConversionModifier ~= 0 or pBuilding.GlobalConversionModifier ~= 0
		or pBuilding.BasePressureModifierGlobal ~= 0 or pBuilding.InstantReligiousPressure ~= 0 or pBuilding.TradeReligionModifier ~= 0
		or pBuilding.ExtraMissionarySpreads ~= 0 or pBuilding.ExtraMissionaryStrengthGlobal ~= 0 
		or pBuilding.ReformationFollowerReduction ~= 0)
end
	
function IsGoldenAge(pBuilding)
	return (IsYield(pBuilding, "YIELD_GOLDEN_AGE_POINTS") or pBuilding.GoldenAgeModifier ~= 0 or pBuilding.GoldenAge == true)
end
	
function IsTourism(pBuilding)
	return (IsYield(pBuilding, "YIELD_TOURISM") or pBuilding.EventTourism == true
		or pBuilding.GreatWorkCount ~= 0 or pBuilding.FreeGreatWork ~= nil or pBuilding.GreatWorkSlotType ~= nil
		or pBuilding.GlobalLandmarksTourismPercent ~= 0 or pBuilding.LandmarksTourismPercent ~= 0
		or pBuilding.GlobalGreatWorksTourismModifier ~= 0 or pBuilding.GreatWorksTourismModifier ~= 0
		or pBuilding.TechEnhancedTourism ~= 0)
end
	
function IsTrade(pBuilding)
	for row in GameInfo.Building_ResourceQuantity{BuildingType=pBuilding.Type} do
		if row.Quantity ~= 0 then
			return true
		end
	end
	for row in GameInfo.Building_ResourceQuantityFromPOP{BuildingType=pBuilding.Type} do
		if row.Modifier ~= 0 then
			return true
		end
	end
	for row in GameInfo.Building_ResourceQuantityPerXFranchises{BuildingType=pBuilding.Type} do
		if row.NumFranchises ~= 0 then
			return true
		end
	end
	for row in GameInfo.Building_ResourcePlotsToPlace{BuildingType=pBuilding.Type} do
		if row.NumPlots ~= 0 then
			return true
		end
	end

	return (pBuilding.NumTradeRouteBonus ~= 0 or pBuilding.TradeRouteRecipientBonus ~= 0 or pBuilding.TradeRouteTargetBonus ~= 0 
		or pBuilding.TradeRouteSeaGoldBonus ~= 0 or pBuilding.TradeRouteLandGoldBonus ~= 0 or pBuilding.CityStateTradeRouteProductionModifier ~= 0
		or pBuilding.TradeRouteSeaDistanceModifier ~= 0 or pBuilding.TradeRouteLandDistanceModifier ~= 0
		or pBuilding.TRTurnModLocal ~= 0 or pBuilding.TRTurnModGlobal ~= 0 or pBuilding.TRVisionBoost ~= 0 or pBuilding.TRSpeedBoost ~= 0
		or pBuilding.FinishSeaTRTourism ~= 0 or pBuilding.FinishLandTRTourism ~= 0
		or pBuilding.CityConnectionTradeRouteModifier ~= 0)
end

function IsHappy(pBuilding)
	for row in GameInfo.Building_BuildingClassHappiness{BuildingType=pBuilding.Type} do
		if row.Happiness ~= 0 then
			return true
		end
	end
	for row in GameInfo.Building_BuildingClassLocalHappiness{BuildingType=pBuilding.Type} do
		if row.Happiness ~= 0 then
			return true
		end
	end

	for row in GameInfo.Building_ResourceHappinessChange{BuildingType=pBuilding.Type} do
		if row.HappinessChange ~= 0 then
			return true
		end
	end

	for row in GameInfo.Building_WLTKDFromProject{BuildingType=pBuilding.Type} do
		if row.Turns ~= 0 then
			return true
		end
	end
	  
	return (pBuilding.Happiness ~= 0 or pBuilding.UnmoddedHappiness ~= 0 or pBuilding.NoOccupiedUnhappiness == true 
		or pBuilding.GoldMedianModifier ~= 0 or pBuilding.BasicNeedsMedianModifier ~= 0 or pBuilding.ScienceMedianModifier ~= 0 or pBuilding.CultureMedianModifier ~= 0  or pBuilding.ReligiousUnrestModifier ~= 0
		or pBuilding.GoldMedianModifierGlobal ~= 0 or pBuilding.BasicNeedsMedianModifierGlobal ~= 0 or pBuilding.ScienceMedianModifierGlobal ~= 0 or pBuilding.CultureMedianModifierGlobal ~= 0  or pBuilding.ReligiousUnrestModifierGlobal ~= 0
		or pBuilding.PovertyFlatReduction ~= 0 or pBuilding.DistressFlatReduction ~= 0 or pBuilding.IlliteracyFlatReduction ~= 0 or pBuilding.BoredomFlatReduction ~= 0  or pBuilding.ReligiousUnrestFlatReduction ~= 0
		or pBuilding.PovertyFlatReductionGlobal ~= 0 or pBuilding.DistressFlatReductionGlobal ~= 0 or pBuilding.IlliteracyFlatReductionGlobal ~= 0 or pBuilding.BoredomFlatReductionGlobal ~= 0  or pBuilding.ReligiousUnrestFlatReductionGlobal ~= 0
		or pBuilding.UnhappinessModifier ~= 0 or pBuilding.LocalUnhappinessModifier ~= 0 or pBuilding.CityCountUnhappinessMod ~= 0
		or pBuilding.EmpireSizeModifierReduction ~= 0 or pBuilding.EmpireSizeModifierReductionGlobal ~= 0 
		or pBuilding.NoUnhappfromXSpecialists ~= 0 or pBuilding.NoUnhappfromXSpecialistsGlobal ~= 0 or pBuilding.NoStarvationNonSpecialist == true
		or pBuilding.HappinessPerXPolicies ~= 0 or pBuilding.HappinessPerCity ~= 0 or pBuilding.GlobalHappinessPerMajorWar ~= 0
		or pBuilding.ResourceDiversityModifier ~= 0 
		or pBuilding.WLTKDTurns ~= 0)
end

function IsDefense(pBuilding)
	return (pBuilding.Defense ~= 0 or pBuilding.BuildingDefenseModifier ~= 0 or pBuilding.GlobalDefenseMod ~= 0 or pBuilding.DefensePerXWonder ~= 0  
		or pBuilding.ExtraCityHitPoints ~= 0 or pBuilding.DamageReductionFlat ~= 0
		or pBuilding.AllowsRangeStrike == true or pBuilding.RangedStrikeModifier ~= 0 or pBuilding.CityRangedStrikeRange ~= 0
		or pBuilding.CityAirStrikeDefense ~= 0 or pBuilding.GarrisonRangedAttackModifier ~= 0 or pBuilding.CityIndirectFire == true
		or pBuilding.HealRateChange ~= 0 or pBuilding.AlwaysHeal == true
		or pBuilding.BorderObstacle == true or pBuilding.BorderObstacleWater == true or pBuilding.BorderObstacleCity == true
		or pBuilding.CityGainlessPillage == true or pBuilding.PlayerBorderGainlessPillage == true
		or pBuilding.NukeInterceptionChance ~= 0 or pBuilding.NukeModifier ~= 0 or pBuilding.NukeExplosionRand ~= 0
		or pBuilding.DeepWaterTileDamage ~= 0 
		or pBuilding.IgnoreDefensivePactLimit == true )
end
	
function IsOffense(pBuilding)
	return (IsCombatBonus(pBuilding) or pBuilding.FreePromotion ~= nil or pBuilding.TrainedFreePromotion ~= nil
		or pBuilding.CitySupplyModifier ~= 0 or pBuilding.CitySupplyModifierGlobal ~= 0
		or pBuilding.CitySupplyFlat ~= 0 or pBuilding.CitySupplyFlatGlobal ~= 0
		or pBuilding.UnitUpgradeCostMod ~= 0
		or pBuilding.ExperiencePerGoldenAge ~= 0 or pBuilding.GlobalExperience ~= 0 or pBuilding.Experience ~= 0
		or pBuilding.AirModifierGlobal ~= 0 or pBuilding.InstantMilitaryIncrease ~= 0
		or pBuilding.CapturePlunderModifier ~= 0)
end
	
function IsExpansion(pBuilding)
	for i, unit in pairs(g_tSettlers) do
		for row in GameInfo.Building_FreeUnits{BuildingType=pBuilding.Type, UnitType=g_tSettlers[i]} do
			return true
		end
	end
	
	return (pBuilding.GlobalPlotCultureCostModifier ~= 0 or pBuilding.GlobalPlotBuyCostModifier ~= 0
		or pBuilding.BorderGrowthRateIncreaseGlobal ~= 0 or pBuilding.BorderGrowthRateIncrease ~= 0
		or pBuilding.GlobalCityWorkingChange ~= 0 or pBuilding.CityWorkingChange ~= 0
		or pBuilding.GlobalCityAutomatonWorkersChange ~= 0 or pBuilding.CityAutomatonWorkersChange ~= 0
		or pBuilding.AllowsAirRoutes == true or pBuilding.AllowsIndustrialWaterRoutes == true
		or pBuilding.AllowsPuppetPurchase == true or pBuilding.PuppetPurchaseOverride == true
		or pBuilding.GrantsRandomResourceTerritory ~= 0 or pBuilding.Airlift == true)
end
	
function IsEspionage(pBuilding)
	local bVotes = pBuilding.ExtraLeagueVotes ~= 0 or pBuilding.SingleLeagueVotes ~= 0 or pBuilding.VotesPerGPT ~= 0 
		or pBuilding.FaithToVotes ~= 0 or pBuilding.CapitalsToVotes ~= 0 or pBuilding.DoFToVotes ~= 0 or pBuilding.RAToVotes ~= 0
	
	return (bVotes or (pBuilding.Espionage == true or pBuilding.AffectSpiesNow == true 
		or pBuilding.ExtraSpies ~= 0 or pBuilding.SpyRankChange == true or pBuilding.InstantSpyRankChange == true 		
		or pBuilding.GlobalSpySecurityModifier ~= 0 or pBuilding.SpySecurityModifier ~= 0 or pBuilding.SpySecurityModifierPerXPop ~= 0 	
		or pBuilding.EspionageModifier ~= 0 or pBuilding.GlobalEspionageModifier ~= 0 	
		or pBuilding.DiplomatInfluenceBoost ~= 0 or pBuilding.MinorFriendshipChange ~= 0))
end
	
function IsFreeUnit(pBuilding)
	local sTooltip, sFinalTooltip
	
	for rowBuilding in GameInfo.Building_FreeUnits{BuildingType=pBuilding.Type} do
		if rowBuilding.NumUnits ~= 0 then
			for rowFreeUnit in GameInfo.Units{Type=rowBuilding.UnitType} do
				if rowFreeUnit.CombatClass ~= 'UNITCOMBAT_SPECIAL_PEOPLE' then
					sTooltip = L(rowFreeUnit.Description)
					sFinalTooltip = AddNewLineWithColor(sTooltip, sFinalTooltip, g_sColorGold)
				end
			end
		end
	end

	if pBuilding.FreeBuildingThisCity ~= nil then
		for rowBuilding in GameInfo.Buildings{BuildingClass=pBuilding.FreeBuildingThisCity} do
			for rowBuildingClass in GameInfo.BuildingClasses{DefaultBuilding=rowBuilding.Type} do
				sTooltip = L(rowBuilding.Description)
				sFinalTooltip = AddNewLineWithColor(sTooltip, sFinalTooltip, g_sColorOrange)
			end
		end
	end
	
	if pBuilding.FreeBuilding ~= nil then
		for rowBuilding in GameInfo.Buildings{BuildingClass=pBuilding.FreeBuilding} do
			for rowBuildingClass in GameInfo.BuildingClasses{DefaultBuilding=rowBuilding.Type} do
				sTooltip = L(rowBuilding.Description)
				sFinalTooltip = AddNewLineWithColor(sTooltip, sFinalTooltip, g_sColorOrange)
			end
		end
	end
	
	return sFinalTooltip
end
	
function IsGreatPeople(pBuilding)
	local iNumberOfResults = 0
	local iGreatRateChange = 0
	local iIconID = -1	
	local sEraName, sTooltip, sFinalTooltip, iSort, iFinalSort


	-- PART 1: free GP
	for unit, unitID in pairs(g_tGreatPeopleUnits) do 
		for row in GameInfo.Building_FreeUnits{BuildingType=pBuilding.Type, UnitType=unit} do
			iNumberOfResults = iNumberOfResults + 1
			
			iSort = g_tGreatPeopleUnits[unit] - #g_tGreatPeopleIcons -- sometimes two types fit (free great person and specialist are different)
			iFinalSort = CompareSortValues(iSort, iFinalSort, #g_tGreatPeopleIcons)

			iGreatRateChange = iGreatRateChange - g_iSortTier1
			iIconID = g_tGreatPeopleUnits[unit] + 1
			
			sFinalTooltip = L("TXT_KEY_WONDERPLANNER_GPP_VER_1", g_tGreatPeopleIcons[iIconID])
		end
	end



	-- PART 2A: specialists and GPP per turn (excluding GGenP and GAdmP)
	if pBuilding.SpecialistCount ~= 0 or pBuilding.GreatPeopleRateChange ~= 0 then
		for i, specialist in ipairs(g_tAvailableSpecialists) do
			if pBuilding.SpecialistType == specialist then
				iNumberOfResults = iNumberOfResults + 1
				
				-- reverted results for sorting order
				iSort = i - #g_tGreatPeopleIcons
				iFinalSort = CompareSortValues(iSort, iFinalSort, #g_tGreatPeopleIcons)
				
				iGreatRateChange = iGreatRateChange - (g_iSortTier2 * pBuilding.SpecialistCount) - (g_iSortTier3 * pBuilding.GreatPeopleRateChange)
				iIconID = i + 1
				
				if pBuilding.SpecialistCount ~= 0 then
					if pBuilding.SpecialistCount == 1 then
						sTooltip = L("TXT_KEY_WONDERPLANNER_GPP_VER_2A1", g_tGreatPeopleIcons[iIconID])
					else
						sTooltip = L("TXT_KEY_WONDERPLANNER_GPP_VER_2A2", pBuilding.SpecialistCount, g_tGreatPeopleIcons[iIconID])
					end

					sFinalTooltip = AddNewLine(sTooltip, sFinalTooltip)
				end
				
				if pBuilding.GreatPeopleRateChange ~= 0 then
					sTooltip = L("TXT_KEY_WONDERPLANNER_GPP_VER_2B", pBuilding.GreatPeopleRateChange, g_tGreatPeopleIcons[iIconID])
					sFinalTooltip = AddNewLine(sTooltip, sFinalTooltip)
				end
			end
		end
	end
	
	-- PART 2B: GPP per turn (only GGenP and GAdmP)
	for yieldrow in GameInfo.Building_YieldChanges{BuildingType=pBuilding.Type} do
		if yieldrow.YieldType == "YIELD_GREAT_GENERAL_POINTS" then
			iNumberOfResults = iNumberOfResults + 1
			
			iSort = -4 -- sorting value for civil servant is -5
			iFinalSort = CompareSortValues(iSort, iFinalSort, #g_tGreatPeopleIcons)

			iGreatRateChange = iGreatRateChange - (g_iSortTier3 * yieldrow.Yield)
			iIconID = 9
			
			sTooltip = L("TXT_KEY_WONDERPLANNER_GPP_VER_2B", yieldrow.Yield, g_tGreatPeopleIcons[iIconID])
			sFinalTooltip = AddNewLine(sTooltip, sFinalTooltip)
		end
	end
	for yieldrow in GameInfo.Building_YieldChanges{BuildingType=pBuilding.Type} do
		if yieldrow.YieldType == "YIELD_GREAT_ADMIRAL_POINTS" then
			iNumberOfResults = iNumberOfResults + 1
			
			iSort = -3
			iFinalSort = CompareSortValues(iSort, iFinalSort, #g_tGreatPeopleIcons)

			iGreatRateChange = iGreatRateChange - (g_iSortTier3 * yieldrow.Yield)
			iIconID = 10
			
			sTooltip = L("TXT_KEY_WONDERPLANNER_GPP_VER_2B", yieldrow.Yield, g_tGreatPeopleIcons[iIconID])
			sFinalTooltip = AddNewLine(sTooltip, sFinalTooltip)
		end
	end

	-- PART 2C: specific GP modifiers
	for row in GameInfo.Building_SpecificGreatPersonRateModifier{BuildingType=pBuilding.Type} do
		if row.Modifier ~= 0 then
			iNumberOfResults = iNumberOfResults + 1
			
			for i, specialist in ipairs(g_tAvailableSpecialists) do
				if row.SpecialistType == specialist then
					iSort = i - #g_tGreatPeopleIcons
					iFinalSort = CompareSortValues(iSort, iFinalSort, #g_tGreatPeopleIcons)

					iGreatRateChange = iGreatRateChange - (g_iSortTier5 * row.Modifier)
					iIconID = i + 1

					sTooltip = L("TXT_KEY_WONDERPLANNER_GPP_VER_2C", row.Modifier, g_tGreatPeopleIcons[iIconID])
					
					if pBuilding.IsDummy then sTooltip = L("TXT_KEY_WONDERPLANNER_GPP_VER_EXTENSION", sTooltip) end
					
					sFinalTooltip = AddNewLine(sTooltip, sFinalTooltip)
					break
				end
			end
		end
	end
	if pBuilding.GreatGeneralRateModifier ~= 0 then
		iNumberOfResults = iNumberOfResults + 1

		iSort = -4
		iFinalSort = CompareSortValues(iSort, iFinalSort, #g_tGreatPeopleIcons)

		iGreatRateChange = iGreatRateChange - (g_iSortTier5 * pBuilding.GreatGeneralRateModifier)
		iIconID = 9

		sTooltip = L("TXT_KEY_WONDERPLANNER_GPP_VER_2C", pBuilding.GreatGeneralRateModifier, g_tGreatPeopleIcons[iIconID])
		sFinalTooltip = AddNewLine(sTooltip, sFinalTooltip)
	end
	
	-- PART 2D: GP points or progress from building construction
	for row in GameInfo.Building_GreatPersonPointFromConstruction{BuildingType=pBuilding.Type} do
		if row.Value ~= 0 then
			iNumberOfResults = iNumberOfResults + 1

			iSort = g_tGreatPersonTypes[row.GreatPersonType] - #g_tGreatPeopleIcons
			iFinalSort = CompareSortValues(iSort, iFinalSort, #g_tGreatPeopleIcons)

			iGreatRateChange = iGreatRateChange - (g_iSortTier5 * row.Value)
			iIconID = g_tGreatPersonTypes[row.GreatPersonType] + 1

			for era in GameInfo.Eras{Type=row.EraType} do
				sEraName = L(era.Description)
				break
			end			

			sTooltip = L("TXT_KEY_WONDERPLANNER_GPP_VER_2D", row.Value, g_tGreatPeopleIcons[iIconID], sEraName)
			sFinalTooltip = AddNewLine(sTooltip, sFinalTooltip)
		end
	end			
	for row in GameInfo.Building_GreatPersonProgressFromConstruction{BuildingType=pBuilding.Type} do
		if row.Value ~= 0 then
			iNumberOfResults = iNumberOfResults + 1

			iSort = g_tGreatPersonTypes[row.GreatPersonType] - #g_tGreatPeopleIcons
			iFinalSort = CompareSortValues(iSort, iFinalSort, #g_tGreatPeopleIcons)

			iGreatRateChange = iGreatRateChange - (g_iSortTier4 * row.Value)
			iIconID = g_tGreatPersonTypes[row.GreatPersonType] + 1

			for era in GameInfo.Eras{Type=row.EraType} do
				sEraName = L(era.Description)
				break
			end			

			sTooltip = L("TXT_KEY_WONDERPLANNER_GPP_VER_2E", row.Value, g_tGreatPeopleIcons[iIconID], sEraName)
			sFinalTooltip = AddNewLine(sTooltip, sFinalTooltip)
		end
	end



	-- PART 3: bonuses to overall GP generation
	if pBuilding.FreeGreatPeople ~= 0 or pBuilding.GreatPeopleRateModifier ~= 0 or pBuilding.GlobalGreatPeopleRateModifier ~= 0
		or pBuilding.GPRateModifierPerMarriage ~= 0 or pBuilding.GPRateModifierPerLocalTheme ~= 0 or pBuilding.GPPOnCitizenBirth ~= 0 then
		iNumberOfResults = iNumberOfResults + 1
		
		iSort = -1
		iFinalSort = CompareSortValues(iSort, iFinalSort, #g_tGreatPeopleIcons)

		if pBuilding.FreeGreatPeople ~= 0 then
			iGreatRateChange = iGreatRateChange - g_iSortTier1
			
			sTooltip = L("TXT_KEY_WONDERPLANNER_GPP_VER_3A")
			sFinalTooltip = AddNewLine(sTooltip, sFinalTooltip)
		end
		
		if pBuilding.GlobalGreatPeopleRateModifier ~= 0 then
			iGreatRateChange = iGreatRateChange - (g_iSortTier5 * pBuilding.GlobalGreatPeopleRateModifier)
			
			sTooltip = L("TXT_KEY_WONDERPLANNER_GPP_VER_3B", pBuilding.GlobalGreatPeopleRateModifier)
			sFinalTooltip = AddNewLine(sTooltip, sFinalTooltip)
		end

		if pBuilding.GreatPeopleRateModifier ~= 0 then
			iGreatRateChange = iGreatRateChange - (g_iSortTier5 * pBuilding.GreatPeopleRateModifier)
			
			sTooltip = L("TXT_KEY_WONDERPLANNER_GPP_VER_3C", pBuilding.GreatPeopleRateModifier)
			sFinalTooltip = AddNewLine(sTooltip, sFinalTooltip)
		end

		if pBuilding.GPRateModifierPerMarriage ~= 0 then
			iGreatRateChange = iGreatRateChange - (g_iSortTier5 * pBuilding.GPRateModifierPerMarriage)
			
			sTooltip = L("TXT_KEY_WONDERPLANNER_GPP_VER_3D", pBuilding.GPRateModifierPerMarriage)
			sFinalTooltip = AddNewLine(sTooltip, sFinalTooltip)
		end

		if pBuilding.GPRateModifierPerLocalTheme ~= 0 then
			iGreatRateChange = iGreatRateChange - (g_iSortTier5 * pBuilding.GPRateModifierPerLocalTheme)
			
			sTooltip = L("TXT_KEY_WONDERPLANNER_GPP_VER_3E", pBuilding.GPRateModifierPerLocalTheme)
			sFinalTooltip = AddNewLine(sTooltip, sFinalTooltip)
		end

		if pBuilding.GPPOnCitizenBirth ~= 0 then
			iGreatRateChange = iGreatRateChange - (g_iSortTier5 * pBuilding.GPPOnCitizenBirth)
			
			sTooltip = L("TXT_KEY_WONDERPLANNER_GPP_VER_3F", pBuilding.GPPOnCitizenBirth)
			sFinalTooltip = AddNewLine(sTooltip, sFinalTooltip)
		end
	end

	if iNumberOfResults == 0 then
		-- return empty table
		return {nil, nil, nil}
	else
		-- returns a table (base sorting also defining an icon; additional sorting if base is the same; tooltip)
		return {iFinalSort, iGreatRateChange, sFinalTooltip}
	end
end
--------------------------------------------------------------
function CompareSortValues(iNewSort, iCurrentSort, iMaxSort)
	-- function checks if wonder supports one or more types of great people
	return (iCurrentSort == nil) and iNewSort or ((iCurrentSort == iNewSort) and iCurrentSort or -iMaxSort)
end

function AddNewLine(iNewValue, iCurrentValue)
	-- function concatenates multiple lines into one tooltip
	return (iCurrentValue == nil) and iNewValue or (iCurrentValue .. '[NEWLINE]' .. iNewValue)
end

function AddNewLineWithColor(iNewValue, iCurrentValue, sColor)
	-- function concatenates multiple lines into one tooltip with colors addition
	iNewValue = sColor .. iNewValue .. "[ENDCOLOR]"
	return (iCurrentValue == nil) and iNewValue or (iCurrentValue .. '[NEWLINE]' .. iNewValue)
end
--------------------------------------------------------------
function IsYield(pBuilding, sYieldType)
	for row in GameInfo.Building_YieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldChangesFromAccomplishments{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end 
	for row in GameInfo.Building_YieldChangesFromMonopoly{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end 
	for row in GameInfo.Building_YieldChangesFromPassingTR{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end 
	for row in GameInfo.Building_YieldChangesFromXCityStateStrategicResource{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end 


	for row in GameInfo.Building_YieldChangesPerCityStrengthTimes100{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end 
	for row in GameInfo.Building_YieldChangesPerGoldenAge{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end 
	for row in GameInfo.Building_YieldChangesPerLocalTheme{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end 
	for row in GameInfo.Building_YieldChangesPerPop{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldChangesPerPopInEmpire{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldChangesPerReligion{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldChangesPerXBuilding{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldChangesPerXTiles{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end


	for row in GameInfo.Building_YieldChangeWorldWonder{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldChangeWorldWonderGlobal{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end


	for row in GameInfo.Building_YieldFromBirth{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromBirthRetroactive{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromBorderGrowth{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromCombatExperienceTimes100{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromConstruction{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromDeath{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromFaithPurchase{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromGoldenAgeStart{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end 
	for row in GameInfo.Building_YieldFromGPBirthScaledWithArtistBulb{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromGPBirthScaledWithPerTurnYield{BuildingType=pBuilding.Type, YieldOut=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromGPBirthScaledWithWriterBulb{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromGPExpend{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromInternalTR{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromInternalTREnd{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromInternationalTREnd{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromLongCount{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromPillage{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromPillageGlobal{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromPillageGlobalPlayer{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromPolicyUnlock{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromProcessModifier{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromPurchase{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromPurchaseGlobal{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromSpyAttack{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromSpyDefense{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromSpyDefenseOrID{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromSpyIdentify{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromSpyRigElection{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromTech{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromUnitGiftGlobal{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromUnitLevelUp{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromUnitLevelUpGlobal{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromUnitProduction{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromVictory{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromVictoryGlobal{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromVictoryGlobalPlayer{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromWLTKD{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldFromYieldPercent{BuildingType=pBuilding.Type, YieldOut=sYieldType} do
		if (row.Value ~= 0) then return true end
	end	
	for row in GameInfo.Building_YieldFromYieldPercentGlobal{BuildingType=pBuilding.Type, YieldOut=sYieldType} do
		if (row.Value ~= 0) then return true end
	end	


	for row in GameInfo.Building_YieldModifiers{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end	  


	for row in GameInfo.Building_YieldPerAlly{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end	  
	for row in GameInfo.Building_YieldPerFranchise{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end	
	for row in GameInfo.Building_YieldPerFriend{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_YieldPerXFeatureTimes100{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end	
	for row in GameInfo.Building_YieldPerXTerrainTimes100{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end	


	for row in GameInfo.Building_AreaYieldModifiers{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_InstantYield{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_GlobalYieldModifiers{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_GoldenAgeYieldMod{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	

	for row in GameInfo.Building_BuildingClassLocalYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.YieldChange ~= 0) then return true end
	end	
	for row in GameInfo.Building_BuildingClassYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.YieldChange ~= 0) then return true end
	end
	for row in GameInfo.Building_BuildingClassYieldModifiers{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Modifier ~= 0) then return true end
	end
		

	for row in GameInfo.Building_GreatWorkYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_GreatWorkYieldChangesLocal{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_ThemingYieldBonus{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end


	for row in GameInfo.Building_GrowthExtraYield{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end

	for row in GameInfo.Building_ImprovementYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_ImprovementYieldChangesGlobal{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_LakePlotYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_LakePlotYieldChangesGlobal{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_PlotYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_ResourceYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_ResourceYieldChangesGlobal{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_ResourceYieldModifiers{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_RiverPlotYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_SeaPlotYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_SeaResourceYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_TerrainYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_FeatureYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end	
	for row in GameInfo.Building_LuxuryYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end


	for row in GameInfo.Building_SpecialistYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	for row in GameInfo.Building_SpecialistYieldChangesLocal{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
	

	for row in GameInfo.Building_TechEnhancedYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end


	for row in GameInfo.Building_WLTKDYieldMod{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end


	for row in GameInfo.Building_FranchiseTradeRouteCityYield{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield ~= 0) then return true end
	end
 
	return false
end

function IsHurry(pBuilding, sHurryType)
	for row in GameInfo.Building_HurryModifiers{BuildingType=pBuilding.Type, HurryType=sHurryType} do
		if row.HurryCostModifier < 0 then return true end
	end
	for row in GameInfo.Building_HurryModifiersLocal{BuildingType=pBuilding.Type, HurryType=sHurryType} do
		if row.HurryCostModifier < 0 then return true end
	end

	return false
end

function IsCombatBonus(pBuilding)
	for row in GameInfo.Building_DomainFreeExperiencePerGreatWork{BuildingType=pBuilding.Type} do
		if row.Experience ~= 0 then return true end
	end
	for row in GameInfo.Building_DomainFreeExperiencePerGreatWorkGlobal{BuildingType=pBuilding.Type} do
		if row.Experience ~= 0 then return true end
	end
	for row in GameInfo.Building_DomainFreeExperiences{BuildingType=pBuilding.Type} do
		if row.Experience ~= 0 then return true end
	end
	for row in GameInfo.Building_DomainFreeExperiencesGlobal{BuildingType=pBuilding.Type} do
		if row.Experience ~= 0 then return true end
	end

	for row in GameInfo.Building_UnitCombatFreeExperiences{BuildingType=pBuilding.Type} do
		if row.Experience ~= 0 then return true end
	end
	
	for row in GameInfo.Building_UnitCombatProductionModifiers{BuildingType=pBuilding.Type} do
		if row.Modifier ~= 0 then return true end
	end
	for row in GameInfo.Building_UnitCombatProductionModifiersGlobal{BuildingType=pBuilding.Type} do
		if row.Modifier ~= 0 then return true end
	end
	for row in GameInfo.Building_DomainProductionModifiers{BuildingType=pBuilding.Type} do
		if row.Modifier ~= 0 then return true end
	end

	if pBuilding.GlobalMilitaryProductionModPerMajorWar ~= 0 or pBuilding.MilitaryProductionModifier ~= 0 then return true end

	return false
end
--------------------------------------------------------------
function IsLocked(tWonder, ePlayer)
	local bLocked = false
	local sReason = nil
	local pPlayer = Players[ePlayer]

	local bHoly = tWonder.bHoly
	local sIdeologyBranch = tWonder.sIdeologyBranch
	local sPolicyType = tWonder.sPolicyType
	local bLeagueProject = tWonder.bLeagueProject
	local bUniqueCS = tWonder.sEvent
	local bUniqueCiv = tWonder.sCivilization
	
	
	if Game.GetBuildingClassCreatedCount(tWonder.eBuildingClass) > 0 then
		bLocked = true
		sReason = L("TXT_KEY_WONDERPLANNER_LOCKED_DESTROYED")
	elseif bHoly then
		local bHasHolyCity = false

		for city in pPlayer:Cities() do
			if city:IsHolyCityAnyReligion() then
				bHasHolyCity = true
				break
			end
		end

		if not bHasHolyCity then
			bLocked = true
			sReason = L("TXT_KEY_WONDERPLANNER_LOCKED_MISSING_RELIGION", g_sColorHoly)
		end
	elseif sIdeologyBranch then
		local eIdeologyBranch = GameInfoTypes[sIdeologyBranch]
		
		if not pPlayer:IsPolicyBranchUnlocked(eIdeologyBranch) then
			bLocked = true
			sReason = L("TXT_KEY_WONDERPLANNER_LOCKED_MISSING_IDEOLOGY", g_sColorIdeology, L(GameInfo.PolicyBranchTypes[eIdeologyBranch].Description))
		end
	elseif sPolicyType then
		local ePolicyBranch, sPolicyBranchName
		local ePolicy = GameInfo.Policies{Type=sPolicyType}().ID
		
		for row in GameInfo.PolicyBranchTypes{FreeFinishingPolicy=sPolicyType} do
			ePolicyBranch = row.ID
			sPolicyBranchName = L(row.Description)
			break
		end
		
		if ePolicyBranch ~= nil then
			if not pPlayer:IsPolicyBranchFinished(ePolicyBranch) then
				bLocked = true
				sReason = L("TXT_KEY_WONDERPLANNER_LOCKED_MISSING_POLICY_BRANCH", g_sColorPolicyFinisher, sPolicyBranchName)
			end
		else
			if not pPlayer:HasPolicy(ePolicy) then
				bLocked = true
				sReason = L("TXT_KEY_WONDERPLANNER_LOCKED_MISSING_POLICY", g_sColorPolicy, L(GameInfo.Policies{Type=sPolicyType}().Description))
			end
		end
	elseif bLeagueProject then
		local sProjectName, eResolution, eProject
		
		for rowLeagueRewards in GameInfo.LeagueProjectRewards{Building=tWonder.sType} do
			for rowLeagueProject in GameInfo.LeagueProjects() do
				if rowLeagueProject.RewardTier1 == rowLeagueRewards.Type or rowLeagueProject.RewardTier2 == rowLeagueRewards.Type or rowLeagueProject.RewardTier3 == rowLeagueRewards.Type then
					for rowResolution in GameInfo.Resolutions{LeagueProjectEnabled=rowLeagueProject.Type} do
						eResolution = rowResolution.ID
						eProject = rowLeagueProject.ID
						sProjectName = L(rowLeagueProject.Description)
						break
					end
				
					if eResolution ~= nil then break end
				end
			end	

			if eResolution ~= nil then break end
		end
		
		local pLeague = Game.GetActiveLeague()
		
		if not pLeague or not pLeague:IsProjectActive(eProject) then
			bLocked = true
			sReason = L("TXT_KEY_WONDERPLANNER_LOCKED_MISSING_WORLD_PROJECT", g_sColorCongress, sProjectName)
		end
	elseif bUniqueCS then
		local pEventChoice = GameInfo.EventChoices{Type=tWonder.sEvent}()
		local eEventChoice = pEventChoice.ID
		local iEventChoiceCooldown = pPlayer:GetEventChoiceCooldown(eEventChoice)
		local sUniqueCSName = L(pEventChoice.Description)
		
		if iEventChoiceCooldown == 0 then
			bLocked = true
			sReason = L("TXT_KEY_WONDERPLANNER_LOCKED_MISSING_ALLIANCE", g_sColorUniqueCs, sUniqueCSName)
		end
	elseif bUniqueCiv then
		local pCivilization = GameInfo.Civilizations{Type=tWonder.sCivilization}()

		if pPlayer:GetCivilizationType() ~= pCivilization.ID then
			bLocked = true
			sReason = L("TXT_KEY_WONDERPLANNER_LOCKED_WRONG_CIVILIZATION", g_sColorUniqueCiv, pCivilization.ShortDescription)
		end
	end
	
	return bLocked, sReason
end

function CheckWonderMaxEraOnStart(pBuilding, sPrereqTechType)
	local iMaxStartEra = (pBuilding.MaxStartEra == nil) and #GameInfo.Eras or GameInfoTypes[pBuilding.MaxStartEra]
	
	return ((PreGame.GetEra() > iMaxStartEra) and -1 or GameInfoTypes[sPrereqTechType])
end

function GetTechs(ePlayer)
	local techs = {}
	local pTeam = Teams[Players[ePlayer]:GetTeam()]

	for pTech in GameInfo.Technologies() do
		if pTeam:IsHasTech(pTech.ID) then
			techs[pTech.ID] = 1
			techs[pTech.Type] = 1
		end
	end

	return techs
end

function OnEraSelected(eEra)
	if g_iEraLimit ~= eEra then
		g_iEraLimit = eEra

		Controls.EraMenu:GetButton():LocalizeAndSetText(GameInfo.Eras[g_iEraLimit].Description)

		for eWonder, wonder in pairs(g_tWonders) do
			if wonder.ePlayer == -1 then
				wonder.instance.Wonder:SetHide(wonder.eEra > g_iEraLimit)
			end
		end

		Controls.PlannerStack:CalculateSize()
		Controls.PlannerScrollPanel:CalculateInternalSize()
	end
end

function UpdateEraList(ePlayer)
	local pPlayer = Players[ePlayer]
	local iTeam = pPlayer:GetTeam()

	Controls.EraMenu:ClearEntries()

	for iera = pPlayer:GetCurrentEra(), #GameInfo.Eras - 1, 1 do
		local pEra = GameInfo.Eras[iera]
   		local era = {}
		
		Controls.EraMenu:BuildEntry("InstanceOne", era)
	
		era.Button:SetVoid1(iera)
		era.Button:SetText(L(pEra.Description))
	end

	Controls.EraMenu:GetButton():LocalizeAndSetText(GameInfo.Eras[g_iEraLimit].Description)

	Controls.EraMenu:CalculateInternals()
	Controls.EraMenu:RegisterSelectionCallback(OnEraSelected)
end

function OnNoEraCheck()
	local eActivePlayer = Game.GetActivePlayer()
	
	if Controls.NoEraLimitCheckbox:IsChecked() then
		g_iEraLimit = g_iMaxEraLimit
		Controls.EraMenu:GetButton():LocalizeAndSetText(GameInfo.Eras[g_iEraLimit].Description)
		Controls.EraMenu:SetDisabled(true)
		UpdateEraList(eActivePlayer)
		OnWondersUpdate()
	else
		g_iEraLimit = math.min(#GameInfo.Eras - 1, Players[eActivePlayer]:GetCurrentEra() + 1)
		Controls.EraMenu:GetButton():LocalizeAndSetText(GameInfo.Eras[g_iEraLimit].Description)
		Controls.EraMenu:SetDisabled(false)		
		UpdateEraList(eActivePlayer)
		OnWondersUpdate()
	end
end
Controls.NoEraLimitCheckbox:RegisterCallback(Mouse.eLClick, OnNoEraCheck)

function OnClose()
	ContextPtr:SetHide(true)
end
Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose)

function InputHandler(uiMsg, wParam, lParam)
	if uiMsg == KeyEvents.KeyDown then
		if wParam == Keys.VK_ESCAPE then
			OnClose()
			return true
		end
	end
end
ContextPtr:SetInputHandler(InputHandler)

function OnWondersUpdate()
	if not ContextPtr:IsHidden() then
		local ePlayer = Game.GetActivePlayer()

		if (g_iEraLimit == -1) then
			g_iEraLimit = math.min(#GameInfo.Eras - 1, Players[ePlayer]:GetCurrentEra() + 1)
		end

		UpdateEraList(ePlayer)
		UpdateData(ePlayer)
	end
end
LuaEvents.WonderPlannerDisplay.Add(function() ContextPtr:SetHide(false) end)

function ShowHideHandler(bIsHide, bInitState)
	if not bInitState and not bIsHide then
		OnWondersUpdate()
	end
end
ContextPtr:SetShowHideHandler(ShowHideHandler)


function OnShowPlanner()
	Controls.PlannerPanel:SetHide(false)
	Controls.BuiltPanel:SetHide(true)

	Controls.PlannerHighlight:SetHide(false)
	Controls.BuiltHighlight:SetHide(true)
  
	Controls.EraLimit:SetHide(false)
end
Controls.PlannerButton:RegisterCallback(Mouse.eLClick, OnShowPlanner)

function OnShowBuilt()
	Controls.BuiltPanel:SetHide(false)
	Controls.PlannerPanel:SetHide(true)

	Controls.BuiltHighlight:SetHide(false)
	Controls.PlannerHighlight:SetHide(true)
  
	Controls.EraLimit:SetHide(true)
end
Controls.BuiltButton:RegisterCallback(Mouse.eLClick, OnShowBuilt)

GetCivs();
OnShowPlanner()
ContextPtr:SetHide(true)
--
-- DiploCorner addin methods
--
function OnDiploCornerPopup()
	ContextPtr:SetHide(false)
end

function OnAdditionalInformationDropdownGatherEntries(additionalEntries)
	table.insert(additionalEntries, {text=L("TXT_KEY_WONDERPLANNER_DIPLO_CORNER_HOOK"), call=OnDiploCornerPopup, art="WonderPlannerLogo.dds"})
end
LuaEvents.AdditionalInformationDropdownGatherEntries.Add(OnAdditionalInformationDropdownGatherEntries)
LuaEvents.RequestRefreshAdditionalInformationDropdownEntries()