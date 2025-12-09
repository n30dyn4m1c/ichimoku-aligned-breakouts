//+------------------------------------------------------------------+
//| Ichimoku Multi-TF Alignment Alerts (H4→M1, H1→M1, M30→M1) + TK   |
//|------------------------------------------------------------------|
//| Original Code: n30dyn4m1c, Neo Malesa                           |
//| Development Assistance: ChatGPT and Gemini                       |
//| Added logic for Monthly, Weekly, Daily, H4 alignment             |
//+------------------------------------------------------------------+
#property strict

//--- Input Parameters ---
input string Symbols = "EURUSD,GBPUSD,USDJPY,USDCHF,USDCAD,AUDUSD,NZDUSD,EURGBP,EURJPY,EURCHF,EURCAD,EURAUD,EURNZD,GBPJPY,GBPCHF,GBPCAD,GBPAUD,GBPNZD,AUDJPY,AUDNZD,AUDCAD,AUDCHF,NZDJPY,NZDCAD,NZDCHF,CADJPY,CHFJPY,GOLD,SILVER,XAUJPY,XAUCNH,XAUEUR,XPDUSD,XPTUSD,BTCUSD,BTCEUR,BTCGBP,DOGEUSD,ETHBTC,LTCUSD,SHIBUSD,SOLUSD,XRPUSD,OILCash,BRENTCash,NGASCash,US30Cash,US500Cash,US100Cash";
//input string Symbols = "GOLD,US30Cash,BTCUSD"; // Use when only monitoring these three
input int    Tenkan  = 9;
input int    Kijun   = 26;
input int    SenkouB = 52;

//--- Constants and Global Variables ---
#define MAX_SYMS 60
#define TF_COUNT 6
// *** MODIFIED: HTF_COUNT is now 7 for MN1, W1, D1, H4, H1, M30, M15 ***
#define HTF_COUNT 7

// 0..5 = M1, M5, M15, M30, H1, H4
ENUM_TIMEFRAMES TFs[TF_COUNT] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4};
// *** MODIFIED: Added PERIOD_MN1 and PERIOD_W1 to the beginning of the HTFs array ***
// 0..6 = MN1, W1, D1, H4, H1, M30, M15
ENUM_TIMEFRAMES HTFs[HTF_COUNT] = {PERIOD_MN1, PERIOD_W1, PERIOD_D1, PERIOD_H4, PERIOD_H1, PERIOD_M30, PERIOD_M15};

int    ich[MAX_SYMS][TF_COUNT];      // Handles for TFs[0] to TFs[5]
int    ichHTF[MAX_SYMS][HTF_COUNT];  // Handles for HTFs[0] to HTFs[6]
string syms[MAX_SYMS];
int    symsCount = 0;
datetime lastM1bar = 0;

//==============================================================
// Initialization and Deinitialization
//==============================================================

//--- Utility function to parse the input symbol list ---
int ParseSymbols(string list)
{
    string parts[];
    int n = StringSplit(list, ',', parts);
    int cnt = 0;

    for(int i = 0; i < n && cnt < MAX_SYMS; i++)
    {
        string sym = parts[i];
        StringTrimLeft(sym);
        StringTrimRight(sym);
        if(SymbolSelect(sym, true)) syms[cnt++] = sym;
    }
    return cnt;
}

