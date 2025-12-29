ModUtil.Mod.Register( "NewBrokerUpdate" )

-- Safety init for our flag
if GameState then
    GameState.BrokerSwapInProgress = GameState.BrokerSwapInProgress or false
end

local function NormalizeMultiplier(value)
    local mult = tonumber(value) or 1
    if mult < 1 then
        mult = 1
    end
    return math.floor(mult + 0.5)
end

function GetBrokerMultiplier()
    if CurrentRun and CurrentRun.BrokerMultiplier then
        return NormalizeMultiplier(CurrentRun.BrokerMultiplier)
    end
    return 1
end

local function GetScaledAmounts( item, mult )
    mult = mult or GetBrokerMultiplier() or 1

    local effectiveCost = (item.CostAmount or 0) * mult
    effectiveCost = math.floor(effectiveCost + 0.5)
    if effectiveCost < 1 then
        effectiveCost = 1
    end

    local effectiveBuy = (item.BuyAmount or 0) * mult
    effectiveBuy = math.floor(effectiveBuy + 0.5)
    if effectiveBuy < 1 then
        effectiveBuy = 1
    end

    return effectiveCost, effectiveBuy
end

local function GetDisplayMarketItem( item, mult )
    local effectiveCost, effectiveBuy = GetScaledAmounts( item, mult )

    local displayItem = DeepCopyTable(item)
    displayItem.CostAmount = effectiveCost
    displayItem.BuyAmount  = effectiveBuy

    return displayItem, effectiveCost, effectiveBuy
end

function SetBrokerMultiplierValue(value)
    local mult = NormalizeMultiplier(value)

    if CurrentRun then
        CurrentRun.BrokerMultiplier = mult
    end
    return mult
end

local function IsEligibleMarketItem( buyData )
    return buyData and (buyData.GameStateRequirements == nil or IsGameStateEligible( CurrentRun, buyData, buyData.GameStateRequirements ))
end

local function ApplyMarketSoldOut( items )
    if not CurrentRun or not CurrentRun.MarketSoldOut then
        return
    end
    for i, it in ipairs(items) do
        if CurrentRun.MarketSoldOut[i] then
            it.SoldOut = true
        end
    end
end

local function BuildReverseMarketItems( forwardItems )
    local reverseItems = {}
    for i, item in ipairs(forwardItems) do
        if type(item) == "table" then
            local rev = DeepCopyTable(item)

            -- link back so SoldOut can be mirrored to forward
            rev.SourceIndex = i

            -- swap roles
            rev.BuyName, rev.CostName       = item.CostName, item.BuyName
            rev.BuyAmount, rev.CostAmount   = item.CostAmount, item.BuyAmount

            -- regen display fields (guard ResourceData lookups)
            local buyRes  = ResourceData and rev.BuyName  and ResourceData[rev.BuyName]
            local costRes = ResourceData and rev.CostName and ResourceData[rev.CostName]

            if buyRes then
                rev.BuyTitle = buyRes.TitleName
                rev.BuyTitleSingular = buyRes.TitleName_Singular or buyRes.TitleName
                if buyRes.IconString then
                    rev.BuyIcon = "{!Icons."..buyRes.IconString.."}"
                end
            end

            if costRes and costRes.SmallIconString then
                rev.CostIcon = "{!Icons."..costRes.SmallIconString.."}"
            end

            reverseItems[i] = rev
        end
    end

    ApplyMarketSoldOut(reverseItems)

    return reverseItems
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

			if IsEligibleMarketItem(buyData) then
				numRemainingTempOptions = numRemainingTempOptions - 1
			end
		end

		buyData.BuyTitle = ResourceData[buyData.BuyName].TitleName
		buyData.BuyTitleSingular = ResourceData[buyData.BuyName].TitleName_Singular or ResourceData[buyData.BuyName].TitleName
		buyData.BuyIcon = "{!Icons."..ResourceData[buyData.BuyName].IconString.."}"
		buyData.CostIcon = "{!Icons."..ResourceData[buyData.CostName].SmallIconString.."}"
		if IsEligibleMarketItem(buyData) then
			table.insert( CurrentRun.MarketItems, DeepCopyTable( buyData ))
		end
	end
    -- Re-apply persistent sold-out flags (prevents LTO resurrecting)
    ApplyMarketSoldOut(CurrentRun.MarketItems)


    -- Cache forward items only once so SoldOut state survives swaps
    if not CurrentRun.ForwardMarketItems then
        CurrentRun.ForwardMarketItems = ShallowCopyTable(CurrentRun.MarketItems)
    end

    return CurrentRun.MarketItems
