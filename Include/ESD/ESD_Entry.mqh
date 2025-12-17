//+------------------------------------------------------------------+
//|                        ESD TRADING FRAMEWORK                      |
//|                           ESD_Entry.mqh                           |
//+------------------------------------------------------------------+
//| MODULE: Entry Signal Logic
//|
//| DESCRIPTION:
//|   Entry signal generation based on SMC zones, confirmations,
//|   and multi-filter validation for BUY/SELL decisions.
//|
//| DEPENDENCIES:
//|   - ESD_Globals.mqh, ESD_Inputs.mqh, ESD_SMC.mqh, ESD_Trend.mqh
//|   - ESD_Execution.mqh, ESD_Risk.mqh, ESD_Core.mqh
//|
//| PUBLIC FUNCTIONS:
//|   - ESD_CheckForEntry()             : Main entry logic
//|   - ESD_CheckForAggressiveEntry()   : Aggressive mode entries
//|   - ESD_CheckForShortEntries()      : Short trading entries
//|   - ESD_CheckForEntryWithML()       : ML-enhanced entries
//|   - ESD_StochasticEntryFilter()     : Oscillator filter
//|   - ESD_IsValidMomentum()           : Momentum validation
//|   - ESD_HasRetestOccurred()         : Retest confirmation
//|
//| VERSION: 2.1 | LAST UPDATED: 2025-12-17
//+------------------------------------------------------------------+
#property copyright "SMC"
#property link      "https://www.mql5.com"

#include "ESD_Globals.mqh"
#include "ESD_Inputs.mqh"

#include "ESD_SMC.mqh"
#include "ESD_Trend.mqh"
#include "ESD_Execution.mqh"
#include "ESD_Risk.mqh"
#include "ESD_Core.mqh"

