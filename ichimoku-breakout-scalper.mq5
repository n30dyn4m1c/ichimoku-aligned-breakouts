//+------------------------------------------------------------------+
//| Ichimoku D1→M1 Auto Trader (Gold)                               |
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

//------------------------------------------------------------
int ParseSymbols(string list)
{
   string parts[];
   int n=StringSplit(list,',',parts), cnt=0;
   for(int i=0;i<n && cnt<MAX_SYMS;i++)
   {
      string sym=parts[i];
      StringTrimLeft(sym); StringTrimRight(sym);
      if(SymbolSelect(sym,true))
         syms[cnt++]=sym;
   }
   return cnt;
}
//------------------------------------------------------------
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
//------------------------------------------------------------
void OnDeinit(const int reason)
{
   for(int s=0;s<symsCount;s++)
      for(int t=0;t<TF_COUNT;t++)
         IndicatorRelease(ich[s][t]);
}
//------------------------------------------------------------
// 1=bull, -1=bear, 0=none
int CheckTF(string sym, ENUM_TIMEFRAMES tf, int h)
{
   MqlRates rt[];
   if(CopyRates(sym,tf,0,90,rt)<=0) return 0;
   ArraySetAsSeries(rt,true);

   int sh=1;
   int priceCloudShift = sh+26;  // to match cloud position
   int chikouShift     = sh+26;  // chikou is 26 back
   int chikouCloudShift= sh+52;  // your rule

   // current tenkan/kijun
   double ten[1], kij[1];
   if(CopyBuffer(h,0,sh,1,ten)<=0) return 0;
   if(CopyBuffer(h,1,sh,1,kij)<=0) return 0;

   // current cloud (26 back)
   double senA[1], senB[1];
   if(CopyBuffer(h,2,priceCloudShift,1,senA)<=0) return 0;
   if(CopyBuffer(h,3,priceCloudShift,1,senB)<=0) return 0;

   // chikou at its bar (26 back)
   double chikou[1];
   if(CopyBuffer(h,4,chikouShift,1,chikou)<=0) return 0;

   // tenkan/kijun at chikou bar (26 back)
   double ten_ch[1], kij_ch[1];
   if(CopyBuffer(h,0,chikouShift,1,ten_ch)<=0) return 0;
   if(CopyBuffer(h,1,chikouShift,1,kij_ch)<=0) return 0;

   // cloud at chikou bar (52 back)
   double senA_ch[1], senB_ch[1];
   if(CopyBuffer(h,2,chikouCloudShift,1,senA_ch)<=0) return 0;
   if(CopyBuffer(h,3,chikouCloudShift,1,senB_ch)<=0) return 0;

   double closeP   = rt[sh].close;
   double cloudHi  = MathMax(senA[0],senB[0]);
   double cloudLo  = MathMin(senA[0],senB[0]);
   double cloudHiC = MathMax(senA_ch[0],senB_ch[0]);
   double cloudLoC = MathMin(senA_ch[0],senB_ch[0]);

   // bullish: price above current cloud, above current tenkan/kijun
   // chikou above its cloud (52 back) and above its tenkan/kijun (26 back)
   bool bull =
      closeP>cloudHi &&
      closeP>ten[0] &&
      closeP>kij[0] &&
      chikou[0]>cloudHiC &&
      chikou[0]>ten_ch[0] &&
      chikou[0]>kij_ch[0];

   // bearish symmetric
   bool bear =
      closeP<cloudLo &&
      closeP<ten[0] &&
      closeP<kij[0] &&
      chikou[0]<cloudLoC &&
      chikou[0]<ten_ch[0] &&
      chikou[0]<kij_ch[0];

   if(bull) return 1;
   if(bear) return -1;
   return 0;
}
//------------------------------------------------------------
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
//------------------------------------------------------------
bool OpenOrder(string sym, bool isBuy)
{
   double pt    = SymbolInfoDouble(sym,SYMBOL_POINT);
   double ask   = SymbolInfoDouble(sym,SYMBOL_ASK);
   double bid   = SymbolInfoDouble(sym,SYMBOL_BID);
   int    digits= (int)SymbolInfoInteger(sym,SYMBOL_DIGITS);

   MqlTradeRequest req;
   MqlTradeResult  res;
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
      req.sl    = NormalizeDouble(ask - SL_Points*pt, digits);
      req.tp    = NormalizeDouble(ask + TP_Points*pt, digits);
   }
   else
   {
      req.type  = ORDER_TYPE_SELL;
      req.price = bid;
      req.sl    = NormalizeDouble(bid + SL_Points*pt, digits);
      req.tp    = NormalizeDouble(bid - TP_Points*pt, digits);
   }

   if(!OrderSend(req,res)) return false;
   if(res.retcode!=10009 && res.retcode!=10008) return false;
   return true;
}
//------------------------------------------------------------
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
      // top-down: if D1 fails, we skip the rest
      for(int t=0;t<TF_COUNT;t++)
      {
         int st = CheckTF(syms[s],TFs[t],ich[s][t]);
         if(st==0){ state=0; break; }
         if(t==0) state=st;
         else if(st!=state){ state=0; break; }
      }

      if(state==0 || HasOpenPosition(syms[s])) continue;

      if(state==1)
      {
         string msg="Bullish Alignment (D1→M1) BUY: "+syms[s];
         Alert(msg); Print(msg);
         OpenOrder(syms[s],true);
      }
      else if(state==-1)
      {
         string msg="Bearish Alignment (D1→M1) SELL: "+syms[s];
         Alert(msg); Print(msg);
         OpenOrder(syms[s],false);
      }
   }
}
