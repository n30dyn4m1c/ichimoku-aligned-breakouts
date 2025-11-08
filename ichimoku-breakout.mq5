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
int CheckTF(string sym, ENUM_TIMEFRAMES tf, int h)
{
   MqlRates rt[]; if(CopyRates(sym,tf,0,90,rt)<=0) return 0;
   ArraySetAsSeries(rt,true);
   int sh=1, priceCloud=sh+26, chShift=sh+26, chCloud=sh+52;

   double ten[1],kij[1],senA[1],senB[1],chik[1];
   double ten_ch[1],kij_ch[1],senA_ch[1],senB_ch[1];

   if(CopyBuffer(h,0,sh,1,ten)<=0) return 0;
   if(CopyBuffer(h,1,sh,1,kij)<=0) return 0;
   if(CopyBuffer(h,2,priceCloud,1,senA)<=0) return 0;
   if(CopyBuffer(h,3,priceCloud,1,senB)<=0) return 0;

   if(CopyBuffer(h,4,chShift,1,chik)<=0) return 0;
   if(CopyBuffer(h,0,chShift,1,ten_ch)<=0) return 0;
   if(CopyBuffer(h,1,chShift,1,kij_ch)<=0) return 0;
   if(CopyBuffer(h,2,chCloud,1,senA_ch)<=0) return 0;
   if(CopyBuffer(h,3,chCloud,1,senB_ch)<=0) return 0;

   double closeP=rt[sh].close;
   double cHi = MathMax(senA[0],senB[0]);
   double cLo = MathMin(senA[0],senB[0]);
   double cHiC= MathMax(senA_ch[0],senB_ch[0]);
   double cLoC= MathMin(senA_ch[0],senB_ch[0]);

   bool bull = (closeP>cHi && closeP>ten[0] && closeP>kij[0] &&
                chik[0]>cHiC && chik[0]>ten_ch[0] && chik[0]>kij_ch[0]);
   bool bear = (closeP<cLo && closeP<ten[0] && closeP<kij[0] &&
                chik[0]<cLoC && chik[0]<ten_ch[0] && chik[0]<kij_ch[0]);

   if(bull) return 1;
   if(bear) return -1;
   return 0;
}

//------------------------------------------------------------
void OnTick()
{
   MqlRates m1[];
   if(CopyRates(_Symbol,PERIOD_M1,0,5,m1)<=0) return;
   ArraySetAsSeries(m1,true);
   if(m1[1].time==lastM1bar) return;
   lastM1bar = m1[1].time;

   for(int s=0; s<symsCount; s++)
   {
      int state=0;
      // check from highest to lowest: H4(H=5),H1(4),M30(3),M15(2),M5(1),M1(0)
      for(int t=TF_COUNT-1; t>=0; t--)
      {
         int st = CheckTF(syms[s], TFs[t], ich[s][t]);
         if(st==0){ state=0; break; }         // one TF failed → stop for this symbol
         if(t==TF_COUNT-1) state=st;          // first (highest) TF sets direction
         else if(st!=state){ state=0; break;} // mismatch → stop
      }

      if(state==1)
      {
         string msg="Top-down Bullish (H4→M1): "+syms[s];
         Alert(msg); Print(msg);
      }
      else if(state==-1)
      {
         string msg="Top-down Bearish (H4→M1): "+syms[s];
         Alert(msg); Print(msg);
      }
   }
}