int OnInit()
{
    symsCount = ParseSymbols(Symbols);
    if(symsCount <= 0) return(INIT_FAILED);

    // Load standard Ichimoku handles (M1 to H4)
    for(int s = 0; s < symsCount; s++)
    {
        for(int t = 0; t < TF_COUNT; t++)
        {
            ich[s][t] = iIchimoku(syms[s], TFs[t], Tenkan, Kijun, SenkouB);
            if(ich[s][t] == INVALID_HANDLE) return(INIT_FAILED);
        }
    }

    // Load high-TF Ichimoku handles (MN1 to M15)
    // *** MODIFIED: Loop limit is now HTF_COUNT (7) ***
    for(int s = 0; s < symsCount; s++)
    {
        for(int t = 0; t < HTF_COUNT; t++)
        {
            ichHTF[s][t] = iIchimoku(syms[s], HTFs[t], Tenkan, Kijun, SenkouB);
            if(ichHTF[s][t] == INVALID_HANDLE) return INIT_FAILED;
        }
    }

    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    // Release standard Ichimoku handles
    for(int s = 0; s < symsCount; s++)
    {
        for(int t = 0; t < TF_COUNT; t++)
        {
            IndicatorRelease(ich[s][t]);
        }
    }

    // Release high-TF Ichimoku handles
    // *** MODIFIED: Loop limit is now HTF_COUNT (7) ***
    for(int s = 0; s < symsCount; s++)
    {
        for(int t = 0; t < HTF_COUNT; t++)
        {
            IndicatorRelease(ichHTF[s][t]);
        }
    }
}

//==============================================================
// Alerting and Drawing Functions
//==============================================================

//--- Draws the signal label on the current chart symbol only ---
void DrawSignalLabel(const string sym, const string label, const string dir)
{
    if(sym != _Symbol) return; // Draw only on current chart

    long    chart_id = ChartID();
    string  name     = "IchAlign_" + sym + "_" + label;

    ObjectDelete(chart_id, name);

    datetime t = TimeCurrent();
    double   price = SymbolInfoDouble(sym, SYMBOL_BID);

    // Adjust vertical position of the label
    double point = SymbolInfoDouble(sym, SYMBOL_POINT);
    if(dir == "Bullish") price += 50 * point;
    else                 price -= 50 * point;

    if(!ObjectCreate(chart_id, name, OBJ_TEXT, 0, t, price)) return;

    string txt = sym + " | " + label + " | " + dir + " | Check M15 TKx+Pback";
    ObjectSetString(chart_id, name, OBJPROP_TEXT, txt);
    ObjectSetInteger(chart_id, name, OBJPROP_FONTSIZE, 9);
    ObjectSetInteger(chart_id, name, OBJPROP_COLOR,
                     dir == "Bullish" ? clrLime : clrRed);
}

//--- Sends an alert and prints the message ---
void AlertMsg(const string label, const string sym, const int st)
{
    string dir = (st == 1 ? "Bullish" : "Bearish");
    string msg = sym + " | " + label + " | " + dir + " | Check M15 TKx+Pback";
    Alert(msg);
    Print(msg);
    DrawSignalLabel(sym, label, dir);
}

//==============================================================
// Ichimoku Rule Check and Alignment Functions
//==============================================================

