print("Loading WonderPlanner.lua from Wonder Planner")

include("IconSupport")
include("InstanceManager")
include("InfoTooltipInclude")
include("SupportFunctions")
include("NewSaveUtils")

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

local g_PlannerIM = InstanceManager:new("WonderPlanner", "Wonder", Controls.PlannerStack)
local g_BuiltIM = InstanceManager:new("WonderPlanner", "Wonder", Controls.BuiltStack)

local g_SortTable = {}
local g_ActiveSort = "needed"
local g_ReverseSort = false

local g_Civs = {}
local g_Wonders = {init=false}
local g_EraLimit = -1

local sDestroyed = Locale.ConvertTextKey("TXT_KEY_WONDERPLANNER_DESTROYED")

local g_ColorHoly = '[COLOR_MENU_BLUE]'
local g_ColorPolicy = '[COLOR_MAGENTA]'
local g_ColorIdeology = '[COLOR_YELLOW]'
local g_ColorCongress = '[COLOR:45:150:50:255]'
local g_ColorCorporation = '[COLOR_YIELD_FOOD]'

local g_AvailableSpecialists = {
	'SPECIALIST_ENGINEER',
	'SPECIALIST_MERCHANT',
	'SPECIALIST_SCIENTIST',
	'SPECIALIST_ARTIST',
	'SPECIALIST_WRITER',
	'SPECIALIST_MUSICIAN',
	'SPECIALIST_CIVIL_SERVANT'
}

local g_GreatPeopleUnits = {
	['UNIT_ENGINEER'] = 1,
	['UNIT_MERCHANT'] = 2,
	['UNIT_SCIENTIST'] = 3,
	['UNIT_ARTIST'] = 4,
	['UNIT_WRITER'] = 5,
	['UNIT_MUSICIAN'] = 6,
	['UNIT_GREAT_DIPLOMAT'] = 7,
	['UNIT_GREAT_ADMIRAL'] = 8,
	['UNIT_GREAT_GENERAL'] = 9,
	['UNIT_PROPHET'] = 10
}

local g_GreatPeopleIcons = {
	'[ICON_GREAT_WORK]',
	'[ICON_GREAT_ENGINEER]',
	'[ICON_GREAT_MERCHANT]',
	'[ICON_GREAT_SCIENTIST]',
	'[ICON_GREAT_ARTIST]',
	'[ICON_GREAT_WRITER]',
	'[ICON_GREAT_MUSICIAN]',
	'[ICON_DIPLOMAT]',
	'[ICON_GREAT_ADMIRAL]',
	'[ICON_GREAT_GENERAL]',
	'[ICON_PROPHET]',
	'[ICON_GREAT_PEOPLE]'
}

local g_Settlers = {}

for unit in GameInfo.Units() do
	if unit.Found then
		g_Settlers[unit.ID] = unit.Type
		print(g_Settlers[unit.ID])
	end
end
	
function OnSort(sort)
	if sort == g_ActiveSort then
		g_ReverseSort = not g_ReverseSort
	else
		g_ReverseSort = false
		g_ActiveSort = sort
	end

	Controls.PlannerStack:SortChildren(SortByValue)
	Controls.BuiltStack:SortChildren(SortByValue)
end
Controls.SortPlannerName:RegisterCallback(Mouse.eLClick, function() OnSort("name") end)
Controls.SortPlannerTech:RegisterCallback(Mouse.eLClick, function() OnSort("tech") end)
Controls.SortPlannerTechsNeeded:RegisterCallback(Mouse.eLClick, function() OnSort("needed") end)
Controls.SortPlannerHappy:RegisterCallback(Mouse.eLClick, function() OnSort("happy") end)
Controls.SortPlannerFreeUnit:RegisterCallback(Mouse.eLClick, function() OnSort("freeunit") end)
Controls.SortPlannerFaith:RegisterCallback(Mouse.eLClick, function() OnSort("faith") end)
Controls.SortPlannerCulture:RegisterCallback(Mouse.eLClick, function() OnSort("culture") end)
Controls.SortPlannerScience:RegisterCallback(Mouse.eLClick, function() OnSort("science") end)
Controls.SortPlannerExpansion:RegisterCallback(Mouse.eLClick, function() OnSort("expansion") end)
Controls.SortPlannerFood:RegisterCallback(Mouse.eLClick, function() OnSort("food") end)
Controls.SortPlannerGold:RegisterCallback(Mouse.eLClick, function() OnSort("gold") end)
Controls.SortPlannerDefense:RegisterCallback(Mouse.eLClick, function() OnSort("defense") end)
Controls.SortPlannerOffense:RegisterCallback(Mouse.eLClick, function() OnSort("offense") end)
Controls.SortPlannerGreatPeople:RegisterCallback(Mouse.eLClick, function() OnSort("greatpeople") end)
Controls.SortPlannerEspionage:RegisterCallback(Mouse.eLClick, function() OnSort("espionage") end)
Controls.SortPlannerTourism:RegisterCallback(Mouse.eLClick, function() OnSort("tourism") end)
Controls.SortPlannerConstruction:RegisterCallback(Mouse.eLClick, function() OnSort("construction") end)
Controls.SortPlannerGoldenAge:RegisterCallback(Mouse.eLClick, function() OnSort("goldenage") end)
Controls.SortPlannerTrade:RegisterCallback(Mouse.eLClick, function() OnSort("trade") end)
Controls.SortBuiltName:RegisterCallback(Mouse.eLClick, function() OnSort("name") end)
Controls.SortBuiltCity:RegisterCallback(Mouse.eLClick, function() OnSort("city") end)
Controls.SortBuiltHappy:RegisterCallback(Mouse.eLClick, function() OnSort("happy") end)
Controls.SortBuiltFreeUnit:RegisterCallback(Mouse.eLClick, function() OnSort("freeunit") end)
Controls.SortBuiltFaith:RegisterCallback(Mouse.eLClick, function() OnSort("faith") end)
Controls.SortBuiltCulture:RegisterCallback(Mouse.eLClick, function() OnSort("culture") end)
Controls.SortBuiltScience:RegisterCallback(Mouse.eLClick, function() OnSort("science") end)
Controls.SortBuiltExpansion:RegisterCallback(Mouse.eLClick, function() OnSort("expansion") end)
Controls.SortBuiltFood:RegisterCallback(Mouse.eLClick, function() OnSort("food") end)
Controls.SortBuiltGold:RegisterCallback(Mouse.eLClick, function() OnSort("gold") end)
Controls.SortBuiltDefense:RegisterCallback(Mouse.eLClick, function() OnSort("defense") end)
Controls.SortBuiltOffense:RegisterCallback(Mouse.eLClick, function() OnSort("offsense") end)
Controls.SortBuiltGreatPeople:RegisterCallback(Mouse.eLClick, function() OnSort("greatpeople") end)
Controls.SortBuiltEspionage:RegisterCallback(Mouse.eLClick, function() OnSort("espionage") end)
Controls.SortBuiltTourism:RegisterCallback(Mouse.eLClick, function() OnSort("tourism") end)
Controls.SortBuiltConstruction:RegisterCallback(Mouse.eLClick, function() OnSort("construction") end)
Controls.SortBuiltGoldenAge:RegisterCallback(Mouse.eLClick, function() OnSort("goldenage") end)
Controls.SortBuiltTrade:RegisterCallback(Mouse.eLClick, function() OnSort("trade") end)

