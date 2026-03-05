//+------------------------------------------------------------------+
//| Pullback Breakout EA                                              |
//| Entry: D1 trend + H4 alignment + M15 pullback re-alignment      |
//| Overextension guard: ATR distance from H4 Kijun                  |
//| Exit: M5 Kijun (losses), H1 Kijun (profits)                     |
//| Author: Neo Malesa                                                |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>

//--- Input Parameters ---
input string Symbols      = "EURUSD,GBPUSD,USDJPY,USDCHF,USDCAD,AUDUSD,NZDUSD,EURGBP,EURJPY,EURCHF,EURCAD,EURAUD,EURNZD,GBPJPY,GBPCHF,GBPCAD,GBPAUD,GBPNZD,AUDJPY,AUDNZD,AUDCAD,AUDCHF,NZDJPY,NZDCAD,NZDCHF,CADJPY,CHFJPY,GOLD,XAUUSD,SILVER,XAGUSD,XAUJPY,XAUCNH,XAUEUR,XPDUSD,XPTUSD,BTCUSD,BTCEUR,BTCGBP,DOGEUSD,ETHBTC,LTCUSD,SHIBUSD,SOLUSD,XRPUSD,OILCash,BRENTCash,NGASCash,US30Cash,US500Cash,US100Cash";
input int    Tenkan       = 9;
input int    Kijun        = 26;
input int    SenkouB      = 52;
input double Lots         = 0.10;
input int    Slippage     = 30;
input double MinADX       = 25.0;     // Minimum D1 ADX to confirm trend
input int    ADXPeriod    = 14;       // ADX period
input int    MinCloudPts  = 0;        // Minimum D1 cloud thickness in points (0=disabled)
input int    PullbackBars = 10;       // How many M15 bars back to check for lost alignment
input double MaxKijunATR  = 1.5;      // Max distance from H4 Kijun in ATR multiples
input int    ATRPeriod    = 14;       // ATR period for overextension check
input int    CooldownMins = 60;       // Minutes to wait after a losing exit before re-entry
input double MaxSpreadATR = 0.3;      // Max spread as fraction of H4 ATR (0=disabled)
input int    MaxPositions = 8;        // Max simultaneous positions (0=unlimited)

//--- Constants and Global Variables ---
#define MAX_SYMS 60

int      ichD1[MAX_SYMS];
int      ichH4[MAX_SYMS];
int      ichM15[MAX_SYMS];
int      ichM5[MAX_SYMS];
int      ichH1[MAX_SYMS];
int      adxD1[MAX_SYMS];
int      atrH4[MAX_SYMS];
string   syms[MAX_SYMS];
int      symsCount = 0;
datetime lastM5bar = 0;
int      MAGIC = 20260320;

// 0=no position, 1=long, -1=short
int      activeState[MAX_SYMS];
double   entryPrice[MAX_SYMS];

// Cooldown: timestamp when re-entry is allowed after a losing exit
datetime cooldownUntil[MAX_SYMS];

// Count of currently active positions
int      activeCount = 0;

CTrade   trade;

//==============================================================
// Initialization
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
      activeState[s]   = 0;
      entryPrice[s]    = 0;
      cooldownUntil[s] = 0;

      ichD1[s]  = iIchimoku(syms[s], PERIOD_D1,  Tenkan, Kijun, SenkouB);
      ichH4[s]  = iIchimoku(syms[s], PERIOD_H4,  Tenkan, Kijun, SenkouB);
      ichM15[s] = iIchimoku(syms[s], PERIOD_M15, Tenkan, Kijun, SenkouB);
      ichM5[s]  = iIchimoku(syms[s], PERIOD_M5,  Tenkan, Kijun, SenkouB);
      ichH1[s]  = iIchimoku(syms[s], PERIOD_H1,  Tenkan, Kijun, SenkouB);

      if(ichD1[s] == INVALID_HANDLE || ichH4[s] == INVALID_HANDLE ||
         ichM15[s] == INVALID_HANDLE || ichM5[s] == INVALID_HANDLE ||
         ichH1[s] == INVALID_HANDLE)
         return(INIT_FAILED);

      adxD1[s] = iADX(syms[s], PERIOD_D1, ADXPeriod);
      if(adxD1[s] == INVALID_HANDLE) return(INIT_FAILED);

      atrH4[s] = iATR(syms[s], PERIOD_H4, ATRPeriod);
      if(atrH4[s] == INVALID_HANDLE) return(INIT_FAILED);
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
      IndicatorRelease(ichH4[s]);
      IndicatorRelease(ichM15[s]);
      IndicatorRelease(ichM5[s]);
      IndicatorRelease(ichH1[s]);
      IndicatorRelease(adxD1[s]);
      IndicatorRelease(atrH4[s]);
   }
}

