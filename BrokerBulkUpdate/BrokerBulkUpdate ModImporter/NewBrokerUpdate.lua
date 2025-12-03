





function GenerateReverseMarketItems()
    -- build forward items first, using your existing logic
    local forwardItems = GenerateMarketItems()

    local reverseItems = {}
    for i, item in ipairs(forwardItems) do
        local rev = DeepCopyTable(item)

        -- swap roles
        rev.BuyName,  rev.CostName  = item.CostName,  item.BuyName
        rev.BuyAmount,rev.CostAmount= item.CostAmount,item.BuyAmount

        -- regen display fields
        rev.BuyTitle         = ResourceData[rev.BuyName].TitleName
        rev.BuyTitleSingular = ResourceData[rev.BuyName].TitleName_Singular
            or ResourceData[rev.BuyName].TitleName
        rev.BuyIcon          = "{!Icons."..ResourceData[rev.BuyName].IconString.."}"
        rev.CostIcon         = "{!Icons."..ResourceData[rev.CostName].SmallIconString.."}"

        reverseItems[i] = rev
    end

    CurrentRun.MarketItems = reverseItems
    return reverseItems
end