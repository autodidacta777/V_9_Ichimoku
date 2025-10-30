//+------------------------------------------------------------------+
//|              EA Ichimoku con trailing dinámico                   |
//+------------------------------------------------------------------+
#property strict

input double Lote = 0.01;
input double SL_USD = 0.5;
input double TP_USD = 6.0;
input double TrailingStart = 0.5;   // activar trailing a +3 USD
input double TrailingStep = 0.5;    // trailing de 1 USD
input int MaxTrades = 2;

//--- función valor pip
double ValorPip()
{
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   return tickValue * Lote * 100000 / 10.0;
}

//--- función para contar trades del símbolo actual
int ContarOperaciones()
{
   int c = 0;
   for(int i=0; i<OrdersTotal(); i++)
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if(OrderSymbol() == Symbol())
            c++;
   return c;
}

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
{
   if(ContarOperaciones() >= MaxTrades) return;

   //--- obtener valores Ichimoku
   double tenkan0 = iIchimoku(NULL, 0, 9, 26, 52, MODE_TENKANSEN, 0);
   double kijun0  = iIchimoku(NULL, 0, 9, 26, 52, MODE_KIJUNSEN, 0);
   double tenkan1 = iIchimoku(NULL, 0, 9, 26, 52, MODE_TENKANSEN, 1);
   double kijun1  = iIchimoku(NULL, 0, 9, 26, 52, MODE_KIJUNSEN, 1);

   bool cruceAlcista = (tenkan1 < kijun1 && tenkan0 > kijun0);
   bool cruceBajista = (tenkan1 > kijun1 && tenkan0 < kijun0);

   double pipValue = ValorPip();
   if(pipValue <= 0) pipValue = 1;

   double sl_pips = SL_USD / pipValue / Point;
   double tp_pips = TP_USD / pipValue / Point;

   //--- abrir compra
   if(cruceAlcista)
   {
      double sl = Bid - sl_pips * Point;
      double tp = Bid + tp_pips * Point;
      int ticket = OrderSend(Symbol(), OP_BUY, Lote, Ask, 3, sl, tp, "Ichimoku Buy", 12345, 0, clrGreen);
      if(ticket < 0) Print("Error compra: ", GetLastError());
   }

   //--- abrir venta
   if(cruceBajista)
   {
      double sl = Ask + sl_pips * Point;
      double tp = Ask - tp_pips * Point;
      int ticket = OrderSend(Symbol(), OP_SELL, Lote, Bid, 3, sl, tp, "Ichimoku Sell", 12346, 0, clrRed);
      if(ticket < 0) Print("Error venta: ", GetLastError());
   }

   //--- trailing dinámico
   for(int i=0; i<OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() != Symbol()) continue;

         double profitUSD = OrderProfit() + OrderSwap() + OrderCommission();
         if(profitUSD >= TrailingStart)
         {
            double pipValue2 = MarketInfo(Symbol(), MODE_TICKVALUE);
            double newStop;

            if(OrderType() == OP_BUY)
            {
               newStop = Bid - (TrailingStep / pipValue2) * Point * 10;
               if(newStop > OrderStopLoss())
                  OrderModify(OrderTicket(), OrderOpenPrice(), newStop, OrderTakeProfit(), 0, clrBlue);
            }
            if(OrderType() == OP_SELL)
            {
               newStop = Ask + (TrailingStep / pipValue2) * Point * 10;
               if(newStop < OrderStopLoss() || OrderStopLoss() == 0)
                  OrderModify(OrderTicket(), OrderOpenPrice(), newStop, OrderTakeProfit(), 0, clrBlue);
            }
         }
      }
   }
}