//==============================================================
// Position State Sync
//==============================================================

void SyncStateFromPositions()
{
   activeCount = 0;

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
            activeCount++;
            break;
         }
      }
   }
}

//==============================================================
// Utility
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
// D1 Trend Filter
//==============================================================

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

   if(MinCloudPts > 0)
   {
      double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
      double thickness = (cHi - cLo) / pt;
      if(thickness < MinCloudPts) return 0;
   }

   if(closeP > cHi) return 1;
   if(closeP < cLo) return -1;

   return 0;
}

bool D1IsTrending(string sym, int s)
{
   double adx[1];
   if(CopyBuffer(adxD1[s], 0, 1, 1, adx) <= 0) return false;
   return (adx[0] >= MinADX);
}

//==============================================================
// H4 Full Ichimoku Alignment
//==============================================================

int H4FullAlignment(string sym, int h)
{
   MqlRates rt[];
   if(CopyRates(sym, PERIOD_H4, 0, 120, rt) <= 0) return 0;
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
// M15 Full Alignment
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
// Pullback Detection: M15 lost alignment within last N bars
//==============================================================

bool M15HadPullback(string sym, int h, int dir)
{
   MqlRates rt[];
   if(CopyRates(sym, PERIOD_M15, 0, 120, rt) <= 0) return false;
   ArraySetAsSeries(rt, true);

   // Check bars 2..PullbackBars+1 (skip bar 1 which is current signal bar)
   for(int bar = 2; bar <= PullbackBars + 1; bar++)
   {
      int priceCloud = bar + 26;
      int chShift    = bar + 26;
      int chCloud    = bar + 52;

      if(ArraySize(rt) <= chCloud) continue;

      double ten[1], kij[1], senA[1], senB[1], chik[1];
      double ten_ch[1], kij_ch[1], senA_ch[1], senB_ch[1];

      if(CopyBuffer(h, 0, bar, 1, ten) <= 0) continue;
      if(CopyBuffer(h, 1, bar, 1, kij) <= 0) continue;
      if(CopyBuffer(h, 2, priceCloud, 1, senA) <= 0) continue;
      if(CopyBuffer(h, 3, priceCloud, 1, senB) <= 0) continue;

      if(CopyBuffer(h, 4, chShift, 1, chik) <= 0) continue;
      if(CopyBuffer(h, 0, chShift, 1, ten_ch) <= 0) continue;
      if(CopyBuffer(h, 1, chShift, 1, kij_ch) <= 0) continue;
      if(CopyBuffer(h, 2, chCloud, 1, senA_ch) <= 0) continue;
      if(CopyBuffer(h, 3, chCloud, 1, senB_ch) <= 0) continue;

      double closeP   = rt[bar].close;
      double price_26 = rt[chShift].close;

      double cHi  = MathMax(senA[0], senB[0]);
      double cLo  = MathMin(senA[0], senB[0]);
      double cHiC = MathMax(senA_ch[0], senB_ch[0]);
      double cLoC = MathMin(senA_ch[0], senB_ch[0]);

      bool aligned = false;

      if(dir == 1)
      {
         bool priceAbove = (closeP > cHi && closeP > ten[0] && closeP > kij[0]);
         bool chAbove = (chik[0] > cHiC && chik[0] > ten_ch[0] && chik[0] > kij_ch[0] && chik[0] > price_26);
         aligned = (priceAbove && chAbove);
      }
      else
      {
         bool priceBelow = (closeP < cLo && closeP < ten[0] && closeP < kij[0]);
         bool chBelow = (chik[0] < cLoC && chik[0] < ten_ch[0] && chik[0] < kij_ch[0] && chik[0] < price_26);
         aligned = (priceBelow && chBelow);
      }

      // Found a bar where M15 was NOT aligned = pullback occurred
      if(!aligned) return true;
   }

   return false;
}

//==============================================================
// Overextension Guard: Price distance from H4 Kijun in ATR
//==============================================================

bool IsOverextended(string sym, int s, int dir)
{
   double kij[1];
   if(CopyBuffer(ichH4[s], 1, 1, 1, kij) <= 0) return true;

   double atr[1];
   if(CopyBuffer(atrH4[s], 0, 1, 1, atr) <= 0) return true;
   if(atr[0] <= 0) return true;

   MqlRates rt[];
   if(CopyRates(sym, PERIOD_H4, 0, 3, rt) <= 0) return true;
   ArraySetAsSeries(rt, true);

   double closeP = rt[1].close;
   double distance = MathAbs(closeP - kij[0]);

   return (distance > MaxKijunATR * atr[0]);
}

//==============================================================
// Spread Filter
//==============================================================

bool SpreadTooWide(string sym, int s)
{
   if(MaxSpreadATR <= 0) return false;

   double atr[1];
   if(CopyBuffer(atrH4[s], 0, 1, 1, atr) <= 0) return true;
   if(atr[0] <= 0) return true;

   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   double spread = ask - bid;

   return (spread > MaxSpreadATR * atr[0]);
}

//==============================================================
// Profit in ATR (for 3-tier exit)
//==============================================================

double ProfitInATR(string sym, int s, int direction, double openPrice)
{
   double atr[1];
   if(CopyBuffer(atrH4[s], 0, 1, 1, atr) <= 0) return 0;
   if(atr[0] <= 0) return 0;

   double current;
   if(direction == 1)
      current = SymbolInfoDouble(sym, SYMBOL_BID);
   else
      current = SymbolInfoDouble(sym, SYMBOL_ASK);

   double pnl = (direction == 1) ? (current - openPrice) : (openPrice - current);
   return pnl / atr[0];
}

//==============================================================
// Trailing Kijun Exit
//==============================================================

bool KijunBreak(string sym, ENUM_TIMEFRAMES tf, int h, int direction)
{
   MqlRates rt[];
   if(CopyRates(sym, tf, 0, 5, rt) <= 0) return false;
   ArraySetAsSeries(rt, true);

   double kij[1];
   if(CopyBuffer(h, 1, 1, 1, kij) <= 0) return false;

   double closeP = rt[1].close;

   if(direction == 1  && closeP < kij[0]) return true;
   if(direction == -1 && closeP > kij[0]) return true;

   return false;
}

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
      return trade.Buy(Lots, sym, ask, 0, 0, "PB-Breakout");
   else
      return trade.Sell(Lots, sym, bid, 0, 0, "PB-Breakout");
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
   // Trigger on M5 bar close
   MqlRates m5[];
   if(CopyRates(_Symbol, PERIOD_M5, 0, 2, m5) <= 0) return;
   ArraySetAsSeries(m5, true);
   if(m5[1].time == lastM5bar) return;
   lastM5bar = m5[1].time;

   for(int s = 0; s < symsCount; s++)
   {
      //=== EXIT ===
      if(activeState[s] != 0)
      {
         bool shouldExit = false;
         string exitReason = "";

         // Hard exit: H4 alignment flipped against the trade
         int h4Now = H4FullAlignment(syms[s], ichH4[s]);
         if(h4Now != 0 && h4Now != activeState[s])
         {
            shouldExit = true;
            exitReason = "H4 reversal - hard exit";
         }

         // 3-tier trailing Kijun exit based on profit size
         if(!shouldExit)
         {
            double profitATR = ProfitInATR(syms[s], s, activeState[s], entryPrice[s]);

            if(profitATR < 0)
            {
               // Losing — tight stop: M5 Kijun
               if(KijunBreak(syms[s], PERIOD_M5, ichM5[s], activeState[s]))
               {
                  shouldExit = true;
                  exitReason = "M5 Kijun break - loss cut";
               }
            }
            else if(profitATR < 1.0)
            {
               // Small profit — moderate stop: M15 Kijun
               if(KijunBreak(syms[s], PERIOD_M15, ichM15[s], activeState[s]))
               {
                  shouldExit = true;
                  exitReason = "M15 Kijun break - small profit taken";
               }
            }
            else
            {
               // Large profit — loose stop: H1 Kijun
               if(KijunBreak(syms[s], PERIOD_H1, ichH1[s], activeState[s]))
               {
                  shouldExit = true;
                  exitReason = "H1 Kijun break - profit taken";
               }
            }
         }

         if(shouldExit)
         {
            bool wasLoss = !IsInProfit(syms[s], activeState[s], entryPrice[s]);

            string side = (activeState[s] == 1) ? "Long" : "Short";
            string msg = PCTime() + " | Close " + syms[s] + " " + side + " (" + exitReason + ")";
            Print(msg); Alert(msg); SendNotification(msg);

            ClosePosition(syms[s]);
            activeState[s] = 0;
            entryPrice[s]  = 0;
            activeCount--;

            // Set cooldown after losing exits
            if(wasLoss)
               cooldownUntil[s] = TimeCurrent() + CooldownMins * 60;
         }
      }

      //=== ENTRY ===
      if(activeState[s] != 0) continue;

      // Max positions cap
      if(MaxPositions > 0 && activeCount >= MaxPositions) continue;

      // Cooldown after losing exit
      if(cooldownUntil[s] > TimeCurrent()) continue;

      // Step 1: D1 must be trending
      if(!D1IsTrending(syms[s], s)) continue;

      // Step 2: D1 cloud bias
      int d1Bias = D1CloudBias(syms[s], ichD1[s]);
      if(d1Bias == 0) continue;

      // Step 3: H4 full alignment must agree with D1
      int h4St = H4FullAlignment(syms[s], ichH4[s]);
      if(h4St == 0 || h4St != d1Bias) continue;

      // Step 4: M15 must currently be fully aligned in same direction
      int m15St = M15FullAlignment(syms[s], ichM15[s]);
      if(m15St == 0 || m15St != d1Bias) continue;

      // Step 5: M15 must have lost alignment within recent bars (pullback happened)
      if(!M15HadPullback(syms[s], ichM15[s], d1Bias)) continue;

      // Step 6: Not overextended from H4 Kijun
      if(IsOverextended(syms[s], s, d1Bias)) continue;

      // Step 7: Spread not too wide
      if(SpreadTooWide(syms[s], s)) continue;

      // All conditions met — enter
      bool isBuy = (d1Bias == 1);
      string action = isBuy ? "Buy" : "Sell";
      string msg = PCTime() + " | " + action + " " + syms[s] + " @ " + DoubleToString(Lots, 2) + " (Pullback Breakout)";
      Print(msg); Alert(msg); SendNotification(msg);

      if(OpenPosition(syms[s], isBuy))
      {
         activeState[s] = d1Bias;
         entryPrice[s]  = isBuy ? SymbolInfoDouble(syms[s], SYMBOL_ASK)
                                : SymbolInfoDouble(syms[s], SYMBOL_BID);
         activeCount++;
      }
   }
}
