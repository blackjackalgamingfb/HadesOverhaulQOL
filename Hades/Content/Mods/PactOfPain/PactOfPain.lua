local PoP = ModUtil.Mod.Register("PactOfPain")

----------------------------------------------------------------
-- Core state / helpers
----------------------------------------------------------------

function PoP.IsHardModeSave()
    return GameState
        and GameState.Flags
        and GameState.Flags.HardMode == true
end

function PoP.IsEnabled()
    if not PoP.IsHardModeSave() then
        return false
    end
    GameState.Flags = GameState.Flags or {}
    return GameState.Flags.PactOfPainEnabled == true
end

function PoP.SetEnabled(value)
    GameState.Flags = GameState.Flags or {}
    GameState.Flags.PactOfPainEnabled = value and true or false
end

function PoP.Toggle()
    PoP.SetEnabled(not PoP.IsEnabled())
end

local function PoP_GetTotalShrinePoints()
    if not PoP.IsEnabled() then
        return 0
    end
    return GameState.SpentShrinePointsCache or GetTotalSpentShrinePoints() or 0
end

local function PoP_GetEnemyMultipliers()
    local heat = PoP_GetTotalShrinePoints()
    if heat <= 0 then
        return 1, 1, 1, 1
    end

    local hpMult   = 1 + 0.05 * heat
    local dmgMult  = 1 + 0.05 * heat
    local moveMult = 1 + 0.02 * heat
    local atkMult  = 1 + 0.02 * heat

    local cap = 3.0
    local function clamp(x)
        if x < 1 then return 1 end
        if x > cap then return cap end
        return x
    end

    return clamp(hpMult), clamp(dmgMult), clamp(moveMult), clamp(atkMult)
end

----------------------------------------------------------------
-- Enemy scaling hook
----------------------------------------------------------------

