# BadgePrestige Tests

This directory contains tests for the BadgePrestige.lua mod.

## Prerequisites

To run these tests, you need:

1. Lua 5.3 or higher
2. Busted testing framework

### Installing Prerequisites

On Ubuntu/Debian:
```bash
sudo apt update
sudo apt install -y lua5.3 liblua5.3-dev luarocks
sudo luarocks install busted
```

On other systems, refer to:
- Lua: https://www.lua.org/download.html
- Busted: https://lunarmodules.github.io/busted/

## Running Tests

### Method 1: Using the test runner script

```bash
chmod +x run_tests.sh
./run_tests.sh
```

### Method 2: Running busted directly

```bash
busted badgeprestige_spec.lua
```

For verbose output:
```bash
busted badgeprestige_spec.lua --verbose
```

## Test Coverage

The test suite covers:

### Core Functions
- **HasAnyBadgeTotals**: Tests the function that checks if any badge bonuses are active
- **ApplyBadgeTierDelta**: Tests the function that applies badge tier bonuses

### Badge Tiers Tested
All 10 badge tier categories are tested:
1. Ranks 1-5: Max Health (flat bonuses)
2. Ranks 6-10: Damage Multiplier (tenths of % bonuses)
3. Ranks 11-15: Damage Reduction (tenths of % bonuses)
4. Ranks 16-20: Move Speed (% bonuses)
5. Ranks 21-25: Attack Speed (% bonuses)
6. Ranks 26-30: Attack Damage (% bonuses)
7. Ranks 31-35: Special Damage (% bonuses)
8. Ranks 36-40: Cast Damage (flat bonuses)
9. Ranks 41-45: Crit Damage (% bonuses)
10. Ranks 46-50: Crit Chance (% bonuses)

### Edge Cases
- Null/nil values
- Zero and negative ranks
- String to number conversions
- Ranks beyond defined tiers
- Cumulative effects across multiple rank increases

## Test Results

Running the test suite should produce output like:
```
●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●
39 successes / 0 failures / 0 errors / 0 pending : 0.025128 seconds
```

## Understanding the Tests

The tests use mocked game API functions since BadgePrestige.lua is a mod that depends on the Hades game environment. The test file includes:

- Mock implementations of `GameState`, `BadgeTierTotals`, and other game API objects
- Isolated copies of the core logic functions being tested
- Comprehensive test cases for all badge tiers and edge cases

This approach allows us to test the core logic independently of the game environment.