function SortByValue(a, b)
	local entryA = g_SortTable[tostring(a)]
	local entryB = g_SortTable[tostring(b)]

	if entryA == nil or entryB == nil then
		return tostring(a) < tostring(b)
	end

	local valueA = entryA[g_ActiveSort]
	local valueB = entryB[g_ActiveSort]

	if g_ReverseSort then
		valueA = entryB[g_ActiveSort]
		valueB = entryA[g_ActiveSort]
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

function UpdateData(iPlayer)
	local pPlayer = Players[iPlayer]
	CivIconHookup(iPlayer, 64, Controls.Icon, Controls.CivIconBG, Controls.CivIconShadow, false, true)

	local tPlayerTechs = GetTechs(iPlayer)
  
	g_PlannerIM:ResetInstances()
	g_BuiltIM:ResetInstances()
	g_SortTable = {}

	for wonderID, wonder in pairs(UpdateWonders(g_Wonders)) do
		if wonder.iTech ~= -1 then
			AddWonder(iPlayer, tPlayerTechs, wonderID, wonder)
		end
	end

	Controls.PlannerStack:SortChildren(SortByValue)
	Controls.PlannerStack:CalculateSize()
	Controls.PlannerScrollPanel:CalculateInternalSize()

	Controls.BuiltStack:SortChildren(SortByValue)
	Controls.BuiltStack:CalculateSize()
	Controls.BuiltScrollPanel:CalculateInternalSize()
end

