function ShowWeaponUpgradeScreen( args )

		local textOffsetX = -50

		OnScreenOpened( { Flag = "WeaponUpgradeScreen", PersistCombatUI = true } )
		FreezePlayerUnit("WeaponUpgradeScreen" )
		EnableShopGamepadCursor()

		local weaponName = args.WeaponName

		ScreenAnchors.WeaponUpgradeScreen = { Components = {}, Name = "WeaponUpgradeScreen", OpenedEquippedIndex = GetEquippedWeaponTraitIndex( weaponName ) }
		local components = ScreenAnchors.WeaponUpgradeScreen.Components
		EnableShopGamepadCursor( ScreenAnchors.WeaponUpgradeScreen.Name )

		components.ShopBackgroundDim = CreateScreenComponent({ Name = "rectangle01", Group = "Combat_Menu" })
		components.ShopBackground = CreateScreenComponent({ Name = "WeaponSelectPanelBox", Group = "Combat_Menu_TraitTray_Backing", X = ScreenCenterX, Y = ScreenHeight/2 - 18})
		components.WeaponImage = CreateScreenComponent({ Name = "rectangle01", Group = "Combat_Menu_TraitTray", X = 335, Y = 435 })
		DebugAssert({ Condition = GetWeaponAspectImage( weaponName ) ~= nil, Text = "No weapon image available for " .. weaponName .. " index " .. GetEquippedWeaponTraitIndex( weaponName )})
		SetAnimation({ DestinationId = components.WeaponImage.Id, Name = GetWeaponAspectImage( weaponName )})

		SetAlpha({ Id = components.WeaponImage.Id, Fraction = 0 })
		SetThingProperty({ Property = "Ambient", Value = 0.0, DestinationId = components.WeaponImage.Id })


		-- CreateTextBox({ Id = components.ShopBackground.Id, Text = "WeaponUpgradeScreen_Header", FontSize = 24, OffsetX = -500, OffsetY = -380, Color = Color.White, Font = "AlegreyaSansSCRegular", ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2}, Justification = "Center" })
		CreateTextBox({ Id = components.ShopBackground.Id, Text = weaponName.."_Full", FontSize = 38, OffsetX = 0, OffsetY = -480, Color = Color.White, Font = "SpectralSCLightTitling", ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2}, Justification = "Center" })
		CreateTextBox({ Id = components.ShopBackground.Id, Text = weaponName.."_Full", UseDescription = true, FontSize = 20, Width = 620, OffsetX = 0, OffsetY = -406, Color = {0.643, 0.635, 0.482, 1.0}, Font = "CrimsonTextItalic", ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 2}, Justification = "Center" })
		SetScale({ Id = components.ShopBackgroundDim.Id, Fraction = 10 })
		SetColor({ Id = components.ShopBackgroundDim.Id, Color = {0.090, 0.055, 0.157, 0.6} })
		wait(0.5)
		local timesCleared = "NoClears"
		local clearTimeText = "NoClearTime"
		local heatClearText = "NoHeatClear"
		local weaponKills = "NoWeaponKills"
		local weaponSelectPanelRightString = "WeaponSelectPanel_Right"

		if GameState.TimesClearedWeapon and GameState.TimesClearedWeapon[weaponName] then
			timesCleared = GameState.TimesClearedWeapon[weaponName]
		end
		if GameState.WeaponRecordsClearTime and GameState.WeaponRecordsClearTime[weaponName] then
			clearTimeText = GetTimerString( GameState.WeaponRecordsClearTime[weaponName])
		end

		if GameState.WeaponRecordsShrinePoints and GameState.WeaponRecordsShrinePoints[weaponName] and GameState.WeaponRecordsShrinePoints[weaponName] > 0 then
			heatClearText = GameState.WeaponRecordsShrinePoints[weaponName]
		else
			weaponSelectPanelRightString = "WeaponSelectPanel_Right_Alt"
		end

		if GameState.WeaponKills and GameState.WeaponKills[weaponName] then
			weaponKills = GameState.WeaponKills[weaponName]
		end

		SetAlpha({ Id = components.WeaponImage.Id, Fraction = 1 })
		local ruScale = 0.75
		local deScale = 0.8
		local cnScale = 0.8
		local plScale = 0.8
		CreateTextBox({ Id = components.ShopBackground.Id, Text = "WeaponSelectPanel_Title", FontSize = 25, Width = 340, OffsetX = -625, OffsetY = 174, Color = {0.749, 0.749, 0.749, 1.0}, Font = "AlegreyaSansSCBold", ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2}, Justification = "Center", VerticalJustification = "Top", LineSpacingBottom = -5,
			LangPlScaleModifier = plScale
		})
		CreateTextBox({ Id = components.ShopBackground.Id, Text = "WeaponSelectPanel_Left", FontSize = 20, Width = 340, OffsetX = -795, OffsetY = 230, Color = {0.749, 0.749, 0.749, 1.0}, Font = "AlegreyaSansSCRegular", ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2}, Justification = "Left", VerticalJustification = "Top", LineSpacingBottom = -5,

				LangRuScaleModifier = ruScale,
				LangDeScaleModifier = deScale,
				LangCnScaleModifier = cnScale,
				LangPlScaleModifier = plScale,
				})
		CreateTextBox({ Id = components.ShopBackground.Id, Text = weaponSelectPanelRightString, FontSize = 20, Width = 340, OffsetX = -485, OffsetY = 230, Color = {0.749, 0.749, 0.749, 1.0}, Font = "AlegreyaSansSCRegular", ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2}, Justification = "Right", VerticalJustification = "Top",
			LineSpacingBottom = -5,
			LangRuScaleModifier = ruScale,
			LangDeScaleModifier = deScale,
			LangCnScaleModifier = cnScale,
			LangPlScaleModifier = plScale,
			LuaKey = "TempTextData",
			LuaValue =
			{
				TimesCleared = timesCleared,
				RecordClearTime = clearTimeText,
				RecordShrinePoints = heatClearText,
				WeaponKills = weaponKills,
			}})

		components.CurrentKeys = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu_TraitTray" })
		CreateTextBox({ Id = components.CurrentKeys.Id,
			Text = "MetaUpgrade_Available_SuperKeys",
			FontSize = 24,
			Width = 0,
			OffsetX = 500,
			OffsetY = -400,
			Color = Color.White,
			Font = "AlegreyaSansSCRegular",
			ShadowBlur = 0,
			ShadowColor = {0,0,0,1},
			ShadowOffset={0, 2},
			Justification = "Right",
			LuaKey = "TempTextData",
			LuaValue = { Amount = tostring(GameState.Resources.SuperLockKeys)}
		})

		PlaySound({ Name = "/SFX/Menu Sounds/GeneralWhooshMENULoud" })

		thread( PlayVoiceLines, GlobalVoiceLines.OpenedWeaponUpgradeMenuVoiceLines, true )
		--Mod start
		local bloodCost = 0

		for itemIndex, itemData in pairs( WeaponUpgradeData[weaponName] ) do
			local level = GetWeaponUpgradeLevel(weaponName, itemIndex)
			if level > 0 then
				for i = level, 1, -1 do
					bloodCost = bloodCost + itemData.Costs[i]
				end
			end
			--Mod end
			local purchaseButtonKey = "PurchaseButton"..itemIndex
			local animationName = "BoonSlot" .. itemIndex .. "_WeaponSelect"
			if IsBuyWeaponUpgradeDisabled( weaponName, itemIndex ) and IsUpgradeWeaponUpgradeDisabled( weaponName, itemIndex ) then
				animationName = "BoonSlot4_WeaponSelect"
			end
			components[purchaseButtonKey] = CreateScreenComponent({ Name = animationName, Group = "Combat_Menu_TraitTray", X = ScreenCenterX + 40, Y = 20 + itemIndex * 220})
			SetScaleX({ Id = components[purchaseButtonKey].Id, Fraction = 1 })
			SetInteractProperty({ DestinationId = components[purchaseButtonKey].Id, Property = "TooltipOffsetX", Value = 700})

			-- Upgrade description
			local itemName = "UnknownUpgrade"
			local itemIcon = "WeaponUpgrade_Unknown"
			local traitData = {}
			if itemData.DisableBuy then
				itemName = itemData.LockedUpgradeId or "UnknownUpgrade"
				itemIcon = "WeaponUpgrade_Unknown"
			elseif itemData.GameStateRequirements and ( not IsGameStateEligible(CurrentRun, itemData.GameStateRequirements) or IsGameStateEligible(CurrentRun, itemData.GameStateRequirements) and not GameState.SeenWeaponUnlocks[weaponName..itemIndex]) then
				itemName = "UnknownLockedAspect"
				itemIcon = "WeaponUpgrade_Unknown"

				if IsGameStateEligible(CurrentRun, itemData.GameStateRequirements) and not GameState.SeenWeaponUnlocks[weaponName..itemIndex] then
					thread( WeaponAspectRevealPresentation, components, itemData.TraitName, purchaseButtonKey)
					GameState.SeenWeaponUnlocks[weaponName..itemIndex] = true
				end
			elseif itemData.TraitName == nil then
				if itemData.RequiredInvestmentTraitName then
					itemName = itemData.RequiredInvestmentTraitName
					itemIcon = TraitData[itemName].Icon .. "_Large"
					if GetWeaponUpgradeLevel(weaponName, itemIndex) > 0  then
						traitData =  GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = itemName, Rarity = GetRarityKey(GetWeaponUpgradeLevel( weaponName, itemIndex ))})
						SetTraitTextData( traitData )
					else
						itemName = itemData.UpgradeUnequippedId
					end
				else
					itemName = itemData.UpgradeUnequippedId or "NothingEquipped"
					itemIcon = "WeaponUpgrade_Unknown"
				end
			else
				itemName = itemData.TraitName
				itemIcon = TraitData[itemName].Icon .. "_Large"
				traitData =  GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = itemName, Rarity = GetRarityKey(GetWeaponUpgradeLevel( weaponName, itemIndex ))})
				SetTraitTextData( traitData )

				if itemData.MaxedTraitDescription and IsWeaponUpgradeUnlocked( weaponName, itemIndex ) and not CanUpgradeWeaponUpgrade( weaponName, itemIndex ) then
					itemName = itemData.MaxedTraitDescription
				end
			end

			components[purchaseButtonKey.."Icon"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu_TraitTray" })
			Attach({ Id = components[purchaseButtonKey.."Icon"].Id, DestinationId = components[purchaseButtonKey].Id, OffsetX = 365 - 750, OffsetY = 0 })
			SetAnimation({ DestinationId = components[purchaseButtonKey.."Icon"].Id, Name = itemIcon })
			if itemIcon ~= "WeaponUpgrade_Unknown" then
				SetScale({ Id = components[purchaseButtonKey.."Icon"].Id, Fraction = 1.0 })
			end

			CreateTextBoxWithFormat({ Id = components[purchaseButtonKey].Id,
				Text = itemName,
				OffsetX = 465 - 700 + textOffsetX, OffsetY = -35,
				Width = 665,
				Justification = "Left",
				VerticalJustification = "Top",
				LineSpacingBottom = 5,
				UseDescription = true,
				Format = "BaseFormat",
				VariableAutoFormat = "BoldFormatGraft",
				TextSymbolScale = 0.8,
				LuaKey = "TooltipData",
				LuaValue = traitData,
				LangCnScaleModifier = 0.8,
				LangRuScaleModifier = 0.8,
				LangDeScaleModifier = 0.8,
				LangEsScaleModifier = 0.75,
				LangFrScaleModifier = 0.8,
				LangPtBrScaleModifier = 0.8,
				--LangPlScaleModifier = 0.8,
				LangItScaleModifier = 0.8,
				LangKoScaleModifier = 0.7,
			})

			if traitData and traitData.LimitedTime then
				CreateTextBox({ Id = components[purchaseButtonKey].Id, TextSymbolScale = 0, Text = "SeasonalItem", Color = Color.Transparent })
			end

			components[purchaseButtonKey.."Frame"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu_TraitTray" })
			Attach({ Id = components[purchaseButtonKey.."Frame"].Id, DestinationId = components[purchaseButtonKey.."Icon"].Id, OffsetX = 0, OffsetY = 0 })
			SetAnimation({ DestinationId = components[purchaseButtonKey.."Frame"].Id, Name = "Frame_Boon_Menu_Enchantment" })
			SetScale({ Id = components[purchaseButtonKey.."Frame"].Id, Fraction = 1.0 })

			components[purchaseButtonKey].OnPressedFunctionName = "HandleWeaponUpgradeSelection"
			components[purchaseButtonKey].UpgradeButtonKey = purchaseButtonKey .. "Upgrade"
			components[purchaseButtonKey].WeaponName = weaponName
			components[purchaseButtonKey].Data = itemData
			components[purchaseButtonKey].Index = itemIndex

			components[purchaseButtonKey.."Subtitle"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu_TraitTray" })
			Attach({ Id = components[purchaseButtonKey.."Subtitle"].Id, DestinationId = components[purchaseButtonKey.."Icon"].Id, OffsetX = 710, OffsetY = 33 })
			CreateTextBox({ Id = components[purchaseButtonKey.."Subtitle"].Id,
				FontSize = 24,
				Width = 0,
				OffsetX =  0,
				OffsetY = 0,
				Color = Color.White,
				Font = "AlegreyaSansSCRegular",
				ShadowBlur = 0,
				ShadowColor = {0,0,0,1},
				ShadowOffset={0, 2},
				Justification = "Right",
				LuaKey = "TempTextData",
				LuaValue = { Amount = GetNextWeaponUpgradeKeyCost( weaponName, itemIndex )}})

			components[purchaseButtonKey .. "Title"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu_TraitTray" })
			Attach({ Id = components[purchaseButtonKey.."Title"].Id, DestinationId = components[purchaseButtonKey].Id, OffsetX = textOffsetX, OffsetY = 0 })

			CreateTextBox({ Id = components[purchaseButtonKey .. "Title"].Id,
				Text = itemName,
				FontSize = 25,
				OffsetX = 465 - 700, OffsetY = -78,
				Width = 615,
				Color = Color.White,
				Font = "AlegreyaSansSCBold",
				ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
				Justification = "Left",
				VerticalJustification = "Top"
			})

			components[purchaseButtonKey .. "Level"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu_TraitTray" })
			Attach({ Id = components[purchaseButtonKey.."Level"].Id, DestinationId = components[purchaseButtonKey.."Title"].Id, OffsetX = 0, OffsetY = -75 })

			CreateTextBox({ Id = components[purchaseButtonKey .. "Level"].Id,
				FontSize = 25,
				OffsetX = 400, OffsetY = 0,
				Width = 615,
				Color = Color.White,
				Font = "AlegreyaSansSCBold",
				ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
				Justification = "Right",
				VerticalJustification = "Top",
				LuaKey = "TempTextData",
				LuaValue = { Amount = GetWeaponUpgradeLevel(weaponName, itemIndex )}})

			-- LOCK Icons
			local lockIconKey = "LockIcon"..itemIndex
			components[lockIconKey] = CreateScreenComponent({ Name = "BlankObstacle", X = ScreenCenterX, Y = 0, Group = "Combat_Menu_TraitTray" })
			Attach({ Id = components[lockIconKey].Id, DestinationId = components[purchaseButtonKey].Id, OffsetX = 365 - 753, OffsetY = -5 })
			if not IsWeaponUpgradeUnlocked( weaponName, itemIndex ) then
				SetColor({ Id = components[purchaseButtonKey.."Icon"].Id, Color = Color.DarkSlateGray })
				SetAnimation({ Name = "LockedKeepsakeIcon", DestinationId = components[lockIconKey].Id, Scale = 1.0 })
			end

			if IsWeaponUpgradeEquipped( weaponName, itemIndex ) then
				SetAnimation({ Name = "EquippedIcon", DestinationId = components[purchaseButtonKey.."Subtitle"].Id })
				TeleportCursor({ OffsetX = ScreenCenterX + 40, OffsetY = 20 + itemIndex * 220, ForceUseCheck = true })
			end

			if not IsUpgradeWeaponUpgradeDisabled( weaponName, itemIndex ) then
				if IsWeaponUpgradeUnlocked( weaponName, itemIndex ) then
					components[purchaseButtonKey .. "Upgrade" ] = CreateScreenComponent({ Name = "WeaponLevelUpArrowRight", Scale = 1.0, Group = "Combat_Menu_TraitTray" })
				else
					components[purchaseButtonKey .. "Upgrade" ] = CreateScreenComponent({ Name = "WeaponUnlockRight", Scale = 1.0, Group = "Combat_Menu_TraitTray" })
				end
				Attach({ Id = components[purchaseButtonKey .. "Upgrade"].Id, DestinationId = components[purchaseButtonKey].Id, OffsetX = 440, OffsetY = -5})
				components[purchaseButtonKey.. "Upgrade"].OnPressedFunctionName = "HandleUpgradeWeaponUpgradeSelection"
				components[purchaseButtonKey.. "Upgrade"].WeaponName = weaponName
				components[purchaseButtonKey.. "Upgrade"].Data = itemData
				components[purchaseButtonKey.. "Upgrade"].Index = itemIndex
				components[purchaseButtonKey.. "Upgrade"].Name = itemName
				components[purchaseButtonKey.."KeyCost"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu_TraitTray" })
				Attach({ Id = components[purchaseButtonKey.."KeyCost"].Id, DestinationId = components[purchaseButtonKey.."Upgrade"].Id, OffsetX = 0, OffsetY = 0 })
				local text = "MetaUpgrade_Locked_SuperKeys"
				local color = Color.White
				if not CanUpgradeWeaponUpgrade( weaponName, itemIndex ) then
					text = "Blank"
					SetColor({ Id = components[purchaseButtonKey.."KeyCost"].Id, Color = Color.DarkSlateGray })
					UseableOff({ Id = components[purchaseButtonKey .. "Upgrade"].Id })
				end
				if not HasResource("SuperLockKeys", GetNextWeaponUpgradeKeyCost( weaponName, itemIndex )) then
					color = Color.CostUnaffordable
				end
				SetInteractProperty({ DestinationId = components[purchaseButtonKey.."Upgrade"].Id, Property = "TooltipOffsetX", Value = 260})
				SetInteractProperty({ DestinationId = components[purchaseButtonKey.."Upgrade"].Id, Property = "TooltipOffsetY", Value = 5})
				CreateTextBox({ Id = components[purchaseButtonKey.. "Upgrade"].Id,
					Text = itemName,
					FontSize = 1,
					UseDescription = true,
					OffsetX = 1000, OffsetY = 0,
					Justification = "LEFT",
					Color = Color.Transparent,
					LuaKey = "TooltipData",
					LuaValue = traitData,
					ScaleTarget = 0.01,
					ScaleDuration = 0,
				})
				CreateTextBox({ Id = components[purchaseButtonKey.."KeyCost"].Id,
					Text = text,
					FontSize = 24,
					Width = 0,
					OffsetX = -4,
					OffsetY = 30,
					Color = color,
					Font = "AlegreyaSansSCBold",
					ShadowBlur = 0,
					ShadowColor = {0,0,0,1},
					ShadowOffset={0, 2},
					Justification = "Center",
					LuaKey = "TempTextData",
					LuaValue = { Amount = GetNextWeaponUpgradeKeyCost( weaponName, itemIndex ) } })

				if not CanUpgradeWeaponUpgrade( weaponName, itemIndex ) then
					ModifyTextBox({ Id = components[purchaseButtonKey.."Level"].Id, Text = "UI_TraitLevel_Max" })
				elseif GetWeaponUpgradeLevel(weaponName, itemIndex ) > 0 then
					ModifyTextBox({ Id = components[purchaseButtonKey.."Level"].Id, Text = "UI_TraitLevel", LuaKey = "TempTextData", LuaValue = { Amount = GetWeaponUpgradeLevel(weaponName, itemIndex )} })
				end
			end

			wait(0.02)
		end

		--Mod start
		local amount = bloodCost * PQOL.Config.BloodRefund.KeyCostPerBloodRefunded
		if PQOL.Config.BloodRefund.FreeMode then
			amount = 0
		end
		components.RefundButton = CreateScreenComponent({ Name = "ButtonRefund", Scale = 1, Group = "Combat_Menu_TraitTray" })
		Attach({ Id = components.RefundButton.Id, DestinationId = components.ShopBackground.Id, OffsetX = 630, OffsetY = -380 })
		components.RefundButton.OnPressedFunctionName = "RefundBlood"
		components.RefundButton.Cost = bloodCost
		components.RefundButton.KeyCost = amount
		components.RefundButton.Weapon = weaponName

		local color = Color.White
		if not PQOL.Config.BloodRefund.FreeMode or bloodCost == 0 then
			if not HasResource("LockKeys", bloodCost * PQOL.Config.BloodRefund.KeyCostPerBloodRefunded) or bloodCost == 0 then
				color = Color.CostUnaffordable
			end
		end

		CreateTextBox({ Id = components.RefundButton.Id, Text = "WeaponUpgrade_Refund", FontSize = 22, Color = color, Font = "AlegreyaSansSCBold",
		OffsetX = 35, LuaKey = "TempTextData", LuaValue = { Amount = bloodCost }, })
		if not PQOL.Config.BloodRefund.FreeMode then
			CreateTextBox({ Id = components.RefundButton.Id, Text = "WeaponUpgrade_Key_Cost", FontSize = 19, Color = color, Font = "AlegreyaSansSCBold",
			OffsetX = 35, OffsetY = 45, LuaKey = "TempTextData", LuaValue = { Amount = amount }, })
		end
		--Mod end

		components.CloseButton = CreateScreenComponent({ Name = "ButtonClose", Scale = 0.7, Group = "Combat_Menu_TraitTray_Overlay" })
		Attach({ Id = components.CloseButton.Id, DestinationId = components.ShopBackground.Id, OffsetX = 0 , OffsetY = 515 })
		components.CloseButton.OnPressedFunctionName = "CloseWeaponUpgradeScreen"
		components.CloseButton.ControlHotkey = "Cancel"

		ScreenAnchors.WeaponUpgradeScreen.KeepOpen = true
		ScreenAnchors.WeaponUpgradeScreen.CanClose = true
		thread( HandleWASDInput, ScreenAnchors.WeaponUpgradeScreen )
		HandleScreenInput( ScreenAnchors.WeaponUpgradeScreen )
	end

	function RefundBlood(screen, button)
		local weaponName = button.Weapon
		local bloodCost = button.Cost
		local keyCost = button.KeyCost
		if bloodCost > 0 and HasResource("LockKeys", keyCost) then
			for itemIndex, itemData in pairs(WeaponUpgradeData[weaponName]) do
				GameState.WeaponUnlocks[weaponName][itemIndex] = 0
			end
			SelectWeaponUpgrade( screen, weaponName, 1 )
			CloseWeaponUpgradeScreen(screen, button)
			AddResource("SuperLockKeys", bloodCost, "Item")
			if not PQOL.Config.BloodRefund.FreeMode then
				SpendResource("LockKeys", keyCost, "Item")
			end
		end
	end