end)

function GenerateReverseMarketItems()
    local forwardItems = CurrentRun and CurrentRun.ForwardMarketItems

    if type(forwardItems) ~= "table" or next(forwardItems) == nil then
        GenerateMarketItems()
        forwardItems = CurrentRun and CurrentRun.ForwardMarketItems
    end

    if type(forwardItems) ~= "table" then
        forwardItems = (CurrentRun and CurrentRun.MarketItems) or {}
    end

    local reverseItems = BuildReverseMarketItems(forwardItems)
    if CurrentRun then
        CurrentRun.MarketItems = reverseItems
    end


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

	components.ShopBackgroundDim = CreateScreenComponent({ Name = "rectangle01", Group = "Combat_Menu", })
	components.ShopBackground = CreateScreenComponent({ Name = "ShopBackground", Group = "Combat_Menu" })

    local ShopBackGrnd = components.ShopBackground
    SetScaleY({ Id = ShopBackGrnd.Id, Fraction = 1.05 })

	components.CloseButton = CreateScreenComponent({ Name = "ButtonClose", Group = "Combat_Menu", Scale = 0.7 })
	Attach({ Id = components.CloseButton.Id, DestinationId = components.ShopBackground.Id, OffsetX = 0, OffsetY = 465 })
	components.CloseButton.OnPressedFunctionName = "CloseMarketScreen"
	components.CloseButton.ControlHotkey = "Cancel"

	components.SwapButton = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu" })
	Attach({ Id = components.SwapButton.Id, DestinationId = components.ShopBackground.Id })
	components.SwapButton.OnPressedFunctionName = "SwapMarketItemsScreen"
	components.SwapButton.ControlHotkey = "Confirm"

    local multButtonDefs = {
        { key = "MultiplierButtonx1",   Text = "x1",   Multiplier = 1,   OffsetX = -400, OffsetY = 380 },
        { key = "MultiplierButtonx5",   Text = "x5",   Multiplier = 5,   OffsetX = -300, OffsetY = 380 },
        { key = "MultiplierButtonx10",  Text = "x10",  Multiplier = 10,  OffsetX = -200, OffsetY = 380 },
        { key = "MultiplierButtonx25",  Text = "x25",  Multiplier = 25,  OffsetX = -100, OffsetY = 380 },
        { key = "MultiplierButtonx50",  Text = "x50",  Multiplier = 50,  OffsetX =    0, OffsetY = 380 },
        { key = "MultiplierButtonx100", Text = "x100", Multiplier = 100, OffsetX =  100, OffsetY = 380 },
        { key = "MultiplierButtonx250",  Text = "x250",  Multiplier = 250,  OffsetX = 200, OffsetY = 380 },
        { key = "MultiplierButtonx500", Text = "x500",  Multiplier = 500,  OffsetX = 300, OffsetY = 380 },
        { key = "MultiplierButtonx1000", Text = "x1000",  Multiplier = 1000,  OffsetX = 400, OffsetY = 380 },
    }

    for _, def in ipairs( multButtonDefs ) do
        -- visible button frame
        local button = CreateScreenComponent({
            Name  = "MarketSlot",
            Group = "Combat_Menu",
            Scale = 1
        })

        SetScaleX({ Id = button.Id, Fraction = 0.10})
        SetScaleY({ Id = button.Id, Fraction = 0.5})
        components[def.key] = button

        Attach({
            Id = button.Id,
            DestinationId = components.ShopBackground.Id,
            OffsetX = def.OffsetX,
            OffsetY = def.OffsetY,
        })

        button.OnPressedFunctionName = "SetBrokerMultiplier"
        button.Multiplier = def.Multiplier
        button.Key = def.key

        -- child anchor JUST for the text
        local textKey  = def.key .. "Text"
        local textComp = CreateScreenComponent({
            Name  = "BlankObstacle",
            Group = "Combat_Menu",
        })
        components[textKey] = textComp

        Attach({
            Id = textComp.Id,
            DestinationId = button.Id,
            OffsetX = 0,
            OffsetY = 0,
        })

        CreateTextBox({
            Id = textComp.Id,
            Text = def.Text,
            FontSize = 28,
            Color = Color.White,
            Font = "AlegreyaSansSCBold",
            Justification = "Center",
        })

        -- remember the text id on the button for highlighting later
        button.TextId = textComp.Id

        print("Multiplier Button Created:", def.key, "mult:", def.Multiplier)
    end

   	
	SetScale({ Id = components.ShopBackgroundDim.Id, Fraction = 4 })
	SetColor({ Id = components.ShopBackgroundDim.Id, Color = {0.090, 0.055, 0.157, 0.7} })

	-- Title
	CreateTextBox({ Id = components.ShopBackground.Id, Text = "MarketScreen_Title", FontSize = 32, OffsetX = 0, OffsetY = -445, Color = Color.White, Font = "SpectralSCLightTitling", ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 3}, Justification = "Center" })
	
   	-- Flavor Text
	local flavorTextOptions = { "MarketScreen_FlavorText01", "MarketScreen_FlavorText02", "MarketScreen_FlavorText03", }
	local flavorText = GetRandomValue( flavorTextOptions )
	CreateTextBox(MergeTables({ Id = components.ShopBackground.Id, Text = flavorText,
			FontSize = 16,
			OffsetY = -385, Width = 840,
			Color = {0.698, 0.702, 0.514, 1.0},
			Font = "AlegreyaSansSCExtraBold",
			ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset = {0, 3},
			Justification = "Center" } ))

	CreateTextBox({ Id = components.ShopBackground.Id, Text = "Press Confirm (Enter on PC, X on XBox, Square on PS) to swap between Normal Trading and Reverse Trading features",
                FontSize = 16,
				OffsetY = -320, Width = 840,
				Color = {0.698, 0.702, 0.514, 1.0},
				Font = "AlegreyaSansSCExtraBold",
				ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset = {0, 3},
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

            -- NEW: shared helper for cost/buy math so it stays in sync
            local displayItem, effectiveCost, effectiveBuy = GetDisplayMarketItem( item )

            local costColor = { 0.878, 0.737, 0.259, 1.0 }
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
                -- icon holder (left icon for what you're buying)
                local iconKey = purchaseButtonTitleKey.."Icon"
                components[iconKey] = CreateScreenComponent({
                    Name  = "BlankObstacle",
                    Group = "Combat_Menu",
                    Scale = 1,
                })
                SetAnimation({
                    Name          = buyResourceData.Icon,
                    DestinationId = components[iconKey].Id,
                    Scale         = 1,
                })
                Attach({
                    Id            = components[iconKey].Id,
                    DestinationId = components[purchaseButtonTitleKey].Id,
                    OffsetX       = -400,
                    OffsetY       = 0,
                })

                -- RIGHT-SIDE cost text anchor
                local sellTextKey = purchaseButtonTitleKey.."SellText"
                components[sellTextKey] = CreateScreenComponent({
                    Name  = "BlankObstacle",
                    Group = "Combat_Menu",
                    Scale = 1,
                })
                Attach({
                    Id            = components[sellTextKey].Id,
                    DestinationId = components[purchaseButtonTitleKey].Id,
                    OffsetX       = 0,
                    OffsetY       = 0,
                })

                local titleText = "MarketScreen_Entry_Title"
                if displayItem.BuyAmount == 1 then
                    titleText = "MarketScreen_Entry_Title_Singular"
                end

                CreateTextBox({
                    Id          = components[purchaseButtonTitleKey].Id,
                    Text        = titleText,
                    FontSize    = 48 * yScale,      
                    OffsetX     = -350,
                    OffsetY     = -24,
                    Width       = 650,
                    Color       = Color.Gold,
                    Font        = "AlegreyaSansSCMedium",
                    ShadowBlur  = 0,
                    ShadowColor = {0,0,0,1},
                    ShadowOffset = {0, 2},
                    Justification = "Left",
                    LuaKey      = "TempTextData",
                    LuaValue    = displayItem,
                    TextSymbolScale = textSymbolScale,
                })

                CreateTextBox({
                    Id          = components[sellTextKey].Id,
                    Text        = "MarketScreen_Cost",
                    FontSize    = 48 * yScale,      
                    OffsetX     = 420,
                    OffsetY     = -24,
                    Width       = 720,
                    Color       = costColor,
                    Font        = "AlegreyaSansSCMedium",
                    ShadowBlur  = 0,
                    ShadowColor = {0,0,0,1},
                    ShadowOffset = {0, 2},
                    Justification = "Right",
                    LuaKey      = "TempTextData",
                    LuaValue    = displayItem,
                    TextSymbolScale = textSymbolScale,
                })
                ModifyTextBox({ Ids = components[sellTextKey].Id, BlockTooltip = true })

                CreateTextBoxWithFormat({
                    Id                    = components[purchaseButtonKey].Id,
                    Text                  = buyResourceData.IconString or item.BuyName,
                    FontSize              = 16 * yScale,
                    OffsetX               = -350,
                    OffsetY               = 8,
                    Width                 = 650,
                    Color                 = Color.White,
                    Justification         = "Left",
                    VerticalJustification = "Top",
                    LuaKey                = "TempTextData",
                    LuaValue              = displayItem,
                    TextSymbolScale       = textSymbolScale,
                    Format                = "MarketScreenDescriptionFormat",
                    VariableAutoFormat    = "BoldFormatGraft",
                    UseDescription        = true,
                })
                if not item.Priority then
					CreateTextBox({ Id = components[purchaseButtonKey].Id, Text = "Market_LimitedTimeOffer", OffsetX = 300, OffsetY = 0, FontSize = 28, Color = costColor, Font = "AlegreyaSansSCRegular", Justification = "Left", TextSymbolScale = textSymbolScale })
				end
            end

            components[purchaseButtonKey].Data = item
            components[purchaseButtonKey].Index = itemIndex
            components[purchaseButtonKey].TitleId = components[purchaseButtonTitleKey].Id
        
            itemLocationX = itemLocationX + itemLocationXSpacer
            if itemLocationX >= itemLocationMaxX then
                itemLocationX = itemLocationStartX
                itemLocationY = itemLocationY + itemLocationYSpacer
            end
        end
    end
end

local function UpdateBrokerUIForMultiplier( screen )
    if not screen or not screen.Components then
        return
    end
    if not CurrentRun or not CurrentRun.MarketItems then
        return
    end

    local components = screen.Components
    local mult = GetBrokerMultiplier()

    for itemIndex, item in ipairs(CurrentRun.MarketItems) do
                if not item.SoldOut then
            local displayItem, effectiveCost, effectiveBuy = GetDisplayMarketItem(item, mult)

            -- Left description (same template, new values)
            local purchaseButtonKey = "PurchaseButton"..itemIndex
            local purchaseComp = components[purchaseButtonKey]
            if purchaseComp and purchaseComp.Id then
                ModifyTextBox({
                    Id      = purchaseComp.Id,
                    LuaKey  = "TempTextData",
                    LuaValue = displayItem,
                })
            end

            -- TITLE (localized, multiplied)
            local yScale = math.min( 3 / CurrentRun.MarketOptions , 1 )
            local titleKey  = "PurchaseButtonTitle"..itemIndex
            local titleComp = components[titleKey]
            if titleComp and titleComp.Id then
                local titleText = "MarketScreen_Entry_Title"
                if displayItem.BuyAmount == 1 then
                    titleText = "MarketScreen_Entry_Title_Singular"
                end

                ModifyTextBox({
                    Id       = titleComp.Id,
                    Text     = titleText,
                    FontSize = 48 * yScale,      
                    LuaKey   = "TempTextData",
                    LuaValue = displayItem,
                })
            end

            -- RIGHT-SIDE COST (localized, multiplied)
            local sellKey  = "PurchaseButtonTitle"..itemIndex.."SellText"
            local sellComp = components[sellKey]
            if sellComp and sellComp.Id then
                ModifyTextBox({
                    Id       = sellComp.Id,
                    Text     = "MarketScreen_Cost",
                    FontSize = 48 * yScale,      
                    LuaKey   = "TempTextData",
                    LuaValue = displayItem,
                })

                local costColor = Color.TradeAffordable
                if not HasResource(item.CostName, effectiveCost) then
                    costColor = Color.TradeUnaffordable
                end

                ModifyTextBox({
                    Id            = sellComp.Id,
                    ColorTarget   = costColor,
                    ColorDuration = 0.1,
                })
            end

            -- LEFT small number next to icon
            local buyAmountKey = "PurchaseButtonTitle"..itemIndex.."BuyAmount"
            local buyAmountComp = components[buyAmountKey]
            if buyAmountComp and buyAmountComp.Id then
                ModifyTextBox({
                    Id   = buyAmountComp.Id,
                    Text = tostring(effectiveBuy),
                })
            end
        end
    end
end

function SetBrokerMultiplier( screen, button )

    if button ~= nil and button.Id ~= nil and (screen == nil or screen.Name == nil) then
        screen = ActiveScreens and ActiveScreens.Market
    end

    if not button or not button.Multiplier then
        return
    end

    local mult = SetBrokerMultiplierValue(button.Multiplier)

    if not screen or not screen.Components then
        screen = ActiveScreens and ActiveScreens.Market
    end
    if not screen or not screen.Components then
        return
    end

    local components = screen.Components
    
    for _, value in ipairs({ 1, 5, 10, 25, 50, 100, 250, 500, 1000 }) do
        local key = "MultiplierButtonx"..tostring(value)
        local comp = components[key]
        if comp and comp.Id then
            ModifyTextBox({
                Id = comp.TextId,
                ColorTarget = Color.White,
                ColorDuration = 0.1,
            })
        end
    end

    if button.TextId then
    ModifyTextBox({
        Id = button.TextId,
        ColorTarget = Color.Gold,
        ColorDuration = 0.1,
    })
    end
    UpdateBrokerUIForMultiplier(screen)
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

    local mult = GetBrokerMultiplier()
    local costAmount, buyAmount = GetScaledAmounts(item, mult)

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

        CurrentRun.MarketSoldOut = CurrentRun.MarketSoldOut or {}
        local soldIndex = item.SourceIndex or button.Index
        CurrentRun.MarketSoldOut[soldIndex] = true
    

        local ids = {}
        local function TryAddComponentId(key)
            local comp = screen.Components[key]
            if comp and comp.Id then
                table.insert(ids, comp.Id)
            end
        end

        TryAddComponentId("PurchaseButtonTitle"..button.Index)
        TryAddComponentId("PurchaseButtonTitle"..button.Index.."SellText")
        TryAddComponentId("PurchaseButtonTitle"..button.Index.."Icon")
        TryAddComponentId("PurchaseButtonTitle"..button.Index.."BuyAmount")
        TryAddComponentId("Backing"..button.Index)
        TryAddComponentId("Icon"..button.Index)

        if #ids > 0 then
            Destroy({ Ids = ids })
        end

        -- Clear component table entries (safe even if they were never created)
        screen.Components["PurchaseButtonTitle"..button.Index.."Icon"]      = nil
        screen.Components["PurchaseButtonTitle"..button.Index.."SellText"]  = nil
        screen.Components["PurchaseButtonTitle"..button.Index.."BuyAmount"] = nil
        screen.Components["PurchaseButtonTitle"..button.Index]              = nil
        screen.Components["Backing"..button.Index]                          = nil
        screen.Components["Icon"..button.Index]                             = nil

        -- Fade out and destroy the main PurchaseButton safely
        local purchaseKey  = "PurchaseButton"..button.Index
        local purchaseComp = screen.Components[purchaseKey]
        if purchaseComp and purchaseComp.Id then
            SetAlpha({ Id = purchaseComp.Id, Fraction = 0, Duration = 0.2 })
            wait(0.2)
            Destroy({ Id = purchaseComp.Id })
        end
        screen.Components[purchaseKey] = nil
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
            local sellComp = screen.Components["PurchaseButtonTitle"..itemIndex.."SellText"]
            if sellComp and sellComp.Id then
                local effectiveCost = GetScaledAmounts(marketItem, mult)

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
    end

    if CoinFlip() then
        thread( PlayVoiceLines, ResourceData[item.CostName].BrokerSpentVoiceLines, true )
    else
        thread( PlayVoiceLines, ResourceData[item.BuyName].BrokerPurchaseVoiceLines, true )
    end
end)






