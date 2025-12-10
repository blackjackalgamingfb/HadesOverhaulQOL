ModUtil.Mod.Register( "NewBrokerUpdate" )

-- Safety init for our flag
if GameState then
    GameState.BrokerSwapInProgress = GameState.BrokerSwapInProgress or false
end

function GetBrokerMultiplier()
    local mult = 1

    if CurrentRun and CurrentRun.BrokerMultiplier then
        mult = CurrentRun.BrokerMultiplier
    end

    mult = tonumber(mult) or 1
    if mult < 1 then
        mult = 1
    end
    return math.floor(mult + 0.5)
end

function SetBrokerMultiplierValue(value)
    local mult = tonumber(value) or 1
    if mult < 1 then
        mult = 1
    end
    mult = math.floor(mult + 0.5)

    if CurrentRun then
        CurrentRun.BrokerMultiplier = mult
    end

    print("Broker multiplier set to x"..tostring(mult))
    return mult
end

ModUtil.Path.Override( "UseMarketObject", function( usee, args )
	PlayInteractAnimation( usee.ObjectId )
	UseableOff({ Id = usee.ObjectId })
	GenerateMarketItems()
	if CurrentRun.MarketOptions == nil then
		CurrentRun.MarketOptions = TableLength( CurrentRun.MarketItems )
	end
	local screen = OpenMarketScreen()
	UseableOn({ Id = usee.ObjectId })
	MarketSessionCompletePresentation( usee, screen )
end)

ModUtil.Path.Override( "GenerateMarketItems", function()

	if CurrentRun.MarketItems ~= nil then
		return CurrentRun.MarketItems
	end
	RandomSynchronize()
	CurrentRun.MarketItems = {}
	CurrentRun.MarketOptions = BrokerScreenData.MaxOptions
	local numRemainingTempOptions = BrokerScreenData.MaxNonPriorityOffers
	local buyOptions = ShallowCopyTable( BrokerData )
	local priorityOptions = {}
	for i, option in ipairs( buyOptions ) do
		if option.Priority then
			table.insert( priorityOptions, option )
		end
	end
	for i, option in pairs( priorityOptions ) do
		RemoveValue( buyOptions, option )
	end
	while #CurrentRun.MarketItems < CurrentRun.MarketOptions and not ( IsEmpty( buyOptions ) and IsEmpty( priorityOptions )) and not ( IsEmpty( priorityOptions ) and numRemainingTempOptions <= 0 ) do
		local buyData = nil
		if not IsEmpty ( priorityOptions ) then
			buyData = RemoveFirstValue( priorityOptions )
		elseif numRemainingTempOptions > 0 then
			buyData = RemoveRandomValue( buyOptions )

			if buyData and buyData.GameStateRequirements == nil or IsGameStateEligible( CurrentRun, buyData, buyData.GameStateRequirements ) then
				numRemainingTempOptions = numRemainingTempOptions - 1
			end
		end

		buyData.BuyTitle = ResourceData[buyData.BuyName].TitleName
		buyData.BuyTitleSingular = ResourceData[buyData.BuyName].TitleName_Singular or ResourceData[buyData.BuyName].TitleName
		buyData.BuyIcon = "{!Icons."..ResourceData[buyData.BuyName].IconString.."}"
		buyData.CostIcon = "{!Icons."..ResourceData[buyData.CostName].SmallIconString.."}"
		if buyData and buyData.GameStateRequirements == nil or IsGameStateEligible( CurrentRun, buyData, buyData.GameStateRequirements ) then
			table.insert( CurrentRun.MarketItems, DeepCopyTable( buyData ))
		end
	end
    -- Cache a copy of the forward items for reverse swapping
    CurrentRun.ForwardMarketItems = ShallowCopyTable(CurrentRun.MarketItems)

    return CurrentRun.MarketItems
end)


