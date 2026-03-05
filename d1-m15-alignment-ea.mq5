//+------------------------------------------------------------------+
//| D1 Cloud + M15 Full Alignment EA                                  |
//| Entry: D1 price above/below cloud + M15 full Ichimoku alignment  |
//| Exit: Trailing Kijun — M5 when losing, H1 when winning           |
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
input int    Slippage  = 30;
input double MinADX    = 25.0;    // Minimum D1 ADX to confirm trend
input int    ADXPeriod = 14;      // ADX period
input int    MinCloudPts = 0;     // Minimum D1 cloud thickness in points (0=disabled)

//--- Constants and Global Variables ---
#define MAX_SYMS 60

int      ichD1[MAX_SYMS];     // D1 Ichimoku handle
int      ichM15[MAX_SYMS];    // M15 Ichimoku handle
int      ichM5[MAX_SYMS];     // M5 Ichimoku handle (tight exit)
int      ichH1[MAX_SYMS];     // H1 Ichimoku handle (loose exit)
int      adxD1[MAX_SYMS];     // D1 ADX handle
string   syms[MAX_SYMS];
int      symsCount = 0;
datetime lastM5bar = 0;
int      MAGIC = 20260315;

// 0=no position, 1=long, -1=short
int      activeState[MAX_SYMS];
// Entry price per symbol (to determine profit/loss)
double   entryPrice[MAX_SYMS];

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
      entryPrice[s]  = 0;

      ichD1[s] = iIchimoku(syms[s], PERIOD_D1, Tenkan, Kijun, SenkouB);
      if(ichD1[s] == INVALID_HANDLE) return(INIT_FAILED);

      ichM15[s] = iIchimoku(syms[s], PERIOD_M15, Tenkan, Kijun, SenkouB);
      if(ichM15[s] == INVALID_HANDLE) return(INIT_FAILED);

      ichM5[s] = iIchimoku(syms[s], PERIOD_M5, Tenkan, Kijun, SenkouB);
      if(ichM5[s] == INVALID_HANDLE) return(INIT_FAILED);

      ichH1[s] = iIchimoku(syms[s], PERIOD_H1, Tenkan, Kijun, SenkouB);
      if(ichH1[s] == INVALID_HANDLE) return(INIT_FAILED);

      adxD1[s] = iADX(syms[s], PERIOD_D1, ADXPeriod);
      if(adxD1[s] == INVALID_HANDLE) return(INIT_FAILED);
   }

   trade.SetDeviationInPoints(Slippage);
   trade.SetExpertMagicNumber(MAGIC);

   SyncStateFromPositions();

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   for(int s = 0; s < symsCount; s++)
   {
      IndicatorRelease(ichD1[s]);
      IndicatorRelease(ichM15[s]);
      IndicatorRelease(ichM5[s]);
      IndicatorRelease(ichH1[s]);
      IndicatorRelease(adxD1[s]);
   }
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

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);

      for(int s = 0; s < symsCount; s++)
      {
         if(syms[s] == sym)
         {
            activeState[s] = dir;
            entryPrice[s]  = openPrice;
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
// D1 Trend Filters
//==============================================================

// D1 Cloud Bias (Relaxed — price vs cloud only)
// Also checks cloud thickness if MinCloudPts > 0
int D1CloudBias(string sym, int h)
{
   MqlRates rt[];
   if(CopyRates(sym, PERIOD_D1, 0, 30, rt) <= 0) return 0;
   ArraySetAsSeries(rt, true);

   int sh         = 1;
   int priceCloud = sh + 26;

   if(ArraySize(rt) <= priceCloud) return 0;

   double senA[1], senB[1];
   if(CopyBuffer(h, 2, priceCloud, 1, senA) <= 0) return 0;
   if(CopyBuffer(h, 3, priceCloud, 1, senB) <= 0) return 0;

   double closeP = rt[sh].close;
   double cHi = MathMax(senA[0], senB[0]);
   double cLo = MathMin(senA[0], senB[0]);

   // Cloud thickness filter
   if(MinCloudPts > 0)
   {
      double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
      double thickness = (cHi - cLo) / pt;
      if(thickness < MinCloudPts) return 0; // cloud too thin, choppy market
   }

   if(closeP > cHi) return 1;
   if(closeP < cLo) return -1;

   return 0;
}

// D1 ADX filter — returns true if market is trending
bool D1IsTrending(string sym, int s)
{
   double adx[1];
   if(CopyBuffer(adxD1[s], 0, 1, 1, adx) <= 0) return false;
   return (adx[0] >= MinADX);
}

//==============================================================
// M15 Full Ichimoku Alignment (Strict)
//==============================================================

int M15FullAlignment(string sym, int h)
{
   MqlRates rt[];
   if(CopyRates(sym, PERIOD_M15, 0, 120, rt) <= 0) return 0;
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
// Trailing Kijun Exit
//==============================================================

// Generic Kijun break check for any timeframe
bool KijunBreak(string sym, ENUM_TIMEFRAMES tf, int h, int direction)
{
   MqlRates rt[];
   if(CopyRates(sym, tf, 0, 5, rt) <= 0) return false;
   ArraySetAsSeries(rt, true);

   double kij[1];
   if(CopyBuffer(h, 1, 1, 1, kij) <= 0) return false;

   double closeP = rt[1].close;

   if(direction == 1 && closeP < kij[0]) return true;   // long, price below Kijun
   if(direction == -1 && closeP > kij[0]) return true;   // short, price above Kijun

   return false;
}

// Check if position is in profit
bool IsInProfit(string sym, int direction, double openPrice)
{
   if(direction == 1)
      return (SymbolInfoDouble(sym, SYMBOL_BID) > openPrice);
   else
      return (SymbolInfoDouble(sym, SYMBOL_ASK) < openPrice);
}

//==============================================================
// Trading Functions
//==============================================================

bool OpenPosition(string sym, bool isBuy)
{
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);

   if(isBuy)
      return trade.Buy(Lots, sym, ask, 0, 0, "D1+M15");
   else
      return trade.Sell(Lots, sym, bid, 0, 0, "D1+M15");
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
   // Trigger on M5 bar close (needed for tight M5 Kijun exit checks)
   MqlRates m5[];
   if(CopyRates(_Symbol, PERIOD_M5, 0, 2, m5) <= 0) return;
   ArraySetAsSeries(m5, true);
   if(m5[1].time == lastM5bar) return;
   lastM5bar = m5[1].time;

   for(int s = 0; s < symsCount; s++)
   {
      // --- Exit: Trailing Kijun ---
      // Losing: M5 Kijun break (cut losses fast)
      // Winning: H1 Kijun break (let profits run)
      if(activeState[s] != 0)
      {
         bool inProfit = IsInProfit(syms[s], activeState[s], entryPrice[s]);

         bool shouldExit = false;
         string exitReason = "";

         if(!inProfit)
         {
            // Losing — tight stop: M5 Kijun
            if(KijunBreak(syms[s], PERIOD_M5, ichM5[s], activeState[s]))
            {
               shouldExit = true;
               exitReason = "M5 Kijun break - loss cut";
            }
         }
         else
         {
            // Winning — loose stop: H1 Kijun
            if(KijunBreak(syms[s], PERIOD_H1, ichH1[s], activeState[s]))
            {
               shouldExit = true;
               exitReason = "H1 Kijun break - profit taken";
            }
         }

         if(shouldExit)
         {
            string side = (activeState[s] == 1) ? "Long" : "Short";
            string msg = PCTime() + " | Close " + syms[s] + " " + side + " (" + exitReason + ")";
            Print(msg); Alert(msg); SendNotification(msg);

            ClosePosition(syms[s]);
            activeState[s] = 0;
            entryPrice[s]  = 0;
         }
      }

      // --- Entry: D1 trending + D1 cloud bias + M15 full alignment ---
      if(activeState[s] == 0)
      {
         if(!D1IsTrending(syms[s], s)) continue; // ADX too low, choppy market

         int d1Bias = D1CloudBias(syms[s], ichD1[s]);
         if(d1Bias == 0) continue; // price inside D1 cloud or cloud too thin

         int m15St = M15FullAlignment(syms[s], ichM15[s]);
         if(m15St == 0) continue; // M15 not fully aligned

         if(d1Bias != m15St) continue; // D1 and M15 disagree

         bool isBuy = (m15St == 1);
         string action = isBuy ? "Buy" : "Sell";
         string msg = PCTime() + " | " + action + " " + syms[s] + " @ " + DoubleToString(Lots, 2) + " (D1 cloud + M15 aligned)";
         Print(msg); Alert(msg); SendNotification(msg);

         if(OpenPosition(syms[s], isBuy))
         {
            activeState[s] = m15St;
            entryPrice[s]  = isBuy ? SymbolInfoDouble(syms[s], SYMBOL_ASK)
                                   : SymbolInfoDouble(syms[s], SYMBOL_BID);
         }
      }
   }
}
