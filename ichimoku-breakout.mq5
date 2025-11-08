//+------------------------------------------------------------------+
#property strict

input string Symbols = "EURUSD,GBPUSD,USDJPY,USDCHF,USDCAD,AUDUSD,NZDUSD,EURGBP,EURJPY,EURCHF,EURCAD,EURAUD,EURNZD,GBPJPY,GBPCHF,GBPCAD,GBPAUD,GBPNZD,AUDJPY,AUDNZD,AUDCAD,AUDCHF,NZDJPY,NZDCAD,NZDCHF,CADJPY,CHFJPY,XAUUSD,XAGUSD,XAUEUR,XPDUSD,XPTUSD,BTCEUR,BTCGBP,DOGEUSD,ETHBTC,LTCUSD,SHIBUSD,SOLUSD,XRPUSD,OILCash,BRENTCash,NGASCash,US30Cash,US500Cash,US100Cash,GOLD,SILVER";
input int    Tenkan  = 9;
input int    Kijun   = 26;
input int    SenkouB = 52;

#define MAX_SYMS 60
#define TF_COUNT 6
ENUM_TIMEFRAMES TFs[TF_COUNT]={PERIOD_M1,PERIOD_M5,PERIOD_M15,PERIOD_M30,PERIOD_H1,PERIOD_H4};
int    ich[MAX_SYMS][TF_COUNT];
string syms[MAX_SYMS];
int    symsCount=0;
datetime lastM1bar=0;

//------------------------------------------------------------
int ParseSymbols(string list)
{
   string parts[];
   int n = StringSplit(list,',',parts);
   int cnt=0;
   for(int i=0;i<n && cnt<MAX_SYMS;i++)
   {
      string sym = parts[i];
      StringTrimLeft(sym);
      StringTrimRight(sym);
      if(SymbolSelect(sym,true))
         syms[cnt++] = sym;
   }
   return cnt;
}
//------------------------------------------------------------
int OnInit()
{
   symsCount = ParseSymbols(Symbols);
   if(symsCount<=0) return(INIT_FAILED);
   for(int s=0; s<symsCount; s++)
      for(int t=0; t<TF_COUNT; t++)
      {
         ich[s][t]=iIchimoku(syms[s],TFs[t],Tenkan,Kijun,SenkouB);
         if(ich[s][t]==INVALID_HANDLE) return(INIT_FAILED);
      }
   return(INIT_SUCCEEDED);
}
//------------------------------------------------------------
void OnDeinit(const int reason)
{
   for(int s=0; s<symsCount; s++)
      for(int t=0; t<TF_COUNT; t++)
         IndicatorRelease(ich[s][t]);
}
//------------------------------------------------------------
// 1 bull, -1 bear, 0 none
int CheckTF(string sym, ENUM_TIMEFRAMES tf, int handle)
{
   MqlRates rt[];
   if(CopyRates(sym,tf,0,90,rt)<=0) return 0;
   ArraySetAsSeries(rt,true);

   int shift=1;
   int priceCloudShift = shift + 26; // cloud drawn 26 fwd
   int chikouShift     = shift + 26; // chikou is 26 back
   int chikouCloudShift= shift + 52; // your 52-back cloud check

   // current tenkan/kijun
   double ten[1], kij[1];
   if(CopyBuffer(handle,0,shift,1,ten)<=0) return 0;
   if(CopyBuffer(handle,1,shift,1,kij)<=0) return 0;

   // current cloud (for price)
   double senA[1], senB[1];
   if(CopyBuffer(handle,2,priceCloudShift,1,senA)<=0) return 0;
   if(CopyBuffer(handle,3,priceCloudShift,1,senB)<=0) return 0;

   // chikou at its bar
   double chikou[1];
   if(CopyBuffer(handle,4,chikouShift,1,chikou)<=0) return 0;

   // tenkan/kijun at chikou bar (26 back)
   double ten_ch[1], kij_ch[1];
   if(CopyBuffer(handle,0,chikouShift,1,ten_ch)<=0) return 0;
   if(CopyBuffer(handle,1,chikouShift,1,kij_ch)<=0) return 0;

   // cloud at chikou bar (52 back)
   double senA_ch[1], senB_ch[1];
   if(CopyBuffer(handle,2,chikouCloudShift,1,senA_ch)<=0) return 0;
   if(CopyBuffer(handle,3,chikouCloudShift,1,senB_ch)<=0) return 0;

   double closePrice   = rt[shift].close;
   double cloudHigh    = MathMax(senA[0],senB[0]);
   double cloudLow     = MathMin(senA[0],senB[0]);
   double cloudHighCh  = MathMax(senA_ch[0],senB_ch[0]);
   double cloudLowCh   = MathMin(senA_ch[0],senB_ch[0]);

   // price-level conditions (current bar)
   bool priceAbove = (closePrice>cloudHigh) && (closePrice>ten[0]) && (closePrice>kij[0]);
   bool priceBelow = (closePrice<cloudLow)  && (closePrice<ten[0]) && (closePrice<kij[0]);

   // chikou-level conditions (26 back ten/kij, 52 back cloud)
   bool chAbove = (chikou[0]>cloudHighCh) && (chikou[0]>ten_ch[0]) && (chikou[0]>kij_ch[0]);
   bool chBelow = (chikou[0]<cloudLowCh)  && (chikou[0]<ten_ch[0]) && (chikou[0]<kij_ch[0]);

   if(priceAbove && chAbove) return 1;
   if(priceBelow && chBelow) return -1;
   return 0;
}
//------------------------------------------------------------
void OnTick()
{
   // drive by M1 close
   MqlRates m1[];
   if(CopyRates(_Symbol,PERIOD_M1,0,5,m1)<=0) return;
   ArraySetAsSeries(m1,true);
   if(m1[1].time==lastM1bar) return;
   lastM1bar = m1[1].time;

   for(int s=0; s<symsCount; s++)
   {
      int stateFull=0, statePartial=0;

      // FULL (M1–H4)
      for(int t=0; t<TF_COUNT; t++)
      {
         int st=CheckTF(syms[s],TFs[t],ich[s][t]);
         if(st==0){ stateFull=0; break; }
         if(t==0) stateFull=st;
         else if(st!=stateFull){ stateFull=0; break; }
      }

      // PARTIAL (M1–H1)
      for(int t=0; t<5; t++)
      {
         int st=CheckTF(syms[s],TFs[t],ich[s][t]);
         if(st==0){ statePartial=0; break; }
         if(t==0) statePartial=st;
         else if(st!=statePartial){ statePartial=0; break; }
      }

      if(stateFull==1)
      {
         string msg="FULL Bullish Alignment (H4→M1): "+syms[s];
         Alert(msg); Print(msg);
      }
      else if(stateFull==-1)
      {
         string msg="FULL Bearish Alignment (H4→M1): "+syms[s];
         Alert(msg); Print(msg);
      }

      if(statePartial==1)
      {
         string msg="PARTIAL Bullish Alignment (H1→M1): "+syms[s];
         Alert(msg); Print(msg);
      }
      else if(statePartial==-1)
      {
         string msg="PARTIAL Bearish Alignment (H1→M1): "+syms[s];
         Alert(msg); Print(msg);
      }
   }
}