//--- Checks Ichimoku rules for a single TF (1=bull, -1=bear, 0=none) ---
int CheckTF(string sym, ENUM_TIMEFRAMES tf, int h)
{
    MqlRates rt[];
    if(CopyRates(sym, tf, 0, 120, rt) <= 0) return 0;
    ArraySetAsSeries(rt, true);

    int sh           = 1;      // Last closed bar
    int priceCloud   = sh + 26; // Cloud is plotted +26 periods (compare 26 back)
    int chShift      = sh + 26; // Chikou is 26 periods back (Price 26 back)
    int chCloud      = sh + 52; // Cloud at chikou bar (52 periods back)

    if(ArraySize(rt) <= chCloud) return 0;

    double ten[1], kij[1], senA[1], senB[1], chik[1];
    double ten_ch[1], kij_ch[1], senA_ch[1], senB_ch[1];

    // Current TK and Cloud (26 back)
    if(CopyBuffer(h, 0, sh, 1, ten) <= 0) return 0;
    if(CopyBuffer(h, 1, sh, 1, kij) <= 0) return 0;
    if(CopyBuffer(h, 2, priceCloud, 1, senA) <= 0) return 0;
    if(CopyBuffer(h, 3, priceCloud, 1, senB) <= 0) return 0;

    // Chikou, TK at Chikou position (26 back), and Cloud (52 back)
    if(CopyBuffer(h, 4, chShift, 1, chik) <= 0) return 0;
    if(CopyBuffer(h, 0, chShift, 1, ten_ch) <= 0) return 0;
    if(CopyBuffer(h, 1, chShift, 1, kij_ch) <= 0) return 0;
    if(CopyBuffer(h, 2, chCloud, 1, senA_ch) <= 0) return 0;
    if(CopyBuffer(h, 3, chCloud, 1, senB_ch) <= 0) return 0;

    double closeP   = rt[sh].close;
    double price_26 = rt[chShift].close;

    double cHi  = MathMax(senA[0], senB[0]);
    double cLo  = MathMin(senA[0], senB[0]);
    double cHiC = MathMax(senA_ch[0], senB_ch[0]);
    double cLoC = MathMin(senA_ch[0], senB_ch[0]);

    // Price relative to TK/Cloud on the current bar
    bool priceAbove = (closeP > cHi && closeP > ten[0] && closeP > kij[0]);
    bool priceBelow = (closeP < cLo && closeP < ten[0] && closeP < kij[0]);

    // Chikou relative to TK/Cloud/Price on the 26-bar-back position
    bool chAbove = (chik[0] > cHiC &&
                    chik[0] > ten_ch[0] &&
                    chik[0] > kij_ch[0] &&
                    chik[0] > price_26);
    bool chBelow = (chik[0] < cLoC &&
                    chik[0] < ten_ch[0] &&
                    chik[0] < kij_ch[0] &&
                    chik[0] < price_26);

    // Full Bullish Alignment
    if(priceAbove && chAbove) return 1;
    // Full Bearish Alignment
    if(priceBelow && chBelow) return -1;

    return 0;
}

//--- Checks alignment across a range of TFs (e.g., H4->M1 is hi=5, lo=0) ---
int AlignRange(const int s, const int hi, const int lo)
{
    int state = 0; // Final alignment state: 1=Bullish, -1=Bearish, 0=None

    // Iterate from highest TF (hi) down to lowest TF (lo)
    for(int t = hi; t >= lo; t--)
    {
        int st = CheckTF(syms[s], TFs[t], ich[s][t]);

        // If any TF is not aligned, the whole range is not aligned
        if(st == 0) return 0;

        // Set the reference state on the highest TF
        if(t == hi)
        {
            state = st;
        }
        // Check if the current TF alignment matches the highest TF
        else if(st != state)
        {
            return 0; // Alignment mismatch
        }
    }
    return state; // Full alignment detected
}

// --- NEW FUNCTION: Check Monthly → Weekly → Daily → H4 alignment (using HTFs array) ---
// HTFs indexes: 0=MN1, 1=W1, 2=D1, 3=H4
int Align_MN_W_D_H4(int s)
{
    int state = 0; // Final alignment state: 1=Bullish, -1=Bearish, 0=None

    // Loop through MN1 (0), W1 (1), D1 (2), H4 (3)
    for(int t = 0; t <= 3; t++)
    {
        int st = CheckTF(syms[s], HTFs[t], ichHTF[s][t]);

        if(st == 0) return 0;

        if(t == 0) state = st; // Set reference state from Monthly
        else if(st != state) return 0;
    }

    return state;
}

//--- Check D1→H4→H1→M30→M15 alignment (using HTFs array) ---
int Align_D_H4_H1_M30_M15(int s)
{
    int state = 0; // Final alignment state: 1=Bullish, -1=Bearish, 0=None

    // HTFs: 0=MN1, 1=W1, 2=D1, 3=H4, 4=H1, 5=M30, 6=M15
    // We want D1 (2) through M15 (6)
    for(int t = 2; t < HTF_COUNT; t++) // Start at D1 (index 2)
    {
        int st = CheckTF(syms[s], HTFs[t], ichHTF[s][t]);

        if(st == 0) return 0;

        if(t == 2) state = st; // Set reference state from D1
        else if(st != state) return 0;
    }

    return state;
}

//--- Alignment: H4 → H1 → M30 → M15 (using standard TFs array) ---
int Align_H4_H1_M30_M15(int s)
{
    // TF indexes: H4=5, H1=4, M30=3, M15=2 (from TFs array)
    return AlignRange(s, 5, 2);
}

