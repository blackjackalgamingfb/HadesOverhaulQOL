ModUtil.Mod.Register("PactOfPain")
local PoP = PactOfPain or {}

----------------------------------------------------------------
-- Core helpers
----------------------------------------------------------------

function PoP.IsHardModeSave()
    return GameState
        and GameState.Flags
        and GameState.Flags.HardMode == true
end

local function PoP_GetTotalShrinePoints()
    if not PoP.IsHardModeSave() then
        return 0
    end
    -- vanilla helper from RunManager
    return GetTotalSpentShrinePoints() or 0
end

local function PoP_GetEnemyMultipliers()
    local heat = PoP_GetTotalShrinePoints()
    if heat <= 0 then
        return 1, 1, 1, 1
    end

    local hpMult   = 1 + 0.05 * heat
    local dmgMult  = 1 + 0.05 * heat
    local speedMult= 1 + 0.02 * heat
    local atkMult  = 1 + 0.02 * heat

    -- safety cap so things don’t go insane at very high heat
    local cap = 3.0
    local function clamp(x)
        if x < 1 then return 1 end
        if x > cap then return cap end
        return x
    end

    return clamp(hpMult), clamp(dmgMult), clamp(speedMult), clamp(atkMult)
end

----------------------------------------------------------------
-- Enemy scaling hook
----------------------------------------------------------------

ModUtil.Path.Wrap("SetupEnemyObject", function(baseFunc, enemy, currentRun)

    -- call vanilla first so enemy is initialized
    baseFunc(enemy, currentRun)

    if not PoP.IsHardModeSave() or not currentRun or not enemy then
        return
    end

    -- don’t double-apply if something weird happens
    if enemy.PactOfPainApplied then
        return
    end

    local hpMult, dmgMult, moveMult, atkMult = PoP_GetEnemyMultipliers()

    -- Max HP scaling
    if enemy.MaxHealth then
        local oldMax = enemy.MaxHealth
        local newMax = math.floor(oldMax * hpMult + 0.5)
        enemy.MaxHealth = newMax

        -- keep current health in-bounds
        local cur = enemy.Health or newMax
        enemy.Health = math.min(cur, newMax)
    end

    -- Generic damage scaling – safest generic field
    enemy.DamageMultiplier = (enemy.DamageMultiplier or 1) * dmgMult

    -- Movement speed: many enemies use Speed or MoveSpeed
    if enemy.Speed then
        enemy.Speed = enemy.Speed * moveMult
    end
    if enemy.MoveSpeed then
        enemy.MoveSpeed = enemy.MoveSpeed * moveMult
    end

    -- Attack speed: often tied to cooldowns / rates.
    -- We do a conservative pass here; fine-tuning may be needed per enemy later.
    if enemy.Cooldown then
        enemy.Cooldown = enemy.Cooldown / atkMult
    end
    if enemy.PreAttackDuration then
        enemy.PreAttackDuration = enemy.PreAttackDuration / atkMult
    end
    if enemy.PostAttackDuration then
        enemy.PostAttackDuration = enemy.PostAttackDuration / atkMult
    end

    enemy.PactOfPainApplied = true
end)

----------------------------------------------------------------
-- TODO v2: Double resource drops in rooms (HardMode only)
----------------------------------------------------------------
--[[
ModUtil.Path.Wrap("AddResource", function(baseFunc, resourceName, amount, source, args)
    if PoP.IsHardModeSave()
        and CurrentRun
        and CurrentRun.CurrentRoom
        and source ~= "Market"
        and source ~= "Broker"
        and source ~= "CharonStore"
    then
        amount = amount * 2
    end
    return baseFunc(resourceName, amount, source, args)
end)
]]

----------------------------------------------------------------
-- TODO v3: Add Titan Blood as a room reward (HardMode only)
----------------------------------------------------------------
--[[
-- After RewardStoreData is initialized, inject an extra entry that rewards SuperLockKeys
OnAnyLoad{
    function()
        if not RewardStoreData or not RewardStoreData.RunProgress then
            return
        end

        table.insert(RewardStoreData.RunProgress, {
            Name = "PactOfPain_TitanBloodDrop",
            Overrides = {
                Name = "SuperLockKeyDrop",
            },
            GameStateRequirements = {
                RequiredTrueFlags = { "HardMode" },
                -- add more gates if you want (min clears, min heat, etc.)
            },
            -- Weight = 0.2, -- tweak when you see how RewardStoreData is structured
        })
    end
}
]]

-- Show a banner at the start of a run when Pact of Pain is active
ModUtil.Path.Wrap("StartNewRun", function(baseFunc, prevRun, args)
    baseFunc(prevRun, args)

    if not PoP.IsHardModeSave() then
        return
    end

    local heat = GameState.SpentShrinePointsCache or GetTotalSpentShrinePoints() or 0
    if heat <= 0 then
        return
    end

    -- Nice little warning banner
    thread(DisplayLocationText, nil, {
        Text = "Pact of Pain – Heat "..tostring(heat),
        Delay = 1.0,
        Duration = 3.0,
        OffsetY = -360, -- near top
        Color = Color.ShrinePoint,
    })
end)

-- Small HUD label under the active shrine points text
function PoP.UpdateIndicatorText()
    if not ScreenAnchors or not ScreenAnchors.ShrinePointIconId then
        return
    end

    local heat = GameState.SpentShrinePointsCache or GetTotalSpentShrinePoints() or 0
    if not PoP.IsHardModeSave() or heat <= 0 then
        -- Hide if present
        if ScreenAnchors.PactOfPainTextId then
            HideObstacle({ Id = ScreenAnchors.PactOfPainTextId, Duration = 0.2, IncludeText = true })
            Destroy({ Id = ScreenAnchors.PactOfPainTextId })
            ScreenAnchors.PactOfPainTextId = nil
        end
        return
    end

    if not ScreenAnchors.PactOfPainTextId then
        local textId = CreateScreenObstacle({
            Name = "BlankObstacle",
            Group = "Combat_Menu_TraitTray",
            X = 0, Y = 0,
        })
        -- Attach just under the shrine icon text
        Attach({
            Id = textId,
            DestinationId = ScreenAnchors.ShrinePointIconId,
            OffsetX = 0,
            OffsetY = 22,
        })
        ScreenAnchors.PactOfPainTextId = textId

        CreateTextBox({
            Id = textId,
            Text = "",
            Font = "AlegreyaSansSCBold",
            FontSize = 18,
            Justification = "Left",
            ShadowRed = 0, ShadowGreen = 0, ShadowBlue = 0,
            ShadowAlpha = 1, ShadowBlur = 0,
            ShadowOffsetY = 2, ShadowOffsetX = 0,
            OutlineColor = {0,0,0,1},
            OutlineThickness = 1,
        })
    end

    local label = "Pact of Pain x"..tostring(heat)
    ModifyTextBox({
        Id = ScreenAnchors.PactOfPainTextId,
        Text = label,
        AutoSetDataProperties = false,
    })
end

-- Wrap the vanilla UpdateActiveShrinePoints and tack ours on
ModUtil.Path.Wrap("UpdateActiveShrinePoints", function(baseFunc)
    baseFunc()
    PoP.UpdateIndicatorText()
end) 