ModUtil.Path.Wrap("SetupEnemyObject", function(baseFunc, enemy, currentRun, args, ...)
    baseFunc(enemy, currentRun, args, ...)
    if not PoP.IsEnabled() or not currentRun or not enemy then
        return
    end

    if enemy.PactOfPainApplied then
        return
    end

    local hpMult, dmgMult, moveMult, atkMult = PoP_GetEnemyMultipliers()

    -- HP
    if enemy.MaxHealth then
        local newMax = math.floor(enemy.MaxHealth * hpMult + 0.5)
        enemy.MaxHealth = newMax
        local cur = enemy.Health or newMax
        enemy.Health = math.min(cur, newMax)
    end

    -- Generic damage multiplier
    enemy.DamageMultiplier = (enemy.DamageMultiplier or 1.0) * dmgMult

    -- Movement speed
    if enemy.Speed then
        enemy.Speed = enemy.Speed * moveMult
    end
    if enemy.MoveSpeed then
        enemy.MoveSpeed = enemy.MoveSpeed * moveMult
    end

    -- Attack timing (basic conservative pass)
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
-- Run start banner
----------------------------------------------------------------

ModUtil.Path.Wrap("StartNewRun", function(baseFunc, prevRun, args, ...)
    baseFunc(prevRun, args, ...)
    if not CurrentRun then 
        return 
    end

    if not PoP.IsEnabled() then
        return
    end

    local heat = PoP_GetTotalShrinePoints()
    if heat <= 0 then
        return
    end

    -- Simple banner text at top of screen
    thread(DisplayLocationText, nil, {
        Text = "Pact of Pain – Heat "..tostring(heat),
        Delay = 1.0,
        Duration = 3.0,
        OffsetY = -360,
        Color = Color.ShrinePoint,
    })
end)

----------------------------------------------------------------
-- HUD indicator next to active shrine points
----------------------------------------------------------------

function PoP.UpdateIndicatorText()
    if not ScreenAnchors or not ScreenAnchors.ShrinePointIconId then
        return
    end

    if not PoP.IsEnabled() then
        if ScreenAnchors.PactOfPainTextId then
            HideObstacle({
                Id = ScreenAnchors.PactOfPainTextId,
                Duration = 0.2,
                IncludeText = true
            })
            Destroy({ Id = ScreenAnchors.PactOfPainTextId })
            ScreenAnchors.PactOfPainTextId = nil
        end
        return
    end

    local heat = PoP_GetTotalShrinePoints()
    if heat <= 0 then
        return
    end

    if not ScreenAnchors.PactOfPainTextId then
        local textId = CreateScreenObstacle({
            Name  = "BlankObstacle",
            Group = "Combat_Menu_TraitTray",
            X = 0, Y = 0,
        })
        ScreenAnchors.PactOfPainTextId = textId
        Attach({
            Id = textId,
            DestinationId = ScreenAnchors.ShrinePointIconId,
            OffsetX = 0,
            OffsetY = 22,
        })

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

ModUtil.Path.Wrap("UpdateActiveShrinePoints", function(baseFunc)
    baseFunc()
    PoP.UpdateIndicatorText()
end)

----------------------------------------------------------------
-- Shrine UI toggle button
----------------------------------------------------------------

function PoP.UpdateShrineButtonVisual(screen)
    if not screen or not screen.Components or not screen.Components.ShopBackground then
        return
    end
    local components = screen.Components
    local btn = components.PactOfPainButton
    if not btn or not btn.TextId then
        return
    end

    local enabled = PoP.IsEnabled()
    local label   = enabled and "Pact of Pain: ON" or "Pact of Pain: OFF"
    local color   = enabled and Color.ShrinePoint or Color.White

    ModifyTextBox({
        Id = btn.TextId,
        Text = label,
        Color = color,
        AutoSetDataProperties = false,
    })
end

function PoP.OnShrineButtonPressed(screen, button)
    if not PoP.IsHardModeSave() then
        PlaySound({ Name = "/Leftovers/SFX/OutOfAmmo", Id = button.Id })
        return
    end

    PoP.Toggle()
    PoP.UpdateShrineButtonVisual(screen)
    PlaySound({ Name = "/SFX/Menu Sounds/GeneralWhooshMENU", Id = button.Id })
end

_G["PoP_OnShrineButtonPressed"] = PoP.OnShrineButtonPressed

ModUtil.Path.Wrap("HandleScreenInput", function(baseFunc, screen)
    if screen and screen.Name == "ShrineUpgrade"
        and screen.Components
        and screen.Components.ShopBackground then

        local components = screen.Components

        if not components.PactOfPainButton then
            local btn = CreateScreenComponent({
                Name  = "ShrineUpgradeMenuConfirm",
                Group = "Combat_Menu",
                Scale = 0.8,
            })
            components.PactOfPainButton = btn

            Attach({
                Id = btn.Id,
                DestinationId = components.ShopBackground.Id,
                OffsetX = 0,
                OffsetY = 456,
            })

            btn.OnPressedFunctionName = "PoP_OnShrineButtonPressed"
            btn.Sound = "/SFX/Menu Sounds/GodBoonMenuToggle"

            local textId = CreateScreenObstacle({
                Name  = "BlankObstacle",
                Group = "Combat_Menu",
                X = 0, Y = 0,
            })
            btn.TextId = textId

            Attach({
                Id = textId,
                DestinationId = btn.Id,
                OffsetX = 0,
                OffsetY = 0,
            })

            CreateTextBox({
                Id = textId,
                Text = "",
                Font = "AlegreyaSansSCBold",
                FontSize = 24,
                Justification = "Center",
                ShadowRed = 0, ShadowGreen = 0, ShadowBlue = 0,
                ShadowAlpha = 1, ShadowBlur = 0,
                ShadowOffsetY = 2, ShadowOffsetX = 0,
            })

            PoP.UpdateShrineButtonVisual(screen)
        else
            PoP.UpdateShrineButtonVisual(screen)
        end
    end

    return baseFunc(screen)
end)

-- OPTIONAL v2: Double resource rewards when PoP is enabled
-- Uncomment when you’re ready to test.
----------------------------------------------------------------
--[[
ModUtil.Path.Wrap("AddResource", function(baseFunc, resourceName, amount, source, args)
    if PoP.IsEnabled()
        and CurrentRun
        and CurrentRun.CurrentRoom
        and source ~= "Market"
        and source ~= "Broker"
        and source ~= "CharonStore" then

        amount = amount * 2
    end
    return baseFunc(resourceName, amount, source, args)
end)
]]

----------------------------------------------------------------
-- OPTIONAL v3: Add Titan Blood (SuperLockKeys) to room rewards
-- Hell Mode only; not tied to the toggle by default.
----------------------------------------------------------------
--[[
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
                -- you can add more gates here: RequiredMinCompletedRuns, etc.
            },
            -- Weight = 0.2, -- adjust once you inspect RewardStoreData
        })
    end
}
]]
