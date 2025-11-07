//+------------------------------------------------------------------+
#property strict

input string Symbols = "EURUSD,GBPUSD,USDJPY,USDCHF,USDCAD,AUDUSD,NZDUSD,EURGBP,EURJPY,EURCHF,EURCAD,EURAUD,EURNZD,GBPJPY,GBPCHF,GBPCAD,GBPAUD,GBPNZD,AUDJPY,AUDNZD,AUDCAD,AUDCHF,NZDJPY,NZDCAD,NZDCHF,CADJPY,CHFJPY,XAUUSD,XAGUSD,GOLD,SILVER,US30Cash,US500Cash,US100Cash,OILCash,BRENTCash,NGASCash";
input int    Tenkan  = 9;
input int    Kijun   = 26;
input int    SenkouB = 52;

#define MAX_SYMS 60
#define TF_COUNT 5
ENUM_TIMEFRAMES TFs[TF_COUNT]={PERIOD_H1,PERIOD_H4,PERIOD_D1,PERIOD_W1,PERIOD_MN1};
int    ich[MAX_SYMS][TF_COUNT];
string syms[MAX_SYMS];
int    symsCount=0;
datetime lastH1bar=0;

int ParseSymbols(string list)
{
   string parts[];
   int n=StringSplit(list,',',parts);
   int cnt=0;
   for(int i=0;i<n && cnt<MAX_SYMS;i++)
   {
      string sym=parts[i];
      StringTrimLeft(sym); StringTrimRight(sym);
      if(SymbolSelect(sym,true))
         syms[cnt++]=sym;
   }
   return cnt;
}

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

// 1 bull, -1 bear, 0 none
int CheckTF(string sym, ENUM_TIMEFRAMES tf, int handle)
{
   MqlRates rt[];
   if(CopyRates(sym,tf,0,90,rt)<=0) return 0;
   ArraySetAsSeries(rt,true);
   int shift=1;
   int priceCloudShift=shift+26;
   int chikouShift=shift+26;
   int chikouCloudShift=shift+52;

   double senA[1],senB[1],senA_ch[1],senB_ch[1],chikou[1];
   if(CopyBuffer(handle,2,priceCloudShift,1,senA)<=0) return 0;
   if(CopyBuffer(handle,3,priceCloudShift,1,senB)<=0) return 0;
   if(CopyBuffer(handle,4,chikouShift,1,chikou)<=0) return 0;
   if(CopyBuffer(handle,2,chikouCloudShift,1,senA_ch)<=0) return 0;
   if(CopyBuffer(handle,3,chikouCloudShift,1,senB_ch)<=0) return 0;

   double closePrice=rt[shift].close;
   double cloudHigh =MathMax(senA[0],senB[0]);
   double cloudLow  =MathMin(senA[0],senB[0]);
   double cloudHighCh=MathMax(senA_ch[0],senB_ch[0]);
   double cloudLowCh =MathMin(senA_ch[0],senB_ch[0]);

   bool priceAbove=(closePrice>cloudHigh);
   bool priceBelow=(closePrice<cloudLow);
   bool chAbove=(chikou[0]>cloudHighCh);
   bool chBelow=(chikou[0]<cloudLowCh);

   if(priceAbove && chAbove) return 1;
   if(priceBelow && chBelow) return -1;
   return 0;
}

void OnTick()
{
   // fire on H1 close
   MqlRates h1[];
   if(CopyRates(_Symbol,PERIOD_H1,0,5,h1)<=0) return;
   ArraySetAsSeries(h1,true);
   if(h1[1].time==lastH1bar) return;
   lastH1bar=h1[1].time;

   for(int s=0;s<symsCount;s++)
   {
      int state=0;
      for(int t=0;t<TF_COUNT;t++)
      {
         int st=CheckTF(syms[s],TFs[t],ich[s][t]);
         if(st==0){ state=0; break; }
         if(t==0) state=st;
         else if(st!=state){ state=0; break; }
      }

      if(state==1)
      {
         string msg="HTF Bullish Alignment (MN1→H1): "+syms[s];
         Alert(msg); Print(msg);
      }
      else if(state==-1)
      {
         string msg="HTF Bearish Alignment (MN1→H1): "+syms[s];
         Alert(msg); Print(msg);
      }
   }
}