function GenerateReverseMarketItems()
    local forwardItems = GenerateMarketItems()

    local reverseItems = {}
    for i, item in ipairs(forwardItems) do
        local rev = DeepCopyTable(item)

        -- swap roles
        rev.BuyName, rev.CostName = item.CostName, item.BuyName
        rev.BuyAmount, rev.CostAmount = item.CostAmount, item.BuyAmount

        -- regen display fields
        rev.BuyTitle = ResourceData[rev.BuyName].TitleName
        rev.BuyTitleSingular = ResourceData[rev.BuyName].TitleName_Singular or ResourceData[rev.BuyName].TitleName
        rev.BuyIcon = "{!Icons."..ResourceData[rev.BuyName].IconString.."}"
        rev.CostIcon = "{!Icons."..ResourceData[rev.CostName].SmallIconString.."}"

        reverseItems[i] = rev
    end

	CurrentRun.MarketItems = reverseItems

    return reverseItems
end

ModUtil.Path.Override( "OpenMarketScreen", function()

	local screen = { Components = {} }
	screen.Name = "Market"
	screen.NumSales = 0
	screen.NumItemsOffered = 0
	screen.SwapType = "Forward"

	if IsScreenOpen( screen.Name ) then
		return
	end
	OnScreenOpened({ Flag = screen.Name, PersistCombatUI = true })
	FreezePlayerUnit()
	EnableShopGamepadCursor()

	PlaySound({ Name = "/SFX/Menu Sounds/DialoguePanelIn" })

	local components = screen.Components

	components.ShopBackgroundDim = CreateScreenComponent({ Name = "rectangle01", Group = "Combat_Menu" })
	components.ShopBackground = CreateScreenComponent({ Name = "ShopBackground", Group = "Combat_Menu" })

	components.CloseButton = CreateScreenComponent({ Name = "ButtonClose", Group = "Combat_Menu", Scale = 0.7 })
	Attach({ Id = components.CloseButton.Id, DestinationId = components.ShopBackground.Id, OffsetX = 0, OffsetY = 440 })
	components.CloseButton.OnPressedFunctionName = "CloseMarketScreen"
	components.CloseButton.ControlHotkey = "Cancel"

	components.SwapButton = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu" })
	Attach({ Id = components.SwapButton.Id, DestinationId = components.ShopBackground.Id })
	components.SwapButton.OnPressedFunctionName = "SwapMarketItemsScreen"
	components.SwapButton.ControlHotkey = "Confirm"
	
	SetScale({ Id = components.ShopBackgroundDim.Id, Fraction = 4 })
	SetColor({ Id = components.ShopBackgroundDim.Id, Color = {0.090, 0.055, 0.157, 0.7} })

	-- Title
	CreateTextBox({ Id = components.ShopBackground.Id, Text = "MarketScreen_Title", FontSize = 32, OffsetX = 0, OffsetY = -445, Color = Color.White, Font = "SpectralSCLightTitling", ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 3}, Justification = "Center" })
	CreateTextBox({ Id = components.ShopBackground.Id, Text = "MarketScreen_Hint", FontSize = 14, OffsetX = 0, OffsetY = 380, Width = 865, Color = Color.Gray, Font = "AlegreyaSansSCBold", ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2}, Justification = "Center" })

	-- Flavor Text
	local flavorTextOptions = { "MarketScreen_FlavorText01", "MarketScreen_FlavorText02", "MarketScreen_FlavorText03", }
	local flavorText = GetRandomValue( flavorTextOptions )
	CreateTextBox(MergeTables({ Id = components.ShopBackground.Id, Text = flavorText,
			FontSize = 16,
			OffsetY = -385, Width = 840,
			Color = {0.698, 0.702, 0.514, 1.0},
			Font = "AlegreyaSansSCExtraBold",
			ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
			Justification = "Center" } ))

	CreateTextBox({ Id = components.ShopBackground.Id, Text = "Press Confirm to swap between Normal Trading and Reverse Trading features",
				OffsetY = -320, Width = 840,
				Color = {0.698, 0.702, 0.514, 1.0},
				Font = "AlegreyaSansSCExtraBold",
				ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
				Justification = "Center" })

    local multButtonDefs = {
        { key = "MultiplierButtonx1",   Text = "x1",   Multiplier = 1,   OffsetX = -400, OffsetY = 380 },
        { key = "MultiplierButtonx10",  Text = "x10",  Multiplier = 10,  OffsetX =    0, OffsetY = 380 },
        { key = "MultiplierButtonx100", Text = "x100", Multiplier = 100, OffsetX =  400, OffsetY = 380 },
    }

    for _, def in ipairs(multButtonDefs) do
        local comp = CreateScreenComponent({ Name = "Button_Default", Group = "Combat_Menu", Scale = 0.7 })
        components[def.key] = comp

        Attach({
            Id = comp.Id,
            DestinationId = components.ShopBackground.Id,
            OffsetX = def.OffsetX,
            OffsetY = def.OffsetY,
        })

        comp.OnPressedFunctionName = "SetBrokerMultiplier"
        comp.Multiplier = def.Multiplier

        CreateTextBox({
            Id = comp.Id,
            Text = def.Text,
            FontSize = 22,
            Color = Color.White,
            Font = "AlegreyaSansSCBold",
            Justification = "Center",
        })
    end

	CreateMarketButtons( screen )

	if screen.NumItemsOffered == 0 then
		thread( PlayVoiceLines, GlobalVoiceLines.MarketSoldOutVoiceLines, true )
	else
		thread( PlayVoiceLines, GlobalVoiceLines.OpenedMarketVoiceLines, true )
	end

	HandleScreenInput( screen )
	return screen

