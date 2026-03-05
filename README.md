# Ichimoku Multi-Timeframe Alignment Tools

A collection of MQL5 indicators and Expert Advisors that use Ichimoku Kinko Hyo multi-timeframe alignment to generate trade signals and execute trades. Signals fire only when all timeframes in a cascade agree on direction.

## Files

| File | Type | Description |
| :--- | :--- | :--- |
| `ichimoku-breakout.mq5` | Indicator | Independent cascade alerts (MN-H4, H4-M15, H1-M5) |
| `ichimoku-full-alignment.mq5` | Indicator | Multi-tier alignment alerts with entry/exit tracking |
| `ichimoku-full-alignment-ea.mq5` | Expert Advisor | Auto-trades based on multi-tier alignment |
| `ichimoku-breakout-scalper.mq5` | Expert Advisor | D1-M1 alignment auto-trader |

---

## ichimoku-full-alignment.mq5 (Alert Indicator)

Three-tier alignment alert system. Checks every M1 bar close across 51 symbols. Only the highest matching tier fires. Tracks active signals and alerts when alignment breaks.

### Entry Alerts

| Tier | Timeframes | Conviction |
| :--- | :--- | :--- |
| Full MN-M1 | MN, W, D, H4, H1, M30, M15, M5, M1 (9 TFs) | Highest |
| H4-M1 | H4, H1, M30, M15, M5, M1 (6 TFs) | High |
| H1-M1 | H1, M30, M15, M5, M1 (5 TFs) | Medium |

### Exit Alerts

Fires when alignment breaks. Tracks tier upgrades (H1 to H4) and downgrades (H4 to H1).

### Alert Format

```
2:31 AM | Buy GOLD (Full MN-M1)
10:45 PM | Close GOLD Long (H4-M1 broke)
```

---

## ichimoku-full-alignment-ea.mq5 (Trading EA)

Automatically opens and closes trades based on multi-tier alignment. No SL/TP — positions close only when alignment breaks.

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

## ichimoku-breakout.mq5 (Original Alert Indicator)

Three independent cascades, each triggered at its own frequency:

| Cascade | Timeframes | Trigger |
| :--- | :--- | :--- |
| MN → W → D → H4 | Monthly to 4-Hour | Every H4 bar close |
| H4 → H1 → M30 → M15 | 4-Hour to 15-Minute | Every M15 bar close |
| H1 → M30 → M15 → M5 | 1-Hour to 5-Minute | Every M5 bar close |

---

## ichimoku-breakout-scalper.mq5 (Original Trading EA)

D1 → H4 → H1 → M15 → M5 → M1 alignment auto-trader. Triggers on M1 bar close. Uses M15 Kijun for SL placement with fixed TP.

---

## Ichimoku Alignment Logic

For each timeframe, **all conditions must be true** for a bullish signal (bearish is the mirror):

- **Price** is above the cloud, Tenkan-sen, and Kijun-sen
- **Chikou Span** (shifted 26 bars back) is above the cloud, Tenkan-sen, Kijun-sen, and price at that bar

Every timeframe in the cascade must agree on direction (all bullish or all bearish). If any single timeframe is neutral or conflicts, no signal fires.

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

## Alerting

All files use three alert channels:
1. **Alert()** — MT5 popup window
2. **Print()** — Experts tab log
3. **SendNotification()** — Push notification to MT5 mobile app

Alerts include your local PC time in 12-hour format.
