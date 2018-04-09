//+------------------------------------------------------------------+
//|                                                           EA.mq5 |
//|                                         Copyright 2018, SST Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, SST Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
input int      longMAPeriod=60;   //długi okres średniej kroczącej
input int      shortMAPeriod=10;  //krótki okres średniej kroczącej
input double   takeProfit=1000.0; //poziom take profit
input double   stopLoss=300.0;    //poziom stop loss
input double   lot=0.1;           //wolumen w lotach

ENUM_TIMEFRAMES TFMigrate(int tf)
  {
   switch(tf)
     {
      case 0: return(PERIOD_CURRENT);
      case 1: return(PERIOD_M1);
      case 5: return(PERIOD_M5);
      case 15: return(PERIOD_M15);
      case 30: return(PERIOD_M30);
      case 60: return(PERIOD_H1);
      case 240: return(PERIOD_H4);
      case 1440: return(PERIOD_D1);
      case 10080: return(PERIOD_W1);
      case 43200: return(PERIOD_MN1);
      
      case 2: return(PERIOD_M2);
      case 3: return(PERIOD_M3);
      case 4: return(PERIOD_M4);      
      case 6: return(PERIOD_M6);
      case 10: return(PERIOD_M10);
      case 12: return(PERIOD_M12);
      case 16385: return(PERIOD_H1);
      case 16386: return(PERIOD_H2);
      case 16387: return(PERIOD_H3);
      case 16388: return(PERIOD_H4);
      case 16390: return(PERIOD_H6);
      case 16392: return(PERIOD_H8);
      case 16396: return(PERIOD_H12);
      case 16408: return(PERIOD_D1);
      case 32769: return(PERIOD_W1);
      case 49153: return(PERIOD_MN1);      
      default: return(PERIOD_CURRENT);
     }
  }
  
ENUM_MA_METHOD MethodMigrate(int method)
  {
   switch(method)
     {
      case 0: return(MODE_SMA);
      case 1: return(MODE_EMA);
      case 2: return(MODE_SMMA);
      case 3: return(MODE_LWMA);
      default: return(MODE_SMA);
     }
  }
ENUM_APPLIED_PRICE PriceMigrate(int price)
  {
   switch(price)
     {
      case 1: return(PRICE_CLOSE);
      case 2: return(PRICE_OPEN);
      case 3: return(PRICE_HIGH);
      case 4: return(PRICE_LOW);
      case 5: return(PRICE_MEDIAN);
      case 6: return(PRICE_TYPICAL);
      case 7: return(PRICE_WEIGHTED);
      default: return(PRICE_CLOSE);
     }
  }
ENUM_STO_PRICE StoFieldMigrate(int field)
  {
   switch(field)
     {
      case 0: return(STO_LOWHIGH);
      case 1: return(STO_CLOSECLOSE);
      default: return(STO_LOWHIGH);
     }
  }
//+------------------------------------------------------------------+


#define OP_BUY 0           //Buy 
#define OP_SELL 1          //Sell 
#define MODE_TRADES 0
#define SELECT_BY_POS 0
#define SELECT_BY_TICKET 1

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---
   if(Bars(_Symbol,_Period)<100){     //Bars-liczba wszystkich słupków na wykresie
      Print("Liczba słupków mniejsza niż 100");
      return(false); //błąd
   }
   if(stopLoss<100){ //stop loss
      Print("StopLoss mniejszy niż 100");
      return(false);//błąd 
   }
//---
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---
   
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
//---
   double previousLongMA, previousShortMA, currentLongMA, currentShortMA;
   
   //długa pozycja
   previousLongMA = iMAMQL4(NULL,0,longMAPeriod,0,MODE_SMA,PRICE_CLOSE,2);
   currentLongMA = iMAMQL4(NULL,0,longMAPeriod,0,MODE_SMA,PRICE_CLOSE,1);
   
   //krótka pozycja
   previousShortMA = iMAMQL4(NULL,0,shortMAPeriod,0,MODE_SMA,PRICE_CLOSE,2);
   currentShortMA = iMAMQL4(NULL,0,shortMAPeriod,0,MODE_SMA,PRICE_CLOSE,1);
   
   if((previousLongMA>=previousShortMA) && (currentLongMA<currentShortMA)){
      closePositions();        //zamknięcie pozycji spełniającej warunki strategii
      openPositions();
   }
}

//+------------------------------------------------------------------+
//| OTWARCIE POZYCJI                                                 |
//+------------------------------------------------------------------+
void openPositions(){
   int total = OrdersTotal();    //łączna kwota obrotu i zleceń oczekujących
   if(total==0){
      openBuyPosition();
   }
}
  
