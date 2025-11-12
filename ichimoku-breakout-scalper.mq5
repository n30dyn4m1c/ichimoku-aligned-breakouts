//+------------------------------------------------------------------+
//| Ichimoku D1→M1 Auto Trader (Gold) – updated Ichimoku logic      |
//+------------------------------------------------------------------+
#property strict

input string Symbols   = "XAUUSD,XAUEUR,GOLD";
input int    Tenkan    = 9;
input int    Kijun     = 26;
input int    SenkouB   = 52;
input double Lots      = 0.10;
input int    SL_Points = 300;
input int    TP_Points = 600;

#define MAX_SYMS 10
#define TF_COUNT 6
// top-down order
ENUM_TIMEFRAMES TFs[TF_COUNT]={PERIOD_D1,PERIOD_H4,PERIOD_H1,PERIOD_M15,PERIOD_M5,PERIOD_M1};

int      ich[MAX_SYMS][TF_COUNT];
string   syms[MAX_SYMS];
int      symsCount=0;
datetime lastM1bar=0;
int      MAGIC=20251108;

//------------------------ utils -------------------------------
int ParseSymbols(string list)
{
   string parts[]; int n=StringSplit(list,',',parts), cnt=0;
   for(int i=0;i<n && cnt<MAX_SYMS;i++)
   {
      string sym=parts[i]; StringTrimLeft(sym); StringTrimRight(sym);
      if(SymbolSelect(sym,true)) syms[cnt++]=sym;
   }
   return cnt;
}

//------------------------ setup -------------------------------
int OnInit()
{
   symsCount=ParseSymbols(Symbols);
   if(symsCount<=0) return(INIT_FAILED);

   for(int s=0;s<symsCount;s++)
      for(int t=0;t<TF_COUNT;t++)
      {
         ich[s][t]=iIchimoku(syms[s],TFs[t],Tenkan,Kijun,SenkouB);
         if(ich[s][t]==INVALID_HANDLE) return(INIT_FAILED);
      }
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   for(int s=0;s<symsCount;s++)
      for(int t=0;t<TF_COUNT;t++)
         IndicatorRelease(ich[s][t]);
}

//-------------------- Ichimoku rules --------------------------
// 1=bull, -1=bear, 0=none (full price + chikou rules incl. price26)
int CheckTF(string sym, ENUM_TIMEFRAMES tf, int h)
{
   MqlRates rt[]; 
   if(CopyRates(sym,tf,0,120,rt)<=0) return 0;
   ArraySetAsSeries(rt,true);

   int sh=1;                         // last closed bar
   int priceCloud = sh+26;           // cloud drawn +26 → compare 26 back
   int chShift    = sh+26;           // chikou is 26 back
   int chCloud    = sh+52;           // cloud at chikou bar (26 more)

   if(ArraySize(rt)<=chCloud) return 0; // safety

   double ten[1],kij[1],senA[1],senB[1],chik[1];
   double ten_ch[1],kij_ch[1],senA_ch[1],senB_ch[1];

   // current TK and cloud (26 back)
   if(CopyBuffer(h,0,sh,1,ten)<=0) return 0;
   if(CopyBuffer(h,1,sh,1,kij)<=0) return 0;
   if(CopyBuffer(h,2,priceCloud,1,senA)<=0) return 0;
   if(CopyBuffer(h,3,priceCloud,1,senB)<=0) return 0;

   // chikou at 26 back; TK26; cloud at 52 back
   if(CopyBuffer(h,4,chShift,1,chik)<=0) return 0;
   if(CopyBuffer(h,0,chShift,1,ten_ch)<=0) return 0;
   if(CopyBuffer(h,1,chShift,1,kij_ch)<=0) return 0;
   if(CopyBuffer(h,2,chCloud,1,senA_ch)<=0) return 0;
   if(CopyBuffer(h,3,chCloud,1,senB_ch)<=0) return 0;

   double closeP   = rt[sh].close;
   double price_26 = rt[chShift].close;

   double cHi  = MathMax(senA[0],senB[0]);
   double cLo  = MathMin(senA[0],senB[0]);
   double cHiC = MathMax(senA_ch[0],senB_ch[0]);
   double cLoC = MathMin(senA_ch[0],senB_ch[0]);

   bool priceAbove = (closeP>cHi && closeP>ten[0] && closeP>kij[0]);
   bool priceBelow = (closeP<cLo && closeP<ten[0] && closeP<kij[0]);

   bool chAbove = (chik[0]>cHiC && chik[0]>ten_ch[0] && chik[0]>kij_ch[0] && chik[0]>price_26);
   bool chBelow = (chik[0]<cLoC && chik[0]<ten_ch[0] && chik[0]<kij_ch[0] && chik[0]<price_26);

   if(priceAbove && chAbove) return 1;
   if(priceBelow && chBelow) return -1;
   return 0;
}

