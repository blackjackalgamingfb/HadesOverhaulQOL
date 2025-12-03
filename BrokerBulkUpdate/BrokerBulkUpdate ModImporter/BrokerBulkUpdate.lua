---------------------------------------------
-- BrokerUpdate - Market Swap System (ModUtil)
---------------------------------------------

local mod = ModUtil.Mod.Register("BrokerBulkUpdate")

-- Approved global
MarketIsReversed = false

-- Dev logging toggle
mod.LogEnabled = true
local function Log(msg)
    if mod.LogEnabled then
        ModUtil.Hades.Print("[BrokerBulkUpdate] " .. tostring(msg))
    end
end


----------------------------------------------------------------
-- Build reversed entries from BrokerData
----------------------------------------------------------------

local function BuildReversedEntry(entry)
    local reversed = {
        BuyName    = entry.CostName,
        BuyAmount  = entry.CostAmount,
        CostName   = entry.BuyName,
        CostAmount = entry.BuyAmount,
        Priority   = entry.Priority,
        PurchaseSound = entry.PurchaseSound,
        GameStateRequirements = entry.GameStateRequirements,
        IsReversal = true,
    }

    reversed.BuyTitle         = ResourceData[reversed.BuyName].TitleName
    reversed.BuyTitleSingular = ResourceData[reversed.BuyName].TitleName_Singular
        or reversed.BuyTitle
    reversed.BuyIcon          = "{!Icons."..ResourceData[reversed.BuyName].IconString.."}"
    reversed.CostIcon         = "{!Icons."..ResourceData[reversed.CostName].SmallIconString.."}"

    return reversed
end

local function FinalizeForwardEntry(entry)
    entry.BuyTitle         = ResourceData[entry.BuyName].TitleName
    entry.BuyTitleSingular = ResourceData[entry.BuyName].TitleName_Singular 
        or entry.BuyTitle
    entry.BuyIcon          = "{!Icons."..ResourceData[entry.BuyName].IconString.."}"
    entry.CostIcon         = "{!Icons."..ResourceData[entry.CostName].SmallIconString.."}"
    return entry
end


----------------------------------------------------------------
-- Override GenerateMarketItems 
----------------------------------------------------------------

ModUtil.Path.Wrap("GenerateMarketItems", function(base, ...)
    Log("Rebuilding Market Items in " .. (MarketIsReversed and "REVERSE" or "FORWARD") .. " mode")
    
    CurrentRun.MarketItems = {}
    CurrentRun.MarketOptions = BrokerScreenData.MaxOptions

    local tempMax = BrokerScreenData.MaxNonPriorityOffers
    local forward = ShallowCopyTable(BrokerData)
    local priorities = {}

    for _, entry in ipairs(forward) do
        if entry.Priority then table.insert(priorities, entry) end
    end
    for _, p in ipairs(priorities) do RemoveValue(forward, p) end

    local function BuildList(reverse)
        local results = {}

        -- Priority trades
        for _, p in ipairs(priorities) do
            local src = reverse and BuildReversedEntry(p)
                         or FinalizeForwardEntry(DeepCopyTable(p))
            table.insert(results, src)
        end

        -- Non-priority trades
        local remaining = tempMax
        while remaining > 0 and not IsEmpty(forward) do
            local baseEntry = RemoveRandomValue(forward)
            if baseEntry 
               and (baseEntry.GameStateRequirements == nil
               or IsGameStateEligible(CurrentRun, baseEntry, baseEntry.GameStateRequirements)) then
                
                remaining = remaining - 1
                local src = reverse and BuildReversedEntry(baseEntry)
                                 or FinalizeForwardEntry(DeepCopyTable(baseEntry))
                table.insert(results, src)
            end
        end

        return results
    end

    local built = BuildList(MarketIsReversed)
    for i, v in ipairs(built) do built[i] = DeepCopyTable(v) end

    CurrentRun.MarketItems = built
    return built
end, mod)


----------------------------------------------------------------
-- Override OpenMarketScreen to add swap button + mode label
----------------------------------------------------------------

ModUtil.Path.Wrap("OpenMarketScreen", function(base, ...)
    local screen = base(...)

    local components = screen.Components

    -- Mode label
    components.BrokerUpdate_ModeLabel = CreateTextBox({
        Id = components.ShopBackground.Id,
        Text = MarketIsReversed and "REVERSE MODE" or "FORWARD MODE",
        OffsetX = 0,
        OffsetY = -470,
        Font = "AlegreyaSansSCBold",
        FontSize = 28,
        Color = MarketIsReversed and Color.Yellow or Color.White,
        Justification = "Center"
    })

    -- Swap button (hidden hotkey)
    components.BrokerUpdate_Swap = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu" })
    Attach({ Id = components.BrokerUpdate_Swap.Id, DestinationId = components.ShopBackground.Id })
    components.BrokerUpdate_Swap.ControlHotkey = "Confirm"
    components.BrokerUpdate_Swap.OnPressedFunctionName = "SwapMarketMode"

    return screen
end, mod)


----------------------------------------------------------------
-- Override HandleMarketPurchase for non-priority SoldOut logic
----------------------------------------------------------------

ModUtil.Path.Wrap("HandleMarketPurchase", function(base, screen, button)
    local item = button.Data

    base(screen, button)  -- vanilla behavior

    if not item.Priority then
        item.SoldOut = true
        Log("Non-priority trade purchased → SoldOut")
    end
end, mod)


----------------------------------------------------------------
-- Swap function (BrokerUpdate-style)
----------------------------------------------------------------

function SwapMarketMode(screen, button)
    MarketIsReversed = not MarketIsReversed

    PlaySound({ Name = "/SFX/Menu Sounds/ContractorItemSelect" })
    thread(PulseAnimation, { 
        Id = screen.Components.ShopBackground.Id,
        ScaleTarget = 1.05, 
        ScaleDuration = 0.15, 
        HoldDuration = 0, 
        PulseBias = 0.2 
    })

    Log("Swapped to " .. (MarketIsReversed and "REVERSE MODE" or "FORWARD MODE"))

    CloseMarketScreen(screen, button)
    GenerateMarketItems()
    OpenMarketScreen()
end
