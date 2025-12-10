//+------------------------------------------------------------------+
//| Ichimoku Multi-TF Alignment Alerts (Final Customized Frequencies) |
//|------------------------------------------------------------------|
//| Checks: Monthly→H4, H4→M15, H1→M5                                |
//| Triggered by: H4, M15, and M5 bar close, respectively.           |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window 

//--- Input Parameters ---
input string Symbols = "EURUSD,GBPUSD,USDJPY,USDCHF,USDCAD,AUDUSD,NZDUSD,EURGBP,EURJPY,EURCHF,EURCAD,EURAUD,EURNZD,GBPJPY,GBPCHF,GBPCAD,GBPAUD,GBPNZD,AUDJPY,AUDNZD,AUDCAD,AUDCHF,NZDJPY,NZDCAD,NZDCHF,CADJPY,CHFJPY,GOLD,SILVER,XAUJPY,XAUCNH,XAUEUR,XPDUSD,XPTUSD,BTCUSD,BTCEUR,BTCGBP,DOGEUSD,ETHBTC,LTCUSD,SHIBUSD,SOLUSD,XRPUSD,OILCash,BRENTCash,NGASCash,US30Cash,US500Cash,US100Cash";
input int    Tenkan  = 9;
input int    Kijun   = 26;
input int    SenkouB = 52;

//--- Constants and Global Variables ---
#define MAX_SYMS 60
#define TF_COUNT 6
#define HTF_COUNT 7

// 0..5 = M1, M5, M15, M30, H1, H4
ENUM_TIMEFRAMES TFs[TF_COUNT] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4};
// 0..6 = MN1, W1, D1, H4, H1, M30, M15
ENUM_TIMEFRAMES HTFs[HTF_COUNT] = {PERIOD_MN1, PERIOD_W1, PERIOD_D1, PERIOD_H4, PERIOD_H1, PERIOD_M30, PERIOD_M15};

int    ich[MAX_SYMS][TF_COUNT];
int    ichHTF[MAX_SYMS][HTF_COUNT];
string syms[MAX_SYMS];
int    symsCount = 0;

// *** Time Trackers for Custom Frequencies ***
datetime lastM5bar = 0;   // Trigger for H1 -> M5 checks
datetime lastM15bar = 0; // Trigger for H4 -> M15 checks
datetime lastH4bar = 0;   // Trigger for MN -> H4 checks


//==============================================================
// Initialization and Deinitialization (Unchanged)
//==============================================================

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

    for(int s = 0; s < symsCount; s++)
    {
        for(int t = 0; t < TF_COUNT; t++)
        {
            ich[s][t] = iIchimoku(syms[s], TFs[t], Tenkan, Kijun, SenkouB);
            if(ich[s][t] == INVALID_HANDLE) return(INIT_FAILED);
        }
    }

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
    for(int s = 0; s < symsCount; s++)
    {
        for(int t = 0; t < TF_COUNT; t++) IndicatorRelease(ich[s][t]);
        for(int t = 0; t < HTF_COUNT; t++) IndicatorRelease(ichHTF[s][t]);
    }
}

//==============================================================
// Alerting and Drawing Functions (Unchanged)
//==============================================================

void DrawSignalLabel(const string sym, const string label, const string dir)
{
    if(sym != _Symbol) return; 

    long    chart_id = ChartID();
    string  name     = "IchAlign_" + sym + "_" + label;

    ObjectDelete(chart_id, name);

    datetime t = TimeCurrent();
    double   price = SymbolInfoDouble(sym, SYMBOL_BID);

    double point = SymbolInfoDouble(sym, SYMBOL_POINT);
    if(dir == "Bullish") price += 50 * point;
    else                 price -= 50 * point;

    if(!ObjectCreate(chart_id, name, OBJ_TEXT, 0, t, price)) return;

    string txt = sym + " | " + label + " | " + dir; 
    ObjectSetString(chart_id, name, OBJPROP_TEXT, txt);
    ObjectSetInteger(chart_id, name, OBJPROP_FONTSIZE, 9);
    ObjectSetInteger(chart_id, name, OBJPROP_COLOR,
                     dir == "Bullish" ? clrLime : clrRed);
}

void AlertMsg(const string label, const string sym, const int st)
{
    string dir = (st == 1 ? "Bullish" : "Bearish");
    string msg = sym + " | " + label + " | " + dir; 
    
    Alert(msg);
    
    SendNotification(msg); 
    
    DrawSignalLabel(sym, label, dir);
}

//==============================================================
// Ichimoku Rule Check and Alignment Functions
//==============================================================

