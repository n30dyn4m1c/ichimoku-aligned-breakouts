# Ichimoku Multi-Timeframe Alignment Tools

A collection of MQL5 indicators and Expert Advisors that use Ichimoku Kinko Hyo multi-timeframe alignment to generate trade signals and execute trades. Signals fire only when all timeframes in a cascade agree on direction.

## Files

| File | Type | Description |
| :--- | :--- | :--- |
| `ichimoku-breakout.mq5` | Indicator | Independent cascade alerts (MN-H4, H4-M15, H1-M5) |
| `ichimoku-full-alignment.mq5` | Indicator | Multi-tier alignment alerts with entry/exit tracking |
| `ichimoku-breakout-scalper.mq5` | Expert Advisor | D1-M1 alignment auto-trader (Gold, fixed SL/TP) |
| `ichimoku-full-alignment-ea.mq5` | Expert Advisor | Multi-tier alignment EA (51 symbols) |
| `ichimoku-full-alignment-ea-gold.mq5` | Expert Advisor | Multi-tier alignment EA (Gold only) |
| `bottom-up-alignment-ea.mq5` | Expert Advisor | M5+M1 bottom-up alignment EA (51 symbols) |
| `bottom-up-alignment-ea-gold.mq5` | Expert Advisor | M5+M1 bottom-up alignment EA (Gold only) |
| `d1-m15-alignment-ea.mq5` | Expert Advisor | D1 trend + M15 alignment EA (51 symbols) |
| `d1-m15-alignment-ea-gold.mq5` | Expert Advisor | D1 trend + M15 alignment EA (Gold only) |
| `pullback-breakout-ea.mq5` | Expert Advisor | Pullback re-alignment EA (51 symbols) |
| `pullback-breakout-ea-gold.mq5` | Expert Advisor | Pullback re-alignment EA (Gold only) |

---

## ichimoku-full-alignment.mq5 (Alert Indicator)

Three-tier alignment alert system. Checks every M1 bar close across 51 symbols. Only the highest matching tier fires. Tracks active signals and alerts when alignment breaks, downgrades, or upgrades.

### Entry Alerts

| Tier | Timeframes | Conviction |
| :--- | :--- | :--- |
| Full MN-M1 | MN, W, D, H4, H1, M30, M15, M5, M1 (9 TFs) | Highest |
| H4-M1 | H4, H1, M30, M15, M5, M1 (6 TFs) | High |
| H1-M1 | H1, M30, M15, M5, M1 (5 TFs) | Medium |

### Exit Alerts

Fires when alignment breaks completely or direction flips. Also alerts on tier upgrades (e.g. H1 strengthens to H4) and downgrades (e.g. H4 weakens to H1).

### Alert Format

```
2:31 AM | Buy GOLD (Full MN-M1)
10:45 PM | Close GOLD Long (Full MN-M1 broke)
```

---

## ichimoku-full-alignment-ea.mq5 / ichimoku-full-alignment-ea-gold.mq5 (Trading EA)

Automatically opens and closes trades based on multi-tier alignment. No SL/TP — positions close only when the tier's exit timeframe breaks alignment.

The `-gold` variant defaults to `GOLD,XAUUSD` instead of the full 51-symbol list.

### Entry Rules

| Tier | Alignment Required | Positions | Lot Size | Total |
| :--- | :--- | :--- | :--- | :--- |
| Full MN-M1 | 9 TFs all agree | 3 | 0.20 | 0.60 |
| H4-M1 | 6 TFs all agree | 3 | 0.10 | 0.30 |
| H1-M1 | 5 TFs all agree | 1 | 0.10 | 0.10 |

Tiers are exclusive — only the highest matching tier opens trades.

### Exit Rules

| Tier | Closes when... |
| :--- | :--- |
| Full MN-M1 | M15 breaks alignment |
| H4-M1 | M5 breaks alignment |
| H1-M1 | M1 breaks alignment |

### Features

- Trigger: M1 bar close
- Restart recovery via magic numbers (syncs state from open positions)
- Configurable slippage (default 30 points)
- 12-hour PC time on all alerts

### Parameters

