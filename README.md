# Ichimoku Multi-Timeframe Alignment Tools

A collection of MQL5 indicators and Expert Advisors that use Ichimoku Kinko Hyo multi-timeframe alignment to generate trade signals and execute trades. Signals fire only when all timeframes in a cascade agree on direction.

## Files

| File | Type | Description |
| :--- | :--- | :--- |
| `ichimoku-breakout.mq5` | Indicator | Independent cascade alerts (MN-H4, H4-M15, H1-M5) |
| `ichimoku-full-alignment.mq5` | Indicator | Multi-tier alignment alerts with entry/exit tracking |
| `ichimoku-full-alignment-ea.mq5` | EA | Auto-trades based on multi-tier alignment (MN-M1, H4-M1, H1-M1) |
| `ichimoku-full-alignment-ea-gold.mq5` | EA | Gold-only version of multi-tier alignment EA |
| `ichimoku-breakout-scalper.mq5` | EA | D1-M1 alignment auto-trader |
| `bottom-up-alignment-ea.mq5` | EA | Bottom-up M5+M1 alignment entry, M1 exit |
| `bottom-up-alignment-ea-gold.mq5` | EA | Gold-only bottom-up alignment EA |
| `d1-m15-alignment-ea.mq5` | EA | D1 cloud + M15 alignment with ADX filter, trailing Kijun exit |
| `d1-m15-alignment-ea-gold.mq5` | EA | Gold-only D1+M15 alignment EA |
| `pullback-breakout-ea.mq5` | EA | **Pullback breakout**: D1+H4 trend, M15 pullback re-alignment entry |
| `pullback-breakout-ea-gold.mq5` | EA | Gold-only pullback breakout EA |
| `pullback-scalp-ea.mq5` | EA | **Pullback scalp**: H1+M15 trend, M1 pullback re-alignment entry |
| `pullback-scalp-ea-gold.mq5` | EA | Gold-only pullback scalp EA |

---

## Pullback Breakout EA (Swing)

Enters after a pullback completes within an established higher-timeframe trend, avoiding overextended entries. Designed to capture the start of new impulse legs rather than chasing moves already in progress.

### Strategy Logic

1. **D1 trending** — ADX > 25, price above/below cloud, cloud thick enough
2. **H4 fully aligned** — all 5 Ichimoku conditions confirm intermediate trend
3. **M15 re-aligned** — M15 currently shows full alignment in same direction
4. **Pullback occurred** — M15 lost alignment within last 10 bars (price pulled back)
5. **Not overextended** — price within 1.5x ATR of H4 Kijun
6. **Spread OK** — spread < 30% of H4 ATR

### 3-Tier Trailing Exit

| Condition | Exit Trigger | Purpose |
| :--- | :--- | :--- |
| Losing (< 0 ATR) | M5 Kijun break | Cut losses fast |
| Small profit (0–1 ATR) | M15 Kijun break | Protect small gains |
| Large profit (> 1 ATR) | H1 Kijun break | Let profits run |
| H4 reversal | Immediate close | Structural safety net |

### Continuation Re-entry

After a Kijun break exit, the move often resumes in the same direction. If the same direction re-aligns within the re-entry window (`ReentryMins`), the EA re-enters without requiring a pullback — the exit itself was the pullback. This also overrides the loss cooldown for same-direction entries. Alerts show "(Continuation)" to distinguish from fresh entries.

### Risk Management

- **Cooldown**: 60 minutes after a losing exit before re-entry (overridden by continuation)
- **Continuation window**: 120 minutes to re-enter same direction after exit (swing), 30 minutes (scalp)
- **Max positions**: 8 simultaneous (configurable)
- **Spread filter**: Skips entry during wide spreads

### Parameters

| Parameter | Default | Description |
| :--- | :--- | :--- |
| `MinADX` | 25.0 | Minimum D1 ADX for trend confirmation |
| `MinCloudPts` | 0 | Minimum D1 cloud thickness in points (0=disabled) |
| `PullbackBars` | 10 | M15 bars to look back for lost alignment |
| `MaxKijunATR` | 1.5 | Max distance from H4 Kijun in ATR multiples |
| `CooldownMins` | 60 | Minutes to wait after losing exit |
| `MaxSpreadATR` | 0.3 | Max spread as fraction of H4 ATR (0=disabled) |
| `MaxPositions` | 8 | Max simultaneous positions (0=unlimited) |
| `ReentryMins` | 120 | Minutes after exit to allow continuation re-entry (0=disabled) |

---

## Pullback Scalp EA

Same pullback breakout logic shifted to lower timeframes for intraday scalping.

### Timeframe Mapping

| Role | Swing | Scalp |
| :--- | :--- | :--- |
| Trend filter | D1 cloud + ADX | H1 cloud + ADX |
| Intermediate | H4 full alignment | M15 full alignment |
| Entry trigger | M15 pullback re-alignment | M1 pullback re-alignment |
| Hard exit | H4 reversal | M15 reversal |
| Exit (losing) | M5 Kijun | M1 Kijun |
| Exit (small profit) | M15 Kijun | M5 Kijun |
| Exit (large profit) | H1 Kijun | M15 Kijun |
| ATR reference | H4 | M15 |

### Key Differences from Swing

- Triggers on **M1 bar close** (vs M5)
- **15-minute cooldown** after losses (vs 60)
- **15 M1 bars** pullback lookback (vs 10 M15 bars)
- **30-minute continuation window** (vs 120)

---

## D1 + M15 Alignment EA

Entry: D1 price above/below cloud + D1 ADX trending + M15 full Ichimoku alignment. Exit: Trailing Kijun — M5 when losing, H1 when winning.

---

## Multi-Tier Alignment EA

Three-tier system trading MN-M1, H4-M1, and H1-M1 alignment cascades with tier-specific exits and position sizing.

### Entry Rules

| Tier | Alignment Required | Positions | Lot Size |
| :--- | :--- | :--- | :--- |
| Full MN-M1 | 9 TFs all agree | 3 | 0.20 |
| H4-M1 | 6 TFs all agree | 3 | 0.10 |
| H1-M1 | 5 TFs all agree | 1 | 0.10 |

### Exit Rules

| Tier | Closes when... |
| :--- | :--- |
| Full MN-M1 | M15 breaks alignment |
| H4-M1 | M5 breaks alignment |
| H1-M1 | M1 breaks alignment |

---

## Bottom-Up Alignment EA

Entry: M1 and M5 both fully aligned. Exit: M1 breaks alignment. Fastest-reacting strategy — enters and exits on the lowest timeframes.

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