function AddWonder(iPlayer, tPlayerTechs, iWonder, pWonder)
  local instance = (pWonder.iPlayer == -1) and g_PlannerIM:GetInstance() or g_BuiltIM:GetInstance()
  pWonder.instance = instance

  local sort = {}
  g_SortTable[tostring(instance.Wonder)] = sort

  if IconHookup(pWonder.pPortraitIndex, 45, pWonder.pIconAtlas, instance.Icon) then
		instance.Icon:SetHide(false)
		instance.Icon:SetToolTipString(pWonder.sNameWithColor)
  else
		instance.Icon:SetHide(true)
  end

  sort.name = pWonder.sName
  TruncateString(instance.Name, 260, pWonder.sNameWithColor)
  instance.Name:SetToolTipString(pWonder.sToolTip)

  if pWonder.iPlayer == -1 then
		local pTech = GameInfo.Technologies[pWonder.sTechType]
		
		if IconHookup(pTech.PortraitIndex, 45, pTech.IconAtlas, instance.TechIcon) then
			instance.TechIcon:SetHide(false)
			instance.TechIcon:SetToolTipString(pWonder.sTechName)
		else
			instance.TechIcon:SetHide(true)
		end

		sort.tech = pWonder.sTechName
		instance.Tech:SetText(sort.tech)
		instance.Tech:SetToolTipString(pWonder.sEraName)

		instance.TechsNeeded:SetHide(false)
		sort.needed = Players[iPlayer]:FindPathLength(GameInfoTypes[pWonder.sTechType], false);

		local bLocked, sReason = IsLocked(pWonder, iPlayer)
	
		if bLocked then
			instance.TechsNeeded:SetText("[ICON_LOCKED]")
			instance.TechsNeeded:SetToolTipString(sReason)
		else
			instance.TechsNeeded:SetText(sort.needed)
			instance.TechsNeeded:SetToolTipString(nil)
		end

		instance.Year:SetHide(true)
		
		instance.Wonder:SetHide(pWonder.iEra > g_EraLimit)
	else
		instance.TechsNeeded:SetHide(true)
		instance.TechIcon:SetToolTipString(pWonder.sPlayer)
    		
		if pWonder.iPlayer == -2 then
			instance.TechIcon:SetHide(IconHookup(5, 45, "KRIS_SWORDSMAN_PROMOTION_ATLAS", instance.TechIcon) == false)
		else
			local pCiv = g_Civs[pWonder.iPlayer]
			
			instance.TechIcon:SetHide(IconHookup(pCiv.PortraitIndex, 45, pCiv.IconAtlas, instance.TechIcon) == false)
		end

		if pWonder.iPlayer ~= GameDefines.MAX_PLAYERS then
			sort.city = pWonder.sPlayer .. ":" .. pWonder.sCity
			instance.Tech:SetText(pWonder.sCity)
			instance.Tech:SetToolTipString(pWonder.sPlayer)
		else
			sort.city = "destroyed:" .. iWonder
			instance.Tech:SetText(sDestroyed)
			instance.Tech:SetToolTipString(sDestroyed)
		end
		
		sort.year = GetPersistentProperty(iWonder)
		instance.Year:SetHide(false)
		TruncateString(instance.Year, 25, sort.year)
		
		instance.Wonder:SetHide(false)
	end

	sort.happy = pWonder.isHappy
	instance.IsHappy:SetHide(sort.happy == 0)
	sort.freeunit = pWonder.isFreeUnit
	instance.IsFreeUnit:SetHide(sort.freeunit == 0)
	sort.defense = pWonder.isDefense
	instance.IsDefense:SetHide(sort.defense == 0)
	sort.offense = pWonder.isOffense
	instance.IsOffense:SetHide(sort.offense == 0)
	sort.expansion = pWonder.isExpansion
	instance.IsExpansion:SetHide(sort.expansion == 0)
	sort.construction = pWonder.isConstruction
	instance.IsConstruction:SetHide(sort.construction == 0)
	sort.goldenage = pWonder.isGoldenAge
	instance.IsGoldenAge:SetHide(sort.goldenage == 0)
	sort.trade = pWonder.isTrade
	instance.IsTrade:SetHide(sort.trade == 0)
	
	local iResult = pWonder.isGreatPeople
	local sGreatPeopleTooltip = pWonder.isGreatPeopleTT
	local iRateChange = pWonder.isGreatPeopleRC or 0
	sort.greatpeople = (iResult * 100) + iRateChange
	instance.IsGreatPeople:SetText(g_GreatPeopleIcons[#g_GreatPeopleIcons + iResult + 1])
	if sGreatPeopleTooltip then
		instance.IsGreatPeople:SetToolTipString(sGreatPeopleTooltip)
	end
	instance.IsGreatPeople:SetHide(sort.greatpeople == 0)
	
	sort.food = pWonder.isFood
	instance.IsFood:SetHide(sort.food == 0)
	sort.gold = pWonder.isGold
	instance.IsGold:SetHide(sort.gold == 0)
	sort.science = pWonder.isScience
	instance.IsScience:SetHide(sort.science == 0)
	sort.culture = pWonder.isCulture
	instance.IsCulture:SetHide(sort.culture == 0)
	sort.faith = pWonder.isFaith
	instance.IsFaith:SetHide(sort.faith == 0)
	sort.espionage = pWonder.isEspionage
	instance.IsEspionage:SetHide(sort.espionage == 0)
	sort.tourism = pWonder.isTourism
	instance.IsTourism:SetHide(sort.tourism == 0)
end

function GetCivs()
	for iPlayer = 0, GameDefines.MAX_MAJOR_CIVS-1, 1 do
		local pPlayer = Players[iPlayer]
		
		if pPlayer:IsEverAlive() then
			local pCiv = GameInfo.Civilizations[pPlayer:GetCivilizationType()]
			
			g_Civs[iPlayer] = {
				IconAtlas     = pCiv.IconAtlas,
				PortraitIndex = pCiv.PortraitIndex
			}
		end
	end

	local pCiv = GameInfo.Civilizations["CIVILIZATION_BARBARIAN"]
  
	g_Civs[GameDefines.MAX_PLAYERS] = {
		IconAtlas     = pCiv.IconAtlas,
		PortraitIndex = pCiv.PortraitIndex
	}
end

function GetWonders(tWonders)
	for potentialWonder in GameInfo.Buildings() do
		if IsWonder(potentialWonder) then
			local iWonder = potentialWonder.ID
			local pWonder = potentialWonder
			local pWonderDummy
			local sWonderDummy = pWonder.Type .. '_DUMMY'

			for row in GameInfo.Buildings{Type=sWonderDummy} do
				pWonderDummy = row
			end

			local sNameWithColor
			local sNameWithoutColor = Locale.ConvertTextKey(pWonder.Description)
			
			-- setting colors to names
			if pWonder.HolyCity then
				sNameWithColor = g_ColorHoly .. sNameWithoutColor .. ' (Holy)[ENDCOLOR]'
			elseif pWonder.PolicyBranchType then
				local sIdeologyName = 'TXT_KEY_' .. pWonder.PolicyBranchType
				sNameWithColor = g_ColorIdeology .. sNameWithoutColor .. ' (' .. Locale.ConvertTextKey(sIdeologyName) .. ')[ENDCOLOR]'
			elseif pWonder.PolicyType then
				local sPolicyName = 'TXT_KEY_' .. string.gsub(string.gsub(pWonder.PolicyType, '_FINISHER', ''), 'POLICY_', 'POLICY_BRANCH_')
				sNameWithColor = g_ColorPolicy .. sNameWithoutColor .. ' (' .. Locale.ConvertTextKey(sPolicyName) .. ')[ENDCOLOR]'
			elseif pWonder.PrereqTech == nil and pWonder.UnlockedByLeague then
				local sProjectName
				
				for row in GameInfo.LeagueProjectRewards{Building=pWonder.Type} do
					sProjectName = row.Description
				end
				
				sNameWithColor = g_ColorCongress .. sNameWithoutColor .. ' (' .. Locale.ConvertTextKey(sProjectName) .. ')[ENDCOLOR]'
			elseif pWonder.PrereqTech == nil and not pWonder.UnlockedByLeague then
				sNameWithColor = g_ColorCorporation .. string.gsub(sNameWithoutColor, 'Headquarters', 'HQ') .. '[ENDCOLOR]'
			else
				sNameWithColor = sNameWithoutColor
			end
			
			local sPrereqTechType
			
			-- setting techs for wonders which do not have ones
			if pWonder.PrereqTech == nil and pWonder.UnlockedByLeague then
				sPrereqTechType = 'TECH_INDUSTRIALIZATION'
			elseif pWonder.PrereqTech == nil and not pWonder.UnlockedByLeague then
				sPrereqTechType = 'TECH_CORPORATIONS'
			else
				sPrereqTechType = pWonder.PrereqTech
			end
			
			-- creating wonder table
			if pWonderDummy ~= nil then
				tWonders[iWonder] = {
					iWonder			= iWonder,
					sType			= pWonder.Type,
					iClass			= GameInfoTypes[pWonder.BuildingClass], 
					sName			= Locale.ConvertTextKey(pWonder.Description),
					sNameWithColor	= sNameWithColor,
					sToolTip		= GetHelpTextForBuilding(iWonder, false, false, false),
					iTech			= CheckTech(pWonder, sPrereqTechType),
					sTechName		= Locale.ConvertTextKey(GameInfo.Technologies[sPrereqTechType].Description),
					sTechType		= sPrereqTechType,
					iEra			= GameInfoTypes[GameInfo.Technologies[sPrereqTechType].Era],
					sEraName		= Locale.ConvertTextKey(GameInfo.Eras[GameInfo.Technologies[sPrereqTechType].Era].Description),
				
					pIconAtlas     = pWonder.IconAtlas,
					pPortraitIndex = pWonder.PortraitIndex,
				
					iBuildingClass	= GameInfoTypes[pWonder.BuildingClass],
					iIdeologyBranch	= pWonder.PolicyBranchType and GameInfoTypes[pWonder.PolicyBranchType],
					sPolicyType		= pWonder.PolicyType,
					bLeagueProject	= pWonder.UnlockedByLeague,
					bHoly			= pWonder.HolyCity,

					isHappy       	= ((IsHappy(pWonder)			or IsHappy(pWonderDummy))			and -1 or 0),
					isFreeUnit    	= ((IsFreeUnit(pWonder)			or IsFreeUnit(pWonderDummy))		and -1 or 0),
					isDefense     	= ((IsDefense(pWonder)			or IsDefense(pWonderDummy))			and -1 or 0),
					isOffense     	= ((IsOffense(pWonder)			or IsOffense(pWonderDummy))			and -1 or 0),
					isExpansion   	= ((IsExpansion(pWonder)		or IsExpansion(pWonderDummy))		and -1 or 0),
					isConstruction  = ((IsConstruction(pWonder)		or IsConstruction(pWonderDummy))	and -1 or 0),
					isGoldenAge  	= ((IsGoldenAge(pWonder)		or IsGoldenAge(pWonderDummy))		and -1 or 0),
					isTrade  		= ((IsTrade(pWonder)			or IsTrade(pWonderDummy))			and -1 or 0),
					isGreatPeople	= ((IsGreatPeople(pWonder)[1]	or IsGreatPeople(pWonderDummy)[1])	or 0),
					isGreatPeopleTT	= (IsGreatPeople(pWonder)[2]	or IsGreatPeople(pWonderDummy)[2]),
					isGreatPeopleRC	= (IsGreatPeople(pWonder)[3]	or IsGreatPeople(pWonderDummy)[3]),
					isFood        	= ((IsFood(pWonder)				or IsFood(pWonderDummy))			and -1 or 0),
					isGold        	= ((IsGold(pWonder)				or IsGold(pWonderDummy))			and -1 or 0),
					isScience     	= ((IsScience(pWonder)			or IsScience(pWonderDummy))			and -1 or 0),
					isCulture     	= ((IsCulture(pWonder)			or IsCulture(pWonderDummy))			and -1 or 0),
					isFaith       	= ((IsFaith(pWonder)			or IsFaith(pWonderDummy))			and -1 or 0),
					isEspionage   	= ((IsEspionage(pWonder)		or IsEspionage(pWonderDummy))		and -1 or 0),
					isTourism     	= ((IsTourism(pWonder)			or IsTourism(pWonderDummy))			and -1 or 0),

					iPlayer = -1
				}
			else
				tWonders[iWonder] = {
					iWonder			= iWonder,
					sType			= pWonder.Type,
					iClass			= GameInfoTypes[pWonder.BuildingClass], 
					sName			= Locale.ConvertTextKey(pWonder.Description),
					sNameWithColor	= sNameWithColor,
					sToolTip		= GetHelpTextForBuilding(iWonder, false, false, false),
					iTech			= CheckTech(pWonder, sPrereqTechType),
					sTechName		= Locale.ConvertTextKey(GameInfo.Technologies[sPrereqTechType].Description),
					sTechType		= sPrereqTechType,
					iEra			= GameInfoTypes[GameInfo.Technologies[sPrereqTechType].Era],
					sEraName		= Locale.ConvertTextKey(GameInfo.Eras[GameInfo.Technologies[sPrereqTechType].Era].Description),
				
					pIconAtlas     = pWonder.IconAtlas,
					pPortraitIndex = pWonder.PortraitIndex,
				
					iBuildingClass	= GameInfoTypes[pWonder.BuildingClass],
					iIdeologyBranch	= pWonder.PolicyBranchType and GameInfoTypes[pWonder.PolicyBranchType],
					sPolicyType		= pWonder.PolicyType,
					bLeagueProject	= pWonder.UnlockedByLeague,
					bHoly			= pWonder.HolyCity,

					-- We use -1 for true and 0 for false as it makes sorting easier
					isHappy       	= (IsHappy(pWonder)	and -1 or 0),
					isFreeUnit    	= (IsFreeUnit(pWonder) and -1 or 0),
					isDefense     	= (IsDefense(pWonder) and -1 or 0),
					isOffense     	= (IsOffense(pWonder) and -1 or 0),
					isExpansion   	= (IsExpansion(pWonder) and -1 or 0),
					isConstruction  = (IsConstruction(pWonder) and -1 or 0),
					isGoldenAge  	= (IsGoldenAge(pWonder) and -1 or 0),
					isTrade  		= (IsTrade(pWonder) and -1 or 0),
					isGreatPeople	= (IsGreatPeople(pWonder)[1] or 0),
					isGreatPeopleTT	= IsGreatPeople(pWonder)[2],
					isGreatPeopleRC	= IsGreatPeople(pWonder)[3],
					isFood        	= (IsFood(pWonder) and -1 or 0),
					isGold        	= (IsGold(pWonder) and -1 or 0),
					isScience     	= (IsScience(pWonder) and -1 or 0),
					isCulture     	= (IsCulture(pWonder) and -1 or 0),
					isFaith       	= (IsFaith(pWonder) and -1 or 0),
					isEspionage   	= (IsEspionage(pWonder) and -1 or 0),
					isTourism     	= (IsTourism(pWonder) and -1 or 0),

					iPlayer = -1
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
			wonder.iPlayer = -1
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
								wonder.iPlayer = playerID
								wonder.sPlayer = sPlayerName
								wonder.iCity = city:GetID()
								wonder.sCity = city:GetName()
							else
								wonder.iPlayer = -2
								wonder.sPlayer = "Unknown"
								wonder.iCity = -2
								wonder.sCity = "Unknown"
							end
						end
					end
				end	
			end
		end
	end

	-- destroyed wonders
	for _, wonder in pairs(tWonders) do
		if wonder.iPlayer == -1 and Game.IsBuildingClassMaxedOut(wonder.iClass) then
			wonder.iPlayer = GameDefines.MAX_PLAYERS
			wonder.sPlayer = sDestroyed
		end
	end

	return tWonders
end


function IsWonder(pBuilding)
	if pBuilding.PrereqTech == nil and pBuilding.UnlockedByLeague == 0 then return false end -- Infixo, adan_eslavo
	
	if GameInfo.BuildingClasses[pBuilding.BuildingClass].MaxGlobalInstances == 1 then
		return true
	end

	return false
end

-- markings
-- adan_eslavo (added local unhappiness)
function IsHappy(pBuilding)
	for row in GameInfo.Building_BuildingClassHappiness{BuildingType=pBuilding.Type} do
		if row.Happiness > 0 then
			return true
		end
	end
	for rowBuilding in GameInfo.Building_ResourceQuantity{BuildingType=pBuilding.Type} do
		if rowBuilding.Quantity > 0 then
			for rowResource in GameInfo.Resources{Type=rowBuilding.ResourceType} do
				if rowResource.ResourceClassType == 'RESOURCECLASS_LUXURY' then
					return true
				end
			end
		end
	end
	for rowBuilding in GameInfo.Building_ResourcePlotsToPlace{BuildingType=pBuilding.Type} do
		if rowBuilding.NumPlots > 0 then
			for rowResource in GameInfo.Resources{Type=rowBuilding.ResourceType} do
				if rowResource.ResourceClassType == 'RESOURCECLASS_LUXURY' then
					return true
				end
			end
		end
	end
	  
	return (pBuilding.Happiness ~= 0 or pBuilding.UnmoddedHappiness ~= 0 or pBuilding.UnhappinessModifier ~= 0 or pBuilding.LocalUnhappinessModifier ~= 0 or pBuilding.WLTKDTurns > 0
		or pBuilding.EmpireNeedsModifier ~= 0 or pBuilding.EmpireNeedsModifierGlobal ~= 0 
		or pBuilding.HappinessPerXPolicies ~= 0 or pBuilding.HappinessPerCity ~= 0 or pBuilding.LocalUnhappinessModifier ~= 0
		or pBuilding.NoUnhappfromXSpecialists ~= 0 or pBuilding.NoUnhappfromXSpecialistsGlobal ~= 0
		or pBuilding.PovertyHappinessChange ~= 0 or pBuilding.DefenseHappinessChange ~= 0 or pBuilding.IlliteracyHappinessChange ~= 0 or pBuilding.UnculturedHappinessChange ~= 0  or pBuilding.MinorityHappinessChange ~= 0
		or pBuilding.PovertyHappinessChangeGlobal ~= 0 or pBuilding.DefenseHappinessChangeGlobal ~= 0 or pBuilding.IlliteracyHappinessChangeGlobal ~= 0 or pBuilding.UnculturedHappinessChangeGlobal ~= 0  or pBuilding.MinorityHappinessChangeGlobal ~= 0)
end
	
--adan_eslavo (added free buildings)
function IsFreeUnit(pBuilding)
	for row in GameInfo.Building_FreeUnits{BuildingType=pBuilding.Type} do
		if (row.NumUnits > 0) then
			return true
		end
	end

	return (pBuilding.FreeBuildingThisCity ~= nil or pBuilding.FreeGreatPeople > 0)
end
	
-- adan_eslavo (added heal rate change)
function IsDefense(pBuilding)
	return (pBuilding.BorderObstacle == true or pBuilding.GlobalDefenseMod ~= 0 or pBuilding.Defense ~= 0 or (pBuilding.ExtraCityHitPoints ~= nil and pBuilding.ExtraCityHitPoints ~= 0) or pBuilding.HealRateChange ~= 0)
end
	
-- adan_eslavo (added supply modifiers and range strike)
function IsOffense(pBuilding)
	return (pBuilding.FreePromotion ~= nil or pBuilding.TrainedFreePromotion ~= nil or IsCombatBonus(pBuilding) or pBuilding.CitySupplyModifier > 0 or pBuilding.CitySupplyModifierGlobal > 0 or pBuilding.CitySupplyFlat > 0 or pBuilding.CitySupplyFlatGlobal > 0 or pBuilding.UnitUpgradeCostMod ~= 0 or pBuilding.AllowsRangeStrike == true)
end
	
-- adan_eslavo (left only expansion)
function IsExpansion(pBuilding)
	for i, unit in pairs(g_Settlers) do
		print(g_Settlers[i])
		for row in GameInfo.Building_FreeUnits{BuildingType=pBuilding.Type, UnitType=g_Settlers[i]} do
			return true
		end
	end
	
	return (pBuilding.GlobalPlotCultureCostModifier ~= 0 or pBuilding.GlobalPlotBuyCostModifier ~= 0 or pBuilding.GlobalPopulationChange ~= 0)
end
	
-- adan_eslavo (created construction marking)
function IsConstruction(pBuilding)
	return (pBuilding.WorkerSpeedModifier ~= 0 or IsYield(pBuilding, "YIELD_PRODUCTION") or pBuilding.FreeBuilding ~= nil or pBuilding.WonderProductionModifier ~= 0 or pBuilding.BuildingProductionModifier ~= 0)
end
	
-- adan_eslavo (deleted culture limit)
function IsCulture(pBuilding)
	return (pBuilding.GlobalCultureRateModifier ~= 0 or pBuilding.CultureRateModifier ~= 0 or pBuilding.FreePolicies ~= 0 or pBuilding.PolicyCostModifier ~= 0 or IsYield(pBuilding, "YIELD_CULTURE"))
end
	
-- adan_eslavo (added holy city value)
function IsFaith(pBuilding)
	return (IsYield(pBuilding, "YIELD_FAITH") or pBuilding.ExtraMissionarySpreads ~= 0 or pBuilding.HolyCity == true or pBuilding.ReligiousPressureModifier == true)
end

function IsFood(pBuilding)
	return (IsYield(pBuilding, "YIELD_FOOD"))
end

-- adan_eslavo (cut trade and golden age)
function IsGold(pBuilding)
	return (pBuilding.GreatPersonExpendGold ~= 0 or IsYield(pBuilding, "YIELD_GOLD") or IsHurry(pBuilding, "HURRY_GOLD") or pBuilding.CityConnectionTradeRouteModifier ~= 0)
end
	
-- adan_eslavo (created golden age marking)
function IsGoldenAge(pBuilding)
	return (pBuilding.GoldenAgeModifier ~= 0 or pBuilding.GoldenAge == true or IsYield(pBuilding, "YIELD_GOLDEN_AGE_POINTS"))
end
	
-- adan_eslavo (created trade marking)
function IsTrade(pBuilding)
	for row in GameInfo.Building_ResourceQuantity{BuildingType=pBuilding.Type} do
		if row.Quantity > 0 then
			return true
		end
	end
	for row in GameInfo.Building_ResourcePlotsToPlace{BuildingType=pBuilding.Type} do
		if row.NumPlots > 0 then
			return true
		end
	end

	return (pBuilding.CityConnectionTradeRouteModifier ~= 0 or pBuilding.TradeRouteRecipientBonus ~= 0 or pBuilding.TradeRouteTargetBonus ~= 0 or pBuilding.NumTradeRouteBonus ~= 0)
end

-- adan_eslavo (added science yields)
function IsScience(pBuilding)
	return (pBuilding.FreeTechs ~= 0 or (pBuilding.GlobalSpaceProductionModifier ~= nil and pBuilding.GlobalSpaceProductionModifier ~= 0) or pBuilding.MedianTechPercentChange ~= 0 or IsYield(pBuilding, "YIELD_SCIENCE"))
end
	
-- adan_eslavo (modified values)
function IsGreatPeople(pBuilding)
	local iResult1, iResult2, iResult3
	local iNumberOfResults = 0
	local iGreatRateChange

	if pBuilding.SpecialistCount > 0 or pBuilding.GreatPeopleRateChange > 0 then
		for i, specialist in ipairs(g_AvailableSpecialists) do
			if pBuilding.SpecialistType == specialist then
				iResult1 = (i - #g_GreatPeopleIcons) -- reverted for sorting order
				iNumberOfResults = iNumberOfResults + 1
				iGreatRateChange = -pBuilding.GreatPeopleRateChange
			end
		end
	end
	
	for unit, unitID in pairs(g_GreatPeopleUnits) do 
		for row in GameInfo.Building_FreeUnits{BuildingType=pBuilding.Type, UnitType=unit} do
			iResult2 = (g_GreatPeopleUnits[unit] - #g_GreatPeopleIcons) -- sometimes two types fit (free great person and specialist are different)
			iNumberOfResults = iNumberOfResults + 1
		end
	end
	
	if pBuilding.FreeGreatPeople > 0 or pBuilding.GreatPeopleRateModifier > 0 or pBuilding.GlobalGreatPeopleRateModifier > 0 then
		iResult3 = (-1)
		iNumberOfResults = iNumberOfResults + 1
	end
	
	local sGreatPeopleTooltip
	
	if iNumberOfResults == 0 then
		return {false, sGreatPeopleTooltip, nil}
	elseif iNumberOfResults == 1 or (iNumberOfResults == 2 and iResult1 == iResult2) then
		return {(iResult1 or iResult2 or iResult3), sGreatPeopleTooltip, iGreatRateChange}
	else
		if iResult1 ~= nil then
			sGreatPeopleTooltip = g_GreatPeopleIcons[#g_GreatPeopleIcons + iResult1 + 1]
			
			if iResult2 ~= nil and iResult1 ~= iResult2 then
				sGreatPeopleTooltip = sGreatPeopleTooltip .. ',' .. g_GreatPeopleIcons[#g_GreatPeopleIcons + iResult2 + 1]
			end
			if iResult3 ~= nil then
				sGreatPeopleTooltip = sGreatPeopleTooltip .. ',[ICON_GREAT_PEOPLE]'
			end
		else
			sGreatPeopleTooltip = g_GreatPeopleIcons[#g_GreatPeopleIcons + iResult2 + 1] .. ',[ICON_GREAT_PEOPLE]'
		end

		return {-#g_GreatPeopleIcons, sGreatPeopleTooltip, iGreatRateChange}
	end
end
	
-- adan_eslavo (added many new possible outcomes)
function IsEspionage(pBuilding)
	local bVotes = pBuilding.VotesPerGPT > 0 or pBuilding.FaithToVotes > 0 or pBuilding.CapitalsToVotes > 0 or pBuilding.DoFToVotes > 0 or pBuilding.RAToVotes > 0 or pBuilding.ExtraLeagueVotes > 0
	local bAdvancedActions = (pBuilding.AdvancedActionGold > 0 or pBuilding.AdvancedActionScience > 0 or pBuilding.AdvancedActionUnrest > 0 or pBuilding.AdvancedActionRebellion > 0 or pBuilding.AdvancedActionGP > 0 or pBuilding.AdvancedActionUnit > 0 or pBuilding.AdvancedActionWonder > 0 or pBuilding.AdvancedActionBuilding > 0)
	local bBlockingActions = (pBuilding.BlockBuildingDestructionSpies > 0 or pBuilding.BlockWWDestructionSpies > 0 or pBuilding.BlockUDestructionSpies > 0 or pBuilding.BlockGPDestructionSpies > 0 or pBuilding.BlockRebellionSpies > 0 or pBuilding.BlockUnrestSpies > 0 or pBuilding.BlockScienceTheft > 0 or pBuilding.BlockGoldTheft > 0)

	return ((pBuilding.Espionage == true or pBuilding.AffectSpiesNow == true or pBuilding.SpyRankChange == true or pBuilding.InstantSpyRankChange == true) or bAdvancedActions or bBlockingActions or bVotes)
end
	
-- adan_eslavo (added tourism yields)
function IsTourism(pBuilding)
	return (pBuilding.GreatWorkCount ~= 0 or pBuilding.TechEnhancedTourism ~= 0 or IsYield(pBuilding, "YIELD_TOURISM"))
end


-- adan_eslavo (simplified - no limits now, many new tables)
-- yield calculator
function IsYield(pBuilding, sYieldType)
	for row in GameInfo.Building_YieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldChangesPerPop{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldChangesPerPopInEmpire{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldChangesPerReligion{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldFromBirth{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldFromBorderGrowth{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldFromConstruction{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldFromDeath{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldFromGPExpend{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldFromFaithPurchase{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldFromInternalTR{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldFromInternalTREnd{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldFromPillage{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldFromPillageGlobal{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldFromPillageGlobalPlayer{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldFromPolicyUnlock{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldFromProcessModifier{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldFromPurchase{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldFromSpyAttack{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldFromSpyDefense{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldFromTech{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldFromUnitLevelUp{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldFromUnitProduction{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldFromVictory{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldFromVictoryGlobal{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldFromVictoryGlobalPlayer{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldFromYieldPercent{BuildingType=pBuilding.Type, YieldOut=sYieldType} do
		if (row.Value > 0) then return true end
	end	
	for row in GameInfo.Building_YieldModifiers{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end	  
	for row in GameInfo.Building_YieldPerAlly{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end	  
	for row in GameInfo.Building_YieldPerFranchise{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end	
	for row in GameInfo.Building_YieldPerFriend{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_YieldPerXFeatureTimes100{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end	
	for row in GameInfo.Building_YieldPerXTerrainTimes100{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end	
	for row in GameInfo.Building_InstantYield{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_GlobalYieldModifiers{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_GoldenAgeYieldMod{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	

	for row in GameInfo.Building_BuildingClassLocalYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.YieldChange > 0) then return true end
	end	
	for row in GameInfo.Building_BuildingClassYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.YieldChange > 0) then return true end
	end
	for row in GameInfo.Building_BuildingClassYieldModifiers{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Modifier > 0) then return true end
	end


	if sYieldType == 'YIELD_PRODUCTION' then
		for row in GameInfo.Building_DomainProductionModifiers{BuildingType=pBuilding.Type} do
			if (row.Modifier > 0) then return true end
		end
	end
	

	for row in GameInfo.Building_GreatWorkYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_GreatWorkYieldChangesLocal{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_ThemingYieldBonus{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end


	for row in GameInfo.Building_GrowthExtraYield{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	

	for row in GameInfo.Building_ImprovementYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_ImprovementYieldChangesGlobal{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_LakePlotYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_PlotYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_ResourceYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_ResourceYieldChangesGlobal{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_ResourceYieldModifiers{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_RiverPlotYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_SeaPlotYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_TerrainYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_FeatureYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end


	for row in GameInfo.Building_SpecialistYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	for row in GameInfo.Building_SpecialistYieldChangesLocal{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
	

	for row in GameInfo.Building_TechEnhancedYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end


	for row in GameInfo.Building_WLTKDYieldMod{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	end
 
	return false
end

function IsHurry(pBuilding, sHurryType)
	for row in GameInfo.Building_HurryModifiers{BuildingType=pBuilding.Type, HurryType=sHurryType} do
		if (row.HurryCostModifier < 0) then return true end
	end
	for row in GameInfo.Building_HurryModifiersLocal{BuildingType=pBuilding.Type, HurryType=sHurryType} do
		if (row.HurryCostModifier < 0) then return true end
	end

	return false
end

function IsCombatBonus(pBuilding)
	for row in GameInfo.Building_UnitCombatProductionModifiers{BuildingType=pBuilding.Type} do
		if (row.Modifier > 0) then return true end
	end
	for row in GameInfo.Building_UnitCombatFreeExperiences{BuildingType=pBuilding.Type} do
		if (row.Experience > 0) then return true end
	end
	for row in GameInfo.Building_DomainProductionModifiers{BuildingType=pBuilding.Type} do
		if (row.Experience > 0) then return true end
	end

	return false
end
-- end of markings

function IsLocked(pWonder, iPlayer)
	local bLocked = false
	local sReason = nil
	local pPlayer = Players[iPlayer]
	local iIdeologyBranch = pWonder.iIdeologyBranch
	local sPolicyType = pWonder.sPolicyType
	local bHoly = pWonder.bHoly

	if Game.GetBuildingClassCreatedCount(pWonder.iBuildingClass) > 0 then
		bLocked = true
		sReason = Locale.ConvertTextKey("TXT_KEY_WONDERPLANNER_LOCKED_DESTROYED")
	elseif bHoly then
		local bFoundHolyCity = false

		for city in pPlayer:Cities() do
			if city:IsHolyCityAnyReligion() then
				bFoundHolyCity = true
				break
			end
		end

		if not bFoundHolyCity then
			bLocked = true
			sReason = Locale.ConvertTextKey("TXT_KEY_WONDERPLANNER_LOCKED_MISSING_RELIGION", g_ColorHoly)
		end
	elseif iIdeologyBranch then
		if not pPlayer:IsPolicyBranchUnlocked(iIdeologyBranch) then
			bLocked = true
			sReason = Locale.ConvertTextKey("TXT_KEY_WONDERPLANNER_LOCKED_MISSING_IDEOLOGY", g_ColorIdeology, Locale.ConvertTextKey(GameInfo.PolicyBranchTypes[iIdeologyBranch].Description))
		end
	elseif sPolicyType then
		local iPolicyBranch, sPolicyBranchName
		
		for row in GameInfo.PolicyBranchTypes{FreeFinishingPolicy=sPolicyType} do
			iPolicyBranch = row.ID
			sPolicyBranchName = row.Description
		end
		
		if not pPlayer:IsPolicyBranchFinished(iPolicyBranch) then
			bLocked = true
			sReason = Locale.ConvertTextKey("TXT_KEY_WONDERPLANNER_LOCKED_MISSING_POLICY", g_ColorPolicy, Locale.ConvertTextKey(sPolicyBranchName))
		end
	elseif pWonder.bLeagueProject then
		local sProjectName
		
		for row in GameInfo.LeagueProjectRewards{Building=pWonder.sType} do
			sProjectName = row.Description
		end

		bLocked = true
		sReason = Locale.ConvertTextKey("TXT_KEY_WONDERPLANNER_LOCKED_MISSING_WORLD_PROJECT", g_ColorCongress, Locale.ConvertTextKey(sProjectName))
	end
	
	return bLocked, sReason
end

function CheckTech(pBuilding, sPrereqTechType)
	local iMaxStartEra = (pBuilding.MaxStartEra == nil) and #GameInfo.Eras or GameInfoTypes[pBuilding.MaxStartEra]
	
	return ((PreGame.GetEra() > iMaxStartEra) and -1 or GameInfoTypes[sPrereqTechType])
end

function GetTechs(iPlayer)
	local techs = {}
	local pTeam = Teams[Players[iPlayer]:GetTeam()]

	for pTech in GameInfo.Technologies() do
		if (pTeam:IsHasTech(pTech.ID)) then
			techs[pTech.ID] = 1
			techs[pTech.Type] = 1
		end
	end

	return techs
end

function OnEraSelected(iEra)
	if (g_EraLimit ~= iEra) then
		g_EraLimit = iEra

		Controls.EraMenu:GetButton():LocalizeAndSetText(GameInfo.Eras[g_EraLimit].Description)

		for iWonder, wonder in pairs(g_Wonders) do
			if (wonder.iPlayer == -1) then
				wonder.instance.Wonder:SetHide(wonder.iEra > g_EraLimit)
			end
		end

		Controls.PlannerStack:CalculateSize()
		Controls.PlannerScrollPanel:CalculateInternalSize()
	end
end

function UpdateEraList(iPlayer)
	local pPlayer = Players[iPlayer]
	local iTeam = pPlayer:GetTeam()

	Controls.EraMenu:ClearEntries()

	for iEra = pPlayer:GetCurrentEra(), #GameInfo.Eras-1, 1 do
		local pEra = GameInfo.Eras[iEra]
   		local era = {}
		
		Controls.EraMenu:BuildEntry("InstanceOne", era)
	
		era.Button:SetVoid1(iEra)
		era.Button:SetText(Locale.ConvertTextKey(pEra.Description))
	end

	Controls.EraMenu:GetButton():LocalizeAndSetText(GameInfo.Eras[g_EraLimit].Description)

	Controls.EraMenu:CalculateInternals()
	Controls.EraMenu:RegisterSelectionCallback(OnEraSelected)
end

function OnWonderConstruction(ePlayer, eCity, eBuilding, bGold, bFaith)
	for building in GameInfo.Buildings(ID=eBuilding) do
		SetPersistentProperty(ID, Game.GetGameTurnYear());
		break
	end
end
GameEvents.CityConstructed.Add(OnWonderConstruction)

function OnClose()
	ContextPtr:SetHide(true)
end
Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose)

function InputHandler(uiMsg, wParam, lParam)
	if (uiMsg == KeyEvents.KeyDown) then
		if (wParam == Keys.VK_ESCAPE) then
			OnClose()
			return true
		end
	end
end
ContextPtr:SetInputHandler(InputHandler)

function OnWondersUpdate()
	if (not ContextPtr:IsHidden()) then
		local iPlayer = Game.GetActivePlayer()

		if (g_EraLimit == -1) then
			g_EraLimit = math.min(#GameInfo.Eras-1, Players[iPlayer]:GetCurrentEra()+2)
		end

		UpdateEraList(iPlayer)
		UpdateData(iPlayer)
	end
end
LuaEvents.WonderPlannerDisplay.Add(function() ContextPtr:SetHide(false) end)

function ShowHideHandler(bIsHide, bInitState)
	if (not bInitState and not bIsHide) then
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
	table.insert(additionalEntries, {text=Locale.ConvertTextKey("TXT_KEY_WONDERPLANNER_DIPLO_CORNER_HOOK"), call=OnDiploCornerPopup, art="WonderPlannerLogo.dds"})
end
LuaEvents.AdditionalInformationDropdownGatherEntries.Add(OnAdditionalInformationDropdownGatherEntries)
LuaEvents.RequestRefreshAdditionalInformationDropdownEntries()

print("Loaded WonderPlanner.lua from Wonder Planner")