//+------------------------------------------------------------------+
//| OTWARCIE POZYCJI (kupna)                                         |
//|      Kupno przy zachwowaniu warunków zgodnych ze strategią       |
//|      Bid-kurs kupna                                              |
//|      Ask-kurs sprzedaży                                          |
//+------------------------------------------------------------------+
void openBuyPosition(){
   int position = OP_BUY;
   double volume = lot;
   MqlTick last_tick;
   SymbolInfoTick(_Symbol,last_tick);
   double price = last_tick.ask; //kurs sprzedaży
   double sl = last_tick.bid - stopLoss*_Point; 
   double tp = 0;
   if(takeProfit>0){
      tp = last_tick.ask + takeProfit*_Point;
   }  
   color clr = Green;
   sendRequest(position,volume,price,sl,tp,clr);
}

//+------------------------------------------------------------------+
//| ZAMKNIĘCIE POZYCJI                                               |
//+------------------------------------------------------------------+
void closePositions(){
   int position;
   int total = OrdersTotal(); //łączna kwota obrotu i zleceń oczekujących
   if(total>0){
      for(position=0; position<total; position++){
         OrderSelect(position,SELECT_BY_POS,MODE_TRADES); //wybór zlecenia do przetworzenia
         if((OrderType()<=OP_SELL) && (OrderSymbol()==Symbol())){
            closeSellPosition(); //wysłanie żądania zamknięcia zlecenia
         }
      }
   }
}

//+------------------------------------------------------------------+
//| WYSŁANIE ŻĄDANIA ZAMKNIĘCIA POZYCJI (kupna)                      |
//+------------------------------------------------------------------+
void closeBuyPosition(){
   MqlTick last_tick;
   SymbolInfoTick(_Symbol,last_tick);
   OrderClose(OrderTicket(),OrderLots(),last_tick.bid,3,Violet);
}

//+------------------------------------------------------------------+
//| WYSŁANIE ŻĄDANIA ZAMKNIĘCIA POZYCJI (sprzedaży)                  |
//+------------------------------------------------------------------+
void closeSellPosition(){
   MqlTick last_tick;
   SymbolInfoTick(_Symbol,last_tick);
   OrderClose(OrderTicket(),OrderLots(),last_tick.ask,3,Violet);
}

//+------------------------------------------------------------------+
//| WYSŁANIE ZLECENIA NA RYNEK                                       |
//+------------------------------------------------------------------+
void sendRequest(int position, double volume, double price, double sl, double tp, color clr){
   int ticket = OrderSend(Symbol(),position,volume,price,3,sl,tp,"Program",12345,0,clr); //numer zlecenia lub błąd 
   if(ticket>0){ //jeżeli pobrano numer zlecenia to...
      if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES)){ //wybór zlecnia zakończony sukcesem
         Print("Pozycja otwarta:",OrderOpenPrice()); //wartrość aktualnego zlecenia
      }
      else Print("Blad otwarcia pozycji", GetLastError()); //rodzaj błędu
   }
}
//+------------------------------------------------------------------+



double CopyBufferMQL4(int handle,int index,int shift)
  {
   double buf[];
   switch(index)
     {
      case 0: if(CopyBuffer(handle,0,shift,1,buf)>0)
         return(buf[0]); break;
      case 1: if(CopyBuffer(handle,1,shift,1,buf)>0)
         return(buf[0]); break;
      case 2: if(CopyBuffer(handle,2,shift,1,buf)>0)
         return(buf[0]); break;
      case 3: if(CopyBuffer(handle,3,shift,1,buf)>0)
         return(buf[0]); break;
      case 4: if(CopyBuffer(handle,4,shift,1,buf)>0)
         return(buf[0]); break;
      default: break;
     }
   return(EMPTY_VALUE);
  }

double iMAMQL4(string symbol,
               int tf,
               int period,
               int ma_shift,
               int method,
               int price,
               int shift)
  {
   ENUM_TIMEFRAMES timeframe=TFMigrate(tf);
   ENUM_MA_METHOD ma_method=MethodMigrate(method);
   ENUM_APPLIED_PRICE applied_price=PriceMigrate(price);
   int handle=iMA(symbol,timeframe,period,ma_shift,
                  ma_method,applied_price);
   if(handle<0)
     {
      Print("The iMA object is not created: Error",GetLastError());
      return(-1);
     }
   else
      return(CopyBufferMQL4(handle,0,shift));
  }
