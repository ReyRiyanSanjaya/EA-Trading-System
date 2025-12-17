//+------------------------------------------------------------------+
//|                                                      ESD_Dragon.mqh |
//|                                                              SMC |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "SMC"
#property link      "https://www.mql5.com"

#include "ESD_Globals.mqh"
#include "ESD_Inputs.mqh"

int emaHandle = INVALID_HANDLE;
datetime lastCandleTime = 0;
int OnInitDragon()
{
   emaHandle = iMA(_Symbol, PERIOD_M1, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   if(emaHandle == INVALID_HANDLE)
   {
      Print("Error creating EMA indicator");
      return(INIT_FAILED);
   }
   return(INIT_SUCCEEDED);
}


void DragonMomentum()
{
   MqlRates currentCandle[];
   ArraySetAsSeries(currentCandle, true);
   CopyRates(_Symbol, PERIOD_M1, 1, 1, currentCandle);
    
   if(currentCandle[0].time == lastCandleTime) return;
   
   double candleRange = currentCandle[0].high - currentCandle[0].low;
   double bodySize = MathAbs(currentCandle[0].close - currentCandle[0].open);
   
   bool isStrongCandle = (candleRange > MinDragonPower) && 
                        (bodySize >= SoulEssence * candleRange);
   
   if(isStrongCandle && !PositionSelect(_Symbol))
   {
      // Dapatkan nilai EMA
      double emaValue[];
      ArraySetAsSeries(emaValue, true);
      CopyBuffer(emaHandle, 0, 0, 1, emaValue);
      
      double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double deviation = MathAbs(currentAsk - emaValue[0]) / _Point;
      
      // Tentukan arah candle
      bool isBullish = currentCandle[0].close > currentCandle[0].open;
      bool isBearish = currentCandle[0].close < currentCandle[0].open;
      
      // Inisialisasi variabel dengan nilai default
      ENUM_ORDER_TYPE orderType = ORDER_TYPE_BUY;
      double entryPrice = currentAsk;
      double sl = 0.0;
      double tp = 0.0;
      bool shouldEntry = false;
      
      if(isBullish)
      {
         // BUY: Hanya entry jika harga TIDAK JAUH DI ATAS EMA
         if(currentAsk <= emaValue[0] + (Max_Deviation_Pips * _Point))
         {
            orderType = ORDER_TYPE_BUY;
            entryPrice = currentAsk;
            sl = entryPrice - FireBreath * _Point;
            tp = entryPrice + SkyReach * _Point;
            shouldEntry = true;
            Print("✅ BUY Signal - Harga dekat atau di bawah EMA10");
         }
         else
         {
            Print("❌ Skip BUY - Harga sudah terlalu jauh di atas EMA10. Deviation: ", deviation, " pips");
         }
      }
      else if(isBearish)
      {
         // SELL: Hanya entry jika harga TIDAK JAUH DI BAWAH EMA
         if(currentBid >= emaValue[0] - (Max_Deviation_Pips * _Point))
         {
            orderType = ORDER_TYPE_SELL;
            entryPrice = currentBid;
            sl = entryPrice + FireBreath * _Point;
            tp = entryPrice - SkyReach * _Point;
            shouldEntry = true;
            Print("✅ SELL Signal - Harga dekat atau di atas EMA10");
         }
         else
         {
            Print("❌ Skip SELL - Harga sudah terlalu jauh di bawah EMA10. Deviation: ", deviation, " pips");
         }
      }
      
      // Eksekusi trade jika memenuhi kriteria
      if(shouldEntry)
      {
         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         
         request.action = TRADE_ACTION_DEAL;
         request.symbol = _Symbol;
         request.volume = DragonScale;
         request.type = orderType;
         request.price = entryPrice;
         request.sl = sl;
         request.tp = tp;
         request.deviation = 10;
         request.magic = mysticalSeal;
         request.comment = "Dragon Momentum";
         
         if(OrderSend(request, result) && result.retcode == TRADE_RETCODE_DONE)
         {
            lastCandleTime = currentCandle[0].time;
            Print("🐉 Entry ", orderType == ORDER_TYPE_BUY ? "BUY" : "SELL", 
                  " | Deviation: ", deviation, " pips",
                  " | EMA: ", emaValue[0]);
         }
      }
      else
      {
         lastCandleTime = currentCandle[0].time; // Tetap update waktu meski skip entry
      }
   }
}


void UpdateMaxLossSL_AndReversal(double maxLossPip)
{
    string symbol = _Symbol;
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double pipValue = (digits == 3 || digits == 5) ? point * 10.0 : point;
    double maxLossDistance = maxLossPip * pipValue;

    // Jika tidak ada posisi aktif, hentikan
    if (!PositionSelect(symbol))
        return;

    // --- Ambil data posisi aktif ---
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double sl = PositionGetDouble(POSITION_SL);
    double tp = PositionGetDouble(POSITION_TP);
    long type = PositionGetInteger(POSITION_TYPE); // 0=BUY, 1=SELL
    double volume = PositionGetDouble(POSITION_VOLUME);

    double newSL;

    // Hitung SL baru sesuai arah
    if (type == POSITION_TYPE_BUY)
        newSL = openPrice - maxLossDistance;
    else
        newSL = openPrice + maxLossDistance;

    // Update SL jika berbeda
    if (MathAbs(sl - newSL) > (pipValue / 2.0))
    {
        bool mod = ESD_trade.PositionModify(symbol, newSL, tp);
        if (mod)
            PrintFormat("✅ [%s] SL Diperbarui: Open=%.5f | SL=%.5f | MaxLoss=%.0f pip",
                        symbol, openPrice, newSL, maxLossPip);
        else
            PrintFormat("❌ [%s] Gagal update SL | Error %d", symbol, GetLastError());
    }

    // --- Cek apakah posisi sudah kena SL ---
    double currentPrice = (type == POSITION_TYPE_BUY)
                              ? SymbolInfoDouble(symbol, SYMBOL_BID)
                              : SymbolInfoDouble(symbol, SYMBOL_ASK);

    bool slHit = false;
    if (type == POSITION_TYPE_BUY && currentPrice <= newSL)
        slHit = true;
    else if (type == POSITION_TYPE_SELL && currentPrice >= newSL)
        slHit = true;

    // Jika SL kena → tutup posisi & entry arah berlawanan
    if (slHit)
    {
        PrintFormat("⚠️ [%s] SL Tersentuh | %s Kena di Harga=%.5f | SL=%.5f",
                    symbol, (type == POSITION_TYPE_BUY ? "BUY" : "SELL"), currentPrice, newSL);

        // Tutup posisi lama
        ESD_trade.PositionClose(symbol);
        Sleep(500);

        // Entry arah berlawanan + comment di order
        string commentOrder;

        if (type == POSITION_TYPE_BUY)
        {
            commentOrder = StringFormat("Reversal SELL setelah SL BUY di %.5f (Loss %.0f pip)",
                                        newSL, maxLossPip);
            if (ESD_trade.Sell(volume, symbol, 0, 0, 0, commentOrder))
                PrintFormat("🔁 %s | SELL dibuka di %.5f | Lot=%.2f | Comment='%s'",
                            symbol, SymbolInfoDouble(symbol, SYMBOL_BID), volume, commentOrder);
        }
        else
        {
            commentOrder = StringFormat("Reversal BUY setelah SL SELL di %.5f (Loss %.0f pip)",
                                        newSL, maxLossPip);
            if (ESD_trade.Buy(volume, symbol, 0, 0, 0, commentOrder))
                PrintFormat("🔁 %s | BUY dibuka di %.5f | Lot=%.2f | Comment='%s'",
                            symbol, SymbolInfoDouble(symbol, SYMBOL_ASK), volume, commentOrder);
        }
    }
}