int CheckTF(string sym, ENUM_TIMEFRAMES tf, int h)
{
    MqlRates rt[];
    if(CopyRates(sym, tf, 0, 120, rt) <= 0) return 0;
    ArraySetAsSeries(rt, true);

    int sh           = 1;
    int priceCloud   = sh + 26;
    int chShift      = sh + 26;
    int chCloud      = sh + 52;

    if(ArraySize(rt) <= chCloud) return 0;

    double ten[1], kij[1], senA[1], senB[1], chik[1];
    double ten_ch[1], kij_ch[1], senA_ch[1], senB_ch[1];

    if(CopyBuffer(h, 0, sh, 1, ten) <= 0) return 0;
    if(CopyBuffer(h, 1, sh, 1, kij) <= 0) return 0;
    if(CopyBuffer(h, 2, priceCloud, 1, senA) <= 0) return 0;
    if(CopyBuffer(h, 3, priceCloud, 1, senB) <= 0) return 0;

    if(CopyBuffer(h, 4, chShift, 1, chik) <= 0) return 0;
    if(CopyBuffer(h, 0, chShift, 1, ten_ch) <= 0) return 0;
    if(CopyBuffer(h, 1, chShift, 1, kij_ch) <= 0) return 0;
    if(CopyBuffer(h, 2, chCloud, 1, senA_ch) <= 0) return 0;
    if(CopyBuffer(h, 3, chCloud, 1, senB_ch) <= 0) return 0;

    double closeP   = rt[sh].close;
    double price_26 = rt[chShift].close;

    double cHi  = MathMax(senA[0], senB[0]);
    double cLo  = MathMin(senA[0], senB[0]);
    double cHiC = MathMax(senA_ch[0], senB_ch[0]);
    double cLoC = MathMin(senA_ch[0], senB_ch[0]);

    bool priceAbove = (closeP > cHi && closeP > ten[0] && closeP > kij[0]);
    bool priceBelow = (closeP < cLo && closeP < ten[0] && closeP < kij[0]);

    bool chAbove = (chik[0] > cHiC &&
                    chik[0] > ten_ch[0] &&
                    chik[0] > kij_ch[0] &&
                    chik[0] > price_26);
    bool chBelow = (chik[0] < cLoC &&
                    chik[0] < ten_ch[0] &&
                    chik[0] < kij_ch[0] &&
                    chik[0] < price_26);

    if(priceAbove && chAbove) return 1;
    if(priceBelow && chBelow) return -1;

    return 0;
}

// Re-usable function for alignments using the standard Ichimoku handle array (ich)
int AlignRange(const int s, const int hi, const int lo)
{
    int state = 0;

    for(int t = hi; t >= lo; t--)
    {
        int st = CheckTF(syms[s], TFs[t], ich[s][t]);

        if(st == 0) return 0;

        if(t == hi)
        {
            state = st;
        }
        else if(st != state)
        {
            return 0;
        }
    }
    return state;
}

// --- 1. MN1 → W1 → D1 → H4 Alignment (Uses HTFs array: 0, 1, 2, 3) ---
int Align_MN_W_D_H4(int s)
{
    int state = 0;

    for(int t = 0; t <= 3; t++) 
    {
        int st = CheckTF(syms[s], HTFs[t], ichHTF[s][t]);

        if(st == 0) return 0;

        if(t == 0) state = st;
        else if(st != state) return 0;
    }

    return state;
}


// --- 2. H4 → H1 → M30 → M15 Alignment (Uses TFs array: 5, 4, 3, 2) ---
int Align_H4_H1_M30_M15(int s)
{
    return AlignRange(s, 5, 2);
}

// --- 3. H1 → M30 → M15 → M5 Alignment (Uses TFs array: 4, 3, 2, 1) ---
int Align_H1_M5(int s)
{
    return AlignRange(s, 4, 1);
}


//==============================================================
// Main Loop - Customized for H4, M15, and M5 Triggers
//==============================================================

void OnTick()
{
    //--- 1. Determine which time-based checks to run based on bar closure ---
    
    // H4 Check (Trigger for MN->H4)
    MqlRates h4[];
    bool checkH4 = false;
    if(CopyRates(_Symbol, PERIOD_H4, 0, 5, h4) > 0)
    {
        ArraySetAsSeries(h4, true);
        if(h4[1].time != lastH4bar)
        {
            lastH4bar = h4[1].time;
            checkH4 = true;
        }
    }
    
    // M15 Check (Trigger for H4->M15)
    MqlRates m15[];
    bool checkM15 = false;
    if(CopyRates(_Symbol, PERIOD_M15, 0, 5, m15) > 0)
    {
        ArraySetAsSeries(m15, true);
        if(m15[1].time != lastM15bar)
        {
            lastM15bar = m15[1].time;
            checkM15 = true;
        }
    }

    // M5 Check (Trigger for H1->M5)
    // Note: The M5 check is the fastest running check now.
    MqlRates m5[];
    bool checkM5 = false;
    if(CopyRates(_Symbol, PERIOD_M5, 0, 5, m5) > 0)
    {
        ArraySetAsSeries(m5, true);
        if(m5[1].time != lastM5bar)
        {
            lastM5bar = m5[1].time;
            checkM5 = true;
        }
    }

    //--- 2. Loop through all symbols and execute the three independent checks ---
    for(int s = 0; s < symsCount; s++)
    {
        string currentSym = syms[s];
        int st = 0;
        
        // =========================================================================
        // A. LONG-TERM TREND: MN → W → D → H4 (Triggered by H4 close)
        // =========================================================================
        if(checkH4)
        {
            st = Align_MN_W_D_H4(s);
            if(st != 0)
            {
                AlertMsg("MN→W→D→H4", currentSym, st);
            }
        }
        
        // =========================================================================
        // B. MEDIUM-TERM SWING: H4 → H1 → M30 → M15 (Triggered by M15 close)
        // =========================================================================
        if(checkM15)
        {
            st = Align_H4_H1_M30_M15(s);
            if(st != 0)
            {
                AlertMsg("H4→H1→M30→M15", currentSym, st);
            }
        }
        
        // =========================================================================
        // C. SHORT-TERM SWING: H1 → M30 → M15 → M5 (Triggered by M5 close)
        // =========================================================================
        if(checkM5)
        {
            st = Align_H1_M5(s);
            if(st != 0)
            {
                AlertMsg("H1→M30→M15→M5", currentSym, st);
            }
        }
    }
}