end)

function SetBrokerMultiplier( screen, button )
    -- Sometimes called as SetBrokerMultiplier(button)
    if button ~= nil and button.Id ~= nil and (screen == nil or screen.Name == nil) then
        screen = ActiveScreens and ActiveScreens.Market
    end

    if not button or not button.Multiplier then
        return
    end

    -- Set and clamp the multiplier using your helper
    local mult = SetBrokerMultiplierValue(button.Multiplier)

    -- Find the active screen if not passed in
    if not screen or not screen.Components then
        screen = ActiveScreens and ActiveScreens.Market
    end
    if not screen or not screen.Components then
        return
    end

    -- Reset all multiplier button colors to white
    for _, value in ipairs({ 1, 10, 100 }) do
        local key = "MultiplierButtonx"..tostring(value)
        local comp = screen.Components[key]
        if comp then
            ModifyTextBox({
                Id = comp.Id,
                ColorTarget = Color.White,
                ColorDuration = 0.1,
            })
        end
    end

    -- Highlight the selected one in gold
    ModifyTextBox({
        Id = button.Id,
        ColorTarget = Color.Gold,
        ColorDuration = 0.1,
    })
end

function CreateMarketButtons( screen )
	local components = screen.Components
	local tooltipData = {}
	local yScale = math.min( 3 / CurrentRun.MarketOptions , 1 )

	local itemLocationStartY = ShopUI.ShopItemStartY - ( ShopUI.ShopItemSpacerY * (1 - yScale) * 0.5)
	local itemLocationYSpacer = ShopUI.ShopItemSpacerY * yScale
	local itemLocationMaxY = itemLocationStartY + 4 * itemLocationYSpacer

	local itemLocationStartX = ShopUI.ShopItemStartX
	local itemLocationXSpacer = ShopUI.ShopItemSpacerX
	local itemLocationMaxX = itemLocationStartX + 1 * itemLocationXSpacer

	local itemLocationTextBoxOffset = 380

	local itemLocationX = itemLocationStartX
	local itemLocationY = itemLocationStartY

	local textSymbolScale = 0.8

	local firstUseable = false
	for itemIndex, item in ipairs( CurrentRun.MarketItems ) do

		if not item.SoldOut then

			screen.NumItemsOffered = screen.NumItemsOffered + 1
			local purchaseButtonKey = "PurchaseButton"..itemIndex
			components[purchaseButtonKey] = CreateScreenComponent({ Name = "MarketSlot", Group = "Combat_Menu", Scale = 1, X = itemLocationX, Y = itemLocationY })
			SetInteractProperty({ DestinationId = components[purchaseButtonKey].Id, Property = "TooltipOffsetX", Value = 665 })

			local iconKey = "Icon"..itemIndex
			components[iconKey] = CreateScreenComponent({ Name = "BlankObstacle", X = itemLocationX - 360, Y = itemLocationY, Group = "Combat_Menu" })
			
			local itemBackingKey = "Backing"..itemIndex
			components[itemBackingKey] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", X = itemLocationX + itemLocationTextBoxOffset, Y = itemLocationY })

			local purchaseButtonTitleKey = "PurchaseButtonTitle"..itemIndex
			components[purchaseButtonTitleKey] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", Scale = 1, X = itemLocationX, Y = itemLocationY })
            
            local mult = GetBrokerMultiplier()
            local effectiveCost = (item.CostAmount or 0) * mult
            effectiveCost = math.floor(effectiveCost + 0.5)
            if effectiveCost < 1 then effectiveCost = 1 end


            local costColor = {0.878, 0.737, 0.259, 1.0}
			if not HasResource( item.CostName, effectiveCost ) then
				costColor = Color.TradeUnaffordable
			end

			components[purchaseButtonKey].OnPressedFunctionName = "HandleMarketPurchase"
			if not firstUseable then
				TeleportCursor({ OffsetX = itemLocationX, OffsetY = itemLocationY })
				firstUseable = true
			end

			-- left side text
			local buyResourceData = ResourceData[item.BuyName]
			if buyResourceData then
				components[purchaseButtonTitleKey .. "Icon"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", Scale = 1 })
				SetAnimation({ Name = buyResourceData.Icon, DestinationId = components[purchaseButtonTitleKey .. "Icon"].Id, Scale = 1 })
				Attach({ Id = components[purchaseButtonTitleKey .. "Icon"].Id, DestinationId = components[purchaseButtonTitleKey].Id, OffsetX = -400, OffsetY = 0 })
				components[purchaseButtonTitleKey .. "SellText"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", Scale = 1 })
				Attach({ Id = components[purchaseButtonTitleKey .. "SellText"].Id, DestinationId = components[purchaseButtonTitleKey].Id, OffsetX = 0, OffsetY = 0 })

				local titleText = "MarketScreen_Entry_Title"
				if item.BuyAmount == 1 then
					titleText = "MarketScreen_Entry_Title_Singular"
				end
				CreateTextBox({ Id = components[purchaseButtonKey].Id, Text = titleText,
					FontSize = 48 * yScale ,
					OffsetX = -350, OffsetY = -35,
					Width = 720,
					Color = {0.878, 0.737, 0.259, 1.0},
					Font = "AlegreyaSansSCMedium",
					ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
					Justification = "Left",
					VerticalJustification = "Top",
					LuaKey = "TempTextData",
					LuaValue = item,
					LineSpacingBottom = 20,
					TextSymbolScale = textSymbolScale,
				})
				CreateTextBox({ Id = components[purchaseButtonTitleKey.."SellText"].Id, Text = "MarketScreen_Cost",
					FontSize = 48 * yScale ,
					OffsetX = 420, OffsetY = -24,
					Width = 720,
					Color = costColor,
					Font = "AlegreyaSansSCMedium",
					ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
					Justification = "Right",
					LuaKey = "TempTextData",
					LuaValue = item,
					LineSpacingBottom = 20,
					TextSymbolScale = textSymbolScale,
				})
				ModifyTextBox({ Ids = components[purchaseButtonTitleKey.."SellText"].Id, BlockTooltip = true })

				CreateTextBoxWithFormat({ Id = components[purchaseButtonKey].Id, Text = buyResourceData.IconString or item.BuyName,
					FontSize = 16 * yScale,
					OffsetX = -350, OffsetY = 0,
					Width = 650,
					Color = Color.White,
					Justification = "Left",
					VerticalJustification = "Top",
					LuaKey = "TempTextData",
					LuaValue = item,
					TextSymbolScale = textSymbolScale,
					Format = "MarketScreenDescriptionFormat",
					VariableAutoFormat = "BoldFormatGraft",
					UseDescription = true
				})
				if not item.Priority then
					CreateTextBox({ Id = components[purchaseButtonKey].Id, Text = "Market_LimitedTimeOffer", OffsetX = 300, OffsetY = 0, FontSize = 28, Color = costColor, Font = "AlegreyaSansSCRegular", Justification = "Left", TextSymbolScale = textSymbolScale })
				end
			end

			components[purchaseButtonKey].Data = item
			components[purchaseButtonKey].Index = itemIndex
			components[purchaseButtonKey].TitleId = components[purchaseButtonTitleKey].Id
		end

		itemLocationX = itemLocationX + itemLocationXSpacer
		if itemLocationX >= itemLocationMaxX then
			itemLocationX = itemLocationStartX
			itemLocationY = itemLocationY + itemLocationYSpacer
		end
	end
end

local function IsMarketCurrentlyReversed()
    if not CurrentRun or not CurrentRun.MarketItems or not CurrentRun.MarketItems[1] then
        return false 
    end

    local first = CurrentRun.MarketItems[1]

    -- Look for a matching BrokerData entry to tell if we're forward or reversed
    for _, entry in ipairs(BrokerData) do
        -- Forward-style match
        if first.BuyName == entry.BuyName and first.CostName == entry.CostName then
            return false
        end
        -- Reverse-style match
        if first.BuyName == entry.CostName and first.CostName == entry.BuyName then
            return true
        end
    end

    return false
end

function SwapMarketItemsScreen( screen, button )
    print("SwapMarketItemsScreen Called")

    if not CurrentRun.MarketItems or #CurrentRun.MarketItems == 0 then
        GenerateMarketItems()
    else
        if IsMarketCurrentlyReversed() then
            if CurrentRun.ForwardMarketItems then
                CurrentRun.MarketItems = CurrentRun.ForwardMarketItems
            else
                CurrentRun.MarketItems = nil
                GenerateMarketItems()
            end
        else
            GenerateReverseMarketItems()
        end
    end
    
    if CurrentRun then
        CurrentRun.BrokerMultiplier = 1
    end
    
    -- Mark that this close is part of a swap, not a real exit
    if GameState then
        GameState.BrokerSwapInProgress = true
    end

    CloseMarketScreen( screen, button )

    if GameState then
        GameState.BrokerSwapInProgress = false
    end

    wait(0.3)

    OpenMarketScreen()
end

ModUtil.Path.Override("CloseMarketScreen", function( screen, button )
	DisableShopGamepadCursor()
	CloseScreen( GetAllIds( screen.Components ) )
	PlaySound({ Name = "/SFX/Menu Sounds/GeneralWhooshMENU" })
	UnfreezePlayerUnit()
	screen.KeepOpen = false
	OnScreenClosed({ Flag = screen.Name })
        -- Only run cleanup when this is a real close, not a swap
    if GameState and not GameState.BrokerSwapInProgress and CurrentRun then
        if CurrentRun.ForwardMarketItems then
            -- If we somehow left while reversed, snap back to forward
            if IsMarketCurrentlyReversed and IsMarketCurrentlyReversed() then
                CurrentRun.MarketItems = CurrentRun.ForwardMarketItems
            end
            -- Clear cache so next market session starts clean
            CurrentRun.ForwardMarketItems = nil
        end
        CurrentRun.BrokerMultiplier = 1
    end

    -- Belt-and-suspenders: never leave this stuck true in a save
    if GameState then
        GameState.BrokerSwapInProgress = false
    end
end)

ModUtil.Path.Override( "HandleMarketPurchase", function( screen, button )
    local item = button.Data
    if not item then
        return
    end

    -- =========================================
    -- Apply broker multiplication factor
    -- =========================================
    local mult = GetBrokerMultiplier()

    local rawCostAmount = item.CostAmount or 0
    local rawBuyAmount  = item.BuyAmount or 0

    local costAmount = rawCostAmount * mult
    local buyAmount  = rawBuyAmount * mult

    costAmount = math.floor(costAmount + 0.5)
    buyAmount  = math.floor(buyAmount + 0.5)

    if costAmount < 1 then
        costAmount = 1
    end
    if buyAmount < 1 then
        buyAmount = 1
    end
    -- =========================================

    -- Use the *scaled* cost here, not item.CostAmount
    if not HasResource( item.CostName, costAmount ) then
        Flash({
            Id = screen.Components["PurchaseButton".. button.Index].Id,
            Speed = 3,
            MinFraction = 0.6,
            MaxFraction = 0.0,
            Color = Color.CostUnaffordable,
            ExpireAfterCycle = true
        })
        MarketPurchaseFailPresentation( item )
        return
    end

    screen.NumSales = screen.NumSales + 1
    GameState.MarketSales = (GameState.MarketSales or 0) + 1

    MarketPurchaseSuccessPresentation( item )
    if item.Priority then
        MarketPurchaseSuccessRepeatablePresentation( button )
    else
        item.SoldOut = true
        Destroy({ Ids = {
            screen.Components["PurchaseButtonTitle".. button.Index].Id,
            screen.Components["PurchaseButtonTitle".. button.Index .. "SellText"].Id,
            screen.Components["PurchaseButtonTitle".. button.Index .. "Icon"].Id,
            screen.Components["Backing".. button.Index].Id,
            screen.Components["Icon".. button.Index].Id
        }})
        screen.Components["PurchaseButtonTitle".. button.Index .. "Icon"] = nil
        screen.Components["PurchaseButtonTitle".. button.Index .. "SellText"] = nil
        screen.Components["PurchaseButtonTitle".. button.Index] = nil
        screen.Components["Backing".. button.Index] = nil
        screen.Components["Icon".. button.Index] = nil

        SetAlpha({ Id = screen.Components["PurchaseButton".. button.Index].Id, Fraction = 0, Duration = 0.2 })
        wait(0.2)
        Destroy({ Id = screen.Components["PurchaseButton".. button.Index].Id })
        screen.Components["PurchaseButton".. button.Index] = nil
    end

    local resourceArgs = { SkipOverheadText = true, ApplyMultiplier = false, }

    -- Spend scaled cost
    SpendResource( item.CostName, costAmount, "Market", resourceArgs  )

    wait(0.3)

    -- Give scaled amount
    AddResource( item.BuyName, buyAmount, "Market", resourceArgs  )

    -- Check updated affordability (also scaled by current multiplier)
    for itemIndex, marketItem in ipairs( CurrentRun.MarketItems ) do
        if not marketItem.SoldOut then
            local baseCost = marketItem.CostAmount or 0
            local effectiveCost = baseCost * mult
            effectiveCost = math.floor(effectiveCost + 0.5)
            if effectiveCost < 1 then
                effectiveCost = 1
            end

            local costColor = Color.TradeAffordable
            if not HasResource( marketItem.CostName, effectiveCost ) then
                costColor = Color.TradeUnaffordable
            end

            ModifyTextBox({
                Id = screen.Components["PurchaseButtonTitle"..itemIndex.."SellText"].Id,
                ColorTarget = costColor,
                ColorDuration = 0.1
            })
        end
    end

    if CoinFlip() then
        thread( PlayVoiceLines, ResourceData[item.CostName].BrokerSpentVoiceLines, true )
    else
        thread( PlayVoiceLines, ResourceData[item.BuyName].BrokerPurchaseVoiceLines, true )
    end
end)