//-------------------- trading utils (unchanged) ---------------
bool HasOpenPosition(string sym)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
         if(PositionGetString(POSITION_SYMBOL)==sym &&
            (int)PositionGetInteger(POSITION_MAGIC)==MAGIC)
            return true;
   }
   return false;
}

bool OpenOrder(string sym, bool isBuy)
{
   double pt = SymbolInfoDouble(sym,SYMBOL_POINT);
   double ask = SymbolInfoDouble(sym,SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym,SYMBOL_BID);
   int digits = (int)SymbolInfoInteger(sym,SYMBOL_DIGITS);

   // Get M15 Kijun value
   int kijHandle = iIchimoku(sym, PERIOD_M15, Tenkan, Kijun, SenkouB);
   double kijun[1];
   if(CopyBuffer(kijHandle, 1, 1, 1, kijun) <= 0)
      return false;
   IndicatorRelease(kijHandle);

   double sl, tp;
   if(isBuy)
   {
      sl = NormalizeDouble(kijun[0] - 100 * pt, digits);
      tp = NormalizeDouble(ask + TP_Points * pt, digits);
   }
   else
   {
      sl = NormalizeDouble(kijun[0] + 100 * pt, digits);
      tp = NormalizeDouble(bid - TP_Points * pt, digits);
   }

   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req); ZeroMemory(res);

   req.action       = TRADE_ACTION_DEAL;
   req.symbol       = sym;
   req.magic        = MAGIC;
   req.volume       = Lots;
   req.type_filling = ORDER_FILLING_IOC;

   if(isBuy)
   {
      req.type  = ORDER_TYPE_BUY;
      req.price = ask;
      req.sl    = sl;
      req.tp    = tp;
   }
   else
   {
      req.type  = ORDER_TYPE_SELL;
      req.price = bid;
      req.sl    = sl;
      req.tp    = tp;
   }

   if(!OrderSend(req,res)) return false;
   if(res.retcode!=10009 && res.retcode!=10008) return false;
   return true;
}


//------------------------- loop -------------------------------
void OnTick()
{
   // drive on M1 close
   MqlRates m1[];
   if(CopyRates(_Symbol,PERIOD_M1,0,5,m1)<=0) return;
   ArraySetAsSeries(m1,true);
   if(m1[1].time==lastM1bar) return;
   lastM1bar = m1[1].time;

   for(int s=0;s<symsCount;s++)
   {
      int state=0;
      // top-down: if D1 fails, skip lower TFs
      for(int t=0;t<TF_COUNT;t++)
      {
         int st=CheckTF(syms[s],TFs[t],ich[s][t]);
         if(st==0){ state=0; break; }
         if(t==0) state=st;
         else if(st!=state){ state=0; break; }
      }

      if(state==0 || HasOpenPosition(syms[s])) continue;

      if(state==1)
      {
         string msg="Bullish Alignment (D1→M1) BUY: "+syms[s];
         Alert(msg); Print(msg); OpenOrder(syms[s],true);
      }
      else if(state==-1)
      {
         string msg="Bearish Alignment (D1→M1) SELL: "+syms[s];
         Alert(msg); Print(msg); OpenOrder(syms[s],false);
      }
   }
}
