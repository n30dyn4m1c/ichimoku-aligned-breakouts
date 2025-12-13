# ☁️ Ichimoku Multi-Timeframe Alignment Alerts (Customized & Independent)

This MQL5 indicator is designed for traders who utilize the Ichimoku Kinko Hyo system combined with multi-timeframe (MTF) analysis. It monitors a large list of symbols for alignment across specific, customized groups of timeframes, ensuring signals are generated only when a trend cascade is confirmed from high to low.

The core feature of this indicator is the use of **independent, time-triggered checks**, which run only when the lowest analyzed bar in a sequence closes. This guarantees signal precision while minimizing computational overhead.

## 🌟 Key Features

* **Customized Alignment Sequences:** Monitors three distinct trading horizons (Long, Medium, and Short-Term Swing).
* **Independent Firing:** Each alignment check operates independently, triggered only by the closure of its most sensitive bar (**H4, M15, or M5**).
* **Comprehensive Monitoring:** Checks a wide default list of 50+ Forex, Index, Metal, and Crypto symbols.
* **Multi-Alerting:** Generates `Alert()` windows, sends `Print()` messages to the Experts tab, and transmits immediate **Push Notifications** to your mobile device.
* **Visual Confirmation:** Draws a signal label on the chart of the current symbol when an alignment is found.

## ⚙️ Alignment Logic and Trigger Frequencies

The indicator uses three separate, critical checks, each running at its own optimal frequency. This structure is designed to catch trends across multiple trading styles:

| Alignment Check Sequence | Trading Horizon | Timeframes Checked | Trigger Frequency | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **1. MN → W → D → H4** | Long-Term Trend | Monthly to 4-Hour | **Every H4 Bar Close** | Confirms major structural trend. |
| **2. H4 → H1 → M30 → M15** | Medium-Term Swing | 4-Hour to 15-Minute | **Every M15 Bar Close** | Confirms primary swing direction. |
| **3. H1 → M30 → M15 → M5** | Short-Term Swing | 1-Hour to 5-Minute | **Every M5 Bar Close** | Identifies short-term entry momentum. |



## 📝 Installation

1.  Download the `.mq5` file.
2.  Open your MetaTrader 5 (MT5) platform.
3.  Go to `File` -> `Open Data Folder`.
4.  Navigate to `MQL5` -> `Indicators`.
5.  Place the `.mq5` file into the `Indicators` folder.
6.  Close and reopen MT5, or right-click the `Indicators` folder in the Navigator window and select `Refresh`.
7.  Attach the indicator to any chart.

## 🛠️ Settings & Parameters

The indicator is highly configurable via the **Inputs** tab:

| Parameter | Default Value | Description |
| :--- | :--- | :--- |
| `Symbols` | (50+ symbols) | **Comma-separated list** of all symbols you wish to monitor. Ensure they are available in your Market Watch. |
| `Tenkan` | `9` | Ichimoku Tenkan-sen period. |
| `Kijun` | `26` | Ichimoku Kijun-sen period. |
| `SenkouB` | `52` | Ichimoku Senkou Span B period (Cloud B). |

### Customizing Symbols

To reduce lag or focus on specific pairs, you can modify the `Symbols` input. For example, to only monitor three key instruments: GOLD,US30Cash,BTCUSD

## 🚨 Alerting Mechanism

The indicator uses a robust alerting system to ensure you never miss a confirmed signal:

1.  **`Alert()`:** A pop-up window appears on your MT5 terminal.
2.  **`Print()`:** A detailed message is logged in the `Experts` tab of the terminal window.
3.  **`SendNotification()`:** An instant push notification is sent to your registered MT5 mobile app.
4.  **Visual Label:** A text label indicating the alignment (`Bullish` or `Bearish`) is drawn on the chart of the aligned symbol (if the chart is open).

***

