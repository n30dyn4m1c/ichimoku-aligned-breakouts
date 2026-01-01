//+------------------------------------------------------------------+
//| Ichimoku Multi-TF Alignment Alerts (No Drawing Functions)        |
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

ENUM_TIMEFRAMES TFs[TF_COUNT] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4};
ENUM_TIMEFRAMES HTFs[HTF_COUNT] = {PERIOD_MN1, PERIOD_W1, PERIOD_D1, PERIOD_H4, PERIOD_H1, PERIOD_M30, PERIOD_M15};

int    ich[MAX_SYMS][TF_COUNT];
int    ichHTF[MAX_SYMS][HTF_COUNT];
string syms[MAX_SYMS];
int    symsCount = 0;

datetime lastM5bar = 0;   
datetime lastM15bar = 0; 
datetime lastH4bar = 0;   

//==============================================================
// Initialization and Deinitialization
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
// Alerting Functions
//==============================================================

void AlertMsg(const string label, const string sym, const int st)
{
    string dir = (st == 1 ? "Bullish" : "Bearish");
    string msg = sym + "| " + label + " " + dir + "| CheckRisk"; 
    
    Alert(msg);
    SendNotification(msg); 
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

    bool chAbove = (chik[0] > cHiC && chik[0] > ten_ch[0] && chik[0] > kij_ch[0] && chik[0] > price_26);
    bool chBelow = (chik[0] < cLoC && chik[0] < ten_ch[0] && chik[0] < kij_ch[0] && chik[0] < price_26);

    if(priceAbove && chAbove) return 1;
    if(priceBelow && chBelow) return -1;

    return 0;
}

int AlignRange(const int s, const int hi, const int lo)
{
    int state = 0;
    for(int t = hi; t >= lo; t--)
    {
        int st = CheckTF(syms[s], TFs[t], ich[s][t]);
        if(st == 0) return 0;
        if(t == hi) state = st;
        else if(st != state) return 0;
    }
    return state;
}

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

int Align_H4_H1_M30_M15(int s) { return AlignRange(s, 5, 2); }
int Align_H1_M5(int s) { return AlignRange(s, 4, 1); }

//==============================================================
// Main Loop
//==============================================================

void OnTick()
{
    bool checkH4 = false, checkM15 = false, checkM5 = false;
    
    MqlRates h4[], m15[], m5[];
    if(CopyRates(_Symbol, PERIOD_H4, 0, 2, h4) > 0 && h4[1].time != lastH4bar) { lastH4bar = h4[1].time; checkH4 = true; }
    if(CopyRates(_Symbol, PERIOD_M15, 0, 2, m15) > 0 && m15[1].time != lastM15bar) { lastM15bar = m15[1].time; checkM15 = true; }
    if(CopyRates(_Symbol, PERIOD_M5, 0, 2, m5) > 0 && m5[1].time != lastM5bar) { lastM5bar = m5[1].time; checkM5 = true; }

    for(int s = 0; s < symsCount; s++)
    {
        if(checkH4)  { int st = Align_MN_W_D_H4(s); if(st != 0) AlertMsg("MN-W-D-H4", syms[s], st); }
        if(checkM15) { int st = Align_H4_H1_M30_M15(s); if(st != 0) AlertMsg("H4-H1-M30-M15", syms[s], st); }
        if(checkM5)  { int st = Align_H1_M5(s); if(st != 0) AlertMsg("H1-M30-M15-M5", syms[s], st); }
    }
}
