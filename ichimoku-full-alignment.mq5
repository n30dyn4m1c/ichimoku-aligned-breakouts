//+------------------------------------------------------------------+
//| Ichimoku Multi-Tier Alignment Alerts (MN→M1, H4→M1, H1→M1)     |
//| Three conviction tiers: Full, H4-down, H1-down                  |
//| Author: Neo Malesa                                              |
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
#define TF_COUNT 9

ENUM_TIMEFRAMES TFs[TF_COUNT] = {
   PERIOD_MN1, PERIOD_W1, PERIOD_D1,
   PERIOD_H4, PERIOD_H1, PERIOD_M30,
   PERIOD_M15, PERIOD_M5, PERIOD_M1
};

int      ich[MAX_SYMS][TF_COUNT];
string   syms[MAX_SYMS];
int      symsCount = 0;
datetime lastM1bar = 0;

// Active alignment tracking per symbol
// 0 = no active alignment, 1 = bullish, -1 = bearish
int      activeState[MAX_SYMS];
// Which tier triggered: 0=none, 1=Full, 2=H4, 3=H1
int      activeTier[MAX_SYMS];

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
      activeState[s] = 0;
      activeTier[s]  = 0;
      for(int t = 0; t < TF_COUNT; t++)
      {
         ich[s][t] = iIchimoku(syms[s], TFs[t], Tenkan, Kijun, SenkouB);
         if(ich[s][t] == INVALID_HANDLE) return(INIT_FAILED);
      }
   }
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   for(int s = 0; s < symsCount; s++)
      for(int t = 0; t < TF_COUNT; t++)
         IndicatorRelease(ich[s][t]);
}

//==============================================================
// Alerting Functions
//==============================================================

void AlertEntry(const string label, const string sym, const int st)
{
   string action = (st == 1 ? "Buy" : "Sell");
   string msg = action + " " + sym + " (" + label + ")";

   Alert(msg);
   Print(msg);
   SendNotification(msg);
}

void AlertExit(const string label, const string sym, const int prevState)
{
   string side = (prevState == 1 ? "Long" : "Short");
   string msg = "Close " + sym + " " + side + " (" + label + " broke)";

   Alert(msg);
   Print(msg);
   SendNotification(msg);
}

string TierLabel(const int tier)
{
   if(tier == 1) return "Full MN-M1";
   if(tier == 2) return "H4-M1";
   if(tier == 3) return "H1-M1";
   return "";
}

//==============================================================
// Ichimoku Rule Check
//==============================================================

int CheckTF(string sym, ENUM_TIMEFRAMES tf, int h)
{
   MqlRates rt[];
   if(CopyRates(sym, tf, 0, 120, rt) <= 0) return 0;
   ArraySetAsSeries(rt, true);

   int sh         = 1;
   int priceCloud = sh + 26;
   int chShift    = sh + 26;
   int chCloud    = sh + 52;

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

//==============================================================
// Alignment Check Functions
//==============================================================

// Generic range check: TFs[from] → TFs[to] inclusive
int AlignRange(const int s, const int from, const int to)
{
   int state = 0;
   for(int t = from; t <= to; t++)
   {
      int st = CheckTF(syms[s], TFs[t], ich[s][t]);
      if(st == 0) return 0;
      if(t == from) state = st;
      else if(st != state) return 0;
   }
   return state;
}

// MN → M1 (indices 0-8, all 9 TFs)
int AlignFull(const int s) { return AlignRange(s, 0, 8); }

// H4 → M1 (indices 3-8, 6 TFs)
int AlignH4(const int s)   { return AlignRange(s, 3, 8); }

// H1 → M1 (indices 4-8, 5 TFs)
int AlignH1(const int s)   { return AlignRange(s, 4, 8); }

//==============================================================
// Main Loop
//==============================================================

void OnTick()
{
   MqlRates m1[];
   if(CopyRates(_Symbol, PERIOD_M1, 0, 2, m1) <= 0) return;
   ArraySetAsSeries(m1, true);
   if(m1[1].time == lastM1bar) return;
   lastM1bar = m1[1].time;

   for(int s = 0; s < symsCount; s++)
   {
      // Determine current best tier
      int curTier  = 0;
      int curState = 0;

      int stFull = AlignFull(s);
      if(stFull != 0)
      {
         curTier = 1; curState = stFull;
      }
      else
      {
         int stH4 = AlignH4(s);
         if(stH4 != 0)
         {
            curTier = 2; curState = stH4;
         }
         else
         {
            int stH1 = AlignH1(s);
            if(stH1 != 0)
            {
               curTier = 3; curState = stH1;
            }
         }
      }

      // Check for exit: had active alignment, now lost completely or direction flipped
      if(activeState[s] != 0 && (curTier == 0 || curState != activeState[s]))
      {
         AlertExit(TierLabel(activeTier[s]), syms[s], activeState[s]);
         activeState[s] = 0;
         activeTier[s]  = 0;
      }

      // Check for tier downgrade: same direction but weaker tier (e.g. H4 broke, H1 holds)
      if(activeState[s] != 0 && curState == activeState[s] && curTier > activeTier[s])
      {
         AlertExit(TierLabel(activeTier[s]), syms[s], activeState[s]);
         AlertEntry(TierLabel(curTier), syms[s], curState);
         activeTier[s] = curTier;
      }

      // Check for tier upgrade: same direction but stronger tier (e.g. H4 joined H1)
      if(activeState[s] != 0 && curState == activeState[s] && curTier < activeTier[s])
      {
         AlertEntry(TierLabel(curTier), syms[s], curState);
         activeTier[s] = curTier;
      }

      // Check for new entry (no active tracking)
      if(curTier != 0 && activeState[s] == 0)
      {
         AlertEntry(TierLabel(curTier), syms[s], curState);
         activeState[s] = curState;
         activeTier[s]  = curTier;
      }
   }
}
