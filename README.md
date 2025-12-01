# 📈 Ichimoku Multi-Timeframe Alignment Alert

**Author:** [n30dyn4m1c, Neo Malesa]
**Development Assistance:** Code, Cleanup, and Documentation with the help of **ChatGPT** and **Gemini**.

This MQL5 Expert Advisor (EA) is designed to scan a user-defined list of symbols for **full Ichimoku Kinko Hyo alignment** across multiple timeframes, issuing alerts and drawing a signal label on the chart when a high-probability alignment is found.

---

## ✨ Features

* **Multi-Symbol Scanning:** Monitors a wide list of symbols (currency pairs, metals, indices, etc.).
* **Timeframe Alignment Checks:** Prioritized checks for full Ichimoku alignment across key ranges (e.g., **H4 → M1**).
* **Strict Ichimoku Rules:** Enforces the **full Ichimoku bullish/bearish condition** on every timeframe checked (Price vs. Cloud, Price vs. Tenkan/Kijun, and Chikou Span vs. Cloud/Price 26).
* **Visual Alerts:** Triggers a standard MQL5 `Alert()`, prints the signal to the Experts tab, and draws a persistent text label on the current chart.

---

## 🛠️ Installation and Configuration

### Parameters

| Name | Default | Description |
| :--- | :--- | :--- |
| **Symbols** | (Long List) | Comma-separated list of symbols to monitor. Must be valid symbols on your broker's server. |
| **Tenkan** | `9` | Tenkan-Sen period for Ichimoku. |
| **Kijun** | `26` | Kijun-Sen period for Ichimoku. |
| **SenkouB** | `52` | Senkou Span B period for Ichimoku. |

---

## 🧠 Alignment Logic Explained

The EA requires a **Fully Bullish** or **Fully Bearish** state on every timeframe within a checked range for the alert to trigger.

### Full Ichimoku State (`CheckTF` Function)

A timeframe is considered aligned only if **all** primary Ichimoku relationships confirm the direction:

* **Price Position:** Price is **outside** and on the correct side of the Kumo Cloud and both the Tenkan-Sen and Kijun-Sen.
* **Chikou Span Position:** The Chikou Span is **outside** and on the correct side of the Kumo 52 bars back, and also on the correct side of the Price, Tenkan-Sen, and Kijun-Sen 26 bars back. 

### Priority Checks (`OnTick` Function)

Checks are performed in a strict priority order. If an alignment is found at a higher priority level, all subsequent lower-priority checks are **skipped** for that symbol on the current M1 bar close.

| Priority | Alignment Check | Timeframes Checked (Highest → Lowest) |
| :---: | :--- | :--- |
| **1 (Highest)** | **H4 → M1** | H4, H1, M30, M15, M5, M1 |
| **2** | **H1 → M1** | H1, M30, M15, M5, M1 |
| **3** | **M30 → M1** | M30, M15, M5, M1 |
| **4** | **D1 → M15** | D1, H4, H1, M30, M15 |
| **5** | **H4 → M15** | H4, H1, M30, M15 |

---

## 💻 Code Structure & Technical Notes

* **Handle Management:** Indicator handles are stored in two-dimensional global arrays (`ich` and `ichHTF`) to efficiently manage multiple timeframes across multiple symbols.
* **Time Control:** The `OnTick()` function uses the `lastM1bar` variable and `CopyRates` on the M1 timeframe to ensure the complex alignment checks are performed only once per closed M1 bar, preventing excessive resource use.