| Parameter | Default | Description |
| :--- | :--- | :--- |
| `Symbols` | 51 symbols | Comma-separated symbol list |
| `Tenkan` | 9 | Tenkan-sen period |
| `Kijun` | 26 | Kijun-sen period |
| `SenkouB` | 52 | Senkou Span B period |
| `FullLots` | 0.20 | Lot size per position (Full tier) |
| `H4Lots` | 0.10 | Lot size per position (H4 tier) |
| `H1Lots` | 0.10 | Lot size per position (H1 tier) |
| `Slippage` | 30 | Max slippage in points |

---

## bottom-up-alignment-ea.mq5 / bottom-up-alignment-ea-gold.mq5 (Trading EA)

Simplified two-timeframe EA that enters when M5 and M1 both fully align. The fastest-reacting EA in the collection — no higher timeframe filters.

The `-gold` variant defaults to `GOLD,XAUUSD`.

### Entry Rules

M5 and M1 must both show full Ichimoku alignment in the same direction. One position per symbol. No SL/TP.

### Exit Rules

Position closes when M1 breaks alignment (neutral or flips direction).

### Features

- Trigger: M1 bar close
- Restart recovery via magic numbers
- Configurable slippage (default 30 points)

### Parameters

| Parameter | Default | Description |
| :--- | :--- | :--- |
| `Symbols` | 51 symbols | Comma-separated symbol list |
| `Tenkan` | 9 | Tenkan-sen period |
| `Kijun` | 26 | Kijun-sen period |
| `SenkouB` | 52 | Senkou Span B period |
| `Lots` | 0.10 | Lot size |
| `Slippage` | 30 | Max slippage in points |

---

## d1-m15-alignment-ea.mq5 / d1-m15-alignment-ea-gold.mq5 (Trading EA)

Two-layer EA that uses D1 as a trend filter and M15 as the entry trigger. Includes an ADX filter to avoid choppy markets and a trailing Kijun exit that adapts based on whether the trade is winning or losing.

The `-gold` variant defaults to `GOLD,XAUUSD`.

### Entry Rules

All three conditions must agree in direction:

1. **D1 ADX ≥ MinADX** — market is trending (default 25)
2. **D1 price above/below cloud** — defines the bias direction
3. **M15 full Ichimoku alignment** — price and Chikou both fully aligned

Optional: `MinCloudPts` filters out thin D1 clouds (choppy conditions).

### Exit Rules

Exit adapts to trade P&L:

| State | Exit |
| :--- | :--- |
| Losing | M5 Kijun break (tight stop) |
| Winning | H1 Kijun break (let profits run) |

### Features

- Trigger: M5 bar close
- Restart recovery via magic numbers
- Configurable slippage (default 30 points)

### Parameters

| Parameter | Default | Description |
| :--- | :--- | :--- |
| `Symbols` | 51 symbols | Comma-separated symbol list |
| `Tenkan` | 9 | Tenkan-sen period |
| `Kijun` | 26 | Kijun-sen period |
| `SenkouB` | 52 | Senkou Span B period |
| `Lots` | 0.10 | Lot size |
| `Slippage` | 30 | Max slippage in points |
| `MinADX` | 25.0 | Minimum D1 ADX to confirm trend |
| `ADXPeriod` | 14 | ADX period |
| `MinCloudPts` | 0 | Minimum D1 cloud thickness in points (0 = disabled) |

---

## pullback-breakout-ea.mq5 / pullback-breakout-ea-gold.mq5 (Trading EA)

The most selective EA in the collection. Requires a confirmed trend across three timeframes, then waits for a pullback and re-alignment on M15 before entering. Includes overextension guards, spread filter, cooldown, and a three-tier Kijun exit scaled to ATR profit.

The `-gold` variant defaults to `GOLD,XAUUSD,XAUJPY,XAUCNH,XAUEUR` and has a tighter `MaxPositions` cap of 3 (vs 8 for the base).

### Entry Rules (7 steps, all must pass)

1. D1 ADX ≥ MinADX (trending market)
2. D1 price above/below cloud (trend direction)
3. H4 full Ichimoku alignment agrees with D1 direction
4. M15 currently fully aligned in same direction
5. M15 had a pullback within the last `PullbackBars` bars (alignment was briefly lost)
6. Price is not overextended from H4 Kijun (within `MaxKijunATR` × H4 ATR)
7. Spread ≤ `MaxSpreadATR` × H4 ATR (0 = disabled)

