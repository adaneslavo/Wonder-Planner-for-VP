print("This is the 'UI - Wonder Planner' mod script.")

include("IconSupport")
include("InstanceManager")
include("InfoTooltipInclude")

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


function OnSort(sort)
  if (sort == g_ActiveSort) then
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

  if (entryA == nil or entryB == nil) then
    return tostring(a) < tostring(b)
  end

  local valueA = entryA[g_ActiveSort]
  local valueB = entryB[g_ActiveSort]

  if (g_ReverseSort) then
    valueA = entryB[g_ActiveSort]
    valueB = entryA[g_ActiveSort]
  end

  if (valueA == valueB) then
    if (entryA.needed ~= nil) then
      valueA = entryA.needed
      valueB = entryB.needed
    else
      valueA = entryA.name
      valueB = entryB.name
    end
  end

  if (valueA == nil or valueB == nil) then
    return tostring(a) < tostring(b)
  end

  return valueA < valueB
end

function UpdateData(iPlayer)
  local pPlayer = Players[iPlayer]
  CivIconHookup(iPlayer, 64, Controls.Icon, Controls.CivIconBG, Controls.CivIconShadow, false, true)

  local playerTechs = GetTechs(iPlayer)
  
  g_PlannerIM:ResetInstances()
  g_BuiltIM:ResetInstances()
  g_SortTable = {}

  for iWonder, wonder in pairs(UpdateWonders(g_Wonders)) do
    if (wonder.iTech ~= -1) then
      AddWonder(iPlayer, playerTechs, iWonder, wonder)
    end
  end

  Controls.PlannerStack:SortChildren(SortByValue)
  Controls.PlannerStack:CalculateSize()
  Controls.PlannerScrollPanel:CalculateInternalSize()

  Controls.BuiltStack:SortChildren(SortByValue)
  Controls.BuiltStack:CalculateSize()
  Controls.BuiltScrollPanel:CalculateInternalSize()
end