//+------------------------------------------------------------------+
//| Check for Main Entry Signal                                     |
//+------------------------------------------------------------------+
void ESD_CheckForEntry()
{
    // Jika sudah ada posisi, tidak usah entry lagi
    // if (PositionSelect(_Symbol))
    //     return;

    // ?? PRIORITAS 1: ENTRY BERDASARKAN INDUCEMENT (False Breakout)
    if (ESD_TradeAgainstInducement())
        return; // Jika sudah entry dari inducement, skip logic lainnya

    // Tambah filter momentum
    if (!ESD_IsValidMomentum(ESD_bullish_trend_confirmed))
        return;

    // --- Dapatkan data harga ---
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // Data candle untuk konfirmasi
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    CopyRates(_Symbol, PERIOD_CURRENT, 0, ESD_RejectionCandleLookback + 2, rates);

    // Toleransi zona
    double tolerance = ESD_ZoneTolerancePoints * point;

    // ================== LOGIKA ENTRY BUY ==================
    if (ESD_bullish_trend_confirmed && ESD_bullish_trend_strength >= ESD_TrendStrengthThreshold)
    {
        // REGIME FILTER untuk BUY
        if (!ESD_RegimeFilter(true))
            return;

        // ?? BSL/SSL AVOIDANCE CHECK
        if (ESD_IsInBSL_SSLZone(ask, true))
            return;

        bool is_in_buy_zone = false;
        bool is_retesting_zone = false;
        double zone_top = 0;
        double zone_bottom = 0;
        string zone_type = "";
        double zone_quality = 0.0;

        // HANYA entry buy jika candle terakhir adalah BULLISH
        MqlRates current_candle = rates[0];
        bool is_bullish_candle = (current_candle.close > current_candle.open);
        bool strong_bullish = ((current_candle.close - current_candle.open) > (current_candle.high - current_candle.low) * 0.6);

        if (!is_bullish_candle && !strong_bullish)
        {
            return; // Jangan entry buy jika candle bearish
        }

        // 1. Cek apakah harga berada di zona Bullish FVG
        if (ESD_bullish_fvg_bottom != EMPTY_VALUE)
        {
            if (ask >= ESD_bullish_fvg_bottom - tolerance && ask <= ESD_bullish_fvg_top + tolerance)
            {
                is_in_buy_zone = true;
                zone_top = ESD_bullish_fvg_top;
                zone_bottom = ESD_bullish_fvg_bottom;
                zone_type = "FVG";
                zone_quality = ESD_GetZoneQuality("FVG", iTime(_Symbol, ESD_HigherTimeframe, 0), true);
            }
        }

        // 2. Jika tidak di FVG, cek apakah harga berada di zona Bullish OB
        if (!is_in_buy_zone && ESD_bullish_ob_bottom != EMPTY_VALUE)
        {
            if (ask >= ESD_bullish_ob_bottom - tolerance && ask <= ESD_bullish_ob_top + tolerance)
            {
                is_in_buy_zone = true;
                zone_top = ESD_bullish_ob_top;
                zone_bottom = ESD_bullish_ob_bottom;
                zone_type = "OB";
                zone_quality = ESD_GetZoneQuality("OB", iTime(_Symbol, ESD_HigherTimeframe, ESD_ObLookback), true);
            }
        }

        // 3. Cek apakah FVG baru saja terisi (harga menembus FVG dari bawah)
        bool fvg_just_filled = false;
        if (ESD_bullish_fvg_bottom != EMPTY_VALUE && !is_in_buy_zone)
        {
            if (ask > ESD_bullish_fvg_top && rates[1].close < ESD_bullish_fvg_bottom)
            {
                fvg_just_filled = true;
                zone_top = ESD_bullish_fvg_top;
                zone_bottom = ESD_bullish_fvg_bottom;
                zone_type = "FVG_FILLED";
                is_retesting_zone = true;
                zone_quality = ESD_GetZoneQuality("FVG", iTime(_Symbol, ESD_HigherTimeframe, 0), true);
            }
        }

        // Quality filter check
        if (ESD_EnableQualityFilter && zone_quality < ESD_MinZoneQualityScore)
        {
            is_in_buy_zone = false;
            fvg_just_filled = false;
        }

        // Jika harga berada di zona atau FVG baru saja terisi, lanjut ke pengecekan berikutnya
        if ((is_in_buy_zone && is_retesting_zone) || fvg_just_filled)
        {
            // Additional confirmation checks
            bool confirmed = true;

            // Rejection candle confirmation
            if (ESD_UseRejectionCandleConfirmation)
            {
                confirmed = ESD_IsRejectionCandle(rates[ESD_RejectionCandleLookback], true);
            }

            // Liquidity sweep confirmation
            if (ESD_EnableLiquiditySweepFilter && ESD_bullish_liquidity != EMPTY_VALUE)
            {
                confirmed = confirmed && ESD_IsLiquiditySweeped(ESD_bullish_liquidity, true);
            }

            // FVG mitigation filter
            if (ESD_UseFvgMitigationFilter && ESD_bullish_fvg_bottom != EMPTY_VALUE)
            {
                confirmed = confirmed && ESD_IsFVGMitigated(ESD_bullish_fvg_top, ESD_bullish_fvg_bottom, true);
            }

            // Heatmap + Order Flow confirmation filter (CORE)
            if (!ESD_HeatmapFilter(true) || !ESD_OrderFlowFilter(true))
            {
               return;
            }

            // === Stochastic Entry Filter ===
            if (!ESD_StochasticEntryFilter(true))
                return;

            if (confirmed)
            {
                // --- PERHITUNGAN SL & TP ---
                double sl = 0;
                double tp = 0;
                double trigger_price = zone_bottom;

                // Jika menggunakan Partial TP, hitung TP level 3
                if (ESD_UsePartialTP)
                {
                    tp = ask + ESD_PartialTPDistance3 * point;

                    // SL dihitung sesuai metode yang dipilih
                    switch (ESD_SlTpMethod)
                    {
                    case ESD_FIXED_POINTS:
                        sl = zone_bottom - ESD_StopLossPoints * point;
                        break;

                    case ESD_SWING_POINTS:
                        if (ESD_last_significant_pl > 0)
                            sl = ESD_last_significant_pl - ESD_SlBufferPoints * point;
                        else
                            sl = zone_bottom - ESD_SlBufferPoints * point;
                        break;

                    case ESD_LIQUIDITY_LEVELS:
                        sl = zone_bottom - ESD_SlBufferPoints * point;
                        break;

                    case ESD_RISK_REWARD_RATIO:
                        sl = zone_bottom - ESD_SlBufferPoints * point;
                        break;

                    case ESD_STRUCTURE_BASED:
                        if (zone_type == "FVG" && ESD_bullish_fvg_bottom != EMPTY_VALUE)
                            sl = ESD_bullish_fvg_bottom - ESD_SlBufferPoints * point;
                        else if (zone_type == "CHOCH" || zone_type == "BoS")
                            sl = trigger_price - ESD_SlBufferPoints * point;
                        else
                            sl = zone_bottom - ESD_SlBufferPoints * point;
                        break;
                    }
                }
                else
                {
                    double risk = ask - sl;
                    if (risk > 0)
                        tp = ask + (risk * ESD_RiskRewardRatio);
                    else
                        tp = ask + ESD_TakeProfitPoints * point;
                }

                string comment = StringFormat("SMC Buy (%s) Q=%.2f", zone_type, zone_quality);

                // --- EKSEKUSI TRADE ---
                if (ESD_UsePartialTP)
                    ESD_ExecuteTradeWithPartialTP(true, ask, sl, comment);
                else
                    ESD_trade.Buy(ESD_LotSize, _Symbol, ask, sl, tp, comment);
            }
        }
    }

    // ================== LOGIKA ENTRY SELL ==================
    else if (ESD_bearish_trend_confirmed && ESD_bearish_trend_strength >= ESD_TrendStrengthThreshold)
    {
        // REGIME FILTER untuk SELL
        if (!ESD_RegimeFilter(false))
            return;

        // ?? BSL/SSL AVOIDANCE CHECK
        if (ESD_IsInBSL_SSLZone(bid, false))
            return;

        bool is_in_sell_zone = false;
        bool is_retesting_zone = false;
        double zone_top = 0;
        double zone_bottom = 0;
        string zone_type = "";
        double zone_quality = 0.0;

        // HANYA entry sell jika candle terakhir adalah BEARISH
        MqlRates current_candle = rates[0];
        bool is_bearish_candle = (current_candle.close < current_candle.open);
        bool strong_bearish = ((current_candle.open - current_candle.close) > (current_candle.high - current_candle.low) * 0.6);

        if (!is_bearish_candle && !strong_bearish)
        {
            return; // Jangan entry sell jika candle bullish
        }

        // 1. Cek apakah harga berada di zona Bearish FVG
        if (ESD_bearish_fvg_top != EMPTY_VALUE)
        {
            if (bid <= ESD_bearish_fvg_top + tolerance && bid >= ESD_bearish_fvg_bottom - tolerance)
            {
                is_in_sell_zone = true;
                zone_top = ESD_bearish_fvg_top;
                zone_bottom = ESD_bearish_fvg_bottom;
                zone_type = "FVG";
                zone_quality = ESD_GetZoneQuality("FVG", iTime(_Symbol, ESD_HigherTimeframe, 0), false);
            }
        }

        // 2. Jika tidak di FVG, cek apakah harga berada di zona Bearish OB
        if (!is_in_sell_zone && ESD_bearish_ob_top != EMPTY_VALUE)
        {
            if (bid <= ESD_bearish_ob_top + tolerance && bid >= ESD_bearish_ob_bottom - tolerance)
            {
                is_in_sell_zone = true;
                zone_top = ESD_bearish_ob_top;
                zone_bottom = ESD_bearish_ob_bottom;
                zone_type = "OB";
                zone_quality = ESD_GetZoneQuality("OB", iTime(_Symbol, ESD_HigherTimeframe, ESD_ObLookback), false);
            }
        }

        // Quality filter check
        if (ESD_EnableQualityFilter && zone_quality < ESD_MinZoneQualityScore)
            is_in_sell_zone = false;

        // Jika harga berada di zona, lanjut ke pengecekan berikutnya
        if (is_in_sell_zone && (is_retesting_zone || true)) // Simplifikasi, retest logic bisa kompleks
        {
            // Additional confirmation checks
            bool confirmed = true;

            // Rejection candle confirmation
            if (ESD_UseRejectionCandleConfirmation)
            {
                confirmed = ESD_IsRejectionCandle(rates[ESD_RejectionCandleLookback], false);
            }

            // Liquidity sweep confirmation
            if (ESD_EnableLiquiditySweepFilter && ESD_bearish_liquidity != EMPTY_VALUE)
            {
                confirmed = confirmed && ESD_IsLiquiditySweeped(ESD_bearish_liquidity, false);
            }

            // FVG mitigation filter
            if (ESD_UseFvgMitigationFilter && ESD_bearish_fvg_top != EMPTY_VALUE)
            {
                confirmed = confirmed && ESD_IsFVGMitigated(ESD_bearish_fvg_top, ESD_bearish_fvg_bottom, false);
            }

             // Heatmap + Order Flow confirmation filter (CORE)
            if (!ESD_HeatmapFilter(false) || !ESD_OrderFlowFilter(false))
            {
               return;
            }

            // === Stochastic Entry Filter ===
            if (!ESD_StochasticEntryFilter(false))
                return;

            if (confirmed)
            {
                // --- PERHITUNGAN SL & TP ---
                double sl = 0;
                double tp = 0;
                double trigger_price = zone_top;

                // Jika menggunakan Partial TP
                if (ESD_UsePartialTP)
                {
                    tp = bid - ESD_PartialTPDistance3 * point;

                    // SL calculation logic
                    switch (ESD_SlTpMethod)
                    {
                    case ESD_FIXED_POINTS:
                        sl = zone_top + ESD_StopLossPoints * point;
                        break;
                    case ESD_SWING_POINTS:
                        if (ESD_last_significant_ph > 0)
                            sl = ESD_last_significant_ph + ESD_SlBufferPoints * point;
                        else
                            sl = zone_top + ESD_SlBufferPoints * point;
                        break;
                    case ESD_LIQUIDITY_LEVELS:
                    case ESD_RISK_REWARD_RATIO:
                        sl = zone_top + ESD_SlBufferPoints * point;
                        break;
                    case ESD_STRUCTURE_BASED:
                        if (zone_type == "FVG" && ESD_bearish_fvg_top != EMPTY_VALUE)
                            sl = ESD_bearish_fvg_top + ESD_SlBufferPoints * point;
                        else if (zone_type == "CHOCH" || zone_type == "BoS")
                            sl = trigger_price + ESD_SlBufferPoints * point;
                        else
                            sl = zone_top + ESD_SlBufferPoints * point;
                        break;
                    }
                }
                else
                {
                    double risk = sl - bid;
                    if (risk > 0)
                        tp = bid - (risk * ESD_RiskRewardRatio);
                    else
                        tp = bid - ESD_TakeProfitPoints * point;
                }

                string comment = StringFormat("SMC Sell (%s) Q=%.2f", zone_type, zone_quality);

                // --- EKSEKUSI TRADE ---
                if (ESD_UsePartialTP)
                    ESD_ExecuteTradeWithPartialTP(false, bid, sl, comment);
                else
                    ESD_trade.Sell(ESD_LotSize, _Symbol, bid, sl, tp, comment);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check for Aggressive Entry                                      |
//+------------------------------------------------------------------+
void ESD_CheckForAggressiveEntry()
{
    if (!ESD_AggressiveMode)
        return;
        
    // Logic aggressive tetap sama, hanya structure code dipindah
    if (ESD_TradeOnFVGDetection && ESD_fvg_creation_time > TimeCurrent() - 60)
    {
         if (ESD_bullish_fvg_bottom != EMPTY_VALUE)
            ESD_ExecuteAggressiveBuy();
         else if (ESD_bearish_fvg_top != EMPTY_VALUE)
            ESD_ExecuteAggressiveSell();
    }
}

//+------------------------------------------------------------------+
//| Check for Short Trading Opportunities                           |
//+------------------------------------------------------------------+
void ESD_CheckForShortEntries()
{
    // Hanya short entries
    if (!ESD_EnableShortTrading) return;

    // ... Logic short (Liquidity Hunt, Breakdown) here ...
    // Diisi dengan fungsi yang sudah dibuat sebelumnya
    
    // Panggil helper functions
    if(ESD_IsLiquidityHuntOpportunity())
        ESD_ExecuteLiquidityShortTrade();
}

//+------------------------------------------------------------------+
//| ML Enhanced Entry                                               |
//+------------------------------------------------------------------+
void ESD_CheckForEntryWithML()
{
    if (!ESD_UseMachineLearning)
        return;
        
    // --- Collect Features ---
    ESD_ML_Features features = ESD_CollectMLFeatures();
    
    // ... Logic ML ...
    double buy_signal = ESD_GetMLEntrySignal(true, features);
    double sell_signal = ESD_GetMLEntrySignal(false, features);
    
    if (buy_signal > 0.7) // Confidence threshold
    {
         // ML Buy Logic
    }
    else if (sell_signal < -0.7)
    {
         // ML Sell Logic
    }
}

//+------------------------------------------------------------------+
//| Helper: Stochastic Filter                                       |
//+------------------------------------------------------------------+
bool ESD_StochasticEntryFilter(bool is_buy)
{
    double k[], d[];
    ArraySetAsSeries(k, true);
    ArraySetAsSeries(d, true);
    
    int stoch_handle = iStochastic(_Symbol, PERIOD_CURRENT, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
    if(CopyBuffer(stoch_handle, 0, 0, 2, k) < 2 || CopyBuffer(stoch_handle, 1, 0, 2, d) < 2)
       return true; // Default allow if error
       
    if (is_buy)
        return (k[0] < 80); // Jangan beli di overbought ekstrim tanpa momentum
    else
        return (k[0] > 20); // Jangan jual di oversold ekstrim
}

//+------------------------------------------------------------------+
//| Helper: Valid Momentum                                          |
//+------------------------------------------------------------------+
bool ESD_IsValidMomentum(bool is_bullish)
{
   // Simple RSI momentum check
   double rsi = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
   if (is_bullish) return rsi > 40;
   else return rsi < 60;
}

//+------------------------------------------------------------------+
//| Helper: Retest Occurred                                         |
//+------------------------------------------------------------------+
bool ESD_HasRetestOccurred(string type, double level, bool is_bullish)
{
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 10, rates) < 10) return false;
    
    for(int i=1; i<10; i++)
    {
       if(is_bullish && rates[i].low <= level && rates[i].close > level) return true;
       if(!is_bullish && rates[i].high >= level && rates[i].close < level) return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Helper: Inducement Logic                                        |
//+------------------------------------------------------------------+
bool ESD_TradeAgainstInducement()
{
   // Placeholder logic for Inducement Strategy
   // Return true if trade taken
   return false;
}

//+------------------------------------------------------------------+
//| Helper: Check ML Alternative Entries                            |
//+------------------------------------------------------------------+
void ESD_CheckMLAggressiveAlternativeEntries()
{
   // Logic for aggressive ML entries
}

//+------------------------------------------------------------------+
//| Helper: Liquidity Hunt Logic                                    |
//+------------------------------------------------------------------+
bool ESD_IsLiquidityHuntOpportunity()
{
   // Check for liquidity grab patterns
   return false; 
}

void ESD_ExecuteLiquidityShortTrade()
{
   // Execute short trade
}

//+------------------------------------------------------------------+
//| Helper: Short Helpers                                           |
//+------------------------------------------------------------------+
bool ESD_IsBreakdownOpportunity() { return false; }
bool ESD_IsBearishFVGOpportunity() { return false; }
bool ESD_IsResistanceTestOpportunity() { return false; }

//+------------------------------------------------------------------+
//| Helper for Inducement Signal                                    |
//+------------------------------------------------------------------+
bool ESD_IsBullishInducementSignal() { return false; }
bool ESD_IsBearishInducementSignal() { return false; }
bool ESD_HasLowerTFConfirmation(bool is_buy) { return true; }

// --- END OF FILE ---