//--- M15 Tenkan-Kijun cross check (1=up, -1=down, 0=none) ---
int TKCrossM15(int ichHandleM15, int lookback = 36)
{
    double ten[], kij[];
    ArraySetAsSeries(ten, true);
    ArraySetAsSeries(kij, true);

    // Copy shifts 1 (last closed bar) up to lookback+1
    int cnt = lookback + 1;
    if(CopyBuffer(ichHandleM15, 0, 1, cnt, ten) < cnt) return 0;
    if(CopyBuffer(ichHandleM15, 1, 1, cnt, kij) < cnt) return 0;

    // Check for a cross between ten[i] and ten[i-1]
    for(int i = lookback; i >= 1; i--)
    {
        double prevDiff = ten[i] - kij[i];   // Difference at bar i (older bar)
        double curDiff  = ten[i - 1] - kij[i - 1]; // Difference at bar i-1 (newer bar)

        // Previous was Tenkan < Kijun AND Current is Tenkan > Kijun
        if(prevDiff < 0.0 && curDiff > 0.0) return 1;  // TK cross up (Bullish)

        // Previous was Tenkan > Kijun AND Current is Tenkan < Kijun
        if(prevDiff > 0.0 && curDiff < 0.0) return -1; // TK cross down (Bearish)
    }
    return 0;
}

//==============================================================
// Main Loop
//==============================================================

void OnTick()
{
    //--- 1. Check for new M1 bar close on the current chart symbol ---
    MqlRates m1[];
    if(CopyRates(_Symbol, PERIOD_M1, 0, 5, m1) <= 0) return;
    ArraySetAsSeries(m1, true);

    // m1[1].time is the timestamp of the last *closed* M1 bar
    if(m1[1].time == lastM1bar) return;
    lastM1bar = m1[1].time;

    //--- 2. Loop through all symbols and check alignments ---
    for(int s = 0; s < symsCount; s++)
    {
        int st = 0;
        string currentSym = syms[s];

        // *** NEW CHECK: Monthly → Weekly → Daily → H4 Alignment ***
        int stSuperHTF = Align_MN_W_D_H4(s);
        if(stSuperHTF != 0)
        {
            AlertMsg("MN→W→D→H4", currentSym, stSuperHTF);
            // This is a powerful, long-term signal, but we can allow other signals
            // to fire as well, as they refer to a different trade type.
            // For the highest priority, you could add 'continue;' here.
        }
        // -----------------------------------------------------------------

        //--- Check 1: Highest Alignment: H4 → M1 (TFs indexes 5..0) ---
        st = AlignRange(s, 5, 0);
        if(st != 0)
        {
            AlertMsg("H4→M1", currentSym, st);
            continue; // Stop checking this symbol if the highest level alert is triggered
        }

        //--- Check 2: Next Alignment: H1 → M1 (TFs indexes 4..0) ---
        st = AlignRange(s, 4, 0);
        if(st != 0)
        {
            AlertMsg("H1→M1", currentSym, st);
            continue;
        }

        //--- Check 3: Next Alignment: M30 → M1 (TFs indexes 3..0) ---
        st = AlignRange(s, 3, 0);
        if(st != 0)
        {
            AlertMsg("M30→M1", currentSym, st);
            continue;
        }

        //--- Check 4: New additional alert: D→H4→H1→M30→M15 (HTFs array) ---
        int stHTF = Align_D_H4_H1_M30_M15(s);
        if(stHTF != 0)
        {
            AlertMsg("D→H4→H1→M30→M15", currentSym, stHTF);
            // No 'continue' here, as it's an additional, separate condition
        }

        //--- Check 5: H4→H1→M30→M15 alignment (TFs indexes 5..2) ---
        int stH4H1M30M15 = Align_H4_H1_M30_M15(s);
        if(stH4H1M30M15 != 0)
        {
            AlertMsg("H4→H1→M30→M15", currentSym, stH4H1M30M15);
        }
    }
}
