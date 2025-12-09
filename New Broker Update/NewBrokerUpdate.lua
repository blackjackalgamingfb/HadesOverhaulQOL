ModUtil.Mod.Register( "NewBrokerUpdate" )

-- Safety init for our flag
if GameState then
    GameState.BrokerSwapInProgress = GameState.BrokerSwapInProgress or false
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

	CreateTextBox({ Id = components.ShopBackground.Id, Text = "Press Enter(PC), Square(PS) or X(Xbox) to increase and decrease amounts",
				FontSize = 16,
				OffsetY = -320, Width = 840,
				Color = {0.698, 0.702, 0.514, 1.0},
				Font = "AlegreyaSansSCExtraBold",
				ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
				Justification = "Center" })

	CreateMarketButtons( screen )

	if screen.NumItemsOffered == 0 then
		thread( PlayVoiceLines, GlobalVoiceLines.MarketSoldOutVoiceLines, true )
	else
		thread( PlayVoiceLines, GlobalVoiceLines.OpenedMarketVoiceLines, true )
	end

	HandleScreenInput( screen )
	return screen

end)

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



			local costColor = {0.878, 0.737, 0.259, 1.0}
			if not HasResource( item.CostName, item.CostAmount ) then
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
    end

    -- Belt-and-suspenders: never leave this stuck true in a save
    if GameState then
        GameState.BrokerSwapInProgress = false
    end
    return result
	DisableShopGamepadCursor()
	CloseScreen( GetAllIds( screen.Components ) )
	PlaySound({ Name = "/SFX/Menu Sounds/GeneralWhooshMENU" })
	UnfreezePlayerUnit()
	screen.KeepOpen = false
	OnScreenClosed({ Flag = screen.Name })
end)

ModUtil.Path.Override( "HandleMarketPurchase", function( screen, button )
	local item = button.Data
    if not HasResource( item.CostName, item.CostAmount ) then
		Flash({ Id = screen.Components["PurchaseButton".. button.Index].Id, Speed = 3, MinFraction = 0.6, MaxFraction = 0.0, Color = Color.CostUnaffordable, ExpireAfterCycle = true })
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
		Destroy({ Ids = { screen.Components["PurchaseButtonTitle".. button.Index].Id , screen.Components["PurchaseButtonTitle".. button.Index .. "SellText"].Id, screen.Components["PurchaseButtonTitle".. button.Index .. "Icon"].Id, screen.Components["Backing".. button.Index].Id, screen.Components["Icon".. button.Index].Id }})
		screen.Components["PurchaseButtonTitle".. button.Index .. "Icon"] = nil
		screen.Components["PurchaseButtonTitle".. button.Index .. "SellText"] = nil
		screen.Components["PurchaseButtonTitle".. button.Index] = nil
		screen.Components["Backing".. button.Index] = nil
		screen.Components["Icon".. button.Index] = nil

		-- SetScale({ Id = screen.Components["PurchaseButton".. button.Index].Id, Fraction = 0.5, Duration = 0.2 })
		SetAlpha({ Id = screen.Components["PurchaseButton".. button.Index].Id, Fraction = 0, Duration = 0.2 })
		wait(0.2)
		Destroy({ Id = screen.Components["PurchaseButton".. button.Index].Id })
		screen.Components["PurchaseButton".. button.Index] = nil
	end
	local resourceArgs = { SkipOverheadText = true, ApplyMultiplier = false, }

	SpendResource( item.CostName, item.CostAmount, "Market", resourceArgs  )

	wait(0.3)

	AddResource( item.BuyName, item.BuyAmount, "Market", resourceArgs  )

	-- Check updated affordability
	for itemIndex, item in ipairs( CurrentRun.MarketItems ) do
		if not item.SoldOut then
			local costColor = Color.TradeAffordable
			if not HasResource( item.CostName, item.CostAmount ) then
				costColor = Color.TradeUnaffordable
			end
			local purchaseButtonKey = "PurchaseButton"..itemIndex
			ModifyTextBox({ Id = screen.Components["PurchaseButtonTitle"..itemIndex.."SellText"].Id, ColorTarget = costColor, ColorDuration = 0.1 })
		end
	end

	if CoinFlip() then
		thread( PlayVoiceLines, ResourceData[item.CostName].BrokerSpentVoiceLines, true )
	else
		thread( PlayVoiceLines, ResourceData[item.BuyName].BrokerPurchaseVoiceLines, true )
	end
end)




