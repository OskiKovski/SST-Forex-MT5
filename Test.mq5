//+------------------------------------------------------------------+
//|                                                           EA.mq5 |
//|                                         Copyright 2018, SST Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, SST Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
input int      longMAPeriod=50;   //długi okres średniej kroczącej
input int      shortMAPeriod=10;  //krótki okres średniej kroczącej
input double   takeProfit=1000.0; //poziom take profit
input double   stopLoss=300.0;    //poziom stop loss
input double   lot=500;           //wolumen w lotach
input ulong   dev=5;           //dopuszczalne odchylenie wartości transakcji

#define EXPERT_MAGIC 6969666

int CROSSED_UP = 1;               //zmienna pomocnicza do określania kierunku przecięcia
int CROSSED_DOWN = 2;             //zmienna pomocnicza do określania kierunku przecięcia

//---- arrays for indicators
double      lastMA[2];                // array for the indicator iMA

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---
   double startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   Print("Poczatkowy stan konta:", + startingBalance); 
//---
   lastMA[0]=iMA(_Symbol,_Period,longMAPeriod,0,MODE_SMA,PRICE_CLOSE);
   lastMA[1]=iMA(_Symbol,_Period,shortMAPeriod,0,MODE_SMA,PRICE_CLOSE);
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
   if(validate()) {
      int crossingDirection = calculateAveragesAndCheckDirection();
      closePositions();        //zamknięcie pozycji spełniającej warunki strategii
      openPositions(crossingDirection);
   }
}

bool validate() {
   if(Bars(_Symbol,_Period)<100){     //Bars-liczba wszystkich słupków na wykresie
      Print("Liczba słupków mniejsza niż 100");
      return(false); //błąd
   }
   if(stopLoss<100){ //stop loss
      Print("StopLoss mniejszy niż 100");
      return(false);//błąd 
   }
   return(true);
}


int calculateAveragesAndCheckDirection() {
   double previousLongMA, previousShortMA, currentLongMA, currentShortMA;
   
   previousLongMA=lastMA[0];
   previousShortMA=lastMA[1];
   
   //długa pozycja 
   currentLongMA = iMA(_Symbol,_Period,longMAPeriod,0,MODE_SMA,PRICE_CLOSE);
   
   //krótka pozycja
   currentShortMA = iMA(_Symbol,_Period,shortMAPeriod,0,MODE_SMA,PRICE_CLOSE);
   
   lastMA[0]=currentLongMA;
   lastMA[1]=currentShortMA;
   
   if((previousLongMA>=previousShortMA) && (currentLongMA<currentShortMA)){
      return (CROSSED_UP);
   }
   else if((previousLongMA<=previousShortMA) && (currentLongMA>currentShortMA)){
      return(CROSSED_DOWN);
   }
   else return(0);
}

//+------------------------------------------------------------------+
//| OTWARCIE POZYCJI                                                 |
//+------------------------------------------------------------------+
void openPositions(int direction){
   int total = OrdersTotal();    //łączna kwota obrotu i zleceń oczekujących
   if(total==0){
      if(direction==CROSSED_UP){   //otwarcie pozycji kupna
         openBuyPosition();
      }
      if(direction==CROSSED_DOWN){ //otwarcie pozycji sprzedaży
         openSellPosition();
      }
   }
}
  
