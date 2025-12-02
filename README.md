# 🚀 Ichimoku Multi-Timeframe Breakout Alert

**Author:** n30dyn4m1c (Neo Malesa)

**Development Assistance:** Code Cleanup and Documentation with the help of **ChatGPT** and **Gemini**.

This MQL5 Expert Advisor (EA) is designed to scan a user-defined list of symbols for **full Ichimoku Kinko Hyo alignment** across multiple timeframes. This alignment signals a **high-probability trend breakout**, issuing alerts and drawing a signal label on the chart when a confirmed setup is found.

---

## ✨ Key Features (Multi-Timeframe Breakout Confirmation)

* **Multi-Symbol Scanning:** Monitors a wide, customizable list of symbols (currency pairs, metals, indices, etc.).
* **Prioritized Alignment Checks:** Scans for full trend consistency across key timeframes (e.g., **H4 → M1**), prioritizing longer-term alignment for higher-quality **breakout** signals.
* **Strict Ichimoku Rules:** Enforces the **full Ichimoku bullish/bearish condition** on every timeframe checked. This rigorous confirmation minimizes false **breakouts** by ensuring trend consistency from high to low timeframes.
* **Visual Alerts:** Triggers a standard MQL5 `Alert()` box, prints the signal to the Experts tab, and draws a persistent text label on the current chart for immediate notification of a confirmed **breakout**.

---

## 🛠️ Installation and Configuration

### Parameters

| Name | Default | Description |
| :--- | :--- | :--- |
| **Symbols** | (Long List) | Comma-separated list of symbols to monitor. **Must** be valid symbols on your broker's server. |
| **Tenkan** | `9` | Tenkan-Sen period for Ichimoku (fastest line). |
| **Kijun** | `26` | Kijun-Sen period for Ichimoku (base line). |
| **SenkouB** | `52` | Senkou Span B period for Ichimoku (slower cloud boundary). |

---

## 🧠 Alignment Logic Explained (The Breakout Condition)

The EA requires a **Fully Bullish** or **Fully Bearish** state on every single timeframe within a checked range for the alert to trigger. This full alignment validates that the short-term price movement is supported by the long-term trend, confirming a sustainable **breakout**.

### Full Ichimoku State (`CheckTF` Function)

A timeframe is considered fully aligned (e.g., Bullish) only if **all** primary Ichimoku relationships confirm the direction:

* **Price Position:** Price is **outside** and above the Kumo Cloud and above both the Tenkan-Sen and Kijun-Sen.
* **Chikou Span Position:** The Chikou Span is **outside** and above the Kumo 52 bars back, and also above the Price, Tenkan-Sen, and Kijun-Sen 26 bars back.

### Priority Checks (`OnTick` Function)

Checks are performed in a strict priority order. If a strong alignment is found, indicating a powerful **breakout**, all subsequent lower-priority checks are **skipped** for that symbol on the current M1 bar close.

| Priority | Alignment Check | Timeframes Checked (Highest → Lowest) | Purpose |
| :---: | :--- | :--- | :--- |
| **1 (Highest)** | **H4 → M1** | H4, H1, M30, M15, M5, M1 | Confirms a Major Trend **Breakout**. |
| **2** | **H1 → M1** | H1, M30, M15, M5, M1 | Confirms a Mid-Term **Breakout**. |
| **3** | **M30 → M1** | M30, M15, M5, M1 | Confirms a Short-Term **Breakout**. |
| **4** | **D1 → M15** | D1, H4, H1, M30, M15 | Highest Timeframe Trend Validation. |
| **5** | **H4 → M15** | H4, H1, M30, M15 | Mid-to-High Timeframe Trend Validation. |

---

## 💻 Code Structure & Technical Notes

* **Handle Management:** Indicator handles are stored in two-dimensional global arrays (`ich` for standard TFs and `ichHTF` for higher TFs) to efficiently manage multiple timeframes across multiple symbols.
* **Time Control:** The `OnTick()` function uses the `lastM1bar` variable to ensure the complex alignment checks are performed only once per closed M1 bar, preventing excessive resource use and reducing alert spam.
* **Functionality:** The `AlignRange()` and `Align_X_Y()` functions are responsible for iterating through the required timeframes and validating the consistent Ichimoku state using the `CheckTF()` function.