### Exit Rules

| Profit (in H4 ATR) | Exit |
| :--- | :--- |
| Negative (losing) | M5 Kijun break |
| < 1 ATR (small profit) | M15 Kijun break |
| ≥ 1 ATR (large profit) | H1 Kijun break |
| H4 alignment flips | Hard exit immediately |

A cooldown period (`CooldownMins`) blocks re-entry after a losing exit on the same symbol.

### Features

- Trigger: M5 bar close
- Restart recovery via magic numbers
- Max simultaneous positions cap (`MaxPositions`)
- Configurable slippage (default 30 points)

### Parameters

| Parameter | Default | Description |
| :--- | :--- | :--- |
| `Symbols` | 51 symbols | Comma-separated symbol list |
| `Tenkan` | 9 | Tenkan-sen period |
| `Kijun` | 26 | Kijun-sen period |
| `SenkouB` | 52 | Senkou Span B period |
| `Lots` | 0.10 | Lot size |
| `Slippage` | 30 | Max slippage in points |
| `MinADX` | 25.0 | Minimum D1 ADX to confirm trend |
| `ADXPeriod` | 14 | ADX period |
| `MinCloudPts` | 0 | Minimum D1 cloud thickness in points (0 = disabled) |
| `PullbackBars` | 10 | M15 bars to look back for a lost alignment |
| `MaxKijunATR` | 1.5 | Max distance from H4 Kijun in ATR multiples |
| `ATRPeriod` | 14 | ATR period for overextension check |
| `CooldownMins` | 60 | Minutes to block re-entry after a losing exit |
| `MaxSpreadATR` | 0.3 | Max spread as fraction of H4 ATR (0 = disabled) |
| `MaxPositions` | 8 | Max simultaneous open positions (0 = unlimited) |

---

## ichimoku-breakout.mq5 (Original Alert Indicator)

Three independent cascades, each triggered at its own frequency. No exit tracking — fires on every qualifying bar close.

| Cascade | Timeframes | Trigger |
| :--- | :--- | :--- |
| MN → W → D → H4 | Monthly to 4-Hour | Every H4 bar close |
| H4 → H1 → M30 → M15 | 4-Hour to 15-Minute | Every M15 bar close |
| H1 → M30 → M15 → M5 | 1-Hour to 5-Minute | Every M5 bar close |

---

## ichimoku-breakout-scalper.mq5 (Original Trading EA)

D1 → H4 → H1 → M15 → M5 → M1 alignment auto-trader for Gold. Triggers on M1 bar close. Uses M15 Kijun for SL placement with a fixed TP in points.

---

## Ichimoku Alignment Logic

For each timeframe, **all conditions must be true** for a bullish signal (bearish is the mirror):

- **Price** is above the cloud, Tenkan-sen, and Kijun-sen
- **Chikou Span** (shifted 26 bars back) is above the cloud, Tenkan-sen, Kijun-sen, and price at that bar

Every timeframe in the cascade must agree on direction (all bullish or all bearish). If any single timeframe is neutral or conflicts, no signal fires.

---

## Installation

### Indicators
1. Place the `.mq5` file in `MQL5/Indicators/`
2. Restart MT5 or refresh the Navigator
3. Attach to any chart

### Expert Advisors
1. Place the `.mq5` file in `MQL5/Experts/`
2. Restart MT5 or refresh the Navigator
3. Attach to a chart and enable Auto Trading

## Customizing Symbols

All files accept a comma-separated `Symbols` input. Includes XAUUSD/XAGUSD aliases for broker compatibility. To monitor fewer symbols:

```
GOLD,BTCUSD,US30Cash
```

Symbols not available in your Market Watch are automatically skipped.

## Gold Variants

Each EA has a `-gold` variant with a narrower default symbol list targeting Gold pairs. The logic is identical — only the `Symbols` default and `MaxPositions` (where applicable) differ. Use the Gold variants if you only want to trade Gold or want a lighter resource footprint.

## Alerting

All files use three alert channels:
1. **Alert()** — MT5 popup window
2. **Print()** — Experts tab log
3. **SendNotification()** — Push notification to MT5 mobile app

Alerts include your local PC time in 12-hour format.