//+------------------------------------------------------------------+
//| OTWARCIE POZYCJI (kupna)                                         |
//|      Kupno przy zachwowaniu warunków zgodnych ze strategią       |
//|      Bid-kurs kupna                                              |
//|      Ask-kurs sprzedaży                                          |
//+------------------------------------------------------------------+
void openBuyPosition(){
   MqlTradeRequest request={0};
   MqlTradeResult  result={0};
//--- parameters of request
   request.action   =TRADE_ACTION_DEAL;                     // type of trade operation
   request.symbol   =Symbol();                              // symbol
   request.volume   =lot;                                   // volume of 0.1 lot
   request.type     =ORDER_TYPE_BUY;                        // order type
   request.price    =SymbolInfoDouble(Symbol(),SYMBOL_ASK); // price for opening
   request.deviation=dev;                                   // allowed deviation from the price
   request.magic    =EXPERT_MAGIC;                          // MagicNumber of the order
   
   if(!OrderSend(request,result))
      PrintFormat("OrderSend error %d",GetLastError());     // if unable to send the request, output the error code
//--- information about the operation
   PrintFormat("retcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order);

}

//+------------------------------------------------------------------+
//| OTWARCIE POZYCJI (sprzedaży)                                     |
//|      Point-próg rentowności                                      |
//|      Bid-kurs kupna                                              |
//|      Ask-kurs sprzedaży                                          |
//+------------------------------------------------------------------+
void openSellPosition(){
   MqlTradeRequest request={0};
   MqlTradeResult  result={0};
//--- parameters of request
   request.action   =TRADE_ACTION_DEAL;                     // type of trade operation
   request.symbol   =Symbol();                              // symbol
   request.volume   =lot;                                   // volume of 0.1 lot
   request.type     =ORDER_TYPE_SELL;                       // order type
   request.price    =SymbolInfoDouble(Symbol(),SYMBOL_BID); // price for opening
   request.deviation=dev;                                   // allowed deviation from the price
   request.magic    =EXPERT_MAGIC;                          // MagicNumber of the order
//--- send the request
   if(!OrderSend(request,result))
      PrintFormat("OrderSend error %d",GetLastError());     // if unable to send the request, output the error code
//--- information about the operation
   PrintFormat("retcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order);

}

//+------------------------------------------------------------------+
//| ZAMKNIĘCIE WSZYSTKICH POZYCJI                                               |
//+------------------------------------------------------------------+
void closePositions(){
   MqlTradeRequest request;
   MqlTradeResult  result;
   int total=PositionsTotal(); // number of open positions   
//--- iterate over all open positions
   for(int i=total-1; i>=0; i--)
     {
      //--- parameters of the order
      ulong  position_ticket=PositionGetTicket(i);                                      // ticket of the position
      string position_symbol=PositionGetString(POSITION_SYMBOL);                        // symbol 
      int    digits=(int)SymbolInfoInteger(position_symbol,SYMBOL_DIGITS);              // number of decimal places
      ulong  magic=PositionGetInteger(POSITION_MAGIC);                                  // MagicNumber of the position
      double volume=PositionGetDouble(POSITION_VOLUME);                                 // volume of the position
      ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);    // type of the position
      //--- output information about the position
      PrintFormat("#%I64u %s  %s  %.2f  %s [%I64d]",
                  position_ticket,
                  position_symbol,
                  EnumToString(type),
                  volume,
                  DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),digits),
                  magic);
      //--- if the MagicNumber matches
      if(magic==EXPERT_MAGIC)
        {
         //--- zeroing the request and result values
         ZeroMemory(request);
         ZeroMemory(result);
         //--- setting the operation parameters
         request.action   =TRADE_ACTION_DEAL;        // type of trade operation
         request.position =position_ticket;          // ticket of the position
         request.symbol   =position_symbol;          // symbol 
         request.volume   =volume;                   // volume of the position
         request.deviation=5;                        // allowed deviation from the price
         request.magic    =EXPERT_MAGIC;             // MagicNumber of the position
         //--- set the price and order type depending on the position type
         if(type==POSITION_TYPE_BUY)
           {
            request.price=SymbolInfoDouble(position_symbol,SYMBOL_BID);
            request.type =ORDER_TYPE_SELL;
           }
         else
           {
            request.price=SymbolInfoDouble(position_symbol,SYMBOL_ASK);
            request.type =ORDER_TYPE_BUY;
           }
         //--- output information about the closure
         PrintFormat("Close #%I64d %s %s",position_ticket,position_symbol,EnumToString(type));
         //--- send the request
         if(!OrderSend(request,result))
            PrintFormat("OrderSend error %d",GetLastError());  // if unable to send the request, output the error code
         //--- information about the operation   
         PrintFormat("retcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order);
         //---
        }
     }
}