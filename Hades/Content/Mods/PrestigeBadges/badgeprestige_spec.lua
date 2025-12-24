-- Test suite for BadgePrestige.lua
-- This file tests the core logic of the BadgePrestige mod

describe("BadgePrestige", function()
    local GameState
    local BadgeTierTotals
    local TraitData
    local CurrentRun
    local ModUtil
    
    -- Mock functions
    local function mock_game_environment()
        -- Reset GameState before each test
        GameState = {
            BadgeBuffTotals = {
                MaxHealth = 0,
                DamageMult = 0,
                DamageReduction = 0,
                MoveSpeed = 0,
                AttackSpeed = 0,
                AttackDamage = 0,
                SpecialDamage = 0,
                CastDamage = 0,
                CritDamage = 0,
                CritChance = 0,
            },
            BadgeRank = 0
        }
        
        -- Initialize BadgeTierTotals
        BadgeTierTotals = {
            [1]  = { 2, 4, 6, 8, 10 },     -- Max HP (flat)
            [2]  = { 8, 16, 24, 32, 40 },  -- Damage dealt (tenths of %)
            [3]  = { 6, 12, 18, 24, 30 },  -- Damage reduction (tenths of %)
            [4]  = { 2, 4, 6, 8, 10 },     -- Move speed % (whole)
            [5]  = { 2, 4, 6, 8, 10 },     -- Attack speed % (whole)
            [6]  = { 1, 2, 3, 4, 5 },      -- Attack damage % (whole)
            [7]  = { 1, 2, 3, 4, 5 },      -- Special damage % (whole)
            [8]  = { 4, 8, 12, 16, 20 },   -- Cast damage (flat)
            [9]  = { 4, 8, 12, 16, 20 },   -- Crit damage % (whole)
            [10] = { 1, 2, 3, 4, 5 },      -- Crit chance % (whole)
        }
        
        TraitData = {}
        CurrentRun = { Hero = {} }
        
        -- Mock ModUtil functions
        ModUtil = {
            Mod = {
                Register = function() end
            },
            DebugCall = function(fn) fn() end,
            Path = {
                Wrap = function(name, fn) end
            }
        }
    end
    
    -- Core functions to test (extracted from BadgePrestige.lua)
    local function HasAnyBadgeTotals()
        local t = GameState.BadgeBuffTotals
        if not t then return false end
        for _, v in pairs(t) do
            if (tonumber(v) or 0) ~= 0 then
                return true
            end
        end
        return false
    end
    
    local function ApplyBadgeTierDelta(newBadgeRank)
        newBadgeRank = tonumber(newBadgeRank) or 0
        if newBadgeRank <= 0 then
            return
        end
        
        local rankIndex = math.ceil(newBadgeRank / 5)
        local tierIndex = ((newBadgeRank - 1) % 5) + 1
        
        local tierTotals = BadgeTierTotals and BadgeTierTotals[rankIndex]
        if not tierTotals then
            return
        end
        
        local previous = (tierIndex > 1 and tierTotals[tierIndex - 1]) or 0
        local current  = tierTotals[tierIndex] or 0
        local delta    = current - previous
        if delta <= 0 then
            return
        end
        
        local totals = GameState and GameState.BadgeBuffTotals
        if not totals then
            return
        end
        
        if rankIndex == 1 then
            totals.MaxHealth = (tonumber(totals.MaxHealth) or 0) + delta
        elseif rankIndex == 2 then
            totals.DamageMult = (tonumber(totals.DamageMult) or 0) + delta
        elseif rankIndex == 3 then
            totals.DamageReduction = (tonumber(totals.DamageReduction) or 0) + delta
        elseif rankIndex == 4 then
            totals.MoveSpeed = (tonumber(totals.MoveSpeed) or 0) + delta
        elseif rankIndex == 5 then
            totals.AttackSpeed = (tonumber(totals.AttackSpeed) or 0) + delta
        elseif rankIndex == 6 then
            totals.AttackDamage = (tonumber(totals.AttackDamage) or 0) + delta
        elseif rankIndex == 7 then
            totals.SpecialDamage = (tonumber(totals.SpecialDamage) or 0) + delta
        elseif rankIndex == 8 then
            totals.CastDamage = (tonumber(totals.CastDamage) or 0) + delta
        elseif rankIndex == 9 then
            totals.CritDamage = (tonumber(totals.CritDamage) or 0) + delta
        elseif rankIndex == 10 then
            totals.CritChance = (tonumber(totals.CritChance) or 0) + delta
        end
    end
    
    before_each(function()
        mock_game_environment()
    end)
    
    describe("HasAnyBadgeTotals", function()
        it("should return false when BadgeBuffTotals is nil", function()
            GameState.BadgeBuffTotals = nil
            assert.is_false(HasAnyBadgeTotals())
        end)
        
        it("should return false when all badge totals are zero", function()
            assert.is_false(HasAnyBadgeTotals())
        end)
        
        it("should return true when MaxHealth is non-zero", function()
            GameState.BadgeBuffTotals.MaxHealth = 5
            assert.is_true(HasAnyBadgeTotals())
        end)
        
        it("should return true when DamageMult is non-zero", function()
            GameState.BadgeBuffTotals.DamageMult = 8
            assert.is_true(HasAnyBadgeTotals())
        end)
        
        it("should return true when any stat is non-zero", function()
            GameState.BadgeBuffTotals.CritChance = 1
            assert.is_true(HasAnyBadgeTotals())
        end)
    end)
    
    describe("ApplyBadgeTierDelta", function()
        describe("Rank 1-5 (MaxHealth)", function()
            it("should add 2 HP at rank 1", function()
                ApplyBadgeTierDelta(1)
                assert.equals(2, GameState.BadgeBuffTotals.MaxHealth)
            end)
            
            it("should add 2 more HP at rank 2 (total 4)", function()
                ApplyBadgeTierDelta(1)
                ApplyBadgeTierDelta(2)
                assert.equals(4, GameState.BadgeBuffTotals.MaxHealth)
            end)
            
            it("should add 2 more HP at rank 3 (total 6)", function()
                ApplyBadgeTierDelta(1)
                ApplyBadgeTierDelta(2)
                ApplyBadgeTierDelta(3)
                assert.equals(6, GameState.BadgeBuffTotals.MaxHealth)
            end)
            
            it("should reach 10 HP at rank 5", function()
                for i = 1, 5 do
                    ApplyBadgeTierDelta(i)
                end
                assert.equals(10, GameState.BadgeBuffTotals.MaxHealth)
            end)
        end)
        
        describe("Rank 6-10 (DamageMult)", function()
            it("should add 8 tenths-of-% damage at rank 6", function()
                ApplyBadgeTierDelta(6)
                assert.equals(8, GameState.BadgeBuffTotals.DamageMult)
            end)
            
            it("should add 8 more tenths-of-% damage at rank 7 (total 16)", function()
                ApplyBadgeTierDelta(6)
                ApplyBadgeTierDelta(7)
                assert.equals(16, GameState.BadgeBuffTotals.DamageMult)
            end)
            
            it("should reach 40 tenths-of-% (4%) damage at rank 10", function()
                for i = 6, 10 do
                    ApplyBadgeTierDelta(i)
                end
                assert.equals(40, GameState.BadgeBuffTotals.DamageMult)
            end)
        end)
        
        describe("Rank 11-15 (DamageReduction)", function()
            it("should add 6 tenths-of-% damage reduction at rank 11", function()
                ApplyBadgeTierDelta(11)
                assert.equals(6, GameState.BadgeBuffTotals.DamageReduction)
            end)
            
            it("should reach 30 tenths-of-% (3%) damage reduction at rank 15", function()
                for i = 11, 15 do
                    ApplyBadgeTierDelta(i)
                end
                assert.equals(30, GameState.BadgeBuffTotals.DamageReduction)
            end)
        end)
        
        describe("Rank 16-20 (MoveSpeed)", function()
            it("should add 2% move speed at rank 16", function()
                ApplyBadgeTierDelta(16)
                assert.equals(2, GameState.BadgeBuffTotals.MoveSpeed)
            end)
            
            it("should reach 10% move speed at rank 20", function()
                for i = 16, 20 do
                    ApplyBadgeTierDelta(i)
                end
                assert.equals(10, GameState.BadgeBuffTotals.MoveSpeed)
            end)
        end)
        
        describe("Rank 21-25 (AttackSpeed)", function()
            it("should add 2% attack speed at rank 21", function()
                ApplyBadgeTierDelta(21)
                assert.equals(2, GameState.BadgeBuffTotals.AttackSpeed)
            end)
            
            it("should reach 10% attack speed at rank 25", function()
                for i = 21, 25 do
                    ApplyBadgeTierDelta(i)
                end
                assert.equals(10, GameState.BadgeBuffTotals.AttackSpeed)
            end)
        end)
        
        describe("Rank 26-30 (AttackDamage)", function()
            it("should add 1% attack damage at rank 26", function()
                ApplyBadgeTierDelta(26)
                assert.equals(1, GameState.BadgeBuffTotals.AttackDamage)
            end)
            
            it("should reach 5% attack damage at rank 30", function()
                for i = 26, 30 do
                    ApplyBadgeTierDelta(i)
                end
                assert.equals(5, GameState.BadgeBuffTotals.AttackDamage)
            end)
        end)
        
        describe("Rank 31-35 (SpecialDamage)", function()
            it("should add 1% special damage at rank 31", function()
                ApplyBadgeTierDelta(31)
                assert.equals(1, GameState.BadgeBuffTotals.SpecialDamage)
            end)
            
            it("should reach 5% special damage at rank 35", function()
                for i = 31, 35 do
                    ApplyBadgeTierDelta(i)
                end
                assert.equals(5, GameState.BadgeBuffTotals.SpecialDamage)
            end)
        end)
        
        describe("Rank 36-40 (CastDamage)", function()
            it("should add 4 cast damage at rank 36", function()
                ApplyBadgeTierDelta(36)
                assert.equals(4, GameState.BadgeBuffTotals.CastDamage)
            end)
            
            it("should reach 20 cast damage at rank 40", function()
                for i = 36, 40 do
                    ApplyBadgeTierDelta(i)
                end
                assert.equals(20, GameState.BadgeBuffTotals.CastDamage)
            end)
        end)
        
        describe("Rank 41-45 (CritDamage)", function()
            it("should add 4% crit damage at rank 41", function()
                ApplyBadgeTierDelta(41)
                assert.equals(4, GameState.BadgeBuffTotals.CritDamage)
            end)
            
            it("should reach 20% crit damage at rank 45", function()
                for i = 41, 45 do
                    ApplyBadgeTierDelta(i)
                end
                assert.equals(20, GameState.BadgeBuffTotals.CritDamage)
            end)
        end)
        
        describe("Rank 46-50 (CritChance)", function()
            it("should add 1% crit chance at rank 46", function()
                ApplyBadgeTierDelta(46)
                assert.equals(1, GameState.BadgeBuffTotals.CritChance)
            end)
            
            it("should reach 5% crit chance at rank 50", function()
                for i = 46, 50 do
                    ApplyBadgeTierDelta(i)
                end
                assert.equals(5, GameState.BadgeBuffTotals.CritChance)
            end)
        end)
        
        describe("Edge cases", function()
            it("should handle rank 0 gracefully", function()
                ApplyBadgeTierDelta(0)
                assert.equals(0, GameState.BadgeBuffTotals.MaxHealth)
            end)
            
            it("should handle negative rank gracefully", function()
                ApplyBadgeTierDelta(-5)
                assert.equals(0, GameState.BadgeBuffTotals.MaxHealth)
            end)
            
            it("should handle nil rank gracefully", function()
                ApplyBadgeTierDelta(nil)
                assert.equals(0, GameState.BadgeBuffTotals.MaxHealth)
            end)
            
            it("should handle string rank by converting to number", function()
                ApplyBadgeTierDelta("1")
                ApplyBadgeTierDelta("2")
                ApplyBadgeTierDelta("3")
                assert.equals(6, GameState.BadgeBuffTotals.MaxHealth)
            end)
            
            it("should handle rank beyond defined tiers gracefully", function()
                -- Rank 51 would be rankIndex 11, which doesn't exist
                ApplyBadgeTierDelta(51)
                -- Should not crash, and should not modify any stats
                assert.equals(0, GameState.BadgeBuffTotals.MaxHealth)
            end)
            
            it("should handle nil GameState gracefully", function()
                GameState = nil
                ApplyBadgeTierDelta(1)
                -- Should not crash
            end)
            
            it("should handle nil BadgeBuffTotals gracefully", function()
                GameState.BadgeBuffTotals = nil
                ApplyBadgeTierDelta(1)
                -- Should not crash
            end)
        end)
        
        describe("Cumulative effects", function()
            it("should correctly accumulate multiple rank increases", function()
                -- Apply ranks 1-3 for MaxHealth
                ApplyBadgeTierDelta(1)
                ApplyBadgeTierDelta(2)
                ApplyBadgeTierDelta(3)
                
                -- Apply ranks 6-8 for DamageMult
                ApplyBadgeTierDelta(6)
                ApplyBadgeTierDelta(7)
                ApplyBadgeTierDelta(8)
                
                assert.equals(6, GameState.BadgeBuffTotals.MaxHealth)
                assert.equals(24, GameState.BadgeBuffTotals.DamageMult)
            end)
            
            it("should handle multiple stats being upgraded simultaneously", function()
                -- Max out first two tiers
                for i = 1, 10 do
                    ApplyBadgeTierDelta(i)
                end
                
                assert.equals(10, GameState.BadgeBuffTotals.MaxHealth)
                assert.equals(40, GameState.BadgeBuffTotals.DamageMult)
            end)
        end)
    end)
    
    describe("Badge tier calculation logic", function()
        it("should correctly calculate rankIndex for various ranks", function()
            -- Ranks 1-5 should map to rankIndex 1
            for rank = 1, 5 do
                local rankIndex = math.ceil(rank / 5)
                assert.equals(1, rankIndex, "Rank " .. rank .. " should map to rankIndex 1")
            end
            
            -- Ranks 6-10 should map to rankIndex 2
            for rank = 6, 10 do
                local rankIndex = math.ceil(rank / 5)
                assert.equals(2, rankIndex, "Rank " .. rank .. " should map to rankIndex 2")
            end
            
            -- Rank 46 should map to rankIndex 10
            assert.equals(10, math.ceil(46 / 5))
        end)
        
        it("should correctly calculate tierIndex for various ranks", function()
            -- Rank 1 -> tierIndex 1
            assert.equals(1, ((1 - 1) % 5) + 1)
            
            -- Rank 5 -> tierIndex 5
            assert.equals(5, ((5 - 1) % 5) + 1)
            
            -- Rank 6 -> tierIndex 1
            assert.equals(1, ((6 - 1) % 5) + 1)
            
            -- Rank 10 -> tierIndex 5
            assert.equals(5, ((10 - 1) % 5) + 1)
            
            -- Rank 23 -> tierIndex 3
            assert.equals(3, ((23 - 1) % 5) + 1)
        end)
    end)
end)