function AddWonder(iPlayer, playerTechs, iWonder, wonder)
  local instance = (wonder.iPlayer == -1) and g_PlannerIM:GetInstance() or g_BuiltIM:GetInstance()
  wonder.instance = instance

  local sort = {}
  g_SortTable[tostring(instance.Wonder)] = sort

  local pWonder = g_Wonders[iWonder]

  if (IconHookup(pWonder.PortraitIndex, 45, pWonder.IconAtlas, instance.Icon)) then
    instance.Icon:SetHide(false)
    instance.Icon:SetToolTipString(wonder.sName)
  else
    instance.Icon:SetHide(true)
  end

  sort.name = wonder.sName
  instance.Name:SetText(sort.name)
  instance.Name:SetToolTipString(wonder.sToolTip)

  if (wonder.iPlayer == -1) then
    instance.TechsNeeded:SetHide(false)

	local pTech = GameInfo.Technologies[pWonder.PrereqTech]
    if (IconHookup(pTech.PortraitIndex, 45, pTech.IconAtlas, instance.TechIcon)) then
      instance.TechIcon:SetHide(false)
      instance.TechIcon:SetToolTipString(wonder.sTech)
    else
      instance.TechIcon:SetHide(true)
    end

    sort.tech = wonder.sTech
    instance.Tech:SetText(sort.tech)
    instance.Tech:SetToolTipString(wonder.sEra)

    --sort.needed = GetNeededTechs(playerTechs, pWonder)
	sort.needed = Players[iPlayer]:FindPathLength(GameInfoTypes[pWonder.PrereqTech], false);

	local bLocked, sReason = IsLocked(pWonder, iPlayer)
	if (bLocked) then
      instance.TechsNeeded:SetText("[ICON_LOCKED]")
      instance.TechsNeeded:SetToolTipString(sReason)
	else
      instance.TechsNeeded:SetText(sort.needed)
      instance.TechsNeeded:SetToolTipString(nil)
	end

    instance.Wonder:SetHide(wonder.iEra > g_EraLimit)
  else
    instance.TechsNeeded:SetHide(true)
	instance.TechIcon:SetToolTipString(wonder.sPlayer)
    
	  -- adan_eslavo (hid unknown civilization's cities)
	  if wonder.iPlayer == -2 then
	    instance.TechIcon:SetHide(IconHookup(5, 45, "KRIS_SWORDSMAN_PROMOTION_ATLAS", instance.TechIcon) == false)
	  else
	    local pCiv = g_Civs[wonder.iPlayer]
		instance.TechIcon:SetHide(IconHookup(pCiv.PortraitIndex, 45, pCiv.IconAtlas, instance.TechIcon) == false)
	  end

	if (wonder.iPlayer ~= GameDefines.MAX_PLAYERS) then
      sort.city = wonder.sPlayer .. ":" .. wonder.sCity
      instance.Tech:SetText(wonder.sCity)
      instance.Tech:SetToolTipString(wonder.sPlayer)
	else
	  -- The barbarians have it (ie it's been destroyed)
      sort.city = "destroyed:" .. iWonder
      instance.Tech:SetText(sDestroyed)
      instance.Tech:SetToolTipString(sDestroyed)
	end

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
  sort.construction = pWonder.isConstruction -- adan_eslavo (added new construction marking)
  instance.IsConstruction:SetHide(sort.construction == 0) -- adan_eslavo (added new construction marking)
  sort.goldenage = pWonder.isGoldenAge -- adan_eslavo (added new ga marking)
  instance.IsGoldenAge:SetHide(sort.goldenage == 0) -- adan_eslavo (added new ga marking)
  sort.trade = pWonder.isTrade -- adan_eslavo (added new trade marking)
  instance.IsTrade:SetHide(sort.trade == 0) -- adan_eslavo (added new trade marking)
  sort.greatpeople = pWonder.isGreatPeople
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
	if (pPlayer:IsEverAlive()) then
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

function GetWonders(wonders)
  --dprint("FUNSTA GetWonders()");
  --local time_function = os.clock();
  for pWonder in GameInfo.Buildings() do
    --dprint("...checking", pWonder.ID, pWonder.Type);
    if (IsWonder(pWonder)) then
	  --dprint("   ...is WONDER");
	  --local time_wonder = os.clock();
      local iWonder = pWonder.ID
	  --[[
	  local function dshow(isflag,flag) dprint(flag,isflag(pWonder)); end
	  	dshow(IsHappy,"hap");
		dshow(IsFreeUnit,"unit");
		dshow(IsDefense,"def");
		dshow(IsOffense,"off");
		dshow(IsExpansion,"exp");
		dshow(IsGreatPeople,"gp");
		dshow(IsFood,"fd");
		dshow(IsGold,"go");
		dshow(IsScience,"sc");
		dshow(IsCulture,"cu");
		dshow(IsFaith,"fa");
		dshow(IsEspionage,"spy");
		dshow(IsTourism,"tour");
	  --]]
      wonders[iWonder] = {
        iWonder  = iWonder, 
        iClass   = GameInfoTypes[pWonder.BuildingClass], 
        sName    = Locale.ConvertTextKey(pWonder.Description),
        sToolTip = GetHelpTextForBuilding(iWonder, true, false, true),
        iTech    = GetTech(pWonder), 
        sTech    = Locale.ConvertTextKey(GameInfo.Technologies[pWonder.PrereqTech].Description),
        iEra     = GameInfoTypes[GameInfo.Technologies[pWonder.PrereqTech].Era],
        sEra     = Locale.ConvertTextKey(GameInfo.Eras[GameInfo.Technologies[pWonder.PrereqTech].Era].Description),
		--prereqTechs = GetPrereqTechs(pWonder.PrereqTech),

		IconAtlas     = pWonder.IconAtlas,
		PortraitIndex = pWonder.PortraitIndex,
		PrereqTech    = pWonder.PrereqTech,

	    BuildingClass = GameInfoTypes[pWonder.BuildingClass],
        PolicyBranch  = pWonder.PolicyBranchType and GameInfoTypes[pWonder.PolicyBranchType],

        -- We use -1 for true and 0 for false as it makes sorting easier
		isHappy       	= (IsHappy(pWonder) and -1 or 0),
		isFreeUnit    	= (IsFreeUnit(pWonder) and -1 or 0),
		isDefense     	= (IsDefense(pWonder) and -1 or 0),
		isOffense     	= (IsOffense(pWonder) and -1 or 0),
		isExpansion   	= (IsExpansion(pWonder) and -1 or 0),
		isConstruction  = (IsConstruction(pWonder) and -1 or 0), -- adan_eslavo (added new construction marking)
		isGoldenAge  	= (IsGoldenAge(pWonder) and -1 or 0), -- adan_eslavo (added new ga marking)
		isTrade  		= (IsTrade(pWonder) and -1 or 0), -- adan_eslavo (added new trade marking)
		isGreatPeople 	= (IsGreatPeople(pWonder) and -1 or 0), -- adan_eslavo (fixed typo)
		isFood        	= (IsFood(pWonder) and -1 or 0),
		isGold        	= (IsGold(pWonder) and -1 or 0),
		isScience     	= (IsScience(pWonder) and -1 or 0),
		isCulture     	= (IsCulture(pWonder) and -1 or 0),
		isFaith       	= (IsFaith(pWonder) and -1 or 0),
		isEspionage   	= (IsEspionage(pWonder) and -1 or 0),
		isTourism     	= (IsTourism(pWonder) and -1 or 0),

		iPlayer = -1
      }
	  --dprint("  Wonder time (id,type,time)", pWonder.ID, pWonder.Type, string.format("%d", (os.clock()-time_wonder)*1000));
    end
  end
  --dprint("FUNEND GetWonders() (time)", (os.clock()-time_function)*1000)
end

function UpdateWonders(wonders)
  print("UpdateWonders() enter")
  if (wonders.init == false) then
    wonders.init = nil
    GetWonders(wonders)
  else
    for iWonder, wonder in pairs(wonders) do
      wonder.iPlayer = -1
    end
  end

  for iPlayer = 0, GameDefines.MAX_MAJOR_CIVS-1, 1 do
    local pPlayer = Players[iPlayer]

    if (pPlayer:IsAlive()) then
      local sPlayer = pPlayer:GetName()

		--adan_eslavo (code checking if players have met already, 1st part of hiding icons and names for unmet civs)
		local iTeam = pPlayer:GetTeam()
		local pTeam = Teams[iTeam]
		local bPlayerMet = false

		if iPlayer == Game.GetActivePlayer() then
			bPlayerMet = true -- active player
		elseif not pTeam:IsHasMet(Game.GetActiveTeam()) then
			bPlayerMet = false -- haven't yet met this player
		else
			bPlayerMet = true -- met players
		end 
	  
	  
	  
	  for pCity in pPlayer:Cities() do
		if (pCity:GetNumWorldWonders() > 0) then
		  for iWonder, wonder in pairs(wonders) do
			if (pCity:IsHasBuilding(iWonder)) then
			    --adan_eslavo (unmet players are marked with -2 marker, name set to "unknown")
			    if bPlayerMet then
				  wonder.iPlayer = iPlayer
				  wonder.sPlayer = sPlayer
				  wonder.iCity = pCity:GetID()
				  wonder.sCity = pCity:GetName()
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

  for iWonder, wonder in pairs(wonders) do
    if (wonder.iPlayer == -1 and Game.IsBuildingClassMaxedOut(wonder.iClass)) then
      -- The wonder has been destroyed, give it to the barbarians!
      wonder.iPlayer = GameDefines.MAX_PLAYERS
	  wonder.sPlayer = sDestroyed
	end
  end

  print("UpdateWonders() exit")
  return wonders
end


function IsWonder(pBuilding)
  if pBuilding.PrereqTech == nil then return false; end -- Infixo
  if (GameInfo.BuildingClasses[pBuilding.BuildingClass].MaxGlobalInstances == 1) then
    for row in GameInfo.LeagueProjectRewards{Building=pBuilding.Type} do
      return false
	end

    return true
  end

  return false
end

-- markings
	--adan_eslavo (added local unhappiness)
	function IsHappy(pBuilding)
	  for row in GameInfo.Building_BuildingClassHappiness{BuildingType=pBuilding.Type} do
		if (row.Happiness > 0) then
		  return true
		end
	  end
	  
	  return (pBuilding.Happiness ~= 0 or pBuilding.UnmoddedHappiness ~= 0 or pBuilding.UnhappinessModifier ~= 0 or pBuilding.HappinessPerXPolicies ~= 0 or pBuilding.HappinessPerCity ~= 0 or pBuilding.LocalUnhappinessModifier ~= 0)
	end
	
	--adan_eslavo (added free buildings)
	function IsFreeUnit(pBuilding)
	  for row in GameInfo.Building_FreeUnits{BuildingType=pBuilding.Type} do
		if (row.NumUnits > 0) then
		  return true
		end
	  end

	  return (pBuilding.FreeBuildingThisCity ~= nil)
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
	  return (IsYield(pBuilding, "YIELD_FAITH") or pBuilding.ExtraMissionarySpreads ~= 0 or pBuilding.HolyCity == true)
	end

function IsFood(pBuilding)
  return (IsYield(pBuilding, "YIELD_FOOD"))
end

	-- adan_eslavo (cut trade and golden age)
	function IsGold(pBuilding)
	  return (pBuilding.GreatPersonExpendGold ~= 0 or IsYield(pBuilding, "YIELD_GOLD") or IsHurry(pBuilding, "HURRY_GOLD", -5))
	end
	
	-- adan_eslavo (created golden age marking)
	function IsGoldenAge(pBuilding)
	  return (pBuilding.GoldenAgeModifier ~= 0 or pBuilding.GoldenAge == true or IsYield(pBuilding, "YIELD_GOLDEN_AGE"))
	end
	
	-- adan_eslavo (created trade marking)
	function IsTrade(pBuilding)
	  return (pBuilding.CityConnectionTradeRouteModifier ~= 0 or pBuilding.TradeRouteRecipientBonus ~= 0 or pBuilding.TradeRouteTargetBonus ~= 0 or pBuilding.NumTradeRouteBonus ~= 0)
	end

	-- adan_eslavo (added science yields)
	function IsScience(pBuilding)
	  return (pBuilding.FreeTechs ~= 0 or (pBuilding.GlobalSpaceProductionModifier ~= nil and pBuilding.GlobalSpaceProductionModifier ~= 0) or pBuilding.MedianTechPercentChange ~= 0 or IsYield(pBuilding, "YIELD_SCIENCE"))
	end
	
	-- adan_eslavo (modified values)
	function IsGreatPeople(pBuilding)
	  return (pBuilding.FreeGreatPeople > 0 or pBuilding.GlobalGreatPeopleRateModifier > 0 or pBuilding.GreatPeopleRateChange > 0)
	end
	
	-- adan_eslavo (added many new possible outcomes)
	function IsEspionage(pBuilding)
	  local bAdvancedActions = (pBuilding.AdvancedActionGold > 0 or pBuilding.AdvancedActionScience > 0 or pBuilding.AdvancedActionUnrest > 0 or pBuilding.AdvancedActionRebellion > 0 or pBuilding.AdvancedActionGP > 0 or pBuilding.AdvancedActionUnit > 0 or pBuilding.AdvancedActionWonder > 0 or pBuilding.AdvancedActionBuilding > 0)
	  local bBlockingActions = (pBuilding.BlockBuildingDestructionSpies > 0 or pBuilding.BlockWWDestructionSpies > 0 or pBuilding.BlockUDestructionSpies > 0 or pBuilding.BlockGPDestructionSpies > 0 or pBuilding.BlockRebellionSpies > 0 or pBuilding.BlockUnrestSpies > 0 or pBuilding.BlockScienceTheft > 0 or pBuilding.BlockGoldTheft > 0)

	  return ((pBuilding.Espionage == true or pBuilding.AffectSpiesNow == true or pBuilding.SpyRankChange == true or pBuilding.InstantSpyRankChange == true) or bAdvancedActions or bBlockingActions)
	end
	
	-- adan_eslavo (added tourism yields)
	function IsTourism(pBuilding)
	  return (pBuilding.GreatWorkCount ~= 0 or pBuilding.TechEnhancedTourism ~= 0 or IsYield(pBuilding, "YIELD_TOURISM"))
	end


	-- adan_eslavo (simplified - no limits now)
	-- yield calculator
	function IsYield(pBuilding, sYieldType)
	  --dprint("FUN IsYield()",pBuilding.Type,sYieldType);
	  for row in GameInfo.Building_YieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	  end

	  -- adan_eslavo (added yields per pop)
		  for row in GameInfo.Building_YieldChangesPerPop{BuildingType=pBuilding.Type, YieldType=sYieldType} do
			if (row.Yield > 0) then return true end
		  end

	  for row in GameInfo.Building_BuildingClassYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.YieldChange > 0) then return true end
	  end

	  for row in GameInfo.Building_YieldModifiers{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	  end
	  
	  for row in GameInfo.Building_GlobalYieldModifiers{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	  end

	  for row in GameInfo.Building_TechEnhancedYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	  end

	  for row in GameInfo.Building_SpecialistYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
		if (row.Yield > 0) then return true end
	  end
	  
	  -- adan_eslavo (added resource, terrain and feature yields)
		  for row in GameInfo.Building_ResourceYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
			if (row.Yield > 0) then return true end
		  end
		  
		  for row in GameInfo.Building_TerrainYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
			if (row.Yield > 0) then return true end
		  end
		  
		  for row in GameInfo.Building_FeatureYieldChanges{BuildingType=pBuilding.Type, YieldType=sYieldType} do
			if (row.Yield > 0) then return true end
		  end
		  
	  --dprint("FUN IsYield() NO YIELD");
	  return false
	end

function IsHurry(pBuilding, sHurryType, iLimitPercent)
  --dprint("FUN IsHurry()", pBuilding.Type, sHurryType, iLimitPercent);
  --iLimit = iLimit or -5

  for row in GameInfo.Building_HurryModifiers{BuildingType=pBuilding.Type, HurryType=sHurryType} do
    if (row.HurryCostModifier <= iLimitPercent) then return true end
  end

  return false
end

function IsCombatBonus(pBuilding, iLimit)
  iLimit = iLimit or 0

  for row in GameInfo.Building_UnitCombatProductionModifiers{BuildingType=pBuilding.Type} do
    if (row.Modifier > iLimit) then return true end
  end

  for row in GameInfo.Building_UnitCombatFreeExperiences{BuildingType=pBuilding.Type} do
    if (row.Experience > iLimit) then return true end
  end

  return false
end

function IsLocked(pBuilding, iPlayer)
  local bLocked = false
  local sReason = nil

  if (Game.GetBuildingClassCreatedCount(pBuilding.BuildingClass) > 0) then
    bLocked = true
    sReason = Locale.ConvertTextKey("TXT_KEY_WONDERPLANNER_LOCKED_DESTROYED")
  else
    if (pBuilding.PolicyBranch) then
      if (not Players[iPlayer]:IsPolicyBranchUnlocked(pBuilding.PolicyBranch)) then
        bLocked = true
        sReason = Locale.ConvertTextKey("TXT_KEY_WONDERPLANNER_LOCKED_MISSING_POLICY", GameInfo.PolicyBranchTypes[pBuilding.PolicyBranch].Description)
	  end
	end
  end

  return bLocked, sReason
end


function GetTech(pBuilding)
  local iMaxStartEra = (pBuilding.MaxStartEra == nil) and #GameInfo.Eras or GameInfoTypes[pBuilding.MaxStartEra]

  return (PreGame.GetEra() > iMaxStartEra) and -1 or GameInfoTypes[pBuilding.PrereqTech]
end


function CountPrereqTechsNOTWORKING()
	dprint("FUNSTA CountPrereqTechs()");
	local time_start = os.clock();
	-- init
	local tTechStatus = {};
	local tTechStatusLater = {};
	local iNumTechs = 0;
	for tech in GameInfo.Technologies() do
		tNumPrereqTechs[tech.Type] = 0;
		tTechStatus[tech.Type] = false; -- 0 - do not process, 1 - to be analyzed next
		tTechStatusLater[tech.Type] = false; -- 0 - do not process, 1 - to be analyzed later
		iNumTechs = iNumTechs + 1;
	end
	dprint("There are (n) techs total", iNumTechs);
	tTechStatusLater.TECH_AGRICULTURE = true; -- just to make it easier, won't work if somebody will mess up tech tree
	
	--local function GetTechToBeAnalyzed()
		--for tech,status in pairs(tTechStatus) do
			--if status == 1 then return tech; end
		--end
		--return nil;
	--end
	local function IsTechToBeAnalyzedLater()
		for tech,status in pairs(tTechStatusLater) do
			if status then return true; end
		end
		return false;
	end
	
	while IsTechToBeAnalyzedLater() do
		-- there are still some techs to analyze! move them to immediate analysis
		for tech,status in pairs(tTechStatusLater) do tTechStatus[tech] = status; end -- activate next wave
		for tech,_      in pairs(tTechStatusLater) do tTechStatusLater[tech] = false; end -- reset next wave
		-- ok, now analyze 
		--local sTechTBA = GetTechToBeAnalyzed();
		for tech,status in pairs(tTechStatus) do 
			if status then 
				-- we're analyzing tech
				dprint("...analyzing", tech);
				for row in GameInfo.Technology_PrereqTechs() do
					if row.PrereqTech == tech then
						-- each will be analyzed only once, so no additional checks are required
						dprint("   ...precedes (tech,num)", row.TechType, tNumPrereqTechs[row.TechType]);
						tNumPrereqTechs[row.TechType] = tNumPrereqTechs[row.TechType] + 1;
						tTechStatusLater[row.TechType] = true; -- mark this one for later analysis
					end
				end -- all prereqs
			end -- if status 
		end -- for now
	end -- while later
	for tech in GameInfo.Technologies() do dprint("Tech (name) has (num) prereqTechs", tech.Type, tNumPrereqTechs[tech.Type]); end
	dprint("FUNEND CountPrereqTechs() (msec)", string.format("%d", (os.clock()-time_start)*1000));
end

function GetPrereqTechs(sTech, techs)
  if (techs == nil) then
    techs = {}
	techs[sTech] = 1

	GetPrereqTechs(sTech, techs)
  else
    for row in GameInfo.Technology_PrereqTechs{TechType=sTech} do
      techs[row.PrereqTech] = 1

      GetPrereqTechs(row.PrereqTech, techs)
    end
  end
  
  return techs
end

function GetPrereqTechsNew(sTech, techs)
	if techs == nil then
		--dprint("First call for (tech)", sTech);
		techs = {};
		techs[sTech] = 1;
		GetPrereqTechsNew(sTech, techs);
	else
		--dprint("Analyzing (tech)", sTech);
		for row in GameInfo.Technology_PrereqTechs() do
			if row.TechType == sTech then
				--dprint("..found prereq (name)", row.PrereqTech);
				techs[row.PrereqTech] = 1;
				GetPrereqTechsNew(row.PrereqTech, techs);
			end
		end
	end
	return techs;
end

local tNumPrereqTechs = {}; -- each entry shows how many techs are before that one
local tTechAnalyzed = {}; -- true/false

function GetPrereqTechsNewNOTWORKING(sTech)
	if tTechAnalyzed[sTech] then return tNumPrereqTechs[sTech]; end
	dprint("Analyzing (tech) (0)", sTech, tNumPrereqTechs[sTech]);
	-- sum all prereqs
	local iNumPrereqs = 0;
    for row in GameInfo.Technology_PrereqTechs{TechType=sTech} do
		dprint("...now (num), adding (prereq)", iNumPrereqs, row.PrereqTech);
		iNumPrereqs = iNumPrereqs + GetPrereqTechsNew(row.PrereqTech);
	end
	-- store results
	dprint("...(tech) has (num) prereqs", sTech, iNumPrereqs);
	if iNumPrereqs == 0 then -- we reached the end
		tNumPrereqTechs[sTech] = 1;
	else
		tNumPrereqTechs[sTech] = iNumPrereqs;
	end
	tTechAnalyzed[sTech] = true;
	return tNumPrereqTechs[sTech];
end

function CountPrereqTechsNOTWORKING2()
	dprint("FUNSTA CountPrereqTechs()");
	local time_start = os.clock();
	-- init
	for tech in GameInfo.Technologies() do
		tNumPrereqTechs[tech.Type] = 0;
		tTechAnalyzed[tech.Type] = false;
	end
	dprint("Final tech has (num) prereqs", GetPrereqTechsNew("TECH_FUTURE_TECH"));
	for tech in GameInfo.Technologies() do dprint("Tech (name) has (num) prereqTechs", tech.Type, tNumPrereqTechs[tech.Type]); end
	dprint("FUNEND CountPrereqTechs() (msec)", string.format("%d", (os.clock()-time_start)*1000));
end


function CountPrereqTechsNOTWORKING3()
	dprint("FUNSTA CountPrereqTechs()");
	local time_start = os.clock();
	for tech in GameInfo.Technologies() do tNumPrereqTechs[tech.Type] = 0; end -- init
	-- go through grid x
	local iMaxGridX = 0;
	for row in DB.Query("select max(gridx) as num from technologies") do iMaxGridX = row.num; end
	dprint("Max GridX is", iMaxGridX);
	for x = 1, iMaxGridX, 1 do
		dprint("Analyzing (gridx)", x);
		for tech in GameInfo.Technologies{GridX=x} do
			--if tech.GridX == x then 
			dprint("   Analyzing (tech)", tech.Type);
			for row in GameInfo.Technology_PrereqTechs{TechType=tech.Type} do
				dprint("   ...adding (prereq) with (num) prereqs", row.PrereqTech, tNumPrereqTechs[row.PrereqTech]);
				tNumPrereqTechs[tech.Type] = tNumPrereqTechs[tech.Type] + tNumPrereqTechs[row.PrereqTech] + 1;
			end -- for
			--end -- if gridx
		end -- for techs
	end -- for gridx
	-- show results
	for tech in GameInfo.Technologies() do dprint("Tech (name) has (num) prereqTechs", tech.Type, tNumPrereqTechs[tech.Type]); end
	dprint("FUNEND CountPrereqTechs() (msec)", string.format("%d", (os.clock()-time_start)*1000));
end


function CountPrereqTechsXXX()
	dprint("FUNSTA CountPrereqTechs()");
	local time_start = os.clock();
	for tech in GameInfo.Technologies() do tNumPrereqTechs[tech.Type] = 0; end -- init
	-- go through grid x
	--local iMaxGridX = 0;
	--for row in DB.Query("select max(gridx) as num from technologies") do iMaxGridX = row.num; end
	--dprint("Max GridX is", iMaxGridX);
	--for x = 1, iMaxGridX, 1 do
		--dprint("Analyzing (gridx)", x);
		for tech in GameInfo.Technologies() do
			--if tech.GridX == x then 
			dprint("   Analyzing (tech)", tech.Type);
			--for row in GameInfo.Technology_PrereqTechs{TechType=tech.Type} do
				--dprint("   ...adding (prereq) with (num) prereqs", row.PrereqTech, tNumPrereqTechs[row.PrereqTech]);
			local time_tech = os.clock();
			local tPrereqTechs = GetPrereqTechs(tech.Type);
			local iNum = 0; for k,v in pairs(tPrereqTechs) do iNum = iNum + 1; end
			tNumPrereqTechs[tech.Type] = iNum;
			dprint("   ...has (num), took (msec)", tNumPrereqTechs[tech.Type], string.format("%d", (os.clock()-time_tech)*1000));
			--end -- for
			--end -- if gridx
		end -- for techs
	--end -- for gridx
	-- show results
	for tech in GameInfo.Technologies() do dprint("Tech (name) has (num) prereqTechs", tech.Type, tNumPrereqTechs[tech.Type]); end
	dprint("FUNEND CountPrereqTechs() (msec)", string.format("%d", (os.clock()-time_start)*1000));
end

function CountPrereqTechs()
	dprint("FUNSTA CountPrereqTechs()");
	local time_start = os.clock();
	for tech in GameInfo.Technologies() do tNumPrereqTechs[tech.Type] = 0; end -- init
	-- go through grid x
	--local iMaxGridX = 0;
	--for row in DB.Query("select max(gridx) as num from technologies") do iMaxGridX = row.num; end
	--dprint("Max GridX is", iMaxGridX);
	--for x = 1, iMaxGridX, 1 do
		--dprint("Analyzing (gridx)", x);
	--for tech in GameInfo.Technologies() do
			--if tech.GridX == x then 
			--dprint("   Analyzing (tech)", tech.Type);
			--for row in GameInfo.Technology_PrereqTechs{TechType=tech.Type} do
				--dprint("   ...adding (prereq) with (num) prereqs", row.PrereqTech, tNumPrereqTechs[row.PrereqTech]);
			local sTech = "TECH_GUNPOWDER"; -- TECH_EDUCATION
			dprint("ORIGINAL METHOD");
			local time_tech = os.clock();
			local tPrereqTechs = GetPrereqTechs(sTech);
			local iNum = 0; for k,v in pairs(tPrereqTechs) do iNum = iNum + 1; end
			tNumPrereqTechs[sTech] = iNum;
			dprint("   ...(tech) has (num), took (msec)", sTech, tNumPrereqTechs[sTech], string.format("%d", (os.clock()-time_tech)*1000));
			dprint("NEW METHOD");
			time_tech = os.clock();
			tPrereqTechs = GetPrereqTechsNew(sTech);
			iNum = 0; for k,v in pairs(tPrereqTechs) do iNum = iNum + 1; end
			tNumPrereqTechs[sTech] = iNum;
			dprint("   ...(tech) has (num), took (msec)", sTech, tNumPrereqTechs[sTech], string.format("%d", (os.clock()-time_tech)*1000));
			--end -- for
			--end -- if gridx
	--end -- for techs
	--end -- for gridx
	-- show results
	--for tech in GameInfo.Technologies() do dprint("Tech (name) has (num) prereqTechs", tech.Type, tNumPrereqTechs[tech.Type]); end
	dprint("FUNEND CountPrereqTechs() (msec)", string.format("%d", (os.clock()-time_start)*1000));
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

function GetNeededTechs(playerTechs, pWonder)
  local neededTechs = 0

  for sTech, _ in pairs(pWonder.prereqTechs) do
    if (playerTechs[sTech] ~= 1) then
	  neededTechs = neededTechs + 1
    end
  end

  return neededTechs
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
--CountPrereqTechs(); -- special function to avoid time-consuming recursive counting later
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
