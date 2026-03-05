//+------------------------------------------------------------------+
//| Bottom-Up Alignment EA (M1 + M5)                                 |
//| Entry: M1 and M5 both align. Exit: M1 breaks alignment.         |
//| Author: Neo Malesa                                                |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>

//--- Input Parameters ---
input string Symbols   = "EURUSD,GBPUSD,USDJPY,USDCHF,USDCAD,AUDUSD,NZDUSD,EURGBP,EURJPY,EURCHF,EURCAD,EURAUD,EURNZD,GBPJPY,GBPCHF,GBPCAD,GBPAUD,GBPNZD,AUDJPY,AUDNZD,AUDCAD,AUDCHF,NZDJPY,NZDCAD,NZDCHF,CADJPY,CHFJPY,GOLD,XAUUSD,SILVER,XAGUSD,XAUJPY,XAUCNH,XAUEUR,XPDUSD,XPTUSD,BTCUSD,BTCEUR,BTCGBP,DOGEUSD,ETHBTC,LTCUSD,SHIBUSD,SOLUSD,XRPUSD,OILCash,BRENTCash,NGASCash,US30Cash,US500Cash,US100Cash";
input int    Tenkan    = 9;
input int    Kijun     = 26;
input int    SenkouB   = 52;
input double Lots      = 0.10;
input int    Slippage  = 30;    // Max slippage in points

//--- Constants and Global Variables ---
#define MAX_SYMS 60
#define TF_COUNT 2

ENUM_TIMEFRAMES TFs[TF_COUNT] = {PERIOD_M5, PERIOD_M1};

int      ich[MAX_SYMS][TF_COUNT];
string   syms[MAX_SYMS];
int      symsCount = 0;
datetime lastM1bar = 0;
int      MAGIC = 20260310;

// 0=no position, 1=long, -1=short
int      activeState[MAX_SYMS];

CTrade   trade;

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
      for(int t = 0; t < TF_COUNT; t++)
      {
         ich[s][t] = iIchimoku(syms[s], TFs[t], Tenkan, Kijun, SenkouB);
         if(ich[s][t] == INVALID_HANDLE) return(INIT_FAILED);
      }
   }

   trade.SetDeviationInPoints(Slippage);
   trade.SetExpertMagicNumber(MAGIC);

   SyncStateFromPositions();

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   for(int s = 0; s < symsCount; s++)
      for(int t = 0; t < TF_COUNT; t++)
         IndicatorRelease(ich[s][t]);
}

//==============================================================
// Position State Sync (recover after restart)
//==============================================================

void SyncStateFromPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;

      string sym   = PositionGetString(POSITION_SYMBOL);
      int    magic = (int)PositionGetInteger(POSITION_MAGIC);
      int    type  = (int)PositionGetInteger(POSITION_TYPE);

      if(magic != MAGIC) continue;

      int dir = (type == POSITION_TYPE_BUY) ? 1 : -1;

      for(int s = 0; s < symsCount; s++)
      {
         if(syms[s] == sym)
         {
            activeState[s] = dir;
            break;
         }
      }
   }
}

//==============================================================
// Utility Functions
//==============================================================

string PCTime()
{
   MqlDateTime dt;
   TimeToStruct(TimeLocal(), dt);
   int h = dt.hour;
   string ampm = (h >= 12) ? "PM" : "AM";
   if(h == 0) h = 12;
   else if(h > 12) h -= 12;
   return IntegerToString(h) + ":" + StringFormat("%02d", dt.min) + " " + ampm;
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
// Alignment Check
//==============================================================

// M5 + M1 must agree (bottom-up)
int AlignM5M1(const int s)
{
   int stM5 = CheckTF(syms[s], TFs[0], ich[s][0]);
   if(stM5 == 0) return 0;

   int stM1 = CheckTF(syms[s], TFs[1], ich[s][1]);
   if(stM1 == 0) return 0;

   if(stM5 != stM1) return 0;
   return stM1;
}

//==============================================================
// Trading Functions
//==============================================================

bool OpenPosition(string sym, bool isBuy)
{
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);

   if(isBuy)
      return trade.Buy(Lots, sym, ask, 0, 0, "M5-M1");
   else
      return trade.Sell(Lots, sym, bid, 0, 0, "M5-M1");
}

void ClosePosition(string sym)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;

      if(PositionGetString(POSITION_SYMBOL) == sym &&
         (int)PositionGetInteger(POSITION_MAGIC) == MAGIC)
      {
         trade.PositionClose(ticket);
      }
   }
}

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
      // --- Exit: M1 breaks alignment ---
      if(activeState[s] != 0)
      {
         int m1St = CheckTF(syms[s], TFs[1], ich[s][1]);

         if(m1St != activeState[s])
         {
            string side = (activeState[s] == 1) ? "Long" : "Short";
            string msg = PCTime() + " | Close " + syms[s] + " " + side + " (M1 broke)";
            Print(msg); Alert(msg); SendNotification(msg);

            ClosePosition(syms[s]);
            activeState[s] = 0;
         }
      }

      // --- Entry: M1 + M5 align ---
      if(activeState[s] == 0)
      {
         int st = AlignM5M1(s);
         if(st != 0)
         {
            bool isBuy = (st == 1);
            string action = isBuy ? "Buy" : "Sell";
            string msg = PCTime() + " | " + action + " " + syms[s] + " @ " + DoubleToString(Lots, 2) + " (M5-M1)";
            Print(msg); Alert(msg); SendNotification(msg);

            if(OpenPosition(syms[s], isBuy))
               activeState[s] = st;
         }
      }
   }
}
