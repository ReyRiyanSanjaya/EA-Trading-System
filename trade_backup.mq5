#property copyright "SMC"
#property link "https://www.mql5.com"
#property version "2.00" // Enhanced direction accuracy

#include <Trade\Trade.mqh>

//--- Parameter Input
//--- SMC Analysis Settings
input ENUM_TIMEFRAMES ESD_HigherTimeframe = PERIOD_H1; // Timeframe untuk Analisis SMC
input ENUM_TIMEFRAMES ESD_SupremeTimeframe = PERIOD_H4; // Supreme Timeframe untuk konfirmasi arah
input int ESD_SwingLookback = 50;                       // Swing lookback period
input int ESD_BosLookback = 5;                          // BoS lookback period
input int ESD_ObLookback = 5;                           // Order Block lookback period
input int ESD_ChochLookback = 3;                        // CHoCH lookback period
input double ESD_MinSwingStrength = 0.05;               // Minimum swing strength (ATR multiplier)

//--- Enhanced Direction Settings
input bool ESD_UseStrictTrendConfirmation = true; // Use strict trend confirmation
input int ESD_TrendConfirmationBars = 3;          // Number of bars for trend confirmation
double ESD_TrendStrengthThreshold = 0.5;          // Minimum trend strength (0-1)
input bool ESD_UseMultiTimeframeAnalysis = false; // Use multiple timeframe analysis
input bool ESD_UseVolumeConfirmation = false;     // Use volume for confirmation (if available)
input bool ESD_UseMarketStructureShift = true;    // Detect Market Structure Shift (MSS)

//+------------------------------------------------------------------+
//| Liquidity Grab Variables                                         |
//+------------------------------------------------------------------+
datetime last_liquidity_grab_time = 0;
double liquidity_grab_level = 0;
bool liquidity_grab_active = false;
int liquidity_grab_direction = 0; // 1 = bullish, -1 = bearish

input group "=== Liquidity Grab Strategy ===" input bool ESD_UseLiquidityGrabStrategy = true;
input int ESD_LiquidityGrabCooldown = 3600;
input int ESD_LiquidityGrabTimeout = 300;
input double ESD_LiquidityGrabLotSize = 0.08;
string liquidity_grab_signal_type;  // Untuk menyimpan jenis sinyal (BoS/CHOCH)
double liquidity_grab_signal_price; // Untuk menyimpan harga sinyal

//--- Enhanced Entry Settings
input bool ESD_UseRejectionCandleConfirmation = false; // Use rejection candle confirmation
input int ESD_RejectionCandleLookback = 1;             // Candle ke berapa yang diperiksa untuk konfirmasi
input bool ESD_EnableLiquiditySweepFilter = true;      // Enable liquidity sweep filter
input double ESD_ZoneTolerancePoints = 200;            // Tolerance for zone triggers
input bool ESD_EnableQualityFilter = true;             // Enable quality filter for zones
double ESD_MinZoneQualityScore = 0.3;                  // Minimum zone quality score (0-1)

//--- AGGRESSIVE TRADING SETTINGS
input bool ESD_AggressiveMode = true;          // Enable aggressive trading mode
input bool ESD_TradeOnFVGDetection = true;     // Enter trade immediately on FVG detection
input bool ESD_TradeOnCHOCHDetection = true;   // Enter trade immediately on CHOCH detection
input bool ESD_TradeOnBOSSignal = true;        // Enter trade on BoS signal in aggressive mode
input double ESD_AggressiveSLMultiplier = 1.5; // SL multiplier for aggressive mode (higher for safety)
input double ESD_AggressiveTPMultiplier = 1.2; // TP multiplier for aggressive mode

//--- Calculation Method
input bool ESD_UseAtrMethod = true; // Calculation method: true=ATR, false=High/Low

//--- FVG Settings
input int ESD_FvgLookback = 5;                // Lookback untuk deteksi FVG (candle)
input int ESD_FvgDisplayLength = 20;          // Display length for FVG
input bool ESD_UseFvgMitigationFilter = true; // Filter entries based on FVG mitigation

//--- Trading Settings
input double ESD_LotSize = 0.1;        // Volume Lot
input int ESD_StopLossPoints = 3000;   // Stop Loss in points
input int ESD_TakeProfitPoints = 6000; // Take Profit in points
input ulong ESD_MagicNumber = 12345;   // Magic Number untuk EA
input int ESD_Slippage = 3;            // Slippage (Deviation in points)

//--- Enhanced SL/TP Settings
enum ENUM_ESD_SL_TP_METHOD
{
    ESD_FIXED_POINTS,      // Fixed Points
    ESD_SWING_POINTS,      // Berdasarkan Swing High/Low Terakhir
    ESD_LIQUIDITY_LEVELS,  // Berdasarkan Level Likuiditas Berlawanan
    ESD_RISK_REWARD_RATIO, // Berdasarkan Rasio Risk:Reward
    ESD_STRUCTURE_BASED    // Based on SMC structures (OB/FVG)
};
input ENUM_ESD_SL_TP_METHOD ESD_SlTpMethod = ESD_STRUCTURE_BASED;
input double ESD_RiskRewardRatio = 2.0;  // Risk:Reward ratio
input double ESD_SlBufferPoints = 100.0; // Buffer for SL

//--- Visual Settings
input bool ESD_ShowObjects = true;                      // Master switch to show all objects
input bool ESD_ShowHistorical = true;                   // Show historical SMC structures
input bool ESD_ShowBos = true;                          // Show BoS
input bool ESD_ShowChoch = true;                        // Show CHoCH
input bool ESD_ShowOb = true;                           // Show Order Blocks
input bool ESD_ShowFvg = true;                          // Show FVG
input bool ESD_ShowLiquidity = true;                    // Show Liquidity levels
input bool ESD_ShowLabels = true;                       // Tampilkan label teks
input bool ESD_ShowTrendStrength = true;                // Show trend strength indicator
input string ESD_BosStyle = "⎯⎯⎯";                      // BoS line style
input string ESD_ChochStyle = "⎯⎯⎯";                    // CHoCH line style
input string ESD_ObStyle = "⎯⎯⎯";                       // Order Block line style
input ENUM_LINE_STYLE ESD_BosLineStyle = STYLE_SOLID;   // BoS line style
input ENUM_LINE_STYLE ESD_ChochLineStyle = STYLE_SOLID; // CHoCH line style
input ENUM_LINE_STYLE ESD_ObLineStyle = STYLE_DASH;     // Order Block line style - changed to dashed
input color ESD_BullishColor = clrAquamarine;           // Warna untuk elemen bullish
input color ESD_BearishColor = clrPeachPuff;            // Warna untuk elemen bearish
input color ESD_ChochColor = clrGold;                   // Warna untuk label CHoCH
input color ESD_NeutralColor = clrGray;                 // Warna untuk elemen netral
input int ESD_TransparencyLevel = 85;                   // Tingkat transparansi (0-100)
input int ESD_LabelFontSize = 8;                        // Ukuran font label

//--- Objek Global
CTrade ESD_trade;

//--- Variabel untuk menyimpan level SMC
double ESD_bullish_ob_top = EMPTY_VALUE;
double ESD_bullish_ob_bottom = EMPTY_VALUE;
double ESD_bearish_ob_top = EMPTY_VALUE;
double ESD_bearish_ob_bottom = EMPTY_VALUE;

//--- Variabel untuk menyimpan level FVG
double ESD_bullish_fvg_top = EMPTY_VALUE;
double ESD_bullish_fvg_bottom = EMPTY_VALUE;
double ESD_bearish_fvg_top = EMPTY_VALUE;
double ESD_bearish_fvg_bottom = EMPTY_VALUE;
datetime ESD_fvg_creation_time = 0;

datetime ESD_last_bos_time = 0;
datetime ESD_last_choch_time = 0;
bool ESD_bullish_trend_confirmed = false;
bool ESD_bearish_trend_confirmed = false;
double ESD_bullish_trend_strength = 0.0;
double ESD_bearish_trend_strength = 0.0;

//--- Variabel untuk liquidity levels
double ESD_bullish_liquidity = EMPTY_VALUE;
double ESD_bearish_liquidity = EMPTY_VALUE;

//--- Variabel untuk menyimpan Pivot Point terakhir
double ESD_last_significant_ph = 0;
datetime ESD_last_significant_ph_time = 0;
double ESD_last_significant_pl = 0;
datetime ESD_last_significant_pl_time = 0;

//--- Variabel untuk Market Structure Shift
bool ESD_bullish_mss_detected = true;
bool ESD_bearish_mss_detected = true;
datetime ESD_bullish_mss_time = 0;
datetime ESD_bearish_mss_time = 0;

//--- Variabel untuk Aggressive Mode
datetime ESD_last_fvg_buy_time = 0;
datetime ESD_last_fvg_sell_time = 0;
datetime ESD_last_choch_buy_time = 0;
datetime ESD_last_choch_sell_time = 0;
datetime ESD_last_bos_buy_time = 0;
datetime ESD_last_bos_sell_time = 0;

//--- Heatmap Integration Settings
input bool ESD_UseHeatmapFilter = true;          // Enable Heatmap filtering
int ESD_HeatmapStrengthThreshold = 70;           // Min heatmap strength (0-100)
input bool ESD_UseSectorStrength = true;         // Use sector strength confirmation
input int ESD_HeatmapCheckBars = 5;              // Bars to check for heatmap consistency
input color ESD_StrongBullishColor = clrLime;    // Color for strong bullish
input color ESD_WeakBullishColor = clrGreen;     // Color for weak bullish
input color ESD_StrongBearishColor = clrRed;     // Color for strong bearish
input color ESD_WeakBearishColor = clrOrangeRed; // Color for weak bearish

//--- Heatmap Variables
double ESD_heatmap_strength = 0.0;    // Current heatmap strength (-100 to +100)
bool ESD_heatmap_bullish = false;     // Heatmap bias
bool ESD_heatmap_bearish = false;     // Heatmap bias
double ESD_sector_strength = 0.0;     // Sector strength
datetime ESD_last_heatmap_update = 0; // Last heatmap update time

//--- Order Flow Integration Settings
input bool ESD_UseOrderFlow = true;             // Enable Order Flow analysis
input bool ESD_UseVolumeProfile = true;         // Use volume profile analysis
input bool ESD_UseDeltaAnalysis = true;         // Use delta divergence
input int ESD_VolumeThreshold = 1000;           // Min volume for confirmation
input double ESD_DeltaThreshold = 0.7;          // Min delta strength (0-1)
input bool ESD_UseAbsorptionDetection = true;   // Detect absorption patterns
input bool ESD_UseImbalanceDetection = true;    // Detect order flow imbalances
input color ESD_HighVolumeColor = clrYellow;    // High volume level color
input color ESD_BidVolumeColor = clrDodgerBlue; // Bid volume color
input color ESD_AskVolumeColor = clrCrimson;    // Ask volume color

//--- Order Flow Variables
double ESD_orderflow_strength = 0.0;    // Order flow strength (-100 to +100)
double ESD_delta_value = 0.0;           // Current delta value
double ESD_cumulative_delta = 0.0;      // Cumulative delta
double ESD_volume_imbalance = 0.0;      // Volume imbalance ratio
bool ESD_absorption_detected = false;   // Absorption detected
bool ESD_imbalance_detected = false;    // Imbalance detected
datetime ESD_last_orderflow_update = 0; // Last order flow update
double ESD_poc_price = 0.0;             // Point of Control price
double ESD_high_volume_nodes[];         // High volume nodes array

//--- Array untuk menyimpan struktur SMC historis
struct ESD_SMStructure
{
    datetime time;
    double price;
    bool is_bullish;
    string type; // "BOS", "CHOCH", "OB", "FVG", "LIQUIDITY", "MSS"
    double top;
    double bottom;
    double quality_score; // 0-1, higher is better
};
ESD_SMStructure ESD_smc_structures[];

//+------------------------------------------------------------------+
//| Fungsi Deteksi Trend Awal (Inisialisasi)                         |
//+------------------------------------------------------------------+
void ESD_DetectInitialTrend()
{
    int bars_to_check = MathMax(ESD_SwingLookback, 20);
    double high_buffer[], low_buffer[], close_buffer[];
    ArraySetAsSeries(high_buffer, true);
    ArraySetAsSeries(low_buffer, true);
    ArraySetAsSeries(close_buffer, true);

    CopyHigh(_Symbol, ESD_HigherTimeframe, 0, bars_to_check, high_buffer);
    CopyLow(_Symbol, ESD_HigherTimeframe, 0, bars_to_check, low_buffer);
    CopyClose(_Symbol, ESD_HigherTimeframe, 0, bars_to_check, close_buffer);

    // Reset trend confirmation
    ESD_bullish_trend_confirmed = false;
    ESD_bearish_trend_confirmed = false;

    // Enhanced trend detection dengan multiple conditions
    int bullish_signals = 0;
    int bearish_signals = 0;

    // Condition 1: Price position relative to recent swings
    double current_high = high_buffer[0];
    double current_low = low_buffer[0];
    double mid_range = (current_high + current_low) / 2;

    // Check last 5 candles for momentum
    for (int i = 0; i < 5; i++)
    {
        if (close_buffer[i] > close_buffer[i + 1])
            bullish_signals++;
        else if (close_buffer[i] < close_buffer[i + 1])
            bearish_signals++;
    }

    // Condition 2: Swing structure
    if (high_buffer[0] > high_buffer[2] && low_buffer[0] > low_buffer[2])
        bullish_signals += 2;
    else if (high_buffer[0] < high_buffer[2] && low_buffer[0] < low_buffer[2])
        bearish_signals += 2;

    // Condition 3: Strong momentum confirmation
    if (bullish_signals >= 4 && bearish_signals <= 2)
    {
        ESD_bullish_trend_confirmed = true;
        ESD_bearish_trend_confirmed = false;
        ESD_bullish_trend_strength = 0.8;
        ESD_bearish_trend_strength = 0.2;
    }
    else if (bearish_signals >= 4 && bullish_signals <= 2)
    {
        ESD_bearish_trend_confirmed = true;
        ESD_bullish_trend_confirmed = false;
        ESD_bearish_trend_strength = 0.8;
        ESD_bullish_trend_strength = 0.2;
    }
    else
    {
        // Neutral/consolidation
        ESD_bullish_trend_confirmed = false;
        ESD_bearish_trend_confirmed = false;
        ESD_bullish_trend_strength = 0.5;
        ESD_bearish_trend_strength = 0.5;
    }
}

//+------------------------------------------------------------------+
//| Calculate trend strength                                          |
//+------------------------------------------------------------------+
// Perbaiki fungsi existing ESD_CalculateTrendStrength
double ESD_CalculateTrendStrength(const double &close_buffer[], bool is_bullish)
{
    int bars = ArraySize(close_buffer);
    if (bars < 10)
        return 0.0;

    double strength = 0.0;
    int confirming_bars = 0;

    // ENHANCEMENT: Add volume-weighted trend strength
    MqlRates rates[];
    long volume_buffer[];
    ArraySetAsSeries(rates, true);
    ArraySetAsSeries(volume_buffer, true);

    CopyRates(_Symbol, ESD_HigherTimeframe, 0, bars, rates);
    CopyTickVolume(_Symbol, ESD_HigherTimeframe, 0, bars, volume_buffer);

    // Count bars that confirm the trend dengan volume consideration
    double total_volume = 0;
    double confirming_volume = 0;

    for (int i = 0; i < bars - 1; i++)
    {
        total_volume += (double)volume_buffer[i];

        if (is_bullish && close_buffer[i] > close_buffer[i + 1])
        {
            confirming_bars++;
            confirming_volume += (double)volume_buffer[i];
        }
        else if (!is_bullish && close_buffer[i] < close_buffer[i + 1])
        {
            confirming_bars++;
            confirming_volume += (double)volume_buffer[i];
        }
    }

    // Calculate strength as ratio of confirming bars (existing)
    strength = (double)confirming_bars / (bars - 1);

    // ENHANCEMENT: Volume-based strength adjustment
    double volume_strength = (total_volume > 0) ? (confirming_volume / total_volume) : 0.5;
    strength = (strength * 0.6) + (volume_strength * 0.4);

    // Existing recent momentum calculation tetap...
    double recent_momentum = 0.0;
    int recent_bars = MathMin(5, bars / 2);
    for (int i = 0; i < recent_bars; i++)
    {
        if (is_bullish && close_buffer[i] > close_buffer[i + 1])
            recent_momentum += 1.0;
        else if (!is_bullish && close_buffer[i] < close_buffer[i + 1])
            recent_momentum += 1.0;
    }
    recent_momentum /= recent_bars;

    // Combine dengan weight yang disesuaikan
    strength = (strength * 0.5) + (recent_momentum * 0.3) + (volume_strength * 0.2);

    return MathMax(0.0, MathMin(1.0, strength));
}

//+------------------------------------------------------------------+
//| Detect Supreme Timeframe Trend                                    |
//+------------------------------------------------------------------+
void ESD_DetectSupremeTimeframeTrend()
{
    int bars_to_check = ESD_SwingLookback;
    double high_buffer[];
    double low_buffer[];
    double close_buffer[];
    ArraySetAsSeries(high_buffer, true);
    ArraySetAsSeries(low_buffer, true);
    ArraySetAsSeries(close_buffer, true);
    CopyHigh(_Symbol, ESD_SupremeTimeframe, 1, bars_to_check, high_buffer);
    CopyLow(_Symbol, ESD_SupremeTimeframe, 1, bars_to_check, low_buffer);
    CopyClose(_Symbol, ESD_SupremeTimeframe, 1, bars_to_check, close_buffer);

    // Calculate trend strength on supreme timeframe
    double supreme_bullish_strength = ESD_CalculateTrendStrength(close_buffer, true);
    double supreme_bearish_strength = ESD_CalculateTrendStrength(close_buffer, false);

    // Only override higher timeframe trend if supreme trend is strong
    if (ESD_UseStrictTrendConfirmation)
    {
        if (supreme_bullish_strength > ESD_TrendStrengthThreshold &&
            supreme_bullish_strength > supreme_bearish_strength)
        {
            // Strong bullish trend on supreme timeframe
            if (ESD_bullish_trend_strength < ESD_TrendStrengthThreshold)
            {
                ESD_bullish_trend_confirmed = true;
                ESD_bearish_trend_confirmed = false;
            }
        }
        else if (supreme_bearish_strength > ESD_TrendStrengthThreshold &&
                 supreme_bearish_strength > supreme_bullish_strength)
        {
            // Strong bearish trend on supreme timeframe
            if (ESD_bearish_trend_strength < ESD_TrendStrengthThreshold)
            {
                ESD_bearish_trend_confirmed = true;
                ESD_bullish_trend_confirmed = false;
            }
        }
    }

    // Display trend strength if enabled
    if (ESD_ShowObjects && ESD_ShowTrendStrength)
    {
        string text = StringFormat("HTF: B=%.2f S=%.2f | STF: B=%.2f S=%.2f",
                                   ESD_bullish_trend_strength, ESD_bearish_trend_strength,
                                   supreme_bullish_strength, supreme_bearish_strength);
        ESD_DrawLabel("ESD_TrendStrength", iTime(_Symbol, PERIOD_CURRENT, 0),
                      iHigh(_Symbol, PERIOD_CURRENT, 0), text, ESD_NeutralColor, false);
    }
}

//+------------------------------------------------------------------+
//| Fungsi Deteksi SMC (BoS, Order Block, & FVG)                     |
//+------------------------------------------------------------------+
void ESD_DetectSMC()
{
    int bars_to_copy = ESD_SwingLookback + ESD_BosLookback + ESD_ObLookback + ESD_FvgLookback + 10;
    double high_buffer[];
    double low_buffer[];
    double close_buffer[];
    double open_buffer[];
    ArraySetAsSeries(high_buffer, true);
    ArraySetAsSeries(low_buffer, true);
    ArraySetAsSeries(close_buffer, true);
    ArraySetAsSeries(open_buffer, true);
    CopyHigh(_Symbol, ESD_HigherTimeframe, 0, bars_to_copy, high_buffer);
    CopyLow(_Symbol, ESD_HigherTimeframe, 0, bars_to_copy, low_buffer);
    CopyClose(_Symbol, ESD_HigherTimeframe, 0, bars_to_copy, close_buffer);
    CopyOpen(_Symbol, ESD_HigherTimeframe, 0, bars_to_copy, open_buffer);

    // Calculate ATR if needed
    double atr_buffer[];
    ArraySetAsSeries(atr_buffer, true);
    double atr_value = 0;
    if (ESD_UseAtrMethod)
    {
        int atr_handle = iATR(_Symbol, ESD_HigherTimeframe, 14);
        if (CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0)
        {
            atr_value = atr_buffer[0];
        }
    }

    // --- Deteksi Pivot Point (Swing High/Low) ---
    int ph_index = ESD_FindPivotHighIndex(high_buffer, ESD_BosLookback);
    if (ph_index != -1)
    {
        double current_ph = high_buffer[ph_index];
        datetime current_ph_time = iTime(_Symbol, ESD_HigherTimeframe, ph_index);

        // Check if this is a significant swing based on ATR
        bool is_significant = true;
        if (ESD_UseAtrMethod && atr_value > 0)
        {
            double swing_strength = (current_ph - low_buffer[ph_index]) / atr_value;
            is_significant = swing_strength >= ESD_MinSwingStrength;
        }

        if (is_significant && current_ph_time > ESD_last_significant_ph_time)
        {
            ESD_last_significant_ph = current_ph;
            ESD_last_significant_ph_time = current_ph_time;

            // Add to historical structures
            ESD_SMStructure new_ph;
            new_ph.time = current_ph_time;
            new_ph.price = current_ph;
            new_ph.is_bullish = false;
            new_ph.type = "PH";
            new_ph.top = current_ph;
            new_ph.bottom = current_ph;
            new_ph.quality_score = ESD_CalculatePivotQuality(ph_index, high_buffer, low_buffer, false);
            ESD_AddToHistoricalStructures(new_ph);

            if (ESD_ShowObjects && ESD_ShowLabels)
            {
                ESD_DrawSwingPoint(current_ph_time, current_ph, "PH", ESD_BearishColor);
            }
        }
    }

    int pl_index = ESD_FindPivotLowIndex(low_buffer, ESD_BosLookback);
    if (pl_index != -1)
    {
        double current_pl = low_buffer[pl_index];
        datetime current_pl_time = iTime(_Symbol, ESD_HigherTimeframe, pl_index);

        // Check if this is a significant swing based on ATR
        bool is_significant = true;
        if (ESD_UseAtrMethod && atr_value > 0)
        {
            double swing_strength = (high_buffer[pl_index] - current_pl) / atr_value;
            is_significant = swing_strength >= ESD_MinSwingStrength;
        }

        if (is_significant && current_pl_time > ESD_last_significant_pl_time)
        {
            ESD_last_significant_pl = current_pl;
            ESD_last_significant_pl_time = current_pl_time;

            // Add to historical structures
            ESD_SMStructure new_pl;
            new_pl.time = current_pl_time;
            new_pl.price = current_pl;
            new_pl.is_bullish = true;
            new_pl.type = "PL";
            new_pl.top = current_pl;
            new_pl.bottom = current_pl;
            new_pl.quality_score = ESD_CalculatePivotQuality(pl_index, high_buffer, low_buffer, true);
            ESD_AddToHistoricalStructures(new_pl);

            if (ESD_ShowObjects && ESD_ShowLabels)
            {
                ESD_DrawSwingPoint(current_pl_time, current_pl, "PL", ESD_BullishColor);
            }
        }
    }

    // --- Deteksi Market Structure Shift (MSS) ---
    ESD_DetectMarketStructureShift(high_buffer, low_buffer, close_buffer);

    // --- Deteksi BoS / CHoCH ---
    datetime bos_time = iTime(_Symbol, ESD_HigherTimeframe, 1);

    // Bullish Break (PH Break)
    if (ESD_last_significant_ph != 0 && high_buffer[1] > ESD_last_significant_ph && bos_time > ESD_last_bos_time)
    {
        MqlRates current_rates[], prev_rates[];
        long volume_buffer[];
        ArraySetAsSeries(current_rates, true);
        ArraySetAsSeries(prev_rates, true);
        ArraySetAsSeries(volume_buffer, true);

        CopyRates(_Symbol, PERIOD_CURRENT, 0, 3, current_rates);
        CopyRates(_Symbol, ESD_HigherTimeframe, 1, 2, prev_rates);
        CopyTickVolume(_Symbol, ESD_HigherTimeframe, 0, 3, volume_buffer);

        bool bullish_break = (current_rates[0].close > current_rates[0].open);

        bool confirmed_break = false;
        double avg_volume = 0;

        if (ESD_UseStrictTrendConfirmation)
        {
            confirmed_break = ESD_ConfirmBreak(high_buffer, ESD_last_significant_ph, true, ESD_TrendConfirmationBars);
        }
        else
        {
            double break_candle_range = prev_rates[0].high - prev_rates[0].low;
            double break_candle_body = MathAbs(prev_rates[0].close - prev_rates[0].open);
            double break_strength = break_candle_body / break_candle_range;

            if (ArraySize(volume_buffer) >= 3)
            {
                avg_volume = (volume_buffer[1] + volume_buffer[2]) / 2.0;
            }
            else
            {
                avg_volume = volume_buffer[0] * 0.8;
            }

            bool volume_confirm = (volume_buffer[0] > avg_volume * 1.4);
            bool momentum_confirm = (break_strength > 0.6);
            bool follow_through = bullish_break;

            confirmed_break = volume_confirm && momentum_confirm && follow_through;
        }

        if (confirmed_break && bullish_break)
        {
            // 🆕 LIQUIDITY GRAB STRATEGY: Entry lawan arah dulu
            if (ESD_UseLiquidityGrabStrategy && !liquidity_grab_active &&
                (TimeCurrent() - last_liquidity_grab_time) > ESD_LiquidityGrabCooldown)
            {
                double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

                // Entry SELL lawan arah untuk ambil liquidity dengan TP yang lebih ketat
                double sl = ESD_last_significant_ph + (30 * point);       // SL lebih ketat
                double tp = ask - (ESD_PartialTPDistance1 * 0.5 * point); // TP lebih pendek

                string comment = StringFormat("LIQUIDITY-GRAB-SELL @ BoS - PH: %.5f", ESD_last_significant_ph);

                if (ESD_ExecuteTrade(false, ask, sl, tp, ESD_LiquidityGrabLotSize, comment))
                {
                    liquidity_grab_active = true;
                    liquidity_grab_level = ESD_last_significant_ph;
                    liquidity_grab_direction = -1;
                    liquidity_grab_signal_type = "BoS"; // Simpan jenis sinyal
                    liquidity_grab_signal_price = ESD_last_significant_ph;
                    last_liquidity_grab_time = TimeCurrent();

                    Print("Liquidity Grab SELL Executed: ", comment);
                }
            }

            // Tandai sinyal yang terdeteksi
            string signal_type = "BoS";
            if (ESD_bearish_trend_confirmed)
            {
                signal_type = "CHOCH";

                if (ESD_ShowObjects && ESD_ShowChoch)
                {
                    ESD_DrawBreakStructure(bos_time, ESD_last_significant_ph, true, ESD_ChochColor, ESD_ChochLineStyle, ESD_ChochStyle, "CHOCH");
                    if (ESD_ShowLabels)
                        ESD_DrawLabel("ESD_CHOCH_Label_" + IntegerToString(bos_time), bos_time, ESD_last_significant_ph, "CHoCH", ESD_ChochColor, true);
                }

                ESD_SMStructure new_choch;
                new_choch.time = bos_time;
                new_choch.price = ESD_last_significant_ph;
                new_choch.is_bullish = true;
                new_choch.type = "CHOCH";
                new_choch.top = ESD_last_significant_ph;
                new_choch.bottom = ESD_last_significant_ph;
                new_choch.quality_score = ESD_CalculateBreakQuality(bos_time, ESD_last_significant_ph, true);
                ESD_AddToHistoricalStructures(new_choch);

                ESD_last_choch_time = bos_time;
            }
            else
            {
                if (ESD_ShowObjects && ESD_ShowBos)
                {
                    ESD_DrawBreakStructure(bos_time, ESD_last_significant_ph, true, ESD_BullishColor, ESD_BosLineStyle, ESD_BosStyle, "BOS");
                    if (ESD_ShowLabels)
                        ESD_DrawLabel("ESD_BoS_Label_" + IntegerToString(bos_time), bos_time, ESD_last_significant_ph, "BoS", ESD_BullishColor, true);
                }

                ESD_SMStructure new_bos;
                new_bos.time = bos_time;
                new_bos.price = ESD_last_significant_ph;
                new_bos.is_bullish = true;
                new_bos.type = "BOS";
                new_bos.top = ESD_last_significant_ph;
                new_bos.bottom = ESD_last_significant_ph;
                new_bos.quality_score = ESD_CalculateBreakQuality(bos_time, ESD_last_significant_ph, true);
                ESD_AddToHistoricalStructures(new_bos);
            }

            // 🆕 TUNGGU LIQUIDITY GRAB SELESAI DULU SEBELUM ENTRY SINYAL ASLI
            if (!liquidity_grab_active)
            {
                // 🆕 KONFIRMASI CANDLE SETELAH LIQUIDITY GRAB SELESAI + KONDISI STOCHASTIC
                if (ESD_IsBullishConfirmationCandle())
                {
                    // 🆕 TAMBAH KONDISI STOCHASTIC UNTUK BUY - TUNGGU OVERSOLD SELESAI
                    bool stochastic_ok = false;

                    // Untuk sinyal BUY, pastikan stochastic sudah/sedang dari oversold
                    if (signal_type == "CHOCH" || signal_type == "BoS")
                    {
                        // Cek apakah stochastic menunjukkan kondisi oversold atau keluar dari oversold
                        // --- Buat handle Stochastic
                        int stoch_handle = iStochastic(_Symbol, _Period, 5, 3, 3, MODE_SMA, STO_LOWHIGH);

                        // --- Siapkan array penampung
                        double stoch_main_array[], stoch_signal_array[];

                        // --- Ambil nilai dari buffer
                        CopyBuffer(stoch_handle, 0, 0, 1, stoch_main_array);   // buffer 0 = MAIN (%K)
                        CopyBuffer(stoch_handle, 1, 0, 1, stoch_signal_array); // buffer 1 = SIGNAL (%D)

                        // --- Simpan ke variabel lama (nama tidak diubah)
                        double stoch_main = stoch_main_array[0];
                        double stoch_signal = stoch_signal_array[0];

                        // Kondisi untuk BUY: stochastic <= 20 (oversold) atau sedang keluar dari oversold
                        stochastic_ok = (stoch_main <= 20) || (stoch_main > 20 && stoch_main > stoch_signal);

                        if (stochastic_ok)
                        {
                            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                            double sl = ESD_last_significant_ph - (ESD_StopLossPoints * point);
                            double tp = ask + (ESD_PartialTPDistance3 * point);

                            string comment = StringFormat(signal_type,"-BUY after Liquidity Grab %s - PH: %.5f",  ESD_last_significant_ph);
                            if (ESD_ExecuteTrade(true, ask, sl, tp, ESD_LotSize, comment))
                            {
                                Print("Confirmed BUY after Liquidity Grab - ", signal_type);
                            }
                        }
                    }
                }
                else if (ESD_AggressiveMode && ESD_TradeOnCHOCHDetection && ESD_last_choch_buy_time != bos_time && signal_type == "CHOCH")
                {
                    // 🆕 TAMBAH KONDISI STOCHASTIC UNTUK AGGRESSIVE BUY
                    // --- Buat handle Stochastic
                    int stoch_handle = iStochastic(_Symbol, _Period, 5, 3, 3, MODE_SMA, STO_LOWHIGH);

                    // --- Siapkan array penampung
                    double stoch_main_array[], stoch_signal_array[];

                    // --- Ambil nilai dari buffer
                    CopyBuffer(stoch_handle, 0, 0, 1, stoch_main_array);   // buffer 0 = MAIN (%K)
                    CopyBuffer(stoch_handle, 1, 0, 1, stoch_signal_array); // buffer 1 = SIGNAL (%D)

                    // --- Simpan ke variabel lama (nama tidak diubah)
                    double stoch_main = stoch_main_array[0];
                    double stoch_signal = stoch_signal_array[0];

                    ESD_last_choch_buy_time = bos_time;
                    ESD_ExecuteAggressiveBuy("CHOCH", ESD_last_significant_ph, bos_time);
                }
                else if (ESD_AggressiveMode && ESD_TradeOnBOSSignal && ESD_last_bos_buy_time != bos_time && signal_type == "BoS")
                {
                    // 🆕 TAMBAH KONDISI STOCHASTIC UNTUK AGGRESSIVE BUY
                    // --- Buat handle Stochastic
                    int stoch_handle = iStochastic(_Symbol, _Period, 5, 3, 3, MODE_SMA, STO_LOWHIGH);

                    // --- Siapkan array penampung
                    double stoch_main_array[], stoch_signal_array[];

                    // --- Ambil nilai dari buffer
                    CopyBuffer(stoch_handle, 0, 0, 1, stoch_main_array);   // buffer 0 = MAIN (%K)
                    CopyBuffer(stoch_handle, 1, 0, 1, stoch_signal_array); // buffer 1 = SIGNAL (%D)

                    // --- Simpan ke variabel lama (nama tidak diubah)
                    double stoch_main = stoch_main_array[0];
                    double stoch_signal = stoch_signal_array[0];

                    // Untuk aggressive BUY, pastikan stochastic oversold
                    if (stoch_main <= 20 || (stoch_main > 20 && stoch_main > stoch_signal))
                    {
                        ESD_last_bos_buy_time = bos_time;
                        ESD_ExecuteAggressiveBuy("BoS", ESD_last_significant_ph, bos_time);
                    }
                }
            }

            double volume_strength = MathMin(volume_buffer[0] / (avg_volume + 0.1), 2.0) / 2.0;
            ESD_bullish_trend_strength = MathMin(1.0, ESD_bullish_trend_strength + 0.2 + (volume_strength * 0.1));
            ESD_bearish_trend_strength = MathMax(0.0, ESD_bearish_trend_strength - 0.2);

            if (ESD_bullish_trend_strength > ESD_TrendStrengthThreshold)
                ESD_bullish_trend_confirmed = true;

            ESD_bearish_trend_confirmed = false;
            ESD_last_bos_time = bos_time;
            ESD_bearish_liquidity = ESD_last_significant_ph;

            if (ESD_ObLookback < ArraySize(high_buffer))
            {
                ESD_bullish_ob_top = high_buffer[ESD_ObLookback];
                ESD_bullish_ob_bottom = low_buffer[ESD_ObLookback];

                ESD_SMStructure new_ob;
                new_ob.time = iTime(_Symbol, ESD_HigherTimeframe, ESD_ObLookback);
                new_ob.price = (ESD_bullish_ob_top + ESD_bullish_ob_bottom) / 2;
                new_ob.is_bullish = true;
                new_ob.type = "OB";
                new_ob.top = ESD_bullish_ob_top;
                new_ob.bottom = ESD_bullish_ob_bottom;
                new_ob.quality_score = ESD_CalculateOrderBlockQuality(ESD_ObLookback, high_buffer, low_buffer, close_buffer, open_buffer, true);
                ESD_AddToHistoricalStructures(new_ob);
            }
        }
    }

    // Bearish Break (PL Break)
    if (ESD_last_significant_pl != 0 && low_buffer[1] < ESD_last_significant_pl && bos_time > ESD_last_bos_time)
    {
        MqlRates current_rates[];
        ArraySetAsSeries(current_rates, true);
        if (CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, current_rates) <= 0)
            return;

        bool bearish_break = (current_rates[0].close < current_rates[0].open);

        bool confirmed_break = false;
        if (ESD_UseStrictTrendConfirmation)
        {
            confirmed_break = ESD_ConfirmBreak(low_buffer, ESD_last_significant_pl, false, ESD_TrendConfirmationBars);
        }
        else
        {
            confirmed_break = true;
        }

        if (confirmed_break && bearish_break)
        {
            // 🆕 LIQUIDITY GRAB STRATEGY: Entry lawan arah dulu
            if (ESD_UseLiquidityGrabStrategy && !liquidity_grab_active &&
                (TimeCurrent() - last_liquidity_grab_time) > ESD_LiquidityGrabCooldown)
            {
                double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

                // Entry BUY lawan arah untuk ambil liquidity dengan TP yang lebih ketat
                double sl = ESD_last_significant_pl - (30 * point);       // SL lebih ketat
                double tp = bid + (ESD_PartialTPDistance1 * 0.5 * point); // TP lebih pendek

                string comment = StringFormat("LIQUIDITY-GRAB-BUY @ BoS - PL: %.5f", ESD_last_significant_pl);

                if (ESD_ExecuteTrade(true, bid, sl, tp, ESD_LiquidityGrabLotSize, comment))
                {
                    liquidity_grab_active = true;
                    liquidity_grab_level = ESD_last_significant_pl;
                    liquidity_grab_direction = 1;
                    liquidity_grab_signal_type = "BoS"; // Simpan jenis sinyal
                    liquidity_grab_signal_price = ESD_last_significant_pl;
                    last_liquidity_grab_time = TimeCurrent();

                    Print("Liquidity Grab BUY Executed: ", comment);
                }
            }

            // Tandai sinyal yang terdeteksi
            string signal_type = "BoS";
            if (ESD_bullish_trend_confirmed)
            {
                signal_type = "CHOCH";

                if (ESD_ShowObjects && ESD_ShowChoch)
                {
                    ESD_DrawBreakStructure(bos_time, ESD_last_significant_pl, false, ESD_ChochColor, ESD_ChochLineStyle, ESD_ChochStyle, "CHOCH");
                    if (ESD_ShowLabels)
                        ESD_DrawLabel("ESD_CHOCH_Label_" + IntegerToString(bos_time), bos_time, ESD_last_significant_pl, "CHoCH", ESD_ChochColor, true);
                }

                ESD_SMStructure new_choch;
                new_choch.time = bos_time;
                new_choch.price = ESD_last_significant_pl;
                new_choch.is_bullish = false;
                new_choch.type = "CHOCH";
                new_choch.top = ESD_last_significant_pl;
                new_choch.bottom = ESD_last_significant_pl;
                new_choch.quality_score = ESD_CalculateBreakQuality(bos_time, ESD_last_significant_pl, false);
                ESD_AddToHistoricalStructures(new_choch);

                ESD_last_choch_time = bos_time;
            }
            else
            {
                if (ESD_ShowObjects && ESD_ShowBos)
                {
                    ESD_DrawBreakStructure(bos_time, ESD_last_significant_pl, false, ESD_BearishColor, ESD_BosLineStyle, ESD_BosStyle, "BOS");
                    if (ESD_ShowLabels)
                        ESD_DrawLabel("ESD_BoS_Label_" + IntegerToString(bos_time), bos_time, ESD_last_significant_pl, "BoS", ESD_BearishColor, true);
                }

                ESD_SMStructure new_bos;
                new_bos.time = bos_time;
                new_bos.price = ESD_last_significant_pl;
                new_bos.is_bullish = false;
                new_bos.type = "BOS";
                new_bos.top = ESD_last_significant_pl;
                new_bos.bottom = ESD_last_significant_pl;
                new_bos.quality_score = ESD_CalculateBreakQuality(bos_time, ESD_last_significant_pl, false);
                ESD_AddToHistoricalStructures(new_bos);
            }

            // 🆕 TUNGGU LIQUIDITY GRAB SELESAI DULU SEBELUM ENTRY SINYAL ASLI
            if (!liquidity_grab_active)
            {
                // 🆕 KONFIRMASI CANDLE SETELAH LIQUIDITY GRAB SELESAI + KONDISI STOCHASTIC
                if (ESD_IsBearishConfirmationCandle())
                {
                    // 🆕 TAMBAH KONDISI STOCHASTIC UNTUK SELL - TUNGGU OVERBOUGHT SELESAI
                    bool stochastic_ok = false;

                    // Untuk sinyal SELL, pastikan stochastic sudah/sedang dari overbought
                    if (signal_type == "CHOCH" || signal_type == "BoS")
                    {
                        // Cek apakah stochastic menunjukkan kondisi overbought atau keluar dari overbought
                        // --- Buat handle Stochastic
                        int stoch_handle = iStochastic(_Symbol, _Period, 5, 3, 3, MODE_SMA, STO_LOWHIGH);

                        // --- Siapkan array penampung
                        double stoch_main_array[], stoch_signal_array[];

                        // --- Ambil nilai dari buffer
                        CopyBuffer(stoch_handle, 0, 0, 1, stoch_main_array);   // buffer 0 = MAIN (%K)
                        CopyBuffer(stoch_handle, 1, 0, 1, stoch_signal_array); // buffer 1 = SIGNAL (%D)

                        // --- Simpan ke variabel lama (nama tidak diubah)
                        double stoch_main = stoch_main_array[0];
                        double stoch_signal = stoch_signal_array[0];

                        // Kondisi untuk SELL: stochastic >= 80 (overbought) atau sedang keluar dari overbought
                        stochastic_ok = (stoch_main >= 80) || (stoch_main < 80 && stoch_main < stoch_signal);

                        if (stochastic_ok)
                        {
                            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                            double sl = ESD_last_significant_pl + (ESD_StopLossPoints * point);
                            double tp = bid - (ESD_PartialTPDistance3 * point);

                            string comment = StringFormat(signal_type, "-SELL after Liquidity Take %s - PL: %.5f", ESD_last_significant_pl);
                            if (ESD_ExecuteTrade(false, bid, sl, tp, ESD_LotSize, comment))
                            {
                                Print("Confirmed SELL after Liquidity Grab - ", signal_type);
                            }
                        }
                    }
                }
                else if (ESD_AggressiveMode && ESD_TradeOnCHOCHDetection && ESD_last_choch_sell_time != bos_time && signal_type == "CHOCH")
                {
                    // 🆕 TAMBAH KONDISI STOCHASTIC UNTUK AGGRESSIVE SELL
                    // --- Buat handle Stochastic
                    int stoch_handle = iStochastic(_Symbol, _Period, 5, 3, 3, MODE_SMA, STO_LOWHIGH);

                    // --- Siapkan array penampung
                    double stoch_main_array[], stoch_signal_array[];

                    // --- Ambil nilai dari buffer
                    CopyBuffer(stoch_handle, 0, 0, 1, stoch_main_array);   // buffer 0 = MAIN (%K)
                    CopyBuffer(stoch_handle, 1, 0, 1, stoch_signal_array); // buffer 1 = SIGNAL (%D)

                    // --- Simpan ke variabel lama (nama tidak diubah)
                    double stoch_main = stoch_main_array[0];
                    double stoch_signal = stoch_signal_array[0];

                    // Untuk aggressive SELL, pastikan stochastic overbought
                    if (stoch_main >= 80 || (stoch_main < 80 && stoch_main < stoch_signal))
                    {
                        ESD_last_choch_sell_time = bos_time;
                        ESD_ExecuteAggressiveSell("CHOCH", ESD_last_significant_pl, bos_time);
                    }
                }
                else if (ESD_AggressiveMode && ESD_TradeOnBOSSignal && ESD_last_bos_sell_time != bos_time && signal_type == "BoS")
                {
                    // 🆕 TAMBAH KONDISI STOCHASTIC UNTUK AGGRESSIVE SELL
                    // --- Buat handle Stochastic
                    int stoch_handle = iStochastic(_Symbol, _Period, 5, 3, 3, MODE_SMA, STO_LOWHIGH);

                    // --- Siapkan array penampung
                    double stoch_main_array[], stoch_signal_array[];

                    // --- Ambil nilai dari buffer
                    CopyBuffer(stoch_handle, 0, 0, 1, stoch_main_array);   // buffer 0 = MAIN (%K)
                    CopyBuffer(stoch_handle, 1, 0, 1, stoch_signal_array); // buffer 1 = SIGNAL (%D)

                    // --- Simpan ke variabel lama (nama tidak diubah)
                    double stoch_main = stoch_main_array[0];
                    double stoch_signal = stoch_signal_array[0];

                    ESD_last_bos_sell_time = bos_time;
                    ESD_ExecuteAggressiveSell("BoS", ESD_last_significant_pl, bos_time);
                    
                }
            }

            ESD_bearish_trend_strength = MathMin(1.0, ESD_bearish_trend_strength + 0.2);
            ESD_bullish_trend_strength = MathMax(0.0, ESD_bullish_trend_strength - 0.2);

            if (ESD_bearish_trend_strength > ESD_TrendStrengthThreshold)
                ESD_bearish_trend_confirmed = true;

            ESD_bullish_trend_confirmed = false;
            ESD_last_bos_time = bos_time;
            ESD_bullish_liquidity = ESD_last_significant_pl;

            if (ESD_ObLookback < bars_to_copy)
            {
                ESD_bearish_ob_top = high_buffer[ESD_ObLookback];
                ESD_bearish_ob_bottom = low_buffer[ESD_ObLookback];

                ESD_SMStructure new_ob;
                new_ob.time = iTime(_Symbol, ESD_HigherTimeframe, ESD_ObLookback);
                new_ob.price = (ESD_bearish_ob_top + ESD_bearish_ob_bottom) / 2;
                new_ob.is_bullish = false;
                new_ob.type = "OB";
                new_ob.top = ESD_bearish_ob_top;
                new_ob.bottom = ESD_bearish_ob_bottom;
                new_ob.quality_score = ESD_CalculateOrderBlockQuality(ESD_ObLookback, high_buffer, low_buffer, close_buffer, open_buffer, false);
                ESD_AddToHistoricalStructures(new_ob);
            }
        }
    }

    // 🆕 RESET LIQUIDITY GRAB JIKA SUDAH EXPIRED
    if (liquidity_grab_active && (TimeCurrent() - last_liquidity_grab_time) > ESD_LiquidityGrabTimeout)
    {
        liquidity_grab_active = false;
        Print("Liquidity Grab expired - no confirmation within ", ESD_LiquidityGrabTimeout, " seconds");
    }

    // --- Deteksi FVG (Fair Value Gap) ---
    datetime fvg_time = iTime(_Symbol, ESD_HigherTimeframe, 0);
    if (low_buffer[2] > high_buffer[0])
    {
        ESD_bullish_fvg_top = high_buffer[0];
        ESD_bullish_fvg_bottom = low_buffer[2];
        ESD_fvg_creation_time = fvg_time;

        if (ESD_ShowObjects && ESD_ShowFvg)
        {
            ESD_DrawFVG("ESD_BullishFVG", ESD_bullish_fvg_top, ESD_bullish_fvg_bottom, ESD_fvg_creation_time, ESD_BullishColor);
            if (ESD_ShowLabels)
            {
                ESD_DrawLabel("ESD_BullishFVG_Label", fvg_time, ESD_bullish_fvg_bottom, "FVG", ESD_BullishColor, true);
                ESD_DrawLabel("ESD_BullishPOI_Label", fvg_time, (ESD_bullish_fvg_top + ESD_bullish_fvg_bottom) / 2, "POI", clrWhite, false);
            }
        }

        ESD_SMStructure new_fvg;
        new_fvg.time = fvg_time;
        new_fvg.price = (ESD_bullish_fvg_top + ESD_bullish_fvg_bottom) / 2;
        new_fvg.is_bullish = true;
        new_fvg.type = "FVG";
        new_fvg.top = ESD_bullish_fvg_top;
        new_fvg.bottom = ESD_bullish_fvg_bottom;
        new_fvg.quality_score = ESD_CalculateFVGQuality(0, high_buffer, low_buffer, true);
        ESD_AddToHistoricalStructures(new_fvg);

        if (ESD_AggressiveMode && ESD_TradeOnFVGDetection && ESD_last_fvg_buy_time != fvg_time && !liquidity_grab_active)
        {
            ESD_last_fvg_buy_time = fvg_time;
            ESD_ExecuteAggressiveBuy("FVG", (ESD_bullish_fvg_top + ESD_bullish_fvg_bottom) / 2, fvg_time);
        }
    }

    if (high_buffer[2] < low_buffer[0])
    {
        ESD_bearish_fvg_top = high_buffer[2];
        ESD_bearish_fvg_bottom = low_buffer[0];
        ESD_fvg_creation_time = fvg_time;

        if (ESD_ShowObjects && ESD_ShowFvg)
        {
            ESD_DrawFVG("ESD_BearishFVG", ESD_bearish_fvg_top, ESD_bearish_fvg_bottom, ESD_fvg_creation_time, ESD_BearishColor);
            if (ESD_ShowLabels)
            {
                ESD_DrawLabel("ESD_BearishFVG_Label", fvg_time, ESD_bearish_fvg_top, "FVG", ESD_BearishColor, true);
                ESD_DrawLabel("ESD_BearishPOI_Label", fvg_time, (ESD_bearish_fvg_top + ESD_bearish_fvg_bottom) / 2, "POI", clrWhite, false);
            }
        }

        ESD_SMStructure new_fvg;
        new_fvg.time = fvg_time;
        new_fvg.price = (ESD_bearish_fvg_top + ESD_bearish_fvg_bottom) / 2;
        new_fvg.is_bullish = false;
        new_fvg.type = "FVG";
        new_fvg.top = ESD_bearish_fvg_top;
        new_fvg.bottom = ESD_bearish_fvg_bottom;
        new_fvg.quality_score = ESD_CalculateFVGQuality(0, high_buffer, low_buffer, false);
        ESD_AddToHistoricalStructures(new_fvg);

        if (ESD_AggressiveMode && ESD_TradeOnFVGDetection && ESD_last_fvg_sell_time != fvg_time && !liquidity_grab_active)
        {
            ESD_last_fvg_sell_time = fvg_time;
            ESD_ExecuteAggressiveSell("FVG", (ESD_bearish_fvg_top + ESD_bearish_fvg_bottom) / 2, fvg_time);
        }
    }

    // Draw Objects
    if (ESD_ShowObjects)
    {
        if (ESD_ShowOb)
        {
            ESD_DrawOrderBlock("ESD_BullishOB", ESD_bullish_ob_top, ESD_bullish_ob_bottom, ESD_BullishColor, ESD_ObLineStyle, ESD_ObStyle);
            ESD_DrawOrderBlock("ESD_BearishOB", ESD_bearish_ob_top, ESD_bearish_ob_bottom, ESD_BearishColor, ESD_ObLineStyle, ESD_ObStyle);
        }

        if (ESD_ShowLabels)
        {
            if (ESD_bullish_ob_bottom != EMPTY_VALUE)
            {
                ESD_DrawLabel("ESD_BullishOB_Label", fvg_time, ESD_bullish_ob_bottom, "OB", ESD_BullishColor, true);
                ESD_DrawLabel("ESD_BullishOB_POI_Label", fvg_time, (ESD_bullish_ob_top + ESD_bullish_ob_bottom) / 2, "POI", clrWhite, false);
            }
            if (ESD_bearish_ob_top != EMPTY_VALUE)
            {
                ESD_DrawLabel("ESD_BearishOB_Label", fvg_time, ESD_bearish_ob_top, "OB", ESD_BearishColor, true);
                ESD_DrawLabel("ESD_BearishOB_POI_Label", fvg_time, (ESD_bearish_ob_top + ESD_bearish_ob_bottom) / 2, "POI", clrWhite, false);
            }
        }

        // Draw Liquidity Levels
        if (ESD_ShowLiquidity)
        {
            if (ESD_bullish_liquidity != EMPTY_VALUE)
            {
                ESD_DrawLiquidityLine("ESD_BullishLiquidity", ESD_bullish_liquidity, clrAqua);
                if (ESD_ShowLabels)
                    ESD_DrawLabel("ESD_BullishLiq_Label", fvg_time, ESD_bullish_liquidity, "LIQUIDITY", clrAqua, true);
            }
            if (ESD_bearish_liquidity != EMPTY_VALUE)
            {
                ESD_DrawLiquidityLine("ESD_BearishLiquidity", ESD_bearish_liquidity, clrMagenta);
                if (ESD_ShowLabels)
                    ESD_DrawLabel("ESD_BearishLiq_Label", fvg_time, ESD_bearish_liquidity, "LIQUIDITY", clrMagenta, true);
            }
        }

        // Draw Market Structure Shift
        if (ESD_ShowLabels)
        {
            if (ESD_bullish_mss_detected)
                ESD_DrawLabel("ESD_BullishMSS_Label", ESD_bullish_mss_time, 0, "MSS", ESD_BullishColor, true);
            if (ESD_bearish_mss_detected)
                ESD_DrawLabel("ESD_BearishMSS_Label", ESD_bearish_mss_time, 0, "MSS", ESD_BearishColor, true);
        }
    }

    // Draw Heatmap strength indicator
    if (ESD_ShowObjects && ESD_UseHeatmapFilter)
    {
        string heatmap_indicator = "ESD_Heatmap_Indicator";
        double price_level = iLow(_Symbol, PERIOD_CURRENT, 0) - 150 * _Point;

        color indicator_color = ESD_NeutralColor;
        if (ESD_heatmap_strength > 0)
            indicator_color = (color)ColorToARGB(ESD_StrongBullishColor, (uchar)(MathAbs(ESD_heatmap_strength) * 2.55));
        else
            indicator_color = (color)ColorToARGB(ESD_StrongBearishColor, (uchar)(MathAbs(ESD_heatmap_strength) * 2.55));

        ESD_DrawLabel(heatmap_indicator, iTime(_Symbol, PERIOD_CURRENT, 0),
                      price_level,
                      StringFormat("HEAT: %+.0f", ESD_heatmap_strength),
                      indicator_color, true);
    }

    // Draw historical structures if enabled
    if (ESD_ShowHistorical)
    {
        ESD_DrawHistoricalStructures();
    }
}

//+------------------------------------------------------------------+
//| Execute aggressive buy trade                                     |
//+------------------------------------------------------------------+
void ESD_ExecuteAggressiveBuy(string signal_type, double trigger_price, datetime signal_time)
{
    // Jika sudah ada posisi, tidak usah entry lagi
    if (PositionSelect(_Symbol))
        return;

    // Tambahkan regime filter
    if (!ESD_RegimeFilter(true))
        return;

    // CEK KONFIRMASI CANDLE SAAT INI
    MqlRates current_rates[];
    CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, current_rates);

    if (ArraySize(current_rates) > 0)
    {
        bool is_bullish = (current_rates[0].close > current_rates[0].open);
        if (!is_bullish)
        {
            return; // Jangan entry buy jika candle saat ini bearish
        }
    }

    // CEK APAKAH SUDAH ADA RETEST
    if (!ESD_HasRetestOccurred(signal_type, trigger_price, true))
        return; // Jangan entry sebelum retest terjadi

    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // Calculate SL and TP for aggressive mode
    double sl = 0;
    double tp = 0;

    // Use a wider SL for aggressive mode to account for higher risk
    double aggressive_sl_points = ESD_StopLossPoints * ESD_AggressiveSLMultiplier;
    double aggressive_tp_points = ESD_TakeProfitPoints * ESD_AggressiveTPMultiplier;

    switch (ESD_SlTpMethod)
    {
    case ESD_FIXED_POINTS:
    {
        sl = ask - aggressive_sl_points * point;
        tp = ask + aggressive_tp_points * point;
        break;
    }

    case ESD_STRUCTURE_BASED:
    {
        // For FVG, place SL below the FVG
        if (signal_type == "FVG" && ESD_bullish_fvg_bottom != EMPTY_VALUE)
            sl = ESD_bullish_fvg_bottom - ESD_SlBufferPoints * point;
        // For CHOCH/BoS, place SL below the broken level
        else if (signal_type == "CHOCH" || signal_type == "BoS")
            sl = trigger_price - ESD_SlBufferPoints * point;
        else
            sl = ask - aggressive_sl_points * point; // Fallback

        // TP based on risk/reward or fixed points
        double risk = ask - sl;
        if (risk > 0)
            tp = ask + (risk * ESD_RiskRewardRatio);
        else
            tp = ask + aggressive_tp_points * point; // Fallback
        break;
    }

    default:
    {
        sl = ask - aggressive_sl_points * point;
        tp = ask + aggressive_tp_points * point;
        break;
    }
    }

    // Validasi SL/TP agar tidak salah
    if (sl >= ask)
        sl = ask - 10 * point; // Paksa SL minimal
    if (tp <= ask)
        tp = ask + 10 * point; // Paksa TP minimal
    if (sl <= 0 || tp <= 0)
        return; // Jangan trade jika SL/TP tidak valid

    string comment = StringFormat("Aggressive Buy (%s)", signal_type);
    // ESD_trade.Buy(ESD_LotSize, _Symbol, ask, sl, tp, comment); setingan manual lot

    // dengan regime filter ESD_GetRegimeAdjustedLotSize
    double adjusted_lot = ESD_GetRegimeAdjustedLotSize();
    ESD_ExecuteTradeWithPartialTP(true, ask, sl, comment);
}

//+------------------------------------------------------------------+
//| Execute aggressive sell trade                                    |
//+------------------------------------------------------------------+
void ESD_ExecuteAggressiveSell(string signal_type, double trigger_price, datetime signal_time)
{
    // Jika sudah ada posisi, tidak usah entry lagi
    if (PositionSelect(_Symbol))
        return;

    // Tambahkan regime filter
    if (!ESD_RegimeFilter(false))
        return;

    // CEK KONFIRMASI CANDLE SAAT INI
    MqlRates current_rates[];
    CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, current_rates);

    if (ArraySize(current_rates) > 0)
    {
        bool is_bearish = (current_rates[0].close < current_rates[0].open);
        if (!is_bearish)
        {
            return; // Jangan entry sell jika candle saat ini bullish
        }
    }

    // CEK APAKAH SUDAH ADA RETEST
    if (!ESD_HasRetestOccurred(signal_type, trigger_price, false))
        return; // Jangan entry sebelum retest terjadi

    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // Calculate SL and TP for aggressive mode
    double sl = 0;
    double tp = 0;

    // Use a wider SL for aggressive mode to account for higher risk
    double aggressive_sl_points = ESD_StopLossPoints * ESD_AggressiveSLMultiplier;
    double aggressive_tp_points = ESD_TakeProfitPoints * ESD_AggressiveTPMultiplier;

    switch (ESD_SlTpMethod)
    {
    case ESD_FIXED_POINTS:
    {
        sl = bid + aggressive_sl_points * point;
        tp = bid - aggressive_tp_points * point;
        break;
    }

    case ESD_STRUCTURE_BASED:
    {
        // For FVG, place SL above the FVG
        if (signal_type == "FVG" && ESD_bearish_fvg_top != EMPTY_VALUE)
            sl = ESD_bearish_fvg_top + ESD_SlBufferPoints * point;
        // For CHOCH/BoS, place SL above the broken level
        else if (signal_type == "CHOCH" || signal_type == "BoS")
            sl = trigger_price + ESD_SlBufferPoints * point;
        else
            sl = bid + aggressive_sl_points * point; // Fallback

        // TP based on risk/reward or fixed points
        double risk = sl - bid;
        if (risk > 0)
            tp = bid - (risk * ESD_RiskRewardRatio);
        else
            tp = bid - aggressive_tp_points * point; // Fallback
        break;
    }

    default:
    {
        sl = bid + aggressive_sl_points * point;
        tp = bid - aggressive_tp_points * point;
        break;
    }
    }

    // Validasi SL/TP agar tidak salah
    if (sl <= bid)
        sl = bid + 10 * point; // Paksa SL minimal
    if (tp >= bid)
        tp = bid - 10 * point; // Paksa TP minimal
    if (sl <= 0 || tp <= 0)
        return; // Jangan trade jika SL/TP tidak valid

    string comment = StringFormat("Aggressive Sell (%s)", signal_type);
    // ESD_trade.Sell(ESD_LotSize, _Symbol, bid, sl, tp, comment); setingan manual lot size

    // dengan regime filter lot size
    double adjusted_lot = ESD_GetRegimeAdjustedLotSize();
    ESD_ExecuteTradeWithPartialTP(false, bid, sl, comment);
}

//+------------------------------------------------------------------+
//| Check for aggressive entry opportunities dengan ML Enhancement  |
//+------------------------------------------------------------------+
void ESD_CheckForAggressiveEntry()
{
    // Jika sudah ada posisi, tidak usah entry lagi
    // if (PositionSelect(_Symbol))
    //     return;

    if (!ESD_AggressiveMode)
        return;

    // Update ML model untuk aggressive entries
    if (ESD_UseMachineLearning)
        ESD_UpdateMLModel();

    // 🎯 PRIORITAS: Cari inducement opportunities terlebih dahulu
    if (ESD_TradeAgainstInducement())
        return;

    // Tambahkan regime filter untuk aggressive entries
    if (!ESD_RegimeFilter(true) && !ESD_RegimeFilter(false))
        return;

    // 🚫 BSL/SSL AVOIDANCE CHECK untuk aggressive entries
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    if (ESD_IsInBSL_SSLZone(ask, true) && ESD_IsInBSL_SSLZone(bid, false))
        return;

    // ================== ML ENHANCED FILTERING ==================
    if (ESD_UseMachineLearning)
    {
        ESD_ML_Features features = ESD_CollectMLFeatures();
        double ml_buy_signal = ESD_GetMLEntrySignal(true, features);
        double ml_sell_signal = ESD_GetMLEntrySignal(false, features);

        // ML Confidence threshold untuk aggressive mode (lebih rendah dari normal)
        double ml_aggressive_threshold = 0.6;

        // ML-based regime suitability untuk aggressive trading
        bool ml_aggressive_buy_ok = (ml_buy_signal > ml_aggressive_threshold) &&
                                    (features.volatility < 0.008) && // Moderate volatility
                                    (features.trend_strength > 0.6); // Strong trend

        bool ml_aggressive_sell_ok = (ml_sell_signal < -ml_aggressive_threshold) &&
                                     (features.volatility < 0.008) && // Moderate volatility
                                     (features.trend_strength > 0.6); // Strong trend

        // ML Risk Appetite Check - lebih conservative di aggressive mode
        if (ESD_ml_risk_appetite < 0.4)
        {
            Print("ML Risk Appetite too low for aggressive entries: ", ESD_ml_risk_appetite);
            return;
        }
    }

    // ================== COMBINED HEATMAP + ORDER FLOW FILTER ==================

    // Filter 1: Individual Heatmap Strength Check
    if (ESD_UseHeatmapFilter)
    {
        // Only allow aggressive entries when heatmap confirms
        if (ESD_heatmap_bullish && ESD_heatmap_strength < ESD_HeatmapStrengthThreshold)
            return; // Skip aggressive buys if heatmap not strong enough

        if (ESD_heatmap_bearish && ESD_heatmap_strength > -ESD_HeatmapStrengthThreshold)
            return; // Skip aggressive sells if heatmap not strong enough
    }

    // Filter 2: Order Flow Specific Filters (if enabled alone)
    else if (ESD_UseOrderFlow)
    {
        // Minimum order flow strength requirement
        if (MathAbs(ESD_orderflow_strength) < 35)
            return; // Skip if order flow too weak

        // Absorption filter for aggressive entries
        if (ESD_absorption_detected && MathAbs(ESD_orderflow_strength) < 60)
            return; // Skip aggressive entries during absorption unless very strong
    }

    // Filter 3: Combined Heatmap + Order Flow Strength Check
    if (ESD_UseHeatmapFilter && ESD_UseOrderFlow)
    {
        double combined_strength = (ESD_heatmap_strength + ESD_orderflow_strength) / 2;

        // More strict filter for aggressive entries
        if (MathAbs(combined_strength) < 50) // Increased from 40 to 50 for better filtering
            return;                          // Skip if combined strength too low

        // Additional: Check for conflict between heatmap and order flow
        if ((ESD_heatmap_strength > 30 && ESD_orderflow_strength < -20) ||
            (ESD_heatmap_strength < -30 && ESD_orderflow_strength > 20))
        {
            return; // Skip if significant conflict between signals
        }
    }

    // Get current price
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // Tolerance for zone approach - ML Adjusted
    double base_tolerance = ESD_ZoneTolerancePoints * point * 2;
    double ml_tolerance_adjustment = 1.0;

    if (ESD_UseMachineLearning)
    {
        // Adjust tolerance berdasarkan ML confidence dan volatility
        ESD_ML_Features features = ESD_CollectMLFeatures();
        ml_tolerance_adjustment = 1.0 + (features.trend_strength * 0.5) - (features.volatility * 50);
        ml_tolerance_adjustment = MathMax(ml_tolerance_adjustment, 0.5); // Min 0.5x
        ml_tolerance_adjustment = MathMin(ml_tolerance_adjustment, 2.0); // Max 2.0x
    }

    double approach_tolerance = base_tolerance * ml_tolerance_adjustment;

    // Get current candle untuk konfirmasi
    MqlRates current_rates[];
    ArraySetAsSeries(current_rates, true);
    if (CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, current_rates) <= 0)
        return;

    bool current_bullish = (current_rates[0].close > current_rates[0].open);
    bool current_bearish = (current_rates[0].close < current_rates[0].open);

    // ================== ML-ENHANCED AGGRESSIVE BUY ==================
    if (current_bullish && ESD_bullish_fvg_bottom != EMPTY_VALUE &&
        ask < ESD_bullish_fvg_bottom + approach_tolerance && ask > ESD_bullish_fvg_bottom)
    {
        // Price is approaching bullish FVG from above, enter early
        if (ESD_last_fvg_buy_time != iTime(_Symbol, ESD_HigherTimeframe, 0))
        {
            // ML Confidence Check untuk aggressive buy
            bool ml_approved = true;
            if (ESD_UseMachineLearning)
            {
                ESD_ML_Features features = ESD_CollectMLFeatures();
                double ml_signal = ESD_GetMLEntrySignal(true, features);
                double aggressive_threshold = 0.6;

                ml_approved = (ml_signal > aggressive_threshold) &&
                              (features.structure_quality > 0.5) &&
                              (features.risk_sentiment > 0.4);

                if (!ml_approved)
                {
                    Print("ML Rejected Aggressive Buy. Signal: ", ml_signal, " Quality: ", features.structure_quality);
                }
            }

            if (ml_approved)
            {
                ESD_last_fvg_buy_time = iTime(_Symbol, ESD_HigherTimeframe, 0);

                // HANYA ENTRY JIKA SUDAH ADA RETEST
                if (ESD_HasRetestOccurred("FVG_Approach", (ESD_bullish_fvg_top + ESD_bullish_fvg_bottom) / 2, true))
                {
                    // ML-Enhanced aggressive execution
                    ESD_ExecuteMLAggressiveBuy("ML_Aggressive_FVG",
                                               (ESD_bullish_fvg_top + ESD_bullish_fvg_bottom) / 2,
                                               iTime(_Symbol, ESD_HigherTimeframe, 0));
                }
            }
        }
    }

    // ================== ML-ENHANCED AGGRESSIVE SELL ==================
    if (current_bearish && ESD_bearish_fvg_top != EMPTY_VALUE &&
        bid > ESD_bearish_fvg_top - approach_tolerance && bid < ESD_bearish_fvg_top)
    {
        // Price is approaching bearish FVG from below, enter early
        if (ESD_last_fvg_sell_time != iTime(_Symbol, ESD_HigherTimeframe, 0))
        {
            // ML Confidence Check untuk aggressive sell
            bool ml_approved = true;
            if (ESD_UseMachineLearning)
            {
                ESD_ML_Features features = ESD_CollectMLFeatures();
                double ml_signal = ESD_GetMLEntrySignal(false, features);
                double aggressive_threshold = 0.6;

                ml_approved = (ml_signal < -aggressive_threshold) &&
                              (features.structure_quality > 0.5) &&
                              (features.risk_sentiment > 0.4);

                if (!ml_approved)
                {
                    Print("ML Rejected Aggressive Sell. Signal: ", MathAbs(ml_signal), " Quality: ", features.structure_quality);
                }
            }

            if (ml_approved)
            {
                ESD_last_fvg_sell_time = iTime(_Symbol, ESD_HigherTimeframe, 0);

                // HANYA ENTRY JIKA SUDAH ADA RETEST
                if (ESD_HasRetestOccurred("FVG_Approach", (ESD_bearish_fvg_top + ESD_bearish_fvg_bottom) / 2, false))
                {
                    // ML-Enhanced aggressive execution
                    ESD_ExecuteMLAggressiveSell("ML_Aggressive_FVG",
                                                (ESD_bearish_fvg_top + ESD_bearish_fvg_bottom) / 2,
                                                iTime(_Symbol, ESD_HigherTimeframe, 0));
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Execute ML-Enhanced Aggressive Buy                             |
//+------------------------------------------------------------------+
void ESD_ExecuteMLAggressiveBuy(string signal_type, double trigger_price, datetime signal_time)
{
    // Enhanced aggressive buy dengan ML parameters
    if (PositionSelect(_Symbol))
        return;

    // ML Risk Appetite Check
    if (ESD_ml_risk_appetite < 0.3)
    {
        Print("ML Risk Appetite too low for aggressive buy: ", ESD_ml_risk_appetite);
        return;
    }

    // CEK KONFIRMASI CANDLE SAAT INI
    MqlRates current_rates[];
    CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, current_rates);

    if (ArraySize(current_rates) > 0)
    {
        bool is_bullish = (current_rates[0].close > current_rates[0].open);
        if (!is_bullish)
        {
            return; // Jangan entry buy jika candle saat ini bearish
        }
    }

    // CEK APAKAH SUDAH ADA RETEST
    if (!ESD_HasRetestOccurred(signal_type, trigger_price, true))
        return;

    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // ML-Enhanced SL and TP calculation
    double sl = 0;
    double tp = 0;
    double risk = ask - sl;

    // Use ML-adjusted multipliers untuk aggressive mode
    double aggressive_sl_points = ESD_StopLossPoints * ESD_AggressiveSLMultiplier * ESD_ml_optimal_sl_multiplier;
    double aggressive_tp_points = ESD_TakeProfitPoints * ESD_AggressiveTPMultiplier * ESD_ml_optimal_tp_multiplier;

    // ML-Enhanced position sizing
    double ml_lot_size = ESD_GetMLAdjustedLotSize();
    double aggressive_lot = ml_lot_size * 1.2; // Slightly larger lots untuk aggressive mode

    switch (ESD_SlTpMethod)
    {
    case ESD_FIXED_POINTS:
        sl = ask - aggressive_sl_points * point;
        tp = ask + aggressive_tp_points * point;
        break;

    case ESD_STRUCTURE_BASED:
        // For FVG, place SL below the FVG dengan ML adjustment
        if (signal_type == "ML_Aggressive_FVG" && ESD_bullish_fvg_bottom != EMPTY_VALUE)
            sl = ESD_bullish_fvg_bottom - (ESD_SlBufferPoints * ESD_ml_optimal_sl_multiplier * point);
        else
            sl = ask - aggressive_sl_points * point;

        if (risk > 0)
            tp = ask + (risk * ESD_RiskRewardRatio * ESD_ml_optimal_tp_multiplier);
        else
            tp = ask + aggressive_tp_points * point;
        break;

    default:
        sl = ask - aggressive_sl_points * point;
        tp = ask + aggressive_tp_points * point;
        break;
    }

    // Validasi SL/TP
    if (sl >= ask)
        sl = ask - 10 * point;
    if (tp <= ask)
        tp = ask + 10 * point;
    if (sl <= 0 || tp <= 0)
        return;

    string comment = StringFormat("ML-Aggressive Buy (%s) Conf:%.2f", signal_type, ESD_ml_risk_appetite);

    // Execute dengan ML-enhanced parameters
    ESD_ExecuteTradeWithPartialTP(true, ask, sl, comment);
}

//+------------------------------------------------------------------+
//| Execute ML-Enhanced Aggressive Sell                            |
//+------------------------------------------------------------------+
void ESD_ExecuteMLAggressiveSell(string signal_type, double trigger_price, datetime signal_time)
{
    // Enhanced aggressive sell dengan ML parameters
    if (PositionSelect(_Symbol))
        return;

    // ML Risk Appetite Check
    if (ESD_ml_risk_appetite < 0.3)
    {
        Print("ML Risk Appetite too low for aggressive sell: ", ESD_ml_risk_appetite);
        return;
    }

    // CEK KONFIRMASI CANDLE SAAT INI
    MqlRates current_rates[];
    CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, current_rates);

    if (ArraySize(current_rates) > 0)
    {
        bool is_bearish = (current_rates[0].close < current_rates[0].open);
        if (!is_bearish)
        {
            return; // Jangan entry sell jika candle saat ini bullish
        }
    }

    // CEK APAKAH SUDAH ADA RETEST
    if (!ESD_HasRetestOccurred(signal_type, trigger_price, false))
        return;

    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // ML-Enhanced SL and TP calculation
    double sl = 0;
    double tp = 0;
    double risk = sl - bid;

    // Use ML-adjusted multipliers untuk aggressive mode
    double aggressive_sl_points = ESD_StopLossPoints * ESD_AggressiveSLMultiplier * ESD_ml_optimal_sl_multiplier;
    double aggressive_tp_points = ESD_TakeProfitPoints * ESD_AggressiveTPMultiplier * ESD_ml_optimal_tp_multiplier;

    // ML-Enhanced position sizing
    double ml_lot_size = ESD_GetMLAdjustedLotSize();
    double aggressive_lot = ml_lot_size * 1.2; // Slightly larger lots untuk aggressive mode

    switch (ESD_SlTpMethod)
    {
    case ESD_FIXED_POINTS:
        sl = bid + aggressive_sl_points * point;
        tp = bid - aggressive_tp_points * point;
        break;

    case ESD_STRUCTURE_BASED:
        // For FVG, place SL above the FVG dengan ML adjustment
        if (signal_type == "ML_Aggressive_FVG" && ESD_bearish_fvg_top != EMPTY_VALUE)
            sl = ESD_bearish_fvg_top + (ESD_SlBufferPoints * ESD_ml_optimal_sl_multiplier * point);
        else
            sl = bid + aggressive_sl_points * point;

        // TP based on ML-enhanced risk/reward
        if (risk > 0)
            tp = bid - (risk * ESD_RiskRewardRatio * ESD_ml_optimal_tp_multiplier);
        else
            tp = bid - aggressive_tp_points * point;
        break;

    default:
        sl = bid + aggressive_sl_points * point;
        tp = bid - aggressive_tp_points * point;
        break;
    }

    // Validasi SL/TP
    if (sl <= bid)
        sl = bid + 10 * point;
    if (tp >= bid)
        tp = bid - 10 * point;
    if (sl <= 0 || tp <= 0)
        return;

    string comment = StringFormat("ML-Aggressive Sell (%s) Conf:%.2f", signal_type, ESD_ml_risk_appetite);

    // Execute dengan ML-enhanced parameters
    ESD_ExecuteTradeWithPartialTP(false, bid, sl, comment);
}

//+------------------------------------------------------------------+
//| Check ML-Enhanced Alternative Aggressive Entries               |
//+------------------------------------------------------------------+
void ESD_CheckMLAggressiveAlternativeEntries()
{
    // if (PositionSelect(_Symbol))
    //     return;

    ESD_ML_Features features = ESD_CollectMLFeatures();

    // ML-Based Momentum Aggressive Entries
    if (features.momentum > 0.8 && features.trend_strength > 0.7 && ESD_ml_risk_appetite > 0.6)
    {
        // Strong bullish momentum dengan ML confirmation
        double ml_buy_signal = ESD_GetMLEntrySignal(true, features);
        if (ml_buy_signal > 0.75)
        {
            Print("ML Momentum Aggressive Buy Triggered");
            ESD_ExecuteMLAggressiveBuy("ML_Momentum_Breakout", SymbolInfoDouble(_Symbol, SYMBOL_ASK), TimeCurrent());
        }
    }

    if (features.momentum < 0.2 && features.trend_strength > 0.7 && ESD_ml_risk_appetite > 0.6)
    {
        // Strong bearish momentum dengan ML confirmation
        double ml_sell_signal = ESD_GetMLEntrySignal(false, features);
        if (ml_sell_signal < -0.75)
        {
            Print("ML Momentum Aggressive Sell Triggered");
            ESD_ExecuteMLAggressiveSell("ML_Momentum_Breakdown", SymbolInfoDouble(_Symbol, SYMBOL_BID), TimeCurrent());
        }
    }

    // ML-Based Structure Break Aggressive Entries
    if (features.structure_quality > 0.8 && features.heatmap_strength > 0.7)
    {
        // High quality structure break dengan strong heatmap
        if (ESD_bullish_trend_confirmed && ESD_ml_risk_appetite > 0.5)
        {
            Print("ML Structure Aggressive Buy Triggered");
            ESD_ExecuteMLAggressiveBuy("ML_Structure_Break", SymbolInfoDouble(_Symbol, SYMBOL_ASK), TimeCurrent());
        }
        else if (ESD_bearish_trend_confirmed && ESD_ml_risk_appetite > 0.5)
        {
            Print("ML Structure Aggressive Sell Triggered");
            ESD_ExecuteMLAggressiveSell("ML_Structure_Break", SymbolInfoDouble(_Symbol, SYMBOL_BID), TimeCurrent());
        }
    }
}

//+------------------------------------------------------------------+
//| Check if VALID retest has occurred for a signal - ENHANCED       |
//+------------------------------------------------------------------+
bool ESD_HasRetestOccurred(string signal_type, double trigger_price, bool is_buy_signal)
{
    int max_bars = (int)MathMin(100, MathMax(15, ESD_SwingLookback * 2));
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if (CopyRates(_Symbol, PERIOD_CURRENT, 0, max_bars, rates) != max_bars)
        return false;

    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
    double dynamic_tolerance = MathMax(50 * point, atr * 0.3); // Dynamic tolerance based on ATR
    double tight_tolerance = MathMax(20 * point, atr * 0.15);  // Tighter tolerance for precise levels

    // Enhanced zone validation with multiple condition checks
    bool valid_zone = true;
    if (signal_type == "FVG" || signal_type == "FVG_Approach")
    {
        if (is_buy_signal)
            valid_zone = (ESD_bullish_fvg_bottom != EMPTY_VALUE);
        else
            valid_zone = (ESD_bearish_fvg_top != EMPTY_VALUE);
    }

    if (!valid_zone)
        return false;

    int consecutive_confirmation = 0;
    bool potential_retest_found = false;
    double confirmed_price = 0;
    int confirmation_bar_index = -1;

    for (int i = 3; i < max_bars - 2; i++)
    {
        bool price_touch = false;
        double reference_price = 0;
        double current_tolerance = dynamic_tolerance;

        // Determine reference price and appropriate tolerance
        if (signal_type == "FVG" || signal_type == "FVG_Approach")
        {
            if (is_buy_signal)
            {
                reference_price = ESD_bullish_fvg_bottom;
                // Use tighter tolerance for FVG levels
                current_tolerance = tight_tolerance;
            }
            else
            {
                reference_price = ESD_bearish_fvg_top;
                current_tolerance = tight_tolerance;
            }
        }
        else // CHOCH or BoS
        {
            reference_price = trigger_price;
            // Use dynamic tolerance for swing points
            current_tolerance = dynamic_tolerance;
        }

        // Enhanced price touch detection with multiple conditions
        if (is_buy_signal)
        {
            // Buy retest: price touches the level from above
            bool wick_touch = (rates[i].low <= reference_price + current_tolerance &&
                               rates[i].low >= reference_price - current_tolerance);
            bool body_touch = (rates[i].open <= reference_price + current_tolerance ||
                               rates[i].close <= reference_price + current_tolerance);
            bool close_near = (MathAbs(rates[i].close - reference_price) <= current_tolerance * 1.5);

            price_touch = wick_touch || body_touch || close_near;
        }
        else
        {
            // Sell retest: price touches the level from below
            bool wick_touch = (rates[i].high >= reference_price - current_tolerance &&
                               rates[i].high <= reference_price + current_tolerance);
            bool body_touch = (rates[i].open >= reference_price - current_tolerance ||
                               rates[i].close >= reference_price - current_tolerance);
            bool close_near = (MathAbs(rates[i].close - reference_price) <= current_tolerance * 1.5);

            price_touch = wick_touch || body_touch || close_near;
        }

        if (price_touch)
        {
            potential_retest_found = true;
            confirmed_price = reference_price;
            confirmation_bar_index = i;

            // MULTI-CONFIRMATION VALIDATION SYSTEM
            int confirmation_score = 0;
            int max_lookback = MathMin(3, i); // Look back up to 3 bars

            for (int j = 1; j <= max_lookback; j++)
            {
                int check_bar = i - j;
                if (check_bar < 0)
                    continue;

                // 1. Candle Direction Confirmation
                if (is_buy_signal)
                {
                    if (rates[check_bar].close > rates[check_bar].open)
                        confirmation_score++;
                    if (rates[check_bar].close > confirmed_price)
                        confirmation_score++;
                    if (check_bar >= 1 && rates[check_bar].close > rates[check_bar - 1].high)
                        confirmation_score += 2;
                }
                else
                {
                    if (rates[check_bar].close < rates[check_bar].open)
                        confirmation_score++;
                    if (rates[check_bar].close < confirmed_price)
                        confirmation_score++;
                    if (check_bar >= 1 && rates[check_bar].close < rates[check_bar - 1].low)
                        confirmation_score += 2;
                }

                // 2. Volume and Momentum Confirmation (if available)
                if (rates[check_bar].tick_volume > rates[check_bar + 1].tick_volume * 1.2)
                    confirmation_score++;

                // 3. Rejection Pattern Detection
                if (is_buy_signal && rates[check_bar].close > rates[check_bar].high * 0.6)
                    confirmation_score++;
                if (!is_buy_signal && rates[check_bar].close < rates[check_bar].low * 1.4)
                    confirmation_score++;
            }

            // 4. Subsequent Price Action Validation
            bool subsequent_confirmation = false;
            if (i + 1 < max_bars)
            {
                if (is_buy_signal)
                {
                    subsequent_confirmation = (rates[i + 1].close > rates[i].high) ||
                                              (rates[i + 1].close > confirmed_price + current_tolerance);
                }
                else
                {
                    subsequent_confirmation = (rates[i + 1].close < rates[i].low) ||
                                              (rates[i + 1].close < confirmed_price - current_tolerance);
                }
            }

            // FINAL VALIDATION: Require strong confirmation
            if (confirmation_score >= 3 || (confirmation_score >= 2 && subsequent_confirmation))
            {
                // Additional filter: Check if this is the most recent valid retest
                bool is_most_recent = true;
                for (int k = i + 1; k < MathMin(i + 5, max_bars); k++)
                {
                    if (is_buy_signal && rates[k].low <= confirmed_price + current_tolerance)
                        is_most_recent = false;
                    if (!is_buy_signal && rates[k].high >= confirmed_price - current_tolerance)
                        is_most_recent = false;
                }

                if (is_most_recent)
                    return true;
            }
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Detect Market Structure Shift                                     |
//+------------------------------------------------------------------+
void ESD_DetectMarketStructureShift(const double &high_buffer[], const double &low_buffer[], const double &close_buffer[])
{
    MqlRates rates[];
    long volume_buffer[];
    ArraySetAsSeries(rates, true);
    ArraySetAsSeries(volume_buffer, true);

    int bars_to_check = 20;
    CopyRates(_Symbol, ESD_HigherTimeframe, 0, bars_to_check, rates);
    CopyTickVolume(_Symbol, ESD_HigherTimeframe, 0, bars_to_check, volume_buffer);

    // Bullish MSS: Lower Low followed by break of previous Lower High
    if (ESD_last_significant_pl > 0 && ESD_last_significant_ph > 0)
    {
        // Check for a new lower low
        for (int i = 1; i < 10; i++)
        {
            if (low_buffer[i] < ESD_last_significant_pl)
            {
                // Found a new lower low, now check for break of previous lower high
                for (int j = 1; j < i; j++)
                {
                    if (high_buffer[j] > ESD_last_significant_ph)
                    {

                        double break_strength = (high_buffer[j] - ESD_last_significant_ph) / (high_buffer[j] - low_buffer[j]);
                        bool strong_break = (break_strength > 0.6);

                        if (strong_break)
                        {
                            // Bullish MSS detected
                            ESD_bullish_mss_detected = true;
                            ESD_bullish_mss_time = iTime(_Symbol, ESD_HigherTimeframe, j);

                            // Add to historical structures
                            ESD_SMStructure new_mss;
                            new_mss.time = ESD_bullish_mss_time;
                            new_mss.price = ESD_last_significant_ph;
                            new_mss.is_bullish = true;
                            new_mss.type = "MSS";
                            new_mss.top = ESD_last_significant_ph;
                            new_mss.bottom = ESD_last_significant_pl;
                            new_mss.quality_score = 0.8; // High quality signal
                            ESD_AddToHistoricalStructures(new_mss);

                            // Update trend strength
                            ESD_bullish_trend_strength = MathMin(1.0, ESD_bullish_trend_strength + 0.4);
                            ESD_bearish_trend_strength = MathMax(0.0, ESD_bearish_trend_strength - 0.4);

                            if (ESD_bullish_trend_strength > ESD_TrendStrengthThreshold)
                                ESD_bullish_trend_confirmed = true;

                            // In aggressive mode, trigger a buy signal immediately
                            if (ESD_AggressiveMode && ESD_last_fvg_buy_time != ESD_bullish_mss_time)
                            {
                                ESD_last_fvg_buy_time = ESD_bullish_mss_time;
                                ESD_ExecuteAggressiveBuy("MSS", ESD_last_significant_ph, ESD_bullish_mss_time);
                            }

                            return;
                        }
                    }
                }
                break;
            }
        }
    }

    // Bearish MSS: Higher High followed by break of previous Higher Low
    if (ESD_last_significant_ph > 0 && ESD_last_significant_pl > 0)
    {
        // Check for a new higher high
        for (int i = 1; i < 10; i++)
        {
            if (high_buffer[i] > ESD_last_significant_ph)
            {
                // Found a new higher high, now check for break of previous higher low
                for (int j = 1; j < i; j++)
                {
                    if (low_buffer[j] < ESD_last_significant_pl)
                    {
                        // Bearish MSS detected
                        ESD_bearish_mss_detected = true;
                        ESD_bearish_mss_time = iTime(_Symbol, ESD_HigherTimeframe, j);

                        // Add to historical structures
                        ESD_SMStructure new_mss;
                        new_mss.time = ESD_bearish_mss_time;
                        new_mss.price = ESD_last_significant_pl;
                        new_mss.is_bullish = false;
                        new_mss.type = "MSS";
                        new_mss.top = ESD_last_significant_ph;
                        new_mss.bottom = ESD_last_significant_pl;
                        new_mss.quality_score = 0.8; // High quality signal
                        ESD_AddToHistoricalStructures(new_mss);

                        // Update trend strength
                        ESD_bearish_trend_strength = MathMin(1.0, ESD_bearish_trend_strength + 0.3);
                        ESD_bullish_trend_strength = MathMax(0.0, ESD_bullish_trend_strength - 0.3);

                        if (ESD_bearish_trend_strength > ESD_TrendStrengthThreshold)
                            ESD_bearish_trend_confirmed = true;

                        // In aggressive mode, trigger a sell signal immediately
                        if (ESD_AggressiveMode && ESD_last_fvg_sell_time != ESD_bearish_mss_time)
                        {
                            ESD_last_fvg_sell_time = ESD_bearish_mss_time;
                            ESD_ExecuteAggressiveSell("MSS", ESD_last_significant_pl, ESD_bearish_mss_time);
                        }

                        return;
                    }
                }
                break;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Confirm break of structure                                        |
//+------------------------------------------------------------------+
bool ESD_ConfirmBreak(const double &price_buffer[], double level, bool is_bullish, int confirmation_bars)
{
    if (confirmation_bars <= 1)
        return true;

    int confirmed = 0;
    for (int i = 0; i < confirmation_bars; i++)
    {
        if (is_bullish && price_buffer[i] > level)
            confirmed++;
        else if (!is_bullish && price_buffer[i] < level)
            confirmed++;
    }

    return (confirmed >= confirmation_bars / 2 + 1);
}

//+------------------------------------------------------------------+
//| Calculate pivot quality                                           |
//+------------------------------------------------------------------+
double ESD_CalculatePivotQuality(int index, const double &high_buffer[], const double &low_buffer[], bool is_low)
{
    double quality = 0.5; // Base quality

    // Check the strength of the pivot (how much it stands out)
    if (is_low)
    {
        double min_left = low_buffer[index];
        double min_right = low_buffer[index];

        for (int i = index - ESD_BosLookback; i < index; i++)
        {
            if (i >= 0 && low_buffer[i] < min_left)
                min_left = low_buffer[i];
        }

        for (int i = index + 1; i <= index + ESD_BosLookback; i++)
        {
            if (i < ArraySize(low_buffer) && low_buffer[i] < min_right)
                min_right = low_buffer[i];
        }

        // The higher the pivot compared to surrounding lows, the higher the quality
        double left_diff = low_buffer[index] - min_left;
        double right_diff = low_buffer[index] - min_right;
        quality += (left_diff + right_diff) / (2 * low_buffer[index]) * 5;
    }
    else
    {
        double max_left = high_buffer[index];
        double max_right = high_buffer[index];

        for (int i = index - ESD_BosLookback; i < index; i++)
        {
            if (i >= 0 && high_buffer[i] > max_left)
                max_left = high_buffer[i];
        }

        for (int i = index + 1; i <= index + ESD_BosLookback; i++)
        {
            if (i < ArraySize(high_buffer) && high_buffer[i] > max_right)
                max_right = high_buffer[i];
        }

        // The lower the pivot compared to surrounding highs, the higher the quality
        double left_diff = max_left - high_buffer[index];
        double right_diff = max_right - high_buffer[index];
        quality += (left_diff + right_diff) / (2 * high_buffer[index]) * 5;
    }

    return MathMin(1.0, quality);
}

//+------------------------------------------------------------------+
//| Calculate break quality                                           |
//+------------------------------------------------------------------+
double ESD_CalculateBreakQuality(datetime time, double level, bool is_bullish)
{
    double quality = 0.5; // Base quality

    // Get the bar that broke the level
    int shift = iBarShift(_Symbol, ESD_HigherTimeframe, time);
    if (shift < 0)
        return quality;

    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    CopyRates(_Symbol, ESD_HigherTimeframe, shift, 2, rates);

    if (ArraySize(rates) < 2)
        return quality;

    // Check the strength of the break (how much it exceeded the level)
    if (is_bullish)
    {
        double excess = rates[0].high - level;
        double range = rates[0].high - rates[0].low;
        quality += (excess / range) * 0.3;

        // Check if the close is also above the level
        if (rates[0].close > level)
            quality += 0.2;
    }
    else
    {
        double excess = level - rates[0].low;
        double range = rates[0].high - rates[0].low;
        quality += (excess / range) * 0.3;

        // Check if the close is also below the level
        if (rates[0].close < level)
            quality += 0.2;
    }

    return MathMin(1.0, quality);
}

//+------------------------------------------------------------------+
//| Calculate Order Block quality                                     |
//+------------------------------------------------------------------+
double ESD_CalculateOrderBlockQuality(int index, const double &high_buffer[], const double &low_buffer[],
                                      const double &close_buffer[], const double &open_buffer[], bool is_bullish)
{
    double quality = 0.5; // Base quality

    if (index < 0 || index >= ArraySize(high_buffer))
        return quality;

    // Existing calculations
    double range = high_buffer[index] - low_buffer[index];
    double body = MathAbs(close_buffer[index] - open_buffer[index]);
    quality += (body / range) * 0.2;

    // ENHANCEMENT 1: Volume Context (gunakan volume dari tick data)
    MqlRates rates[];
    long volume_buffer[];
    ArraySetAsSeries(rates, true);
    ArraySetAsSeries(volume_buffer, true);

    int start_idx = MathMax(0, index - 5);
    int count = MathMin(6, ArraySize(high_buffer) - start_idx);

    CopyRates(_Symbol, ESD_HigherTimeframe, start_idx, count, rates);
    CopyTickVolume(_Symbol, ESD_HigherTimeframe, start_idx, count, volume_buffer);

    if (count > 0 && index - start_idx < count)
    {
        double ob_volume = (double)volume_buffer[index - start_idx];
        double avg_volume = 0;
        for (int i = 0; i < count; i++)
        {
            if (i != index - start_idx) // Exclude the OB candle itself
                avg_volume += (double)volume_buffer[i];
        }
        avg_volume /= (count - 1);

        // Volume spike meningkatkan quality
        if (avg_volume > 0)
            quality += MathMin(0.3, (ob_volume / avg_volume - 1.0) * 0.15);
    }

    // ENHANCEMENT 2: Momentum Follow-through
    if (index > 0 && index < ArraySize(high_buffer) - 1)
    {
        if (is_bullish)
        {
            // Untuk bullish OB, candle berikutnya harus confirm dengan higher high
            bool follow_through = (high_buffer[index + 1] > high_buffer[index]);
            if (follow_through)
                quality += 0.15;
        }
        else
        {
            // Untuk bearish OB, candle berikutnya harus confirm dengan lower low
            bool follow_through = (low_buffer[index + 1] < low_buffer[index]);
            if (follow_through)
                quality += 0.15;
        }
    }

    // ENHANCEMENT 3: Wick Analysis (existing tapi diperbaiki)
    double upper_wick = high_buffer[index] - MathMax(open_buffer[index], close_buffer[index]);
    double lower_wick = MathMin(open_buffer[index], close_buffer[index]) - low_buffer[index];
    double total_wick = upper_wick + lower_wick;

    // Untuk bullish OB, lower wick should be small (institutional buying di open)
    // Untuk bearish OB, upper wick should be small (institutional selling di open)
    if (is_bullish)
        quality += (1.0 - (lower_wick / range)) * 0.1;
    else
        quality += (1.0 - (upper_wick / range)) * 0.1;

    // Existing candle direction check
    if (is_bullish && close_buffer[index] > open_buffer[index])
        quality += 0.1;
    else if (!is_bullish && close_buffer[index] < open_buffer[index])
        quality += 0.1;

    return MathMin(1.0, quality);
}

//+------------------------------------------------------------------+
//| Calculate FVG quality                                             |
//+------------------------------------------------------------------+
// Perbaiki fungsi existing ESD_CalculateFVGQuality
double ESD_CalculateFVGQuality(int index, const double &high_buffer[], const double &low_buffer[], bool is_bullish)
{
    double quality = 0.5; // Base quality

    if (index < 0 || index + 2 >= ArraySize(high_buffer))
        return quality;

    // ENHANCEMENT: Add volume analysis untuk FVG
    MqlRates rates[];
    long volume_buffer[];
    ArraySetAsSeries(rates, true);
    ArraySetAsSeries(volume_buffer, true);

    CopyRates(_Symbol, ESD_HigherTimeframe, index, 3, rates);
    CopyTickVolume(_Symbol, ESD_HigherTimeframe, index, 3, volume_buffer);

    // Calculate FVG size (existing)
    double fvg_size;
    if (is_bullish)
        fvg_size = low_buffer[index + 2] - high_buffer[index];
    else
        fvg_size = high_buffer[index + 2] - low_buffer[index];

    // Existing ATR-based quality
    double atr_buffer[];
    ArraySetAsSeries(atr_buffer, true);
    double atr_value = 0;
    int atr_handle = iATR(_Symbol, ESD_HigherTimeframe, 14);
    if (CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0)
    {
        atr_value = atr_buffer[0];
    }

    if (atr_value > 0)
    {
        quality += MathMin(0.3, fvg_size / atr_value);
    }

    // ENHANCEMENT 1: Volume Confirmation untuk FVG
    if (ArraySize(volume_buffer) >= 3)
    {
        double avg_volume = (volume_buffer[0] + volume_buffer[1] + volume_buffer[2]) / 3.0;
        double fvg_volume = (double)MathMax(volume_buffer[0], volume_buffer[2]); // Volume di candle FVG

        if (avg_volume > 0)
            quality += MathMin(0.2, (fvg_volume / avg_volume - 1.0) * 0.1);
    }

    // ENHANCEMENT 2: Momentum Strength of FVG candles - PERBAIKAN DI SINI
    double range1 = high_buffer[index + 2] - low_buffer[index + 2];
    double range2 = high_buffer[index] - low_buffer[index];
    double body1 = MathAbs(rates[2].close - rates[2].open);
    double body2 = MathAbs(rates[0].close - rates[0].open);

    // PERBAIKAN: Handle zero division untuk range1 dan range2
    double strength1 = 0.0;
    double strength2 = 0.0;

    if (range1 > 0)
        strength1 = body1 / range1;
    else
        strength1 = (body1 > 0) ? 1.0 : 0.0; // Jika range=0 tapi ada body

    if (range2 > 0)
        strength2 = body2 / range2;
    else
        strength2 = (body2 > 0) ? 1.0 : 0.0; // Jika range=0 tapi ada body

    quality += (strength1 + strength2) * 0.1; // Strong candles = better FVG

    // ENHANCEMENT 3: Follow-through Confirmation
    if (index > 0)
    {
        if (is_bullish)
        {
            // Untuk bullish FVG, price harus maintain di atas FVG bottom
            bool follow_through = (low_buffer[index - 1] > low_buffer[index + 2]);
            if (follow_through)
                quality += 0.1;
        }
        else
        {
            // Untuk bearish FVG, price harus maintain di bawah FVG top
            bool follow_through = (high_buffer[index - 1] < high_buffer[index + 2]);
            if (follow_through)
                quality += 0.1;
        }
    }

    return MathMin(1.0, quality);
}

//+------------------------------------------------------------------+
//| Add structure to historical array                                |
//+------------------------------------------------------------------+
void ESD_AddToHistoricalStructures(ESD_SMStructure &structure)
{
    int size = ArraySize(ESD_smc_structures);
    ArrayResize(ESD_smc_structures, size + 1);
    ESD_smc_structures[size] = structure;
}

//+------------------------------------------------------------------+
//| Draw historical structures                                       |
//+------------------------------------------------------------------+
void ESD_DrawHistoricalStructures()
{
    int structures_count = ArraySize(ESD_smc_structures);
    for (int i = 0; i < structures_count; i++)
    {
        ESD_SMStructure structure = ESD_smc_structures[i];

        if (structure.type == "PH" || structure.type == "PL")
        {
            ESD_DrawSwingPoint(structure.time, structure.price, structure.type,
                               structure.is_bullish ? ESD_BullishColor : ESD_BearishColor);
        }
        else if (structure.type == "BOS")
        {
            if (ESD_ShowBos)
            {
                ESD_DrawBreakStructure(structure.time, structure.price, structure.is_bullish,
                                       structure.is_bullish ? ESD_BullishColor : ESD_BearishColor,
                                       ESD_BosLineStyle, ESD_BosStyle, "BOS");
            }
        }
        else if (structure.type == "CHOCH")
        {
            if (ESD_ShowChoch)
            {
                ESD_DrawBreakStructure(structure.time, structure.price, structure.is_bullish,
                                       ESD_ChochColor, ESD_ChochLineStyle, ESD_ChochStyle, "CHOCH");
            }
        }
        else if (structure.type == "OB")
        {
            if (ESD_ShowOb)
            {
                ESD_DrawOrderBlock("ESD_HistoricalOB_" + IntegerToString(i), structure.top, structure.bottom,
                                   structure.is_bullish ? ESD_BullishColor : ESD_BearishColor,
                                   ESD_ObLineStyle, ESD_ObStyle);
            }
        }
        else if (structure.type == "FVG")
        {
            if (ESD_ShowFvg)
            {
                ESD_DrawFVG("ESD_HistoricalFVG_" + IntegerToString(i), structure.top, structure.bottom,
                            structure.time, structure.is_bullish ? ESD_BullishColor : ESD_BearishColor);
            }
        }
        else if (structure.type == "MSS")
        {
            if (ESD_ShowLabels)
            {
                ESD_DrawLabel("ESD_HistoricalMSS_" + IntegerToString(i), structure.time, structure.price,
                              "MSS", structure.is_bullish ? ESD_BullishColor : ESD_BearishColor, true);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Fungsi Mencari Index Pivot High                                   |
//+------------------------------------------------------------------+
// PERBAIKAN: Enhanced pivot detection dengan volume dan momentum
int ESD_FindPivotHighIndex(const double &high_buffer[], int lookback)
{
    int bars_to_copy = lookback * 2 + 10;
    double low_buffer[], close_buffer[];
    long volume_buffer[];
    ArraySetAsSeries(high_buffer, true);
    ArraySetAsSeries(low_buffer, true);
    ArraySetAsSeries(close_buffer, true);
    ArraySetAsSeries(volume_buffer, true);

    CopyLow(_Symbol, ESD_HigherTimeframe, 0, bars_to_copy, low_buffer);
    CopyClose(_Symbol, ESD_HigherTimeframe, 0, bars_to_copy, close_buffer);
    CopyTickVolume(_Symbol, ESD_HigherTimeframe, 0, bars_to_copy, volume_buffer);

    for (int i = lookback; i < ArraySize(high_buffer) - lookback; i++)
    {
        bool is_pivot = true;

        // 1. Price Structure Check (Existing)
        for (int j = i - lookback; j <= i + lookback; j++)
        {
            if (j == i)
                continue;
            if (high_buffer[j] > high_buffer[i])
            {
                is_pivot = false;
                break;
            }
        }

        if (is_pivot)
        {
            // 2. ENHANCEMENT: Volume Confirmation
            double avg_volume = 0;
            int volume_lookback = MathMin(5, i);
            int valid_count = 0; // Count valid volume readings

            for (int k = 1; k <= volume_lookback; k++)
            {
                int index = i - k;
                // Check if index is valid
                if (index >= 0 && index < ArraySize(volume_buffer))
                {
                    avg_volume += (double)volume_buffer[index];
                    valid_count++;
                }
            }

            // Check if we have enough valid data points
            if (valid_count == 0)
                return -1;
            avg_volume /= valid_count;

            // Check if current volume index is valid
            if (i >= ArraySize(volume_buffer))
                return -1;
            bool volume_ok = (volume_buffer[i] > avg_volume * 1.3);

            // 3. ENHANCEMENT: Momentum Strength
            // Check if current and previous candle indices are valid
            if (i >= ArraySize(high_buffer) || i >= ArraySize(low_buffer) ||
                (i - 1) < 0 || (i - 1) >= ArraySize(high_buffer) || (i - 1) >= ArraySize(low_buffer))
                return -1;

            double candle_range = high_buffer[i] - low_buffer[i];
            double prev_range = high_buffer[i - 1] - low_buffer[i - 1];
            bool momentum_ok = (candle_range > prev_range * 0.7);

            // 4. ENHANCEMENT: Close Position
            if (i >= ArraySize(close_buffer))
                return -1;
            double close_position = (close_buffer[i] - low_buffer[i]) / candle_range;
            bool close_ok = (close_position < 0.4);

            if (volume_ok && momentum_ok && close_ok)
                return i;
        }
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Fungsi Mencari Index Pivot Low                                    |
//+------------------------------------------------------------------+
int ESD_FindPivotLowIndex(const double &price_array[], int lookback)
{
    for (int i = lookback; i < ArraySize(price_array) - lookback; i++)
    {
        bool is_pivot = true;
        for (int j = i - lookback; j <= i + lookback; j++)
        {
            if (price_array[j] < price_array[i])
            {
                is_pivot = false;
                break;
            }
        }
        if (is_pivot)
            return i;
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Fungsi Logika Entry (dengan Partial TP)                         |
//+------------------------------------------------------------------+
void ESD_CheckForEntry()
{
    // Jika sudah ada posisi, tidak usah entry lagi
    // if (PositionSelect(_Symbol))
    //     return;

    // 🎯 PRIORITAS 1: ENTRY BERDASARKAN INDUCEMENT (False Breakout)
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

        // 🚫 BSL/SSL AVOIDANCE CHECK
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

            // Heatmap + Order Flow confirmation filter
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
                    // Perhitungan normal tanpa Partial TP
                    switch (ESD_SlTpMethod)
                    {
                    case ESD_FIXED_POINTS:
                        sl = zone_bottom - ESD_StopLossPoints * point;
                        tp = ask + ESD_TakeProfitPoints * point;
                        break;

                    case ESD_SWING_POINTS:
                        if (ESD_last_significant_pl > 0)
                            sl = ESD_last_significant_pl - ESD_SlBufferPoints * point;
                        else
                            sl = zone_bottom - ESD_SlBufferPoints * point;

                        if (ESD_last_significant_ph > 0)
                            tp = ESD_last_significant_ph;
                        else
                            tp = ask + ESD_TakeProfitPoints * point;
                        break;

                    case ESD_LIQUIDITY_LEVELS:
                        sl = zone_bottom - ESD_SlBufferPoints * point;
                        if (ESD_bearish_liquidity > 0)
                            tp = ESD_bearish_liquidity;
                        else
                            tp = ask + ESD_TakeProfitPoints * point;
                        break;

                    case ESD_RISK_REWARD_RATIO:
                        sl = zone_bottom - ESD_SlBufferPoints * point;

                        if (risk > 0)
                            tp = ask + (risk * ESD_RiskRewardRatio);
                        else
                            tp = ask + ESD_TakeProfitPoints * point;
                        break;

                    case ESD_STRUCTURE_BASED:
                        if (zone_type == "FVG" && ESD_bullish_fvg_bottom != EMPTY_VALUE)
                            sl = ESD_bullish_fvg_bottom - ESD_SlBufferPoints * point;
                        else if (zone_type == "CHOCH" || zone_type == "BoS")
                            sl = trigger_price - ESD_SlBufferPoints * point;
                        else
                            sl = zone_bottom - ESD_SlBufferPoints * point;

                        if (ESD_last_significant_ph > 0 && ESD_last_significant_ph > ask)
                            tp = ESD_last_significant_ph;
                        else
                        {
                            double risk = ask - sl;
                            if (risk > 0)
                                tp = ask + (risk * ESD_RiskRewardRatio);
                            else
                                tp = ask + ESD_TakeProfitPoints * point;
                        }
                        break;
                    }
                }

                // Validasi SL/TP agar tidak salah
                if (sl >= ask)
                    sl = ask - 100 * point;
                if (tp <= ask)
                    tp = ask + 100 * point;
                if (sl <= 0 || tp <= 0)
                    return;

                string comment = StringFormat("SMC Buy (%s) Q=%.2f", zone_type, zone_quality);
                double adjusted_lot = ESD_GetRegimeAdjustedLotSize();

                // GUNAKAN FUNGSI BARU DENGAN PARTIAL TP
                ESD_ExecuteTradeWithPartialTP(true, ask, sl, comment);
                return;
            }
        }
    }

    // ================== LOGIKA ENTRY SELL ==================
    if (ESD_bearish_trend_confirmed && ESD_bearish_trend_strength >= ESD_TrendStrengthThreshold)
    {
        // REGIME FILTER untuk SELL
        if (!ESD_RegimeFilter(false))
            return;

        // 🚫 BSL/SSL AVOIDANCE CHECK
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
            return;
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

        // 3. Cek apakah FVG baru saja terisi (harga menembus FVG dari atas)
        bool fvg_just_filled = false;
        if (ESD_bearish_fvg_top != EMPTY_VALUE && !is_in_sell_zone)
        {
            if (bid < ESD_bearish_fvg_bottom && rates[1].close > ESD_bearish_fvg_top)
            {
                fvg_just_filled = true;
                zone_top = ESD_bearish_fvg_top;
                zone_bottom = ESD_bearish_fvg_bottom;
                zone_type = "FVG_FILLED";
                is_retesting_zone = true;
                zone_quality = ESD_GetZoneQuality("FVG", iTime(_Symbol, ESD_HigherTimeframe, 0), false);
            }
        }

        // Quality filter check
        if (ESD_EnableQualityFilter && zone_quality < ESD_MinZoneQualityScore)
        {
            is_in_sell_zone = false;
            fvg_just_filled = false;
        }

        // Jika harga berada di zona atau FVG baru saja terisi, lanjut ke pengecekan berikutnya
        if (is_in_sell_zone || fvg_just_filled)
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

            // Heatmap confirmation filter
            if (!ESD_HeatmapFilter(false))
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

                // Jika menggunakan Partial TP, hitung TP level 3
                if (ESD_UsePartialTP)
                {
                    tp = bid - ESD_PartialTPDistance3 * point;

                    // SL dihitung sesuai metode yang dipilih
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
                        sl = zone_top + ESD_SlBufferPoints * point;
                        break;

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
                    // Perhitungan normal tanpa Partial TP
                    switch (ESD_SlTpMethod)
                    {
                    case ESD_FIXED_POINTS:
                        sl = zone_top + ESD_StopLossPoints * point;
                        tp = bid - ESD_TakeProfitPoints * point;
                        break;

                    case ESD_SWING_POINTS:
                        if (ESD_last_significant_ph > 0)
                            sl = ESD_last_significant_ph + ESD_SlBufferPoints * point;
                        else
                            sl = zone_top + ESD_SlBufferPoints * point;

                        if (ESD_last_significant_pl > 0)
                            tp = ESD_last_significant_pl;
                        else
                            tp = bid - ESD_TakeProfitPoints * point;
                        break;

                    case ESD_LIQUIDITY_LEVELS:
                        sl = zone_top + ESD_SlBufferPoints * point;
                        if (ESD_bullish_liquidity > 0)
                            tp = ESD_bullish_liquidity;
                        else
                            tp = bid - ESD_TakeProfitPoints * point;
                        break;

                    case ESD_RISK_REWARD_RATIO:
                        sl = zone_top + ESD_SlBufferPoints * point;

                        if (risk > 0)
                            tp = bid - (risk * ESD_RiskRewardRatio);
                        else
                            tp = bid - ESD_TakeProfitPoints * point;
                        break;

                    case ESD_STRUCTURE_BASED:
                        if (zone_type == "FVG" && ESD_bearish_fvg_top != EMPTY_VALUE)
                            sl = ESD_bearish_fvg_top + ESD_SlBufferPoints * point;
                        else if (zone_type == "CHOCH" || zone_type == "BoS")
                            sl = trigger_price + ESD_SlBufferPoints * point;
                        else
                            sl = zone_top + ESD_SlBufferPoints * point;

                        if (ESD_last_significant_pl > 0 && ESD_last_significant_pl < bid)
                            tp = ESD_last_significant_pl;
                        else
                        {
                            double risk = sl - bid;
                            if (risk > 0)
                                tp = bid - (risk * ESD_RiskRewardRatio);
                            else
                                tp = bid - ESD_TakeProfitPoints * point;
                        }
                        break;
                    }
                }

                // Validasi SL/TP agar tidak salah
                if (sl <= bid)
                    sl = bid + 100 * point;
                if (tp >= bid)
                    tp = bid - 100 * point;
                if (sl <= 0 || tp <= 0)
                    return;

                string comment = StringFormat("SMC Sell (%s) Q=%.2f", zone_type, zone_quality);
                double adjusted_lot = ESD_GetRegimeAdjustedLotSize();

                // GUNAKAN FUNGSI BARU DENGAN PARTIAL TP
                ESD_ExecuteTradeWithPartialTP(false, bid, sl, comment);
                return;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Get zone quality from historical structures                       |
//+------------------------------------------------------------------+
double ESD_GetZoneQuality(string zone_type, datetime time, bool is_bullish)
{
    int structures_count = ArraySize(ESD_smc_structures);
    for (int i = structures_count - 1; i >= 0; i--)
    {
        ESD_SMStructure structure = ESD_smc_structures[i];

        if (structure.type == zone_type &&
            structure.is_bullish == is_bullish &&
            structure.time == time)
        {
            return structure.quality_score;
        }
    }

    return 0.5; // Default quality if not found
}

//+------------------------------------------------------------------+
//| Check if candle is a rejection candle                            |
//+------------------------------------------------------------------+
bool ESD_IsRejectionCandle(MqlRates &candle, bool is_bullish)
{
    double body_size = MathAbs(candle.close - candle.open);
    double upper_wick = candle.high - MathMax(candle.open, candle.close);
    double lower_wick = MathMin(candle.open, candle.close) - candle.low;
    double total_range = candle.high - candle.low;

    if (total_range == 0)
        return false;

    double body_ratio = body_size / total_range;
    double upper_wick_ratio = upper_wick / total_range;
    double lower_wick_ratio = lower_wick / total_range;

    if (is_bullish)
    {
        // Bullish rejection candle: long lower wick, small body
        return (lower_wick_ratio > 0.6 && body_ratio < 0.3);
    }
    else
    {
        // Bearish rejection candle: long upper wick, small body
        return (upper_wick_ratio > 0.6 && body_ratio < 0.3);
    }
}

//+------------------------------------------------------------------+
//| Check if liquidity has been sweeped                              |
//+------------------------------------------------------------------+
bool ESD_IsLiquiditySweeped(double liquidity_level, bool is_bullish)
{
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    CopyRates(_Symbol, ESD_HigherTimeframe, 0, 5, rates);

    if (ArraySize(rates) < 5)
        return false;

    if (is_bullish)
    {
        // Check if price swept below bullish liquidity and came back up
        for (int i = 1; i < 5; i++)
        {
            if (rates[i].low < liquidity_level && rates[0].close > liquidity_level)
                return true;
        }
    }
    else
    {
        // Check if price swept above bearish liquidity and came back down
        for (int i = 1; i < 5; i++)
        {
            if (rates[i].high > liquidity_level && rates[0].close < liquidity_level)
                return true;
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Check if FVG has been mitigated                                  |
//+------------------------------------------------------------------+
bool ESD_IsFVGMitigated(double fvg_top, double fvg_bottom, bool is_bullish)
{
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    CopyRates(_Symbol, ESD_HigherTimeframe, 0, 10, rates);

    if (ArraySize(rates) < 10)
        return false;

    if (is_bullish)
    {
        // Check if bullish FVG has been mitigated (price touched the top)
        for (int i = 1; i < 10; i++)
        {
            if (rates[i].high >= fvg_top)
                return true;
        }
    }
    else
    {
        // Check if bearish FVG has been mitigated (price touched the bottom)
        for (int i = 1; i < 10; i++)
        {
            if (rates[i].low <= fvg_bottom)
                return true;
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Fungsi Menggambar Objek                                           |
//+------------------------------------------------------------------+
void ESD_DrawBreakStructure(datetime time, double price, bool is_bullish, color clr, ENUM_LINE_STYLE line_style, string style_text, string structure_type)
{
    // Delete all old break structures of the same type
    ESD_DeleteObjectsByPrefix("ESD_BreakStructure_" + structure_type);

    string name = "ESD_BreakStructure_" + structure_type + "_" + IntegerToString(time);
    if (ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_TREND, 0, time, price, time + PeriodSeconds(ESD_HigherTimeframe) * 10, price);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_STYLE, line_style);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
        ObjectSetString(0, name, OBJPROP_TOOLTIP, "\n" + style_text + "\n");
    }
}

void ESD_DrawSwingPoint(datetime time, double price, string text, color clr)
{
    // Delete all old swing points of the same type
    ESD_DeleteObjectsByPrefix("ESD_" + text);

    string name = "ESD_" + text + "_" + IntegerToString(time);
    if (ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_ARROW, 0, time, price);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_ARROWCODE, (text == "PH") ? 234 : 233); // Down arrow for PH, Up for PL
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
        if (ESD_ShowLabels)
        {
            ESD_DrawLabel(name + "_Label", time, price, text, clr, false);
        }
    }
}

void ESD_DrawOrderBlock(string name, double top, double bottom, color clr, ENUM_LINE_STYLE line_style, string style_text)
{
    if (top == EMPTY_VALUE || bottom == EMPTY_VALUE)
    {
        ObjectDelete(0, name);
        ObjectDelete(0, name + "_Top");
        ObjectDelete(0, name + "_Bottom");
        return;
    }

    // Delete all old order blocks of the same type
    if (StringFind(name, "BullishOB") >= 0)
        ESD_DeleteObjectsByPrefix("ESD_BullishOB");
    else if (StringFind(name, "BearishOB") >= 0)
        ESD_DeleteObjectsByPrefix("ESD_BearishOB");

    datetime time1 = iTime(_Symbol, ESD_HigherTimeframe, 0);
    datetime time2 = time1 + PeriodSeconds(ESD_HigherTimeframe) * 20;

    // Draw top line
    string top_name = name + "_Top";
    if (ObjectFind(0, top_name) < 0)
    {
        ObjectCreate(0, top_name, OBJ_TREND, 0, time1, top, time2, top);
        ObjectSetInteger(0, top_name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, top_name, OBJPROP_STYLE, line_style);
        ObjectSetInteger(0, top_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, top_name, OBJPROP_RAY_RIGHT, true);
        ObjectSetString(0, top_name, OBJPROP_TOOLTIP, "\n" + style_text + " Top\n");
    }
    else
    {
        ObjectSetInteger(0, top_name, OBJPROP_TIME, 0, time1);
        ObjectSetDouble(0, top_name, OBJPROP_PRICE, 0, top);
        ObjectSetInteger(0, top_name, OBJPROP_TIME, 1, time2);
        ObjectSetDouble(0, top_name, OBJPROP_PRICE, 1, top);
    }

    // Draw bottom line
    string bottom_name = name + "_Bottom";
    if (ObjectFind(0, bottom_name) < 0)
    {
        ObjectCreate(0, bottom_name, OBJ_TREND, 0, time1, bottom, time2, bottom);
        ObjectSetInteger(0, bottom_name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, bottom_name, OBJPROP_STYLE, line_style);
        ObjectSetInteger(0, bottom_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, bottom_name, OBJPROP_RAY_RIGHT, true);
        ObjectSetString(0, bottom_name, OBJPROP_TOOLTIP, "\n" + style_text + " Bottom\n");
    }
    else
    {
        ObjectSetInteger(0, bottom_name, OBJPROP_TIME, 0, time1);
        ObjectSetDouble(0, bottom_name, OBJPROP_PRICE, 0, bottom);
        ObjectSetInteger(0, bottom_name, OBJPROP_TIME, 1, time2);
        ObjectSetDouble(0, bottom_name, OBJPROP_PRICE, 1, bottom);
    }
}

void ESD_DrawFVG(string name, double top, double bottom, datetime creation_time, color clr)
{
    if (iTime(_Symbol, ESD_HigherTimeframe, 0) > creation_time + PeriodSeconds(ESD_HigherTimeframe) * ESD_FvgDisplayLength)
    {
        ObjectDelete(0, name);
        ObjectDelete(0, name + "_Top");
        ObjectDelete(0, name + "_Bottom");
        if (name == "ESD_BullishFVG")
        {
            ESD_bullish_fvg_top = EMPTY_VALUE;
            ESD_bullish_fvg_bottom = EMPTY_VALUE;
        }
        if (name == "ESD_BearishFVG")
        {
            ESD_bearish_fvg_top = EMPTY_VALUE;
            ESD_bearish_fvg_bottom = EMPTY_VALUE;
        }
        return;
    }

    // Delete all old FVGs of the same type
    if (StringFind(name, "BullishFVG") >= 0)
        ESD_DeleteObjectsByPrefix("ESD_BullishFVG");
    else if (StringFind(name, "BearishFVG") >= 0)
        ESD_DeleteObjectsByPrefix("ESD_BearishFVG");

    datetime time1 = creation_time;
    datetime time2 = creation_time + PeriodSeconds(ESD_HigherTimeframe) * ESD_FvgDisplayLength;

    // Draw top line
    string top_name = name + "_Top";
    if (ObjectFind(0, top_name) < 0)
    {
        ObjectCreate(0, top_name, OBJ_TREND, 0, time1, top, time2, top);
        ObjectSetInteger(0, top_name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, top_name, OBJPROP_STYLE, STYLE_DASH);
        ObjectSetInteger(0, top_name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, top_name, OBJPROP_RAY_RIGHT, false);
        ObjectSetString(0, top_name, OBJPROP_TOOLTIP, "\nFVG Top\n");
    }
    else
    {
        ObjectSetInteger(0, top_name, OBJPROP_TIME, 0, time1);
        ObjectSetDouble(0, top_name, OBJPROP_PRICE, 0, top);
        ObjectSetInteger(0, top_name, OBJPROP_TIME, 1, time2);
        ObjectSetDouble(0, top_name, OBJPROP_PRICE, 1, top);
    }

    // Draw bottom line
    string bottom_name = name + "_Bottom";
    if (ObjectFind(0, bottom_name) < 0)
    {
        ObjectCreate(0, bottom_name, OBJ_TREND, 0, time1, bottom, time2, bottom);
        ObjectSetInteger(0, bottom_name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, bottom_name, OBJPROP_STYLE, STYLE_DASH);
        ObjectSetInteger(0, bottom_name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, bottom_name, OBJPROP_RAY_RIGHT, false);
        ObjectSetString(0, bottom_name, OBJPROP_TOOLTIP, "\nFVG Bottom\n");
    }
    else
    {
        ObjectSetInteger(0, bottom_name, OBJPROP_TIME, 0, time1);
        ObjectSetDouble(0, bottom_name, OBJPROP_PRICE, 0, bottom);
        ObjectSetInteger(0, bottom_name, OBJPROP_TIME, 1, time2);
        ObjectSetDouble(0, bottom_name, OBJPROP_PRICE, 1, bottom);
    }
}

void ESD_DeleteObjects()
{
    for (int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i, -1, -1);
        if (StringFind(name, "ESD_", 0) == 0)
            ObjectDelete(0, name);
    }
}

//+------------------------------------------------------------------+
//| Delete objects by prefix                                          |
//+------------------------------------------------------------------+
void ESD_DeleteObjectsByPrefix(string prefix)
{
    for (int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i, -1, -1);
        if (StringFind(name, prefix, 0) == 0)
            ObjectDelete(0, name);
    }
}

//+------------------------------------------------------------------+
//| Fungsi Menggambar Label Teks                                      |
//+------------------------------------------------------------------+
void ESD_DrawLabel(string name, datetime time, double price, string text, color clr, bool highlight = false)
{
    // Delete old label with the same name
    if (ObjectFind(0, name) >= 0)
        ObjectDelete(0, name);

    // Delete old shadow label
    string shadow_name = name + "_Shadow";
    if (ObjectFind(0, shadow_name) >= 0)
        ObjectDelete(0, shadow_name);

    // Delete old highlight
    string highlight_name = name + "_Highlight";
    if (ObjectFind(0, highlight_name) >= 0)
        ObjectDelete(0, highlight_name);

    ObjectCreate(0, name, OBJ_TEXT, 0, time, price);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrGold); // Changed to gold color
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, ESD_LabelFontSize);
    ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold"); // Changed to bold font
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);

    ObjectCreate(0, shadow_name, OBJ_TEXT, 0, time, price);
    ObjectSetString(0, shadow_name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, shadow_name, OBJPROP_COLOR, clrBlack);
    ObjectSetInteger(0, shadow_name, OBJPROP_FONTSIZE, ESD_LabelFontSize);
    ObjectSetString(0, shadow_name, OBJPROP_FONT, "Arial Bold"); // Changed to bold font
    ObjectSetInteger(0, shadow_name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    ObjectSetInteger(0, shadow_name, OBJPROP_BACK, true);

    if (highlight)
    {
        ObjectCreate(0, highlight_name, OBJ_RECTANGLE, 0, time, price, time + PeriodSeconds(ESD_HigherTimeframe) * 5, price + 20 * SymbolInfoDouble(_Symbol, SYMBOL_POINT));
        ObjectSetInteger(0, highlight_name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, highlight_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, highlight_name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, highlight_name, OBJPROP_BACK, true);
        ObjectSetInteger(0, highlight_name, OBJPROP_FILL, true);
        ObjectSetInteger(0, highlight_name, OBJPROP_BGCOLOR, ColorToARGB(clr, 40));
    }
}

//+------------------------------------------------------------------+
//| Fungsi Menggambar Liquidity Line                                 |
//+------------------------------------------------------------------+
void ESD_DrawLiquidityLine(string name, double price, color clr)
{
    // Delete all old liquidity lines of the same type
    if (StringFind(name, "BullishLiquidity") >= 0)
        ESD_DeleteObjectsByPrefix("ESD_BullishLiquidity");
    else if (StringFind(name, "BearishLiquidity") >= 0)
        ESD_DeleteObjectsByPrefix("ESD_BearishLiquidity");

    datetime time1 = iTime(_Symbol, ESD_HigherTimeframe, 20);
    datetime time2 = iTime(_Symbol, ESD_HigherTimeframe, 0) + PeriodSeconds(ESD_HigherTimeframe) * 10;

    string gradient_name = name + "_Gradient";
    if (ObjectFind(0, gradient_name) < 0)
    {
        for (int i = 0; i < 3; i++)
        {
            string line_name = gradient_name + "_" + IntegerToString(i);
            int opacity = ESD_TransparencyLevel - (i * 25); // Increased transparency
            if (opacity < 10)
                opacity = 10;

            ObjectCreate(0, line_name, OBJ_TREND, 0, time1, price, time2, price);
            ObjectSetInteger(0, line_name, OBJPROP_COLOR, ColorToARGB(clr, (uchar)opacity));
            ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DASHDOT);
            ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 5 - i);
            ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, true);
            ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
        }

        ObjectCreate(0, name, OBJ_TREND, 0, time1, price, time2, price);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASHDOT);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
    }
    else
    {
        for (int i = 0; i < 3; i++)
        {
            string line_name = gradient_name + "_" + IntegerToString(i);
            ObjectSetInteger(0, line_name, OBJPROP_TIME, 0, time1);
            ObjectSetDouble(0, line_name, OBJPROP_PRICE, 0, price);
            ObjectSetInteger(0, line_name, OBJPROP_TIME, 1, time2);
            ObjectSetDouble(0, line_name, OBJPROP_PRICE, 1, price);
        }

        ObjectSetInteger(0, name, OBJPROP_TIME, 0, time1);
        ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
        ObjectSetInteger(0, name, OBJPROP_TIME, 1, time2);
        ObjectSetDouble(0, name, OBJPROP_PRICE, 1, price);
    }
}
//+------------------------------------------------------------------+

// TAMBAH filter momentum
// Ganti dengan trend detection yang lebih robust
bool ESD_IsValidMomentum(bool is_bullish)
{
    double ema20[], ema50[];
    ArraySetAsSeries(ema20, true);
    ArraySetAsSeries(ema50, true);

    int ema20_handle = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_EMA, PRICE_CLOSE);
    int ema50_handle = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_EMA, PRICE_CLOSE);

    CopyBuffer(ema20_handle, 0, 0, 3, ema20);
    CopyBuffer(ema50_handle, 0, 0, 3, ema50);

    if (is_bullish)
    {
        // EMA 20 > EMA 50 dan trending up
        return (ema20[0] > ema50[0]) && (ema20[0] > ema20[1]) && (ema50[0] > ema50[1]);
    }
    else
    {
        // EMA 20 < EMA 50 dan trending down
        return (ema20[0] < ema50[0]) && (ema20[0] < ema20[1]) && (ema50[0] < ema50[1]);
    }
}

//+------------------------------------------------------------------+
//| Heatmap Analysis Function                                        |
//+------------------------------------------------------------------+
void ESD_AnalyzeHeatmap()
{
    // Simulate heatmap analysis based on multi-timeframe momentum
    // In real implementation, this would connect to actual heatmap data

    double momentum_score = 0.0;
    int confirming_bars = 0;

    // Analyze multiple timeframes for heatmap-like strength assessment
    ENUM_TIMEFRAMES tf_list[4] = {PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4};
    double timeframe_weights[4] = {0.2, 0.3, 0.3, 0.2}; // Weights for each TF

    for (int i = 0; i < 4; i++)
    {
        double tf_strength = ESD_CalculateTimeframeStrength(tf_list[i]);
        momentum_score += tf_strength * timeframe_weights[i];
    }

    // Convert to heatmap strength (-100 to +100)
    ESD_heatmap_strength = momentum_score * 100;

    // Determine bias
    ESD_heatmap_bullish = (ESD_heatmap_strength > ESD_HeatmapStrengthThreshold);
    ESD_heatmap_bearish = (ESD_heatmap_strength < -ESD_HeatmapStrengthThreshold);

    ESD_last_heatmap_update = TimeCurrent();

    // Visual feedback
    if (ESD_ShowObjects && ESD_ShowLabels)
    {
        string heatmap_text = StringFormat("HEATMAP: %.1f", ESD_heatmap_strength);
        color heatmap_color = ESD_NeutralColor;

        if (ESD_heatmap_strength > ESD_HeatmapStrengthThreshold)
            heatmap_color = ESD_StrongBullishColor;
        else if (ESD_heatmap_strength > 20)
            heatmap_color = ESD_WeakBullishColor;
        else if (ESD_heatmap_strength < -ESD_HeatmapStrengthThreshold)
            heatmap_color = ESD_StrongBearishColor;
        else if (ESD_heatmap_strength < -20)
            heatmap_color = ESD_WeakBearishColor;

        ESD_DrawLabel("ESD_Heatmap_Status", iTime(_Symbol, PERIOD_CURRENT, 0),
                      iHigh(_Symbol, PERIOD_CURRENT, 0) + 100 * _Point,
                      heatmap_text, heatmap_color, true);
    }
}

//+------------------------------------------------------------------+
//| Calculate Timeframe Strength                                     |
//+------------------------------------------------------------------+
double ESD_CalculateTimeframeStrength(ENUM_TIMEFRAMES tf)
{
    int bars = 10;
    double close_buffer[];
    ArraySetAsSeries(close_buffer, true);

    if (CopyClose(_Symbol, tf, 0, bars, close_buffer) < bars)
        return 0.0;

    double strength = 0.0;
    int bullish_count = 0;

    // Calculate momentum strength
    for (int i = 0; i < bars - 1; i++)
    {
        if (close_buffer[i] > close_buffer[i + 1])
            bullish_count++;
    }

    double bullish_ratio = (double)bullish_count / (bars - 1);
    strength = (bullish_ratio - 0.5) * 2; // Convert to -1 to +1 range

    return strength;
}

//+------------------------------------------------------------------+
//| Heatmap Entry Filter                                             |
//+------------------------------------------------------------------+
bool ESD_HeatmapFilter(bool proposed_buy_signal)
{
    if (!ESD_UseHeatmapFilter)
        return true;

    // If heatmap strongly disagrees, filter the signal
    if (proposed_buy_signal && ESD_heatmap_bearish &&
        MathAbs(ESD_heatmap_strength) > ESD_HeatmapStrengthThreshold * 1.5)
    {
        return false; // Reject buy when heatmap strongly bearish
    }

    if (!proposed_buy_signal && ESD_heatmap_bullish &&
        MathAbs(ESD_heatmap_strength) > ESD_HeatmapStrengthThreshold * 1.5)
    {
        return false; // Reject sell when heatmap strongly bullish
    }

    // If heatmap strongly agrees, allow earlier entries
    if (proposed_buy_signal && ESD_heatmap_bullish &&
        ESD_heatmap_strength > ESD_HeatmapStrengthThreshold * 1.2)
    {
        return true; // Strengthen buy signal
    }

    if (!proposed_buy_signal && ESD_heatmap_bearish &&
        ESD_heatmap_strength < -ESD_HeatmapStrengthThreshold * 1.2)
    {
        return true; // Strengthen sell signal
    }

    return true; // Default allow
}

//+------------------------------------------------------------------+
//| Order Flow Analysis Function                                     |
//+------------------------------------------------------------------+
void ESD_AnalyzeOrderFlow()
{
    if (!ESD_UseOrderFlow)
        return;

    double total_volume = 0.0;
    double bid_volume = 0.0;
    double ask_volume = 0.0;
    double volume_imbalance_sum = 0.0;

    // Analyze recent candles for order flow
    MqlRates rates[];
    long tick_volume[];
    ArraySetAsSeries(rates, true);
    ArraySetAsSeries(tick_volume, true);

    int bars = 20; // Analyze last 20 candles
    if (CopyRates(_Symbol, PERIOD_CURRENT, 0, bars, rates) == bars &&
        CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, bars, tick_volume) == bars)
    {
        // Calculate delta and volume analysis
        for (int i = 0; i < bars; i++)
        {
            double candle_size = rates[i].high - rates[i].low;
            if (candle_size == 0)
                continue;

            // Simple delta calculation based on price action
            double buy_pressure = (rates[i].close - rates[i].low) / candle_size;
            double sell_pressure = (rates[i].high - rates[i].close) / candle_size;

            double candle_delta = (buy_pressure - sell_pressure) * tick_volume[i];
            ESD_cumulative_delta += candle_delta;

            // Volume classification (simplified)
            if (rates[i].close > rates[i].open)
                bid_volume += tick_volume[i] * buy_pressure;
            else
                ask_volume += tick_volume[i] * sell_pressure;

            total_volume += (double)tick_volume[i];
        }

        // Calculate order flow strength
        if (total_volume > 0)
        {
            ESD_delta_value = ESD_cumulative_delta / total_volume;
            ESD_volume_imbalance = (bid_volume - ask_volume) / total_volume;

            // Detect absorption
            ESD_absorption_detected = ESD_DetectAbsorption(rates, tick_volume, bars);

            // Detect imbalances
            ESD_imbalance_detected = ESD_DetectImbalance(rates, tick_volume, bars);

            // Calculate overall order flow strength
            ESD_orderflow_strength = (ESD_delta_value * 0.4 + ESD_volume_imbalance * 0.4 +
                                      (ESD_absorption_detected ? -0.2 : 0.0)) *
                                     100;
        }

        ESD_last_orderflow_update = TimeCurrent();
    }

    // Visual feedback
    if (ESD_ShowObjects && ESD_ShowLabels)
    {
        ESD_DrawOrderFlowIndicators();
    }
}

//+------------------------------------------------------------------+
//| Detect Absorption Patterns                                       |
//+------------------------------------------------------------------+
bool ESD_DetectAbsorption(const MqlRates &rates[], const long &volume[], int bars)
{
    // Detect absorption patterns (large volume without significant price movement)
    for (int i = 1; i < bars - 1; i++)
    {
        double price_change = MathAbs(rates[i].close - rates[i - 1].close) / rates[i - 1].close;
        double volume_ratio = (double)volume[i] / volume[i - 1];

        // High volume with small price change suggests absorption
        if (volume_ratio > 2.0 && price_change < 0.001) // 0.1% price change
        {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Detect Order Flow Imbalance                                      |
//+------------------------------------------------------------------+
bool ESD_DetectImbalance(const MqlRates &rates[], const long &volume[], int bars)
{
    // Detect significant order flow imbalances
    int imbalance_count = 0;

    for (int i = 0; i < bars; i++)
    {
        double body_size = MathAbs(rates[i].close - rates[i].open);
        double total_range = rates[i].high - rates[i].low;

        if (total_range > 0)
        {
            double body_ratio = body_size / total_range;

            // Strong directional move with high volume indicates imbalance
            if (body_ratio > 0.7 && volume[i] > ESD_VolumeThreshold)
            {
                imbalance_count++;
            }
        }
    }

    return (imbalance_count >= 3); // Multiple imbalances detected
}

//+------------------------------------------------------------------+
//| Order Flow Entry Filter                                          |
//+------------------------------------------------------------------+
bool ESD_OrderFlowFilter(bool proposed_buy_signal)
{
    if (!ESD_UseOrderFlow)
        return true;

    double of_strength = MathAbs(ESD_orderflow_strength);

    // Strong order flow filter
    if (of_strength > 60) // Very strong order flow
    {
        if (proposed_buy_signal && ESD_orderflow_strength < -50)
            return false; // Reject buy on strong selling pressure

        if (!proposed_buy_signal && ESD_orderflow_strength > 50)
            return false; // Reject sell on strong buying pressure
    }

    // Absorption filter
    if (ESD_UseAbsorptionDetection && ESD_absorption_detected)
    {
        // Be cautious when absorption is detected
        if (of_strength < 30)
            return false;
    }

    // Delta confirmation
    if (ESD_UseDeltaAnalysis)
    {
        if (proposed_buy_signal && ESD_delta_value < -ESD_DeltaThreshold)
            return false; // Reject buy on negative delta

        if (!proposed_buy_signal && ESD_delta_value > ESD_DeltaThreshold)
            return false; // Reject sell on positive delta
    }

    return true;
}

//+------------------------------------------------------------------+
//| Draw Order Flow Indicators                                       |
//+------------------------------------------------------------------+
void ESD_DrawOrderFlowIndicators()
{
    string of_text = StringFormat("OF: %.1f D: %.2f VI: %.2f",
                                  ESD_orderflow_strength, ESD_delta_value, ESD_volume_imbalance);

    color of_color = ESD_NeutralColor;
    if (ESD_orderflow_strength > 30)
        of_color = ESD_BidVolumeColor;
    else if (ESD_orderflow_strength < -30)
        of_color = ESD_AskVolumeColor;

    // Absorption indicator
    if (ESD_absorption_detected)
    {
        of_text += " ABS";
        of_color = ESD_HighVolumeColor;
    }

    // Imbalance indicator
    if (ESD_imbalance_detected)
    {
        of_text += " IMB";
        of_color = clrOrange;
    }

    ESD_DrawLabel("ESD_OrderFlow_Status", iTime(_Symbol, PERIOD_CURRENT, 0),
                  iHigh(_Symbol, PERIOD_CURRENT, 0) + 200 * _Point,
                  of_text, of_color, true);
}

//+------------------------------------------------------------------+
//| Enhanced Filter Monitoring Settings                             |
//+------------------------------------------------------------------+
input bool ESD_ShowFilterMonitor = true;                      // Show detailed filter monitoring
input ENUM_BASE_CORNER ESD_FilterCorner = CORNER_RIGHT_LOWER; // Filter panel corner
input int ESD_FilterX = 5;                                    // Filter panel X position
input int ESD_FilterY = 20;                                   // Filter panel Y position
input color ESD_FilterPassColor = clrLime;                    // Color for passed filters
input color ESD_FilterFailColor = clrRed;                     // Color for failed filters
input color ESD_FilterWarningColor = clrOrange;               // Color for warning filters

//+------------------------------------------------------------------+
//| Trading Data Monitoring Settings                                |
//+------------------------------------------------------------------+
input bool ESD_ShowTradingData = true;                     // Show trading performance data
input ENUM_BASE_CORNER ESD_DataCorner = CORNER_LEFT_UPPER; // Data panel corner
input int ESD_DataX = 5;                                   // Data panel X position
input int ESD_DataY = 10;                                  // Data panel Y position

//+------------------------------------------------------------------+
//| Filter Status Variables                                         |
//+------------------------------------------------------------------+
struct ESD_FilterStatus
{
    string name;
    bool enabled;
    bool passed;
    double strength;
    string details;
    datetime last_update;
};

ESD_FilterStatus ESD_filter_status[];

//+------------------------------------------------------------------+
//| Trading Performance Variables                                   |
//+------------------------------------------------------------------+
struct ESD_TradeData
{
    int total_trades;
    int winning_trades;
    int losing_trades;
    double total_profit;
    double total_loss;
    double largest_win;
    double largest_loss;
    double current_streak;
    double best_streak;
    double win_rate;
    double profit_factor;
    double average_win;
    double average_loss;
    double expectancy;
    datetime last_trade_time;
    double daily_profit;
    double weekly_profit;
    double monthly_profit;
};

ESD_TradeData ESD_trade_data;
double ESD_daily_start_balance = 0;
double ESD_weekly_start_balance = 0;
double ESD_monthly_start_balance = 0;

//+------------------------------------------------------------------+
//| Initialize Filter Monitoring                                    |
//+------------------------------------------------------------------+
void ESD_InitializeFilterMonitoring()
{
    ArrayResize(ESD_filter_status, 15);

    // Trend Filters
    ESD_filter_status[0].name = "Trend Direction";
    ESD_filter_status[1].name = "Trend Strength";
    ESD_filter_status[2].name = "Market Structure";

    // Confirmation Filters
    ESD_filter_status[3].name = "Heatmap Filter";
    ESD_filter_status[4].name = "Order Flow Filter";
    ESD_filter_status[5].name = "Volume Confirmation";
    ESD_filter_status[6].name = "Momentum Filter";

    // Entry Filters
    ESD_filter_status[7].name = "Zone Quality";
    ESD_filter_status[8].name = "Retest Confirmation";
    ESD_filter_status[9].name = "Rejection Candle";
    ESD_filter_status[10].name = "Liquidity Sweep";
    ESD_filter_status[11].name = "FVG Mitigation";

    // Risk Filters
    ESD_filter_status[12].name = "Risk-Reward Check";
    ESD_filter_status[13].name = "Zone Distance";
    ESD_filter_status[14].name = "Aggressive Mode";
}

//+------------------------------------------------------------------+
//| Initialize Trading Data Monitoring                              |
//+------------------------------------------------------------------+
void ESD_InitializeTradingData()
{
    ESD_trade_data.total_trades = 0;
    ESD_trade_data.winning_trades = 0;
    ESD_trade_data.losing_trades = 0;
    ESD_trade_data.total_profit = 0;
    ESD_trade_data.total_loss = 0;
    ESD_trade_data.largest_win = 0;
    ESD_trade_data.largest_loss = 0;
    ESD_trade_data.current_streak = 0;
    ESD_trade_data.best_streak = 0;
    ESD_trade_data.win_rate = 0;
    ESD_trade_data.profit_factor = 0;
    ESD_trade_data.average_win = 0;
    ESD_trade_data.average_loss = 0;
    ESD_trade_data.expectancy = 0;
    ESD_trade_data.last_trade_time = 0;
    ESD_trade_data.daily_profit = 0;
    ESD_trade_data.weekly_profit = 0;
    ESD_trade_data.monthly_profit = 0;

    ESD_daily_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    ESD_weekly_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    ESD_monthly_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
}

//+------------------------------------------------------------------+
//| Update Filter Status Function                                   |
//+------------------------------------------------------------------+
void ESD_UpdateFilterStatus()
{
    // Trend Filters
    ESD_filter_status[0].enabled = true;
    ESD_filter_status[0].passed = ESD_bullish_trend_confirmed || ESD_bearish_trend_confirmed;
    ESD_filter_status[0].strength = MathMax(ESD_bullish_trend_strength, ESD_bearish_trend_strength);
    ESD_filter_status[0].details = ESD_bullish_trend_confirmed ? "BULLISH" : ESD_bearish_trend_confirmed ? "BEARISH"
                                                                                                         : "RANGING";

    ESD_filter_status[1].enabled = ESD_UseStrictTrendConfirmation;
    ESD_filter_status[1].passed = ESD_bullish_trend_strength >= ESD_TrendStrengthThreshold ||
                                  ESD_bearish_trend_strength >= ESD_TrendStrengthThreshold;
    ESD_filter_status[1].strength = MathMax(ESD_bullish_trend_strength, ESD_bearish_trend_strength);
    ESD_filter_status[1].details = StringFormat("Bull:%.1f%%, Bear:%.1f%%",
                                                ESD_bullish_trend_strength * 100,
                                                ESD_bearish_trend_strength * 100);

    ESD_filter_status[2].enabled = ESD_UseMarketStructureShift;
    ESD_filter_status[2].passed = ESD_bullish_mss_detected || ESD_bearish_mss_detected;
    ESD_filter_status[2].strength = 0.8;
    ESD_filter_status[2].details = StringFormat("MSS Bull:%s Bear:%s",
                                                ESD_bullish_mss_detected ? "YES" : "NO",
                                                ESD_bearish_mss_detected ? "YES" : "NO");

    // Confirmation Filters
    ESD_filter_status[3].enabled = ESD_UseHeatmapFilter;
    ESD_filter_status[3].passed = MathAbs(ESD_heatmap_strength) >= ESD_HeatmapStrengthThreshold;
    ESD_filter_status[3].strength = MathAbs(ESD_heatmap_strength) / 100.0;
    ESD_filter_status[3].details = StringFormat("Strength: %.1f", ESD_heatmap_strength);

    ESD_filter_status[4].enabled = ESD_UseOrderFlow;
    ESD_filter_status[4].passed = MathAbs(ESD_orderflow_strength) >= 30;
    ESD_filter_status[4].strength = MathAbs(ESD_orderflow_strength) / 100.0;
    ESD_filter_status[4].details = StringFormat("OF: %.1f, Delta: %.3f",
                                                ESD_orderflow_strength, ESD_delta_value);

    ESD_filter_status[5].enabled = ESD_UseVolumeConfirmation;
    ESD_filter_status[5].passed = ESD_volume_imbalance > ESD_DeltaThreshold;
    ESD_filter_status[5].strength = MathAbs(ESD_volume_imbalance);
    ESD_filter_status[5].details = StringFormat("Imbalance: %.3f", ESD_volume_imbalance);

    ESD_filter_status[6].enabled = true;
    ESD_filter_status[6].passed = ESD_IsValidMomentum(true) || ESD_IsValidMomentum(false);
    ESD_filter_status[6].strength = 0.7;
    ESD_filter_status[6].details = "Momentum OK";

    // Entry Filters
    ESD_filter_status[7].enabled = ESD_EnableQualityFilter;
    double current_quality = ESD_GetCurrentZoneQuality();
    ESD_filter_status[7].passed = current_quality >= ESD_MinZoneQualityScore;
    ESD_filter_status[7].strength = current_quality;
    ESD_filter_status[7].details = StringFormat("Quality: %.2f/%.2f",
                                                current_quality, ESD_MinZoneQualityScore);

    ESD_filter_status[8].enabled = true;
    bool retest_bull = ESD_HasRetestOccurred("FVG", ESD_bullish_fvg_bottom, true);
    bool retest_bear = ESD_HasRetestOccurred("FVG", ESD_bearish_fvg_top, false);
    ESD_filter_status[8].passed = retest_bull || retest_bear;
    ESD_filter_status[8].strength = 0.6;
    ESD_filter_status[8].details = StringFormat("Bull:%s Bear:%s",
                                                retest_bull ? "YES" : "NO",
                                                retest_bear ? "YES" : "NO");

    ESD_filter_status[9].enabled = ESD_UseRejectionCandleConfirmation;
    MqlRates current_candle[];
    CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, current_candle);
    bool rejection_bull = ESD_IsRejectionCandle(current_candle[0], true);
    bool rejection_bear = ESD_IsRejectionCandle(current_candle[0], false);
    ESD_filter_status[9].passed = rejection_bull || rejection_bear;
    ESD_filter_status[9].strength = 0.5;
    ESD_filter_status[9].details = StringFormat("Bull:%s Bear:%s",
                                                rejection_bull ? "YES" : "NO",
                                                rejection_bear ? "YES" : "NO");

    ESD_filter_status[10].enabled = ESD_EnableLiquiditySweepFilter;
    bool sweep_bull = ESD_IsLiquiditySweeped(ESD_bullish_liquidity, true);
    bool sweep_bear = ESD_IsLiquiditySweeped(ESD_bearish_liquidity, false);
    ESD_filter_status[10].passed = sweep_bull || sweep_bear;
    ESD_filter_status[10].strength = 0.7;
    ESD_filter_status[10].details = StringFormat("Bull:%s Bear:%s",
                                                 sweep_bull ? "YES" : "NO",
                                                 sweep_bear ? "YES" : "NO");

    ESD_filter_status[11].enabled = ESD_UseFvgMitigationFilter;
    bool fvg_bull = ESD_IsFVGMitigated(ESD_bullish_fvg_top, ESD_bullish_fvg_bottom, true);
    bool fvg_bear = ESD_IsFVGMitigated(ESD_bearish_fvg_top, ESD_bearish_fvg_bottom, false);
    ESD_filter_status[11].passed = fvg_bull || fvg_bear;
    ESD_filter_status[11].strength = 0.6;
    ESD_filter_status[11].details = StringFormat("Bull:%s Bear:%s",
                                                 fvg_bull ? "YES" : "NO",
                                                 fvg_bear ? "YES" : "NO");

    // Risk Filters
    ESD_filter_status[12].enabled = ESD_SlTpMethod == ESD_RISK_REWARD_RATIO;
    ESD_filter_status[12].passed = ESD_RiskRewardRatio >= 1.5;
    ESD_filter_status[12].strength = ESD_RiskRewardRatio / 3.0;
    ESD_filter_status[12].details = StringFormat("R/R: %.1f", ESD_RiskRewardRatio);

    ESD_filter_status[13].enabled = true;
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double distance_bull = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - ESD_bullish_fvg_bottom) / point;
    double distance_bear = (ESD_bearish_fvg_top - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / point;
    bool distance_ok = MathAbs(distance_bull) <= ESD_ZoneTolerancePoints ||
                       MathAbs(distance_bear) <= ESD_ZoneTolerancePoints;
    ESD_filter_status[13].passed = distance_ok;
    ESD_filter_status[13].strength = 1.0 - (MathMin(MathAbs(distance_bull), MathAbs(distance_bear)) / ESD_ZoneTolerancePoints);
    ESD_filter_status[13].details = StringFormat("Bull:%.0f Bear:%.0f", distance_bull, distance_bear);

    ESD_filter_status[14].enabled = ESD_AggressiveMode;
    ESD_filter_status[14].passed = ESD_AggressiveMode;
    ESD_filter_status[14].strength = 1.0;
    ESD_filter_status[14].details = ESD_AggressiveMode ? "ACTIVE" : "INACTIVE";

    // Add liquidity zone filter status
    int liquidity_index = -1;
    for (int i = 0; i < ArraySize(ESD_filter_status); i++)
    {
        if (ESD_filter_status[i].name == "Liquidity Zone")
        {
            liquidity_index = i;
            break;
        }
    }

    if (liquidity_index == -1)
    {
        int new_size = ArraySize(ESD_filter_status) + 1;
        ArrayResize(ESD_filter_status, new_size);
        liquidity_index = new_size - 1;
        ESD_filter_status[liquidity_index].name = "Liquidity Zone";
    }

    ESD_filter_status[liquidity_index].enabled = ESD_UseLiquidityZones;
    ESD_filter_status[liquidity_index].passed = (ESD_upper_liquidity_zone != EMPTY_VALUE ||
                                                 ESD_lower_liquidity_zone != EMPTY_VALUE);
    ESD_filter_status[liquidity_index].strength = 0.8;
    ESD_filter_status[liquidity_index].details = StringFormat("Upper: %.5f Lower: %.5f",
                                                              ESD_upper_liquidity_zone,
                                                              ESD_lower_liquidity_zone);
    ESD_filter_status[liquidity_index].last_update = TimeCurrent();

    // Tambahkan BSL/SSL status
    int bsl_ssl_index = -1;
    for (int i = 0; i < ArraySize(ESD_filter_status); i++)
    {
        if (ESD_filter_status[i].name == "BSL/SSL Avoidance")
        {
            bsl_ssl_index = i;
            break;
        }
    }

    if (bsl_ssl_index == -1)
    {
        int new_size = ArraySize(ESD_filter_status) + 1;
        ArrayResize(ESD_filter_status, new_size);
        bsl_ssl_index = new_size - 1;
        ESD_filter_status[bsl_ssl_index].name = "BSL/SSL Avoidance";
    }

    ESD_filter_status[bsl_ssl_index].enabled = ESD_AvoidBSL_SSL;
    ESD_filter_status[bsl_ssl_index].passed = (ESD_bsl_level != EMPTY_VALUE || ESD_ssl_level != EMPTY_VALUE);
    ESD_filter_status[bsl_ssl_index].strength = 0.8;
    ESD_filter_status[bsl_ssl_index].details = StringFormat("BSL: %.5f SSL: %.5f",
                                                            ESD_bsl_level, ESD_ssl_level);
    ESD_filter_status[bsl_ssl_index].last_update = TimeCurrent();

    // Update timestamps
    for (int i = 0; i < ArraySize(ESD_filter_status); i++)
    {
        ESD_filter_status[i].last_update = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Get Current Zone Quality Function                               |
//+------------------------------------------------------------------+
double ESD_GetCurrentZoneQuality()
{
    double quality = 0.0;
    int count = 0;

    if (ESD_bullish_fvg_bottom != EMPTY_VALUE)
    {
        quality += ESD_GetZoneQuality("FVG", iTime(_Symbol, ESD_HigherTimeframe, 0), true);
        count++;
    }

    if (ESD_bearish_fvg_top != EMPTY_VALUE)
    {
        quality += ESD_GetZoneQuality("FVG", iTime(_Symbol, ESD_HigherTimeframe, 0), false);
        count++;
    }

    if (ESD_bullish_ob_bottom != EMPTY_VALUE)
    {
        quality += ESD_GetZoneQuality("OB", iTime(_Symbol, ESD_HigherTimeframe, ESD_ObLookback), true);
        count++;
    }

    if (ESD_bearish_ob_top != EMPTY_VALUE)
    {
        quality += ESD_GetZoneQuality("OB", iTime(_Symbol, ESD_HigherTimeframe, ESD_ObLookback), false);
        count++;
    }

    return count > 0 ? quality / count : 0.0;
}

//+------------------------------------------------------------------+
//| Update Trading Data Function                                    |
//+------------------------------------------------------------------+
void ESD_UpdateTradingData()
{
    double total_profit = 0;
    int wins = 0;
    int losses = 0;
    double profit_sum = 0;
    double loss_sum = 0;
    double largest_win = 0;
    double largest_loss = 0;
    double current_streak = 0;
    double best_streak = 0;
    double last_profit = 0;

    // Get history for today
    HistorySelect(0, TimeCurrent());
    int total = HistoryDealsTotal();

    for (int i = 0; i < total; i++)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if (HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
            continue;

        if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != ESD_MagicNumber)
            continue;

        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
        total_profit += profit;

        if (profit > 0)
        {
            wins++;
            profit_sum += profit;
            if (profit > largest_win)
                largest_win = profit;
            if (last_profit > 0)
                current_streak++;
            else
                current_streak = 1;
        }
        else
        {
            losses++;
            loss_sum += MathAbs(profit);
            if (profit < largest_loss)
                largest_loss = profit;
            if (last_profit <= 0)
                current_streak--;
            else
                current_streak = -1;
        }

        if (MathAbs(current_streak) > MathAbs(best_streak))
            best_streak = current_streak;

        last_profit = profit;
    }

    // Update trade data
    ESD_trade_data.total_trades = wins + losses;
    ESD_trade_data.winning_trades = wins;
    ESD_trade_data.losing_trades = losses;
    ESD_trade_data.total_profit = profit_sum;
    ESD_trade_data.total_loss = loss_sum;
    ESD_trade_data.largest_win = largest_win;
    ESD_trade_data.largest_loss = largest_loss;
    ESD_trade_data.current_streak = current_streak;
    ESD_trade_data.best_streak = best_streak;

    // Calculate metrics
    if (ESD_trade_data.total_trades > 0)
    {
        ESD_trade_data.win_rate = (double)wins / ESD_trade_data.total_trades * 100;
        ESD_trade_data.profit_factor = loss_sum > 0 ? profit_sum / loss_sum : profit_sum > 0 ? 999
                                                                                             : 0;
        ESD_trade_data.average_win = wins > 0 ? profit_sum / wins : 0;
        ESD_trade_data.average_loss = losses > 0 ? loss_sum / losses : 0;
        ESD_trade_data.expectancy = (ESD_trade_data.win_rate / 100 * ESD_trade_data.average_win) -
                                    ((100 - ESD_trade_data.win_rate) / 100 * ESD_trade_data.average_loss);
    }

    // Update period profits
    double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    ESD_trade_data.daily_profit = current_balance - ESD_daily_start_balance;
    ESD_trade_data.weekly_profit = current_balance - ESD_weekly_start_balance;
    ESD_trade_data.monthly_profit = current_balance - ESD_monthly_start_balance;
}

//+------------------------------------------------------------------+
//| Draw System Info Panel Function                                 |
//+------------------------------------------------------------------+
void ESD_DrawSystemInfoPanel()
{
    string panel_name = "ESD_SystemPanel";
    string text_name = "ESD_SystemText";

    // Create background panel
    if (ObjectFind(0, panel_name) < 0)
    {
        ObjectCreate(0, panel_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, panel_name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, panel_name, OBJPROP_XDISTANCE, 5);
        ObjectSetInteger(0, panel_name, OBJPROP_YDISTANCE, 150);
        ObjectSetInteger(0, panel_name, OBJPROP_XSIZE, 250);
        ObjectSetInteger(0, panel_name, OBJPROP_YSIZE, 200);
        ObjectSetInteger(0, panel_name, OBJPROP_BGCOLOR, clrDarkGreen);
        ObjectSetInteger(0, panel_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, panel_name, OBJPROP_BORDER_COLOR, clrGray);
        ObjectSetInteger(0, panel_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, panel_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, panel_name, OBJPROP_HIDDEN, false);
    }

    // Prepare system info text
    string system_text = ESD_GetSystemInfo();

    // Create/update text object
    if (ObjectFind(0, text_name) < 0)
    {
        ObjectCreate(0, text_name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, text_name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, text_name, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, text_name, OBJPROP_YDISTANCE, 155);
        ObjectSetInteger(0, text_name, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 8);
        ObjectSetString(0, text_name, OBJPROP_FONT, "Consolas");
        ObjectSetInteger(0, text_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, text_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, text_name, OBJPROP_HIDDEN, false);
    }

    ObjectSetString(0, text_name, OBJPROP_TEXT, system_text);
}

//+------------------------------------------------------------------+
//| Delete Filter Monitor Function                                  |
//+------------------------------------------------------------------+
void ESD_DeleteFilterMonitor()
{
    string names[] = {"ESD_FilterPanel", "ESD_FilterText"};
    for (int i = 0; i < ArraySize(names); i++)
    {
        if (ObjectFind(0, names[i]) >= 0)
            ObjectDelete(0, names[i]);
    }
}

//+------------------------------------------------------------------+
//| Delete Trading Data Panels Function                             |
//+------------------------------------------------------------------+
void ESD_DeleteDataPanels()
{
    string names[] = {"ESD_DataPanel", "ESD_DataText", "ESD_SystemPanel", "ESD_SystemText"};
    for (int i = 0; i < ArraySize(names); i++)
    {
        if (ObjectFind(0, names[i]) >= 0)
            ObjectDelete(0, names[i]);
    }
}

//+------------------------------------------------------------------+
//| Delete All Monitoring Panels Function                           |
//+------------------------------------------------------------------+
void ESD_DeleteAllMonitoringPanels()
{
    ESD_DeleteFilterMonitor();
    ESD_DeleteDataPanels();
}

//+------------------------------------------------------------------+
//| Regime Detection Settings                                       |
//+------------------------------------------------------------------+
input bool ESD_UseRegimeDetection = true;     // Enable market regime detection
input int ESD_RegimeSmoothingPeriod = 20;     // Period for regime smoothing
input double ESD_VolatilityThreshold = 0.005; // Volatility threshold for regime classification
input double ESD_TrendThreshold = 0.15;       // Trend strength threshold
input int ESD_RegimeConfirmationBars = 5;     // Bars for regime confirmation

//+------------------------------------------------------------------+
//| Regime Detection Variables                                      |
//+------------------------------------------------------------------+
enum ENUM_MARKET_REGIME
{
    REGIME_TRENDING_BULLISH, // Strong uptrend
    REGIME_TRENDING_BEARISH, // Strong downtrend
    REGIME_RANGING_LOW_VOL,  // Low volatility consolidation
    REGIME_RANGING_HIGH_VOL, // High volatility consolidation
    REGIME_BREAKOUT_BULLISH, // Bullish breakout
    REGIME_BREAKOUT_BEARISH, // Bearish breakout
    REGIME_TRANSITION        // Market in transition
};

ENUM_MARKET_REGIME ESD_current_regime = REGIME_TRANSITION;
ENUM_MARKET_REGIME ESD_previous_regime = REGIME_TRANSITION;
double ESD_regime_strength = 0.0;
double ESD_volatility_index = 0.0;
double ESD_trend_index = 0.0;
datetime ESD_regime_change_time = 0;
int ESD_regime_duration = 0;

//+------------------------------------------------------------------+
//| Regime Colors                                                   |
//+------------------------------------------------------------------+
color ESD_RegimeBullishColor = clrDodgerBlue;
color ESD_RegimeBearishColor = clrOrangeRed;
color ESD_RegimeRangingColor = clrGray;
color ESD_RegimeBreakoutColor = clrGold;
color ESD_RegimeTransitionColor = clrYellow;

//+------------------------------------------------------------------+
//| Regime Detection Function                                       |
//+------------------------------------------------------------------+
void ESD_DetectMarketRegime()
{
    if (!ESD_UseRegimeDetection)
        return;

    double atr_buffer[];
    double close_buffer[];
    ArraySetAsSeries(atr_buffer, true);
    ArraySetAsSeries(close_buffer, true);

    // Get ATR for volatility measurement
    int atr_handle = iATR(_Symbol, PERIOD_CURRENT, ESD_RegimeSmoothingPeriod);
    CopyBuffer(atr_handle, 0, 0, ESD_RegimeSmoothingPeriod, atr_buffer);

    // Get closing prices for trend analysis
    CopyClose(_Symbol, PERIOD_CURRENT, 0, ESD_RegimeSmoothingPeriod, close_buffer);

    if (ArraySize(atr_buffer) < ESD_RegimeSmoothingPeriod ||
        ArraySize(close_buffer) < ESD_RegimeSmoothingPeriod)
        return;

    // Calculate volatility index (normalized ATR)
    double current_atr = atr_buffer[0];
    double price_mid = (close_buffer[0] + close_buffer[ESD_RegimeSmoothingPeriod - 1]) / 2.0;
    ESD_volatility_index = current_atr / price_mid;

    // Calculate trend index using linear regression
    double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0;
    for (int i = 0; i < ESD_RegimeSmoothingPeriod; i++)
    {
        sum_x += i;
        sum_y += close_buffer[i];
        sum_xy += i * close_buffer[i];
        sum_x2 += i * i;
    }

    double slope = (ESD_RegimeSmoothingPeriod * sum_xy - sum_x * sum_y) /
                   (ESD_RegimeSmoothingPeriod * sum_x2 - sum_x * sum_x);

    // Normalize trend strength
    ESD_trend_index = MathAbs(slope) / price_mid;

    // Store previous regime
    ESD_previous_regime = ESD_current_regime;

    // Determine current regime based on volatility and trend
    if (ESD_volatility_index < ESD_VolatilityThreshold)
    {
        // Low volatility environment
        if (ESD_trend_index > ESD_TrendThreshold)
        {
            // Trending in low volatility
            ESD_current_regime = (slope > 0) ? REGIME_TRENDING_BULLISH : REGIME_TRENDING_BEARISH;
            ESD_regime_strength = ESD_trend_index / ESD_TrendThreshold;
        }
        else
        {
            // Ranging with low volatility
            ESD_current_regime = REGIME_RANGING_LOW_VOL;
            ESD_regime_strength = 1.0 - (ESD_trend_index / ESD_TrendThreshold);
        }
    }
    else
    {
        // High volatility environment
        if (ESD_trend_index > ESD_TrendThreshold * 1.5)
        {
            // Strong trending with high volatility (breakout)
            ESD_current_regime = (slope > 0) ? REGIME_BREAKOUT_BULLISH : REGIME_BREAKOUT_BEARISH;
            ESD_regime_strength = ESD_trend_index / (ESD_TrendThreshold * 1.5);
        }
        else
        {
            // Ranging with high volatility
            ESD_current_regime = REGIME_RANGING_HIGH_VOL;
            ESD_regime_strength = ESD_volatility_index / ESD_VolatilityThreshold;
        }
    }

    // Check for regime confirmation
    if (!ESD_IsRegimeConfirmed())
    {
        ESD_current_regime = REGIME_TRANSITION;
        ESD_regime_strength = 0.5;
    }

    // Update regime duration and change time
    if (ESD_current_regime != ESD_previous_regime)
    {
        ESD_regime_change_time = TimeCurrent();
        ESD_regime_duration = 0;
    }
    else
    {
        ESD_regime_duration++;
    }

    // Update filter status for regime
    ESD_UpdateRegimeFilterStatus();
}

//+------------------------------------------------------------------+
//| Regime Confirmation Function                                    |
//+------------------------------------------------------------------+
bool ESD_IsRegimeConfirmed()
{
    // Check if regime has been consistent for confirmation bars
    ENUM_MARKET_REGIME test_regime = ESD_current_regime;

    for (int i = 1; i <= ESD_RegimeConfirmationBars; i++)
    {
        ENUM_MARKET_REGIME historical_regime = ESD_GetHistoricalRegime(i);
        if (historical_regime != test_regime)
            return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Get Historical Regime Function                                  |
//+------------------------------------------------------------------+
ENUM_MARKET_REGIME ESD_GetHistoricalRegime(int bars_back)
{
    // Simplified historical regime detection (in full implementation,
    // this would store and retrieve historical regime data)

    double close_buffer[];
    ArraySetAsSeries(close_buffer, true);
    CopyClose(_Symbol, PERIOD_CURRENT, bars_back, ESD_RegimeSmoothingPeriod, close_buffer);

    if (ArraySize(close_buffer) < ESD_RegimeSmoothingPeriod)
        return REGIME_TRANSITION;

    // Simple trend detection for historical data
    double first_price = close_buffer[ESD_RegimeSmoothingPeriod - 1];
    double last_price = close_buffer[0];
    double price_change = (last_price - first_price) / first_price;

    if (MathAbs(price_change) > ESD_TrendThreshold)
    {
        return (price_change > 0) ? REGIME_TRENDING_BULLISH : REGIME_TRENDING_BEARISH;
    }
    else
    {
        return REGIME_RANGING_LOW_VOL;
    }
}

//+------------------------------------------------------------------+
//| Update Regime Filter Status                                     |
//+------------------------------------------------------------------+
void ESD_UpdateRegimeFilterStatus()
{
    // Add regime filter to filter monitoring array
    int regime_index = -1;

    // Find regime filter index
    for (int i = 0; i < ArraySize(ESD_filter_status); i++)
    {
        if (ESD_filter_status[i].name == "Market Regime")
        {
            regime_index = i;
            break;
        }
    }

    // If not found, add it
    if (regime_index == -1)
    {
        int new_size = ArraySize(ESD_filter_status) + 1;
        ArrayResize(ESD_filter_status, new_size);
        regime_index = new_size - 1;

        ESD_filter_status[regime_index].name = "Market Regime";
    }

    // Update regime filter status
    ESD_filter_status[regime_index].enabled = ESD_UseRegimeDetection;
    ESD_filter_status[regime_index].passed = ESD_IsRegimeFavorable();
    ESD_filter_status[regime_index].strength = ESD_regime_strength;
    ESD_filter_status[regime_index].details = ESD_GetRegimeDescription();
    ESD_filter_status[regime_index].last_update = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Check if Regime is Favorable                                    |
//+------------------------------------------------------------------+
bool ESD_IsRegimeFavorable()
{
    if (!ESD_UseRegimeDetection)
        return true;

    // Define favorable regimes based on current strategy
    switch (ESD_current_regime)
    {
    case REGIME_TRENDING_BULLISH:
    case REGIME_TRENDING_BEARISH:
    case REGIME_BREAKOUT_BULLISH:
    case REGIME_BREAKOUT_BEARISH:
        return true; // Trending regimes are generally favorable

    case REGIME_RANGING_LOW_VOL:
        return ESD_AggressiveMode; // Only trade ranging in aggressive mode

    case REGIME_RANGING_HIGH_VOL:
    case REGIME_TRANSITION:
    default:
        return false; // Avoid high volatility ranging and transitions
    }
}

//+------------------------------------------------------------------+
//| Get Regime Description                                          |
//+------------------------------------------------------------------+
string ESD_GetRegimeDescription()
{
    string descriptions[7] = {
        "TRENDING BULLISH",
        "TRENDING BEARISH",
        "RANGING LOW VOL",
        "RANGING HIGH VOL",
        "BREAKOUT BULLISH",
        "BREAKOUT BEARISH",
        "TRANSITION"};

    return descriptions[ESD_current_regime] +
           StringFormat(" (%.1f%%)", ESD_regime_strength * 100) +
           StringFormat(" %dbars", ESD_regime_duration);
}

//+------------------------------------------------------------------+
//| Regime-Based Entry Filter (Fixed)                               |
//+------------------------------------------------------------------+
bool ESD_RegimeFilter(bool is_buy_signal)
{
    if (!ESD_UseRegimeDetection)
        return true;

    // Enhanced filtering based on market regime for both buy and sell signals
    switch (ESD_current_regime)
    {
    case REGIME_TRENDING_BULLISH:
        // Favor buy signals in bullish trends, filter sell signals
        if (is_buy_signal)
            return (ESD_regime_strength > 0.7); // Allow buys in strong bullish trends
        else
            return (ESD_regime_strength < 0.4); // Only allow sells if bullish trend is weak

    case REGIME_TRENDING_BEARISH:
        // Favor sell signals in bearish trends, filter buy signals
        if (!is_buy_signal)
            return (ESD_regime_strength > 0.7); // Allow sells in strong bearish trends
        else
            return (ESD_regime_strength < 0.4); // Only allow buys if bearish trend is weak

    case REGIME_BREAKOUT_BULLISH:
        // Strongly favor buy signals in bullish breakouts
        if (is_buy_signal)
            return (ESD_regime_strength > 0.6); // Allow buys
        else
            return (ESD_regime_strength < 0.3); // Very restrictive for sells

    case REGIME_BREAKOUT_BEARISH:
        // Strongly favor sell signals in bearish breakouts
        if (!is_buy_signal)
            return (ESD_regime_strength > 0.6); // Allow sells
        else
            return (ESD_regime_strength < 0.3); // Very restrictive for buys

    case REGIME_RANGING_LOW_VOL:
        // Allow both directions but with tighter filters in ranging
        if (ESD_AggressiveMode)
            return (ESD_regime_strength > 0.6); // Moderate filter for aggressive mode
        else
            return (ESD_regime_strength > 0.8); // Strong filter for conservative mode

    case REGIME_RANGING_HIGH_VOL:
        // Generally avoid trading in high volatility ranging
        if (ESD_AggressiveMode)
            return (ESD_regime_strength > 0.9); // Only very strong signals
        else
            return false; // Avoid completely in conservative mode

    case REGIME_TRANSITION:
        // Avoid trading during regime transitions
        if (ESD_AggressiveMode)
            return (ESD_regime_strength > 0.8); // Only very strong signals
        else
            return false; // Avoid completely
    }

    return true; // Default allow if regime not recognized
}

// =========================================================
// === FUNGSI PEMBANTU: Buat warna dengan alpha transparency ===
// =========================================================
color ColorSetAlpha(color c, int alpha)
{
    // Pastikan alpha berada di antara 0 - 255
    if (alpha < 0)
        alpha = 0;
    if (alpha > 255)
        alpha = 255;

    int r = GetRValue(c);
    int g = GetGValue(c);
    int b = GetBValue(c);

    // MQL5 warna disimpan sebagai ARGB 0xAARRGGBB
    return (color)((alpha << 24) | (r << 16) | (g << 8) | b);
}

// =========================================================
// === FUNGSI: ESD_DrawRegimeIndicator() dengan efek glow ===
// =========================================================
void ESD_DrawRegimeIndicator()
{
    if (!ESD_ShowObjects || !ESD_UseRegimeDetection)
        return;

    string indicator_name = "ESD_Regime_Indicator";
    string text_name = "ESD_Regime_Text";

    // Tentukan warna berdasarkan regime
    color regime_color = ESD_RegimeTransitionColor;
    switch (ESD_current_regime)
    {
    case REGIME_TRENDING_BULLISH:
    case REGIME_BREAKOUT_BULLISH:
        regime_color = ESD_RegimeBullishColor;
        break;
    case REGIME_TRENDING_BEARISH:
    case REGIME_BREAKOUT_BEARISH:
        regime_color = ESD_RegimeBearishColor;
        break;
    case REGIME_RANGING_LOW_VOL:
    case REGIME_RANGING_HIGH_VOL:
        regime_color = ESD_RegimeRangingColor;
        break;
    }

    // === Label teks ===
    if (ObjectFind(0, text_name) < 0)
    {
        ObjectCreate(0, text_name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, text_name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
        ObjectSetInteger(0, text_name, OBJPROP_XDISTANCE, 30);
        ObjectSetInteger(0, text_name, OBJPROP_YDISTANCE, 45);
        ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 14);
        ObjectSetString(0, text_name, OBJPROP_FONT, "Arial Black");
        ObjectSetInteger(0, text_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, text_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, text_name, OBJPROP_HIDDEN, true);
    }

    // === Warna teks sesuai arah regime ===
    color base_color = clrWhite;
    switch (ESD_current_regime)
    {
    case REGIME_TRENDING_BULLISH:
    case REGIME_BREAKOUT_BULLISH:
        base_color = clrLime;
        break;
    case REGIME_TRENDING_BEARISH:
    case REGIME_BREAKOUT_BEARISH:
        base_color = clrRed;
        break;
    case REGIME_RANGING_LOW_VOL:
    case REGIME_RANGING_HIGH_VOL:
        base_color = clrGold;
        break;
    }

    // === Efek glow berkedip halus ===
    static int alpha = 255;
    static int direction = -15;
    alpha += direction;
    if (alpha <= 100 || alpha >= 255)
        direction *= -1;

    color glow_color = ColorSetAlpha(base_color, alpha);

    // === Update teks ===
    string regime_text = ESD_GetRegimeDescription();
    ObjectSetInteger(0, text_name, OBJPROP_COLOR, glow_color);
    ObjectSetString(0, text_name, OBJPROP_TEXT, "⚡ " + regime_text + " ⚡");
}

//+------------------------------------------------------------------+
//| Regime-Based Position Sizing Function                           |
//+------------------------------------------------------------------+
double ESD_GetRegimeAdjustedLotSize()
{
    double adjusted_lot = ESD_LotSize;

    // ================================================================
    // 1️⃣ Regime-based multiplier (logika asli)
    // ================================================================
    if (ESD_UseRegimeDetection)
    {
        switch (ESD_current_regime)
        {
        case REGIME_TRENDING_BULLISH:
        case REGIME_TRENDING_BEARISH:
            adjusted_lot *= 1.2;
            break;

        case REGIME_BREAKOUT_BULLISH:
        case REGIME_BREAKOUT_BEARISH:
            adjusted_lot *= 1.1;
            break;

        case REGIME_RANGING_LOW_VOL:
            break;

        case REGIME_RANGING_HIGH_VOL:
            adjusted_lot *= 0.7;
            break;

        case REGIME_TRANSITION:
            adjusted_lot *= 0.5;
            break;
        }
    }

    // ================================================================
    // 2️⃣ Volatility Safety Control (tanpa variabel baru)
    //    - Jika ATR tinggi, kecilkan LOT agar tidak terjadi "No Money"
    // ================================================================
    double atr_fast = iATR(_Symbol, PERIOD_M5, 5);
    double atr_slow = iATR(_Symbol, PERIOD_M5, 14);

    // ATR XAUUSD besar → risiko besar → kecilkan lot
    if (atr_fast > atr_slow * 1.5)         adjusted_lot *= 0.7;
    if (atr_fast > atr_slow * 2.0)         adjusted_lot *= 0.5;
    if (atr_fast > atr_slow * 3.0)         adjusted_lot *= 0.3;

    // ================================================================
    // 3️⃣ Batasan broker (logika asli)
    // ================================================================
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

    adjusted_lot = MathMax(adjusted_lot, min_lot);
    adjusted_lot = MathMin(adjusted_lot, max_lot);

    return NormalizeDouble(adjusted_lot, 2);
}

//+------------------------------------------------------------------+
//|                    Enhanced SMC Direction EA.mq5                |
//|                  dengan Partial TP & Structure Trailing         |
//+------------------------------------------------------------------+

//--- Partial Take Profit Settings
input bool ESD_UsePartialTP = true;      // Enable Partial Take Profit
input int ESD_PartialTPLevels = 3;       // Number of TP levels
input double ESD_PartialTPRatio1 = 0.5;  // Ratio for TP level 1 (0-1)
input double ESD_PartialTPRatio2 = 0.3;  // Ratio for TP level 2 (0-1)
input double ESD_PartialTPRatio3 = 0.2;  // Ratio for TP level 3 (0-1)
input int ESD_PartialTPDistance1 = 1000; // Distance for TP1 (points)
input int ESD_PartialTPDistance2 = 2000; // Distance for TP2 (points)
input int ESD_PartialTPDistance3 = 3000; // Distance for TP3 (points)

//--- Dynamic TP Levels (for Partial TP)
double ESD_dynamic_tp1 = 0.0;
double ESD_dynamic_tp2 = 0.0;
double ESD_dynamic_tp3 = 0.0;

enum ENUM_TRAILING_TYPE
{
    TRAIL_SWING,     // Based on swing points
    TRAIL_STRUCTURE, // Based on SMC structures (OB/FVG)
    TRAIL_BREAK_EVEN // Break even after activation
};

//--- Structure-Based Trailing Stop Settings
input bool ESD_UseStructureTrailing = true;              // Enable Structure Trailing
input ENUM_TRAILING_TYPE ESD_TrailingType = TRAIL_SWING; // Trailing type
input int ESD_TrailingActivation = 500;                  // Activation distance (points)
input int ESD_TrailingStep = 100;                        // Step for trailing (points)
input double ESD_TrailingBufferRatio = 1.0;              // Buffer multiplier for structure

//--- Global Variables untuk Trailing
double ESD_current_trailing_stop = 0.0;
double ESD_last_swing_low = 0.0;
double ESD_last_swing_high = 0.0;
datetime ESD_last_trailing_update = 0;

// =======================================================
//   FUNGSI TUNGGAL UNTUK MENGELOLA SEMUA POSISI
//   - Partial SL
//   - Cut Profit
//   - Cut Loss
//   - Visual Note di Chart
// =======================================================

void ManagePositionsSL(double partialPercent = 0.50,
                     double cutProfitPips = 10,
                     double cutLossPips   = 25)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket))
            continue;

        string symbol = PositionGetString(POSITION_SYMBOL);
        int type      = (int)PositionGetInteger(POSITION_TYPE);
        double volume = PositionGetDouble(POSITION_VOLUME);
        double price  = PositionGetDouble(POSITION_PRICE_OPEN);
        double sl     = PositionGetDouble(POSITION_SL);
        double bid    = SymbolInfoDouble(symbol, SYMBOL_BID);
        double ask    = SymbolInfoDouble(symbol, SYMBOL_ASK);
        double point  = SymbolInfoDouble(symbol, SYMBOL_POINT);

        double profitPoints = (type == POSITION_TYPE_BUY)  ?
                                (bid - price) / point :
                                (price - ask) / point;

        // ----------------------------------------------
        // 1. PARTIAL SL (close sebagian posisi saat minus tertentu)
        // ----------------------------------------------
        if(profitPoints <= -cutLossPips && volume > SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN))
        {
            long volume_int = 0;
            double closeVol = NormalizeDouble(volume * partialPercent,
                                              (int)SymbolInfoInteger(symbol, SYMBOL_VOLUME, volume_int));

            ESD_trade.PositionClosePartial(ticket, closeVol);
            DrawLabelSL("PartialSL-"+(string)ticket,
                      "Partial SL hit ("+(string)closeVol+")",
                      type==POSITION_TYPE_BUY ? bid : ask,
                      clrRed);
        }

        // ----------------------------------------------
        // 2. CUT PROFIT (ambil profit kecil jika ada sinyal penolakan)
        //    Anda bisa ganti logic PA sesuai kebutuhan
        // ----------------------------------------------
        bool rejection = PriceRejection(symbol); // fungsi PA sederhana

        if(rejection && profitPoints >= cutProfitPips)
        {
            ESD_trade.PositionClose(ticket);
            DrawLabelSL("CutProfit-"+(string)ticket,
                      "Cut Profit ("+(string)profitPoints+" pips)",
                      type==POSITION_TYPE_BUY ? bid : ask,
                      clrGreen);
        }

        // ----------------------------------------------
        // 3. CUT LOSS CEPAT (close full saat kondisi buruk)
        // ----------------------------------------------
        if(rejection && profitPoints <= -cutLossPips * 1.5)
        {
            ESD_trade.PositionClose(ticket);
            DrawLabelSL("CutLoss-"+(string)ticket,
                      "Cut Loss Early",
                      type==POSITION_TYPE_BUY ? bid : ask,
                      clrOrange);
        }
    }
}


// -------------------------------------------------------
// Fungsi pendukung sederhana untuk mendeteksi *price rejection*
// Anda bisa kembangkan sesuai strategi
// -------------------------------------------------------
bool PriceRejection(string symbol)
{
    MqlRates r[];
    if(CopyRates(symbol, PERIOD_M5, 0, 3, r) < 3)
        return false;

    // contoh logic rejection (upper shadow atau lower shadow panjang)
    double body   = MathAbs(r[1].close - r[1].open);
    double upperW = r[1].high - MathMax(r[1].close, r[1].open);
    double lowerW = MathMin(r[1].close, r[1].open) - r[1].low;

    return (upperW > body*1.5 || lowerW > body*1.5);
}


// -------------------------------------------------------
// Visual Label (tanpa spam karena berdasarkan ticket unik)
// -------------------------------------------------------
void DrawLabelSL(string name, string text, double price, color clr)
{
    if(ObjectFind(0, name) == -1)
        ObjectCreate(0, name, OBJ_TEXT, 0, TimeCurrent(), price);

    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
}

//+------------------------------------------------------------------+
//| Enhanced TP Management dengan Profit Protection                 |
//+------------------------------------------------------------------+
void ESD_ManagePartialTP()
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (PositionGetTicket(i) &&
            PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == ESD_MagicNumber)
        {
            ulong ticket = PositionGetTicket(i);
            double current_price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double volume = PositionGetDouble(POSITION_VOLUME);
            double profit = PositionGetDouble(POSITION_PROFIT);
            ulong pos_type = PositionGetInteger(POSITION_TYPE);

            // 🛡️ Profit Protection: Close jika profit sudah tinggi tapi belum kena TP
            if (profit > 0 && ESD_ShouldProtectProfit(ticket, profit))
            {
                ESD_trade.PositionClose(ticket);
                Print("Profit Protection activated! Closed position with profit: ", profit);
                ESD_RemoveTPObjects();
                continue;
            }

            if (pos_type == POSITION_TYPE_BUY)
            {
                // TP1 Logic
                if (!ESD_tp1_hit && current_price >= ESD_current_tp1 && ESD_PartialTPRatio1 > 0)
                {
                    double close_volume = volume * ESD_PartialTPRatio1;
                    if (ESD_ExecutePartialClose(ticket, close_volume, "TP1"))
                    {
                        ESD_tp1_hit = true;
                        Print("✅ TP1 HIT! Closed ", close_volume, " lots");
                    }
                }

                // TP2 Logic
                if (!ESD_tp2_hit && current_price >= ESD_current_tp2 && ESD_PartialTPRatio2 > 0)
                {
                    double close_volume = volume * ESD_PartialTPRatio2;
                    if (ESD_ExecutePartialClose(ticket, close_volume, "TP2"))
                    {
                        ESD_tp2_hit = true;
                        Print("✅ TP2 HIT! Closed ", close_volume, " lots");
                    }
                }

                // TP3 Logic
                if (!ESD_tp3_hit && current_price >= ESD_current_tp3 && ESD_PartialTPRatio3 > 0)
                {
                    double close_volume = volume * ESD_PartialTPRatio3;
                    if (ESD_ExecutePartialClose(ticket, close_volume, "TP3"))
                    {
                        ESD_tp3_hit = true;
                        Print("✅ TP3 HIT! Closed ", close_volume, " lots");
                        ESD_RemoveTPObjects(); // Hapus objek setelah TP3
                    }
                }
            }
            else if (pos_type == POSITION_TYPE_SELL)
            {
                // TP1 Logic
                if (!ESD_tp1_hit && current_price <= ESD_current_tp1 && ESD_PartialTPRatio1 > 0)
                {
                    double close_volume = volume * ESD_PartialTPRatio1;
                    if (ESD_ExecutePartialClose(ticket, close_volume, "TP1"))
                    {
                        ESD_tp1_hit = true;
                        Print("✅ TP1 HIT! Closed ", close_volume, " lots");
                    }
                }

                // TP2 Logic
                if (!ESD_tp2_hit && current_price <= ESD_current_tp2 && ESD_PartialTPRatio2 > 0)
                {
                    double close_volume = volume * ESD_PartialTPRatio2;
                    if (ESD_ExecutePartialClose(ticket, close_volume, "TP2"))
                    {
                        ESD_tp2_hit = true;
                        Print("✅ TP2 HIT! Closed ", close_volume, " lots");
                    }
                }

                // TP3 Logic
                if (!ESD_tp3_hit && current_price <= ESD_current_tp3 && ESD_PartialTPRatio3 > 0)
                {
                    double close_volume = volume * ESD_PartialTPRatio3;
                    if (ESD_ExecutePartialClose(ticket, close_volume, "TP3"))
                    {
                        ESD_tp3_hit = true;
                        Print("✅ TP3 HIT! Closed ", close_volume, " lots");
                        ESD_RemoveTPObjects(); // Hapus objek setelah TP3
                    }
                }
            }

            // Update TP objects visual
            ESD_DrawTPObjects();
        }
    }
}

//+------------------------------------------------------------------+
//| Execute Partial TP for Buy                                      |
//+------------------------------------------------------------------+
void ESD_ExecutePartialTPBuy(ulong ticket, double open_price, double current_price, double volume, double point)
{
    double profit_points = (current_price - open_price) / point;
    double close_volume = 0;

    // TP Level 1
    if (profit_points >= ESD_PartialTPDistance1 && ESD_PartialTPRatio1 > 0)
    {
        close_volume = volume * ESD_PartialTPRatio1;
        if (close_volume >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
        {
            ESD_trade.PositionClosePartial(ticket, close_volume);
            Print("Partial TP1 executed for Buy: ", close_volume, " lots");
        }
    }

    // TP Level 2
    if (profit_points >= ESD_PartialTPDistance2 && ESD_PartialTPRatio2 > 0)
    {
        close_volume = volume * ESD_PartialTPRatio2;
        if (close_volume >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
        {
            ESD_trade.PositionClosePartial(ticket, close_volume);
            Print("Partial TP2 executed for Buy: ", close_volume, " lots");
        }
    }

    // TP Level 3
    if (profit_points >= ESD_PartialTPDistance3 && ESD_PartialTPRatio3 > 0)
    {
        close_volume = volume * ESD_PartialTPRatio3;
        if (close_volume >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
        {
            ESD_trade.PositionClosePartial(ticket, close_volume);
            Print("Partial TP3 executed for Buy: ", close_volume, " lots");
        }
    }
}

//+------------------------------------------------------------------+
//| Execute Partial TP for Sell                                     |
//+------------------------------------------------------------------+
void ESD_ExecutePartialTPSell(ulong ticket, double open_price, double current_price, double volume, double point)
{
    double profit_points = (open_price - current_price) / point;
    double close_volume = 0;

    // TP Level 1
    if (profit_points >= ESD_PartialTPDistance1 && ESD_PartialTPRatio1 > 0)
    {
        close_volume = volume * ESD_PartialTPRatio1;
        if (close_volume >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
        {
            ESD_trade.PositionClosePartial(ticket, close_volume);
            Print("Partial TP1 executed for Sell: ", close_volume, " lots");
        }
    }

    // TP Level 2
    if (profit_points >= ESD_PartialTPDistance2 && ESD_PartialTPRatio2 > 0)
    {
        close_volume = volume * ESD_PartialTPRatio2;
        if (close_volume >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
        {
            ESD_trade.PositionClosePartial(ticket, close_volume);
            Print("Partial TP2 executed for Sell: ", close_volume, " lots");
        }
    }

    // TP Level 3
    if (profit_points >= ESD_PartialTPDistance3 && ESD_PartialTPRatio3 > 0)
    {
        close_volume = volume * ESD_PartialTPRatio3;
        if (close_volume >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
        {
            ESD_trade.PositionClosePartial(ticket, close_volume);
            Print("Partial TP3 executed for Sell: ", close_volume, " lots");
        }
    }
}

//+------------------------------------------------------------------+
//| Structure-Based Trailing Stop Management                        |
//+------------------------------------------------------------------+
void ESD_ManageStructureTrailing()
{
    if (!ESD_UseStructureTrailing)
        return;

    // Update swing levels setiap beberapa candle
    if (TimeCurrent() - ESD_last_trailing_update > PeriodSeconds(PERIOD_CURRENT) * 5)
    {
        ESD_UpdateSwingLevels();
        ESD_last_trailing_update = TimeCurrent();
    }

    for (int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == ESD_MagicNumber)
        {
            double current_sl = PositionGetDouble(POSITION_SL);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            double current_price = 0;
            ulong pos_type = PositionGetInteger(POSITION_TYPE);
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

            if (pos_type == POSITION_TYPE_BUY)
            {
                current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                ESD_UpdateBuyTrailing(ticket, current_sl, open_price, current_price, point);
            }
            else if (pos_type == POSITION_TYPE_SELL)
            {
                current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                ESD_UpdateSellTrailing(ticket, current_sl, open_price, current_price, point);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Update Swing Levels for Trailing                                |
//+------------------------------------------------------------------+
void ESD_UpdateSwingLevels()
{
    int bars = 20;
    double high_buffer[], low_buffer[];
    ArraySetAsSeries(high_buffer, true);
    ArraySetAsSeries(low_buffer, true);

    CopyHigh(_Symbol, PERIOD_CURRENT, 0, bars, high_buffer);
    CopyLow(_Symbol, PERIOD_CURRENT, 0, bars, low_buffer);

    // Find recent swing high
    ESD_last_swing_high = high_buffer[0];
    for (int i = 1; i < bars - 1; i++)
    {
        if (high_buffer[i] > high_buffer[i - 1] && high_buffer[i] > high_buffer[i + 1])
        {
            if (high_buffer[i] > ESD_last_swing_high)
                ESD_last_swing_high = high_buffer[i];
        }
    }

    // Find recent swing low
    ESD_last_swing_low = low_buffer[0];
    for (int i = 1; i < bars - 1; i++)
    {
        if (low_buffer[i] < low_buffer[i - 1] && low_buffer[i] < low_buffer[i + 1])
        {
            if (low_buffer[i] < ESD_last_swing_low)
                ESD_last_swing_low = low_buffer[i];
        }
    }

    // Jika tidak ditemukan swing, gunakan high/low terakhir
    if (ESD_last_swing_high == high_buffer[0])
        ESD_last_swing_high = high_buffer[ArrayMaximum(high_buffer, 0, bars)];
    if (ESD_last_swing_low == low_buffer[0])
        ESD_last_swing_low = low_buffer[ArrayMinimum(low_buffer, 0, bars)];
}

//+------------------------------------------------------------------+
//| Update Trailing Stop for Buy Position                           |
//+------------------------------------------------------------------+
void ESD_UpdateBuyTrailing(ulong ticket, double current_sl, double open_price, double current_price, double point)
{
    double new_sl = current_sl;
    double activation_distance = ESD_TrailingActivation * point;
    if (current_price - open_price < activation_distance)
        return;

    double buffer = ESD_SlBufferPoints * point * ESD_TrailingBufferRatio;

    switch (ESD_TrailingType)
    {
    case TRAIL_SWING:
        if (ESD_last_swing_low > 0)
            new_sl = MathMax(new_sl, ESD_last_swing_low - buffer);
        break;

    case TRAIL_STRUCTURE:
        // Prioritize Volume Profile POC if available
        if (ESD_poc_price > 0)
            new_sl = MathMax(new_sl, ESD_poc_price - buffer);
        // Then FVG bottom
        else if (ESD_bullish_fvg_bottom != EMPTY_VALUE)
            new_sl = MathMax(new_sl, ESD_bullish_fvg_bottom - buffer);
        // Then swing low
        else if (ESD_last_significant_pl > 0)
            new_sl = MathMax(new_sl, ESD_last_significant_pl - buffer);
        break;

    case TRAIL_BREAK_EVEN:
        new_sl = MathMax(new_sl, open_price + 10 * point);
        break;
    }

    // Ensure trailing SL is above current SL and safe distance from price
    if (new_sl > current_sl && new_sl < current_price - 100 * point)
    {
        ESD_trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
        Print("Buy Trailing SL updated to: ", new_sl);
    }
}

//+------------------------------------------------------------------+
//| Update Trailing Stop for Sell Position                          |
//+------------------------------------------------------------------+
void ESD_UpdateSellTrailing(ulong ticket, double current_sl, double open_price, double current_price, double point)
{
    double new_sl = current_sl;
    double activation_distance = ESD_TrailingActivation * point;
    if (open_price - current_price < activation_distance)
        return;

    double buffer = ESD_SlBufferPoints * point * ESD_TrailingBufferRatio;

    switch (ESD_TrailingType)
    {
    case TRAIL_SWING:
        if (ESD_last_swing_high > 0)
            new_sl = MathMin(new_sl, ESD_last_swing_high + buffer);
        break;

    case TRAIL_STRUCTURE:
        // Prioritize Volume Profile POC
        if (ESD_poc_price > 0)
            new_sl = MathMin(new_sl, ESD_poc_price + buffer);
        // Then FVG top
        else if (ESD_bearish_fvg_top != EMPTY_VALUE)
            new_sl = MathMin(new_sl, ESD_bearish_fvg_top + buffer);
        // Then swing high
        else if (ESD_last_significant_ph > 0)
            new_sl = MathMin(new_sl, ESD_last_significant_ph + buffer);
        break;

    case TRAIL_BREAK_EVEN:
        new_sl = MathMin(new_sl, open_price - 10 * point);
        break;
    }

    // Ensure trailing SL is below current SL and safe distance from price
    if (new_sl < current_sl && new_sl > current_price + 100 * point)
    {
        ESD_trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
        Print("Sell Trailing SL updated to: ", new_sl);
    }
}

//+------------------------------------------------------------------+
//| Enhanced Trade Execution dengan PowerPull TP                   |
//+------------------------------------------------------------------+
void ESD_ExecuteTradeWithPartialTP(bool is_buy, double entry_price, double sl, string comment)
{
    double adjusted_lot = ESD_GetRegimeAdjustedLotSize();

    // Calculate enhanced TP levels
    ESD_CalculateEnhancedTP(is_buy, entry_price);

    // Execute trade dengan TP = 0 (akan di-manage manually)
    if (is_buy)
    {
        if (ESD_trade.Buy(adjusted_lot, _Symbol, entry_price, sl, 0, comment))
        {
            Print("BUY Order dengan PowerPull TP - Entry: ", entry_price,
                  " TP1: ", ESD_current_tp1, " TP2: ", ESD_current_tp2, " TP3: ", ESD_current_tp3);
            ESD_DrawTPObjects(); // Draw TP lines immediately
        }
    }
    else
    {
        if (ESD_trade.Sell(adjusted_lot, _Symbol, entry_price, sl, 0, comment))
        {
            Print("SELL Order dengan PowerPull TP - Entry: ", entry_price,
                  " TP1: ", ESD_current_tp1, " TP2: ", ESD_current_tp2, " TP3: ", ESD_current_tp3);
            ESD_DrawTPObjects(); // Draw TP lines immediately
        }
    }
}

//--- Helper: Get HTF Swing High
double ESD_GetHTFSwingHigh()
{
    double high_buffer[];
    ArraySetAsSeries(high_buffer, true);
    if (CopyHigh(_Symbol, ESD_SupremeTimeframe, 0, 20, high_buffer) == 20)
    {
        for (int i = 1; i < 19; i++)
            if (high_buffer[i] >= high_buffer[i - 1] && high_buffer[i] >= high_buffer[i + 1])
                return high_buffer[i];
    }
    return 0;
}

//--- Helper: Get HTF Swing Low
double ESD_GetHTFSwingLow()
{
    double low_buffer[];
    ArraySetAsSeries(low_buffer, true);
    if (CopyLow(_Symbol, ESD_SupremeTimeframe, 0, 20, low_buffer) == 20)
    {
        for (int i = 1; i < 19; i++)
            if (low_buffer[i] <= low_buffer[i - 1] && low_buffer[i] <= low_buffer[i + 1])
                return low_buffer[i];
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Stochastic Confirmation Filter (Standard Reversal Logic)         |
//+------------------------------------------------------------------+
bool ESD_StochasticEntryFilter(bool is_buy_signal)
{
    double stoch_k[], stoch_d[];
    ArraySetAsSeries(stoch_k, true);
    ArraySetAsSeries(stoch_d, true);

    int handle = iStochastic(_Symbol, PERIOD_CURRENT, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
    if (CopyBuffer(handle, 0, 0, 2, stoch_k) < 2)
        return true;
    if (CopyBuffer(handle, 1, 0, 2, stoch_d) < 2)
        return true;

    double k0 = stoch_k[0], k1 = stoch_k[1];

    if (is_buy_signal)
    {
        // BUY: Stochastic tidak di overbought extreme
        return (k0 < 80) && (k0 > 20) && (k0 > k1); // Momentum mulai naik
    }
    else
    {
        // SELL: Stochastic tidak di oversold extreme
        return (k0 > 20) && (k0 < 80) && (k0 < k1); // Momentum mulai turun
    }
}
//+------------------------------------------------------------------+
//| Initialize Monitoring Panels                                    |
//+------------------------------------------------------------------+
void ESD_InitializeMonitoringPanels()
{
    Print("Initializing ESD Monitoring Panels...");

    // Hapus panel lama terlebih dahulu
    ESD_DeleteAllMonitoringPanels();

    // Tunggu sebentar untuk memastikan objects terhapus
    Sleep(100);

    // Inisialisasi status filter
    ESD_InitializeFilterMonitoring();

    // Inisialisasi data trading
    ESD_InitializeTradingData();

    // Force draw panels based on input parameters
    if (ESD_ShowFilterMonitor)
    {
        ESD_DrawFilterMonitor();
        Print("Filter Monitor: ENABLED");
    }
    else
    {
        Print("Filter Monitor: DISABLED (input parameter)");
    }

    // Always draw system info panel
    ESD_DrawSystemInfoPanel();

    Print("ESD Monitoring Panels Initialization Complete");
    Print("Check corners: Filter=", EnumToString(ESD_FilterCorner), " Data=", EnumToString(ESD_DataCorner));
}

//+------------------------------------------------------------------+
//| Enhanced OnTick with Better Panel Management                    |
//+------------------------------------------------------------------+
void OnTick()
{
    static datetime last_htf = 0, last_of = 0, last_heatmap = 0, last_ui = 0, last_liquidity = 0;
    static bool first_tick = true;
    datetime now = TimeCurrent();

    // Initialize panels on first tick
    if (first_tick)
    {
        ESD_InitializeMonitoringPanels();
        first_tick = false;
        Print("First tick initialization complete");
    }

    ESD_UpdateMLModel();


    // ESD_CloseOnPriceAction();

    DragonMomentum();

    // UpdateMaxLossSL_AndReversal(300); // Max loss = 300 pip

    ESD_DetectMarketRegime();
    ESD_DrawRegimeIndicator();

    // Trailing stop untuk Trading manual
    // double trailingDistance = 300; // contoh: 500 points = 50 pips untuk 5-digit
    // ESD_TrailingStop(trailingDistance, 500);

    // --- Liquidity Zone Detection (every 10 seconds)
    if (now - last_liquidity >= 10)
    {
        ESD_DetectLiquidityZones();
        last_liquidity = now;
    }

    // --- Higher Timeframe Analysis (once per HTF candle)
    datetime htf_time = iTime(_Symbol, ESD_HigherTimeframe, 0);
    if (htf_time != last_htf)
    {
        ESD_DetectSMC();
        last_htf = htf_time;
    }

    // --- Order Flow (every 5 seconds)
    if (now - last_of >= 5)
    {
        ESD_AnalyzeOrderFlow();
        last_of = now;
    }

    // --- Heatmap (every 60 seconds)
    if (now - last_heatmap >= 60)
    {
        ESD_AnalyzeHeatmap();
        last_heatmap = now;
    }

    ESD_TryOpenMLStochasticTrade();

    // ESD_HedgeFundMasterML();

    // ================== ML-ENHANCED ALTERNATIVE AGGRESSIVE ENTRIES ==================
    if (ESD_UseMachineLearning)
    {
         ESD_CheckMLAggressiveAlternativeEntries();
    }

    static datetime last_bsl_ssl = 0;

    // Update BSL/SSL levels setiap 30 detik
    if (now - last_bsl_ssl >= 30)
    {
        ESD_DetectBSL_SSLLevels();
        last_bsl_ssl = now;
    }

    // Check untuk short entries
    if (ESD_EnableShortTrading)
    {
        ESD_CheckForShortEntries();
    }

    if (ESD_UseMachineLearning)
        ESD_CheckForEntryWithML(); // NEW dengan ML
    else
        ESD_CheckForEntry(); // Fallback tanpa ML

    if (ESD_AggressiveMode)
        ESD_CheckForAggressiveEntry();

    // --- UI Update (every 3 seconds with forced refresh)
    if (now - last_ui >= 3)
    {
        // Only update if panels are enabled in parameters
        if (ESD_ShowFilterMonitor)
        {
            ESD_DrawFilterMonitor();
        }

        if (ESD_ShowTradingData)
        {
            ESD_DrawTradingDataPanel();
        }

        // Always update system info
        ESD_DrawSystemInfoPanel();

        last_ui = now;
    }

    // Update TP objects setiap 10 detik
    static datetime last_update = 0;
    if (TimeCurrent() - last_update >= 10)
    {
        ESD_DrawTPObjects();
        last_update = TimeCurrent();
    }

    // --- Alternative Entry Methods ---
    if (ESD_UseAlternativeEntries && !PositionSelect(_Symbol))
    {
        ESD_CheckAlternativeEntries();
    }

    // --- Position Management (every 60 seconds)
    static datetime last_manage = 0;
    if (now - last_manage >= 60)
    {
        // ESD_ManagePartialTP();
        ManagePositionsSL();
        ESD_ManageStructureTrailing();
        last_manage = now;
    }
}

// =========================================================
// === STYLE & UTILITY ===
// =========================================================
#define PANEL_BG_BASE clrDarkSlateGray
#define PANEL_BORDER_COLOR clrGoldenrod
#define PANEL_HEADER_COLOR clrAqua
#define PANEL_TEXT_COLOR clrWhite

// Durasi animasi dalam milidetik
#define FADE_STEPS 5
#define FADE_DELAY 10

// ---------------------------------------------------------
// Tambah Baris dengan Warna
void AddLine(string &lines[], color &colors[], int &idx, string txt, color col)
{
    ArrayResize(lines, idx + 1);
    ArrayResize(colors, idx + 1);
    lines[idx] = txt;
    colors[idx] = col;
    idx++;
}

// Tambah Baris Sederhana
void AddLineSimple(string &lines[], int &idx, string txt)
{
    ArrayResize(lines, idx + 1);
    lines[idx] = txt;
    idx++;
}

// =========================================================
// Fungsi helper untuk membuat warna ARGB (Alpha, Red, Green, Blue)
// =========================================================
uint ARGB(int alpha, int red, int green, int blue)
{
    return ((uint)alpha << 24) | ((uint)red << 16) | ((uint)green << 8) | (uint)blue;
}

// Mengambil nilai komponen warna merah dari color
int GetRValue(color clr)
{
    return (clr >> 16) & 0xFF;
}

// Mengambil nilai komponen warna hijau dari color
int GetGValue(color clr)
{
    return (clr >> 8) & 0xFF;
}

// Mengambil nilai komponen warna biru dari color
int GetBValue(color clr)
{
    return clr & 0xFF;
}

// ---------------------------------------------------------
// =========================================================
// Efek Fade-In Panel dengan Transparansi
// =========================================================
void FadeInPanel(string panel_name, color base_color, int x, int y, int w, int h, color border)
{
    // Hapus panel lama kalau ada
    if (ObjectFind(0, panel_name) >= 0)
        ObjectDelete(0, panel_name);

    // Buat panel dengan efek fade
    for (int alpha = 10; alpha <= 100; alpha += (90 / FADE_STEPS)) // alpha kecil = lebih transparan
    {
        ObjectCreate(0, panel_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, panel_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, panel_name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, panel_name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, panel_name, OBJPROP_XSIZE, w);
        ObjectSetInteger(0, panel_name, OBJPROP_YSIZE, h);

        // Warna transparan berdasarkan alpha
        ObjectSetInteger(0, panel_name, OBJPROP_BGCOLOR,
                         ARGB(alpha, GetRValue(base_color), GetGValue(base_color), GetBValue(base_color)));

        ObjectSetInteger(0, panel_name, OBJPROP_BORDER_COLOR, border);
        ObjectSetInteger(0, panel_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, panel_name, OBJPROP_WIDTH, 1);

        // Ini penting! True = panel di belakang candle
        ObjectSetInteger(0, panel_name, OBJPROP_BACK, true);

        ChartRedraw();
        Sleep(FADE_DELAY);
    }
}

// =========================================================
// === UNIFIED MONITORING DASHBOARD (ULTRA MODERN UI) ===
// =========================================================

// Warna ultra modern & eye-friendly
#define PANEL_BG_MAIN            C'20,22,30'       // Deep dark blue
#define PANEL_BG_CARD            C'28,32,42'       // Card background
#define PANEL_ACCENT_PRIMARY     C'99,102,241'     // Indigo
#define PANEL_ACCENT_SUCCESS     C'16,185,129'     // Emerald
#define PANEL_ACCENT_WARNING     C'245,158,11'     // Amber
#define PANEL_ACCENT_DANGER      C'239,68,68'      // Red
#define PANEL_ACCENT_INFO        C'59,130,246'     // Blue
#define PANEL_ACCENT_PURPLE      C'168,85,247'     // Purple
#define PANEL_TEXT_PRIMARY       C'241,245,249'    // Almost white
#define PANEL_TEXT_SECONDARY     C'148,163,184'    // Slate gray
#define PANEL_TEXT_MUTED         C'100,116,139'    // Muted
#define PANEL_BORDER_GLOW        C'99,102,241'     // Indigo glow
#define PANEL_DIVIDER            C'51,65,85'       // Divider

// Helper functions
void AddStyledLineWithPos(string &lines[], color &colors[], int &sizes[], string &fonts[],
                          int &x_pos[], int &y_pos[], int &idx,
                          string text, color col, int size, string font, int x, int y)
{
    ArrayResize(lines, idx + 1);
    ArrayResize(colors, idx + 1);
    ArrayResize(sizes, idx + 1);
    ArrayResize(fonts, idx + 1);
    ArrayResize(x_pos, idx + 1);
    ArrayResize(y_pos, idx + 1);

    lines[idx] = text;
    colors[idx] = col;
    sizes[idx] = size;
    fonts[idx] = font;
    x_pos[idx] = x;
    y_pos[idx] = y;
    idx++;
}

void ESD_DrawUnifiedDashboard()
{
    // Check conditions
    bool show_filters = ESD_ShowFilterMonitor;
    bool show_trading = ESD_ShowTradingData;
    bool show_ml = (ESD_ShowObjects && ESD_UseMachineLearning);

    if (!show_filters && !show_trading && !show_ml)
    {
        ESD_DeleteFilterMonitor();
        ESD_DeleteDataPanels();
        return;
    }

    string base_name = "ESD_Text_";
    string main_panel = "ESD_MainPanel";
    string shadow_panel = "ESD_Shadow";
    string header_bar = "ESD_HeaderBar";
    string left_card = "ESD_LeftCard";
    string right_card = "ESD_RightCard";
    string progress_bg = "ESD_ProgressBG";
    string progress_bar = "ESD_ProgressBar";
    string badge_bg = "ESD_BadgeBG";
    string glow_effect = "ESD_Glow";
    string header_accent = "ESD_HeaderAccent";
    string pulse_effect = "ESD_PulseEffect";

    // Clean old objects
    for (int i = 0; i < 400; i++)
        ObjectDelete(0, base_name + IntegerToString(i));
    ObjectDelete(0, main_panel);
    ObjectDelete(0, shadow_panel);
    ObjectDelete(0, header_bar);
    ObjectDelete(0, left_card);
    ObjectDelete(0, right_card);
    ObjectDelete(0, progress_bg);
    ObjectDelete(0, progress_bar);
    ObjectDelete(0, badge_bg);
    ObjectDelete(0, glow_effect);
    ObjectDelete(0, header_accent);
    ObjectDelete(0, pulse_effect);

    // Update data
    if (show_filters)
        ESD_UpdateFilterStatus();
    if (show_trading)
        ESD_UpdateTradingData();

    // === Calculate statistics ===
    int total_filters = 0, passed_filters = 0;
    if (show_filters)
    {
        for (int i = 0; i < ArraySize(ESD_filter_status); i++)
        {
            if (ESD_filter_status[i].enabled)
            {
                total_filters++;
                if (ESD_filter_status[i].passed)
                    passed_filters++;
            }
        }
    }

    double score = total_filters > 0 ? (double)passed_filters / total_filters * 100 : 0;

    // Status determination
    string status_text;
    color status_color, bar_color, badge_color;

    if (score >= 80)
    {
        status_text = "EXCELLENT";
        status_color = PANEL_ACCENT_SUCCESS;
        bar_color = PANEL_ACCENT_SUCCESS;
        badge_color = C'5,46,22'; // Dark green bg
    }
    else if (score >= 60)
    {
        status_text = "GOOD";
        status_color = C'132,204,22';
        bar_color = C'132,204,22';
        badge_color = C'30,41,15';
    }
    else if (score >= 40)
    {
        status_text = "MODERATE";
        status_color = PANEL_ACCENT_WARNING;
        bar_color = PANEL_ACCENT_WARNING;
        badge_color = C'55,34,5';
    }
    else
    {
        status_text = "WEAK";
        status_color = PANEL_ACCENT_DANGER;
        bar_color = PANEL_ACCENT_DANGER;
        badge_color = C'55,10,10';
    }

    // === Layout calculations ===
    int chart_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
    int panel_x = 15;
    int panel_y = chart_height / 12;
    int panel_w = 760;
    int panel_h = 360;

    // Glow effect (outer glow)
    ObjectCreate(0, glow_effect, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, glow_effect, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, glow_effect, OBJPROP_XDISTANCE, panel_x - 2);
    ObjectSetInteger(0, glow_effect, OBJPROP_YDISTANCE, panel_y - 2);
    ObjectSetInteger(0, glow_effect, OBJPROP_XSIZE, panel_w + 4);
    ObjectSetInteger(0, glow_effect, OBJPROP_YSIZE, panel_h + 4);
    ObjectSetInteger(0, glow_effect, OBJPROP_BGCOLOR, PANEL_BORDER_GLOW);
    ObjectSetInteger(0, glow_effect, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, glow_effect, OBJPROP_BACK, true);

    // Shadow effect
    ObjectCreate(0, shadow_panel, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, shadow_panel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, shadow_panel, OBJPROP_XDISTANCE, panel_x + 4);
    ObjectSetInteger(0, shadow_panel, OBJPROP_YDISTANCE, panel_y + 4);
    ObjectSetInteger(0, shadow_panel, OBJPROP_XSIZE, panel_w);
    ObjectSetInteger(0, shadow_panel, OBJPROP_YSIZE, panel_h);
    ObjectSetInteger(0, shadow_panel, OBJPROP_BGCOLOR, C'8,10,15');
    ObjectSetInteger(0, shadow_panel, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, shadow_panel, OBJPROP_BACK, true);

    // Main panel
    ObjectCreate(0, main_panel, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, main_panel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, main_panel, OBJPROP_XDISTANCE, panel_x);
    ObjectSetInteger(0, main_panel, OBJPROP_YDISTANCE, panel_y);
    ObjectSetInteger(0, main_panel, OBJPROP_XSIZE, panel_w);
    ObjectSetInteger(0, main_panel, OBJPROP_YSIZE, panel_h);
    ObjectSetInteger(0, main_panel, OBJPROP_BGCOLOR, PANEL_BG_MAIN);
    ObjectSetInteger(0, main_panel, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, main_panel, OBJPROP_BACK, true);

    // Header bar (accent top with gradient effect)
    ObjectCreate(0, header_bar, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, header_bar, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, header_bar, OBJPROP_XDISTANCE, panel_x);
    ObjectSetInteger(0, header_bar, OBJPROP_YDISTANCE, panel_y);
    ObjectSetInteger(0, header_bar, OBJPROP_XSIZE, panel_w);
    ObjectSetInteger(0, header_bar, OBJPROP_YSIZE, 55);
    ObjectSetInteger(0, header_bar, OBJPROP_BGCOLOR, C'35,40,58');
    ObjectSetInteger(0, header_bar, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, header_bar, OBJPROP_BACK, true);

    // Header accent line (glowing line at top)
    ObjectCreate(0, header_accent, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, header_accent, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, header_accent, OBJPROP_XDISTANCE, panel_x);
    ObjectSetInteger(0, header_accent, OBJPROP_YDISTANCE, panel_y);
    ObjectSetInteger(0, header_accent, OBJPROP_XSIZE, panel_w);
    ObjectSetInteger(0, header_accent, OBJPROP_YSIZE, 3);
    ObjectSetInteger(0, header_accent, OBJPROP_BGCOLOR, PANEL_ACCENT_PRIMARY);
    ObjectSetInteger(0, header_accent, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, header_accent, OBJPROP_BACK, true);

    // Pulse effect line below header
    ObjectCreate(0, pulse_effect, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, pulse_effect, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, pulse_effect, OBJPROP_XDISTANCE, panel_x);
    ObjectSetInteger(0, pulse_effect, OBJPROP_YDISTANCE, panel_y + 54);
    ObjectSetInteger(0, pulse_effect, OBJPROP_XSIZE, panel_w);
    ObjectSetInteger(0, pulse_effect, OBJPROP_YSIZE, 1);
    ObjectSetInteger(0, pulse_effect, OBJPROP_BGCOLOR, C'99,102,241,50');
    ObjectSetInteger(0, pulse_effect, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, pulse_effect, OBJPROP_BACK, true);

    // Status badge background
    if (show_filters)
    {
        ObjectCreate(0, badge_bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, badge_bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, badge_bg, OBJPROP_XDISTANCE, panel_x + 520);
        ObjectSetInteger(0, badge_bg, OBJPROP_YDISTANCE, panel_y + 15);
        ObjectSetInteger(0, badge_bg, OBJPROP_XSIZE, 180);
        ObjectSetInteger(0, badge_bg, OBJPROP_YSIZE, 22);
        ObjectSetInteger(0, badge_bg, OBJPROP_BGCOLOR, badge_color);
        ObjectSetInteger(0, badge_bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, badge_bg, OBJPROP_BACK, true);
    }

    // === TWO COLUMN CARDS ===
    int card_w = 365;
    int card_h = 270;
    int card_gap = 15;
    int card_y = panel_y + 70;

    // Left Card: Filter Status
    if (show_filters)
    {
        ObjectCreate(0, left_card, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, left_card, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, left_card, OBJPROP_XDISTANCE, panel_x + 15);
        ObjectSetInteger(0, left_card, OBJPROP_YDISTANCE, card_y);
        ObjectSetInteger(0, left_card, OBJPROP_XSIZE, card_w);
        ObjectSetInteger(0, left_card, OBJPROP_YSIZE, card_h);
        ObjectSetInteger(0, left_card, OBJPROP_BGCOLOR, PANEL_BG_CARD);
        ObjectSetInteger(0, left_card, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, left_card, OBJPROP_COLOR, PANEL_DIVIDER);
        ObjectSetInteger(0, left_card, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, left_card, OBJPROP_BACK, true);
    }

    // Right Card: Performance + AI
    if (show_trading || show_ml)
    {
        ObjectCreate(0, right_card, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, right_card, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, right_card, OBJPROP_XDISTANCE, panel_x + 15 + card_w + card_gap);
        ObjectSetInteger(0, right_card, OBJPROP_YDISTANCE, card_y);
        ObjectSetInteger(0, right_card, OBJPROP_XSIZE, card_w);
        ObjectSetInteger(0, right_card, OBJPROP_YSIZE, card_h);
        ObjectSetInteger(0, right_card, OBJPROP_BGCOLOR, PANEL_BG_CARD);
        ObjectSetInteger(0, right_card, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, right_card, OBJPROP_COLOR, PANEL_DIVIDER);
        ObjectSetInteger(0, right_card, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, right_card, OBJPROP_BACK, true);
    }

    // === Progress Bar (bottom) ===
    if (show_filters)
    {
        int progress_y = panel_y + panel_h - 18;
        int progress_x = panel_x + 20;
        int progress_w = panel_w - 40;
        int progress_h = 5;

        ObjectCreate(0, progress_bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, progress_bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, progress_bg, OBJPROP_XDISTANCE, progress_x);
        ObjectSetInteger(0, progress_bg, OBJPROP_YDISTANCE, progress_y);
        ObjectSetInteger(0, progress_bg, OBJPROP_XSIZE, progress_w);
        ObjectSetInteger(0, progress_bg, OBJPROP_YSIZE, progress_h);
        ObjectSetInteger(0, progress_bg, OBJPROP_BGCOLOR, C'40,45,60');
        ObjectSetInteger(0, progress_bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, progress_bg, OBJPROP_BACK, true);

        int filled_width = (int)(progress_w * score / 100.0);
        ObjectCreate(0, progress_bar, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, progress_bar, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, progress_bar, OBJPROP_XDISTANCE, progress_x);
        ObjectSetInteger(0, progress_bar, OBJPROP_YDISTANCE, progress_y);
        ObjectSetInteger(0, progress_bar, OBJPROP_XSIZE, filled_width);
        ObjectSetInteger(0, progress_bar, OBJPROP_YSIZE, progress_h);
        ObjectSetInteger(0, progress_bar, OBJPROP_BGCOLOR, bar_color);
        ObjectSetInteger(0, progress_bar, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, progress_bar, OBJPROP_BACK, true);
    }

    // === Get chart info ===
    int total_objects = ObjectsTotal(0, -1, -1);
    int esd_objects = 0;
    for (int i = 0; i < total_objects; i++)
    {
        string name = ObjectName(0, i, -1, -1);
        if (StringFind(name, "ESD_", 0) == 0)
            esd_objects++;
    }

    // === CONTENT ===
    string lines[];
    color colors[];
    int font_sizes[];
    string fonts[];
    int x_positions[];
    int y_positions[];
    int idx = 0;

    int header_y = panel_y + 12;
    int content_y = card_y + 15;

    // === HEADER ===
    AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                         "⚡ SMC TRADING DASHBOARD ⚡", PANEL_ACCENT_PRIMARY, 13, "Arial Black",
                         panel_x + 20, header_y);

    AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                         StringFormat("%s • %d Objects Active", TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), esd_objects),
                         PANEL_TEXT_MUTED, 8, "Consolas",
                         panel_x + 20, header_y + 20);

    // Status badge
    if (show_filters)
    {
        AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                             StringFormat("● %s | %.0f%% | %d/%d", status_text, score, passed_filters, total_filters),
                             status_color, 10, "Arial Black",
                             panel_x + 550, header_y + 8);
    }

    // === LEFT CARD: FILTER STATUS ===
    if (show_filters)
    {
        int left_x = panel_x + 25;
        int left_y = content_y;

        AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                             "🛡 FILTERS", PANEL_ACCENT_PRIMARY, 10, "Arial Black",
                             left_x, left_y);

        left_y += 25;

        int filter_count = 0;
        for (int i = 0; i < ArraySize(ESD_filter_status); i++)
        {
            if (!ESD_filter_status[i].enabled)
                continue;

            string icon = ESD_filter_status[i].passed ? "●" : "○";
            color col = ESD_filter_status[i].passed ? PANEL_ACCENT_SUCCESS : PANEL_ACCENT_DANGER;

            // Shorten filter names if too long
            string filter_name = ESD_filter_status[i].name;
            if (StringLen(filter_name) > 25)
                filter_name = StringSubstr(filter_name, 0, 22) + "...";

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 StringFormat("%s  %s", icon, filter_name),
                                 col, 9, "Segoe UI",
                                 left_x, left_y);

            left_y += 18;
            filter_count++;

            // Limit display to prevent overflow
            if (filter_count >= 12)
                break;
        }
    }

    // === RIGHT CARD: PERFORMANCE + AI ===
    if (show_trading || show_ml)
    {
        int right_x = panel_x + 25 + card_w + card_gap;
        int right_y = content_y;

        // Get positions info
        int buy_positions = 0;
        int sell_positions = 0;
        double total_floating = 0;

        for (int i = 0; i < PositionsTotal(); i++)
        {
            if (PositionGetSymbol(i) == _Symbol)
            {
                ulong magic = PositionGetInteger(POSITION_MAGIC);
                if (magic == ESD_MagicNumber)
                {
                    if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                        buy_positions++;
                    else
                        sell_positions++;

                    total_floating += PositionGetDouble(POSITION_PROFIT);
                }
            }
        }

        // Market info
        double spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
        int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

        // PERFORMANCE SECTION
        if (show_trading)
        {
            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 "📊 PERFORMANCE", PANEL_ACCENT_INFO, 10, "Arial Black",
                                 right_x, right_y);

            right_y += 22;

            color wr_color = ESD_trade_data.win_rate >= 60 ? PANEL_ACCENT_SUCCESS : ESD_trade_data.win_rate >= 40 ? PANEL_ACCENT_WARNING
                                                                                                                  : PANEL_ACCENT_DANGER;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 StringFormat("Trades: %d  •  Win: %.1f%%  •  PF: %.2f",
                                              ESD_trade_data.total_trades, ESD_trade_data.win_rate,
                                              ESD_trade_data.profit_factor),
                                 wr_color, 8, "Consolas",
                                 right_x, right_y);

            right_y += 16;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 StringFormat("Expectancy: $%.2f", ESD_trade_data.expectancy),
                                 PANEL_TEXT_PRIMARY, 8, "Consolas",
                                 right_x, right_y);

            right_y += 18;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 "─────────────────────────────", PANEL_DIVIDER, 8, "Consolas",
                                 right_x, right_y);

            right_y += 16;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 "💰 ACCOUNT", PANEL_TEXT_SECONDARY, 8, "Arial",
                                 right_x, right_y);

            right_y += 16;

            double margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
            color margin_color = margin_level > 500 ? PANEL_ACCENT_SUCCESS : margin_level > 200 ? PANEL_ACCENT_WARNING
                                                                                                : PANEL_ACCENT_DANGER;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 StringFormat("Bal: $%.0f • Eq: $%.0f • ML: %.0f%%",
                                              AccountInfoDouble(ACCOUNT_BALANCE),
                                              AccountInfoDouble(ACCOUNT_EQUITY),
                                              margin_level),
                                 margin_color, 8, "Consolas",
                                 right_x, right_y);

            right_y += 16;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 StringFormat("Free: $%.2f", AccountInfoDouble(ACCOUNT_MARGIN_FREE)),
                                 PANEL_TEXT_PRIMARY, 8, "Consolas",
                                 right_x, right_y);

            right_y += 18;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 "─────────────────────────────", PANEL_DIVIDER, 8, "Consolas",
                                 right_x, right_y);

            right_y += 16;

            // POSITIONS
            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 "📍 POSITIONS", PANEL_TEXT_SECONDARY, 8, "Arial",
                                 right_x, right_y);

            right_y += 16;

            color float_color = total_floating >= 0 ? PANEL_ACCENT_SUCCESS : PANEL_ACCENT_DANGER;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 StringFormat("Buy: %d • Sell: %d • Float: $%.2f",
                                              buy_positions, sell_positions, total_floating),
                                 float_color, 8, "Consolas",
                                 right_x, right_y);

            right_y += 16;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 StringFormat("Spread: %.0f pts • Lot: %.2f", spread, ESD_LotSize),
                                 PANEL_TEXT_MUTED, 8, "Consolas",
                                 right_x, right_y);

            right_y += 18;
        }

        // AI SECTION
        if (show_ml)
        {
            if (show_trading)
            {
                AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                     "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", PANEL_DIVIDER, 8, "Consolas",
                                     right_x, right_y);
                right_y += 16;
            }

            double ml_perf = ESD_ml_performance.win_rate * 100;
            color ml_color = ml_perf >= 70 ? PANEL_ACCENT_SUCCESS : ml_perf >= 50 ? PANEL_ACCENT_WARNING
                                                                                  : PANEL_ACCENT_DANGER;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 "🤖 AI OPTIMIZATION", PANEL_ACCENT_PURPLE, 10, "Arial Black",
                                 right_x, right_y);

            right_y += 20;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 StringFormat("Acc: %.1f%% • Risk: %.2f • Trend: %.2f",
                                              ml_perf, ESD_ml_risk_appetite, ESD_ml_trend_weight),
                                 ml_color, 8, "Consolas",
                                 right_x, right_y);

            right_y += 16;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 StringFormat("Vol: %.2f • Lot: %.2fx • SL: %.2fx",
                                              ESD_ml_volatility_weight, ESD_ml_lot_size_multiplier,
                                              ESD_ml_optimal_sl_multiplier),
                                 PANEL_TEXT_PRIMARY, 8, "Consolas",
                                 right_x, right_y);

            right_y += 16;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 StringFormat("TP: %.2fx", ESD_ml_optimal_tp_multiplier),
                                 PANEL_ACCENT_INFO, 8, "Consolas",
                                 right_x, right_y);
        }
    }

    // === Render all text ===
    for (int i = 0; i < ArraySize(lines); i++)
    {
        string obj = base_name + IntegerToString(i);
        ObjectCreate(0, obj, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x_positions[i]);
        ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y_positions[i]);
        ObjectSetInteger(0, obj, OBJPROP_COLOR, colors[i]);
        ObjectSetInteger(0, obj, OBJPROP_FONTSIZE, font_sizes[i]);
        ObjectSetString(0, obj, OBJPROP_FONT, fonts[i]);
        ObjectSetInteger(0, obj, OBJPROP_BACK, false);
        ObjectSetString(0, obj, OBJPROP_TEXT, lines[i]);
    }

    ChartRedraw();
}

void ESD_DrawFilterMonitor()
{
    ESD_DrawUnifiedDashboard();
}

void ESD_DrawTradingDataPanel()
{
    ESD_DrawUnifiedDashboard();
}

void ESD_DebugPanelStatus()
{
    int total_objects = ObjectsTotal(0, -1, -1);
    int esd_objects = 0;

    Print("=== ESD PANEL DEBUG INFO ===");
    Print("Total objects on chart: ", total_objects);
    Print("Input Parameters:");
    Print("  ESD_ShowFilterMonitor: ", ESD_ShowFilterMonitor);
    Print("  ESD_ShowTradingData: ", ESD_ShowTradingData);

    // List all ESD objects
    Print("ESD Objects on chart:");
    for (int i = 0; i < total_objects; i++)
    {
        string name = ObjectName(0, i, -1, -1);
        if (StringFind(name, "ESD_", 0) == 0)
        {
            esd_objects++;
            int type = (int)ObjectGetInteger(0, name, OBJPROP_TYPE);
            string type_str = "";
            switch (type)
            {
            case OBJ_RECTANGLE_LABEL:
                type_str = "RECTANGLE_LABEL";
                break;
            case OBJ_LABEL:
                type_str = "LABEL";
                break;
            case OBJ_TEXT:
                type_str = "TEXT";
                break;
            default:
                type_str = "OTHER";
                break;
            }
            Print("  ", name, " (", type_str, ")");
        }
    }

    Print("Total ESD objects found: ", esd_objects);

    // Check if main panels exist
    bool main_panel_exists = (ObjectFind(0, "ESD_MainPanel") >= 0);
    bool left_card_exists = (ObjectFind(0, "ESD_LeftCard") >= 0);
    bool right_card_exists = (ObjectFind(0, "ESD_RightCard") >= 0);

    Print("Panel Status:");
    Print("  Main Panel: ", (main_panel_exists ? "EXISTS" : "MISSING"));
    Print("  Left Card: ", (left_card_exists ? "EXISTS" : "MISSING"));
    Print("  Right Card: ", (right_card_exists ? "EXISTS" : "MISSING"));

    Print("=================================");
}

string ESD_GetSystemInfo()
{
    string system_info = "=== SYSTEM INFORMATION ===\n";

    // Account Information
    system_info += "Account: " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "\n";
    system_info += "Balance: $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n";
    system_info += "Equity: $" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "\n";
    system_info += "Free Margin: $" + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2) + "\n";
    system_info += "Margin Level: " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), 2) + "%\n\n";

    // Current Positions
    int buy_positions = 0;
    int sell_positions = 0;
    double total_floating = 0;

    for (int i = 0; i < PositionsTotal(); i++)
    {
        if (PositionGetSymbol(i) == _Symbol)
        {
            ulong magic = PositionGetInteger(POSITION_MAGIC);
            if (magic == ESD_MagicNumber)
            {
                if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                    buy_positions++;
                else
                    sell_positions++;

                total_floating += PositionGetDouble(POSITION_PROFIT);
            }
        }
    }

    system_info += "Active Positions:\n";
    system_info += "  Buy: " + IntegerToString(buy_positions) + "\n";
    system_info += "  Sell: " + IntegerToString(sell_positions) + "\n";
    system_info += "  Floating: $" + DoubleToString(total_floating, 2) + "\n\n";

    // Market Conditions
    double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    system_info += "Market Conditions:\n";
    system_info += "  Spread: " + DoubleToString(spread / SymbolInfoDouble(_Symbol, SYMBOL_POINT), 0) + " pts\n";
    system_info += "  Digits: " + IntegerToString((int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) + "\n";
    system_info += "  Lot Size: " + DoubleToString(ESD_LotSize, 2) + "\n";
    system_info += "  Magic: " + IntegerToString(ESD_MagicNumber) + "\n";

    return system_info;
}

//+------------------------------------------------------------------+
//| Enhanced OnInit with Debug Capability                          |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("ESD EA Initializing...");

    ESD_InitializeFilterMonitoring();
    ESD_InitializeTradingData();

    ESD_trade.SetExpertMagicNumber(ESD_MagicNumber);
    ESD_trade.SetDeviationInPoints(ESD_Slippage);

    ESD_InitializeML();

    OnInitDragon();

    // Initialize trend state based on historical data
    ESD_DetectInitialTrend();

    // Initialize supreme timeframe trend
    if (ESD_UseMultiTimeframeAnalysis)
        ESD_DetectSupremeTimeframeTrend();

    if (ESD_ShowObjects)
        ESD_DeleteObjects();

    // Initialize panels
    ESD_InitializeMonitoringPanels();

    Print("ESD EA Initialized Successfully");
    Print("Filter Monitor: ", (ESD_ShowFilterMonitor ? "ENABLED" : "DISABLED"));
    Print("Trading Data: ", (ESD_ShowTradingData ? "ENABLED" : "DISABLED"));

    return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("ESD EA Deinitializing... Reason: ", reason);

    ESD_DeleteAllMonitoringPanels();

    if (ESD_ShowObjects)
        ESD_DeleteObjects();

    Print("ESD EA Deinitialized Successfully");
}

//+------------------------------------------------------------------+
//| Chart Event Handler for Manual Testing                          |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    static bool panels_enabled = true;

    // Press 'P' key to toggle panels
    if (id == CHARTEVENT_KEYDOWN && lparam == 'P')
    {
        panels_enabled = !panels_enabled;

        if (panels_enabled)
        {
            // Recreate panels
            ESD_InitializeMonitoringPanels();
            Print("Panels ENABLED");
        }
        else
        {
            // Remove panels
            ESD_DeleteAllMonitoringPanels();
            Print("Panels DISABLED");
        }

        // Force chart redraw
        ChartRedraw();
    }

    // Press 'D' key for debug info
    if (id == CHARTEVENT_KEYDOWN && lparam == 'D')
    {
        ESD_DebugPanelStatus();
    }

    // Press 'R' key to refresh panels
    if (id == CHARTEVENT_KEYDOWN && lparam == 'R')
    {
        ESD_InitializeMonitoringPanels();
        Print("Panels Refreshed");
        ChartRedraw();
    }

    // Press '1' key to show/hide filter monitor
    if (id == CHARTEVENT_KEYDOWN && lparam == '1')
    {
        if (ESD_ShowFilterMonitor)
        {
            ESD_DrawFilterMonitor();
            Print("Filter Monitor SHOWN");
        }
        else
        {
            ESD_DeleteFilterMonitor();
            Print("Filter Monitor HIDDEN (parameter disabled)");
        }
    }
}

//+------------------------------------------------------------------+
//|                    Enhanced TP System dengan Visual Objects     |
//+------------------------------------------------------------------+

//--- TP Enhancement Settings
input bool ESD_ShowTPObjects = true;  // Tampilkan garis TP di chart
input color ESD_TP1_Color = clrGreen; // Warna TP1
input color ESD_TP2_Color = clrBlue;  // Warna TP2
input color ESD_TP3_Color = clrRed;   // Warna TP3
input int ESD_TP_Width = 2;           // Ketebalan garis TP
input bool ESD_UseAdaptiveTP = true;  // Adaptive TP berdasarkan market structure
input double ESD_TP_Multiplier = 1.5; // Multiplier untuk TP distance

//--- Global Variables untuk TP Enhancement
double ESD_current_tp1 = 0.0, ESD_current_tp2 = 0.0, ESD_current_tp3 = 0.0;
bool ESD_tp1_hit = false, ESD_tp2_hit = false, ESD_tp3_hit = false;

//+------------------------------------------------------------------+
//| Enhanced TP Object Management                                   |
//+------------------------------------------------------------------+
void ESD_DrawTPObjects()
{
    if (!ESD_ShowTPObjects)
        return;

    string prefix = "ESD_TP_";
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // Hapus objek TP lama
    for (int i = ObjectsTotal(0) - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i);
        if (StringFind(name, prefix) != -1)
            ObjectDelete(0, name);
    }

    // Gambar TP lines untuk setiap posisi aktif
    for (int i = 0; i < PositionsTotal(); i++)
    {
        if (PositionGetTicket(i) &&
            PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == ESD_MagicNumber)
        {
            ulong pos_type = PositionGetInteger(POSITION_TYPE);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);

            if (pos_type == POSITION_TYPE_BUY)
            {
                if (ESD_current_tp1 > 0 && !ESD_tp1_hit)
                    ESD_CreateTPLine(prefix + "BUY_1", ESD_current_tp1, ESD_TP1_Color, "TP1");
                if (ESD_current_tp2 > 0 && !ESD_tp2_hit)
                    ESD_CreateTPLine(prefix + "BUY_2", ESD_current_tp2, ESD_TP2_Color, "TP2");
                if (ESD_current_tp3 > 0 && !ESD_tp3_hit)
                    ESD_CreateTPLine(prefix + "BUY_3", ESD_current_tp3, ESD_TP3_Color, "TP3");
            }
            else if (pos_type == POSITION_TYPE_SELL)
            {
                if (ESD_current_tp1 > 0 && !ESD_tp1_hit)
                    ESD_CreateTPLine(prefix + "SELL_1", ESD_current_tp1, ESD_TP1_Color, "TP1");
                if (ESD_current_tp2 > 0 && !ESD_tp2_hit)
                    ESD_CreateTPLine(prefix + "SELL_2", ESD_current_tp2, ESD_TP2_Color, "TP2");
                if (ESD_current_tp3 > 0 && !ESD_tp3_hit)
                    ESD_CreateTPLine(prefix + "SELL_3", ESD_current_tp3, ESD_TP3_Color, "TP3");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Create TP Line Object                                           |
//+------------------------------------------------------------------+
void ESD_CreateTPLine(string name, double price, color clr, string text)
{
    if (!ObjectCreate(0, name, OBJ_HLINE, 0, 0, price))
    {
        Print("Failed to create TP line: ", GetLastError());
        return;
    }

    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, ESD_TP_Width);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetString(0, name, OBJPROP_TEXT, text);

    // Tambahkan label harga
    string label_name = name + "_LABEL";
    if (ObjectCreate(0, label_name, OBJ_TEXT, 0, TimeCurrent(), price))
    {
        ObjectSetString(0, label_name, OBJPROP_TEXT, "TP: " + DoubleToString(price, _Digits));
        ObjectSetInteger(0, label_name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, ANCHOR_LEFT);
        ObjectSetInteger(0, label_name, OBJPROP_BACK, false);
    }
}

//+------------------------------------------------------------------+
//| PowerPull TP Calculation - Enhanced Version                     |
//+------------------------------------------------------------------+
void ESD_CalculateEnhancedTP(bool is_buy, double entry_price)
{
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double atr = iATR(_Symbol, PERIOD_CURRENT, 14);

    if (is_buy)
    {
        // 🎯 TP1: Immediate Resistance (FVG/Liquidity)
        ESD_current_tp1 = ESD_GetNearestBearishLevel(entry_price);
        if (ESD_current_tp1 <= entry_price)
            ESD_current_tp1 = entry_price + (ESD_UseAdaptiveTP ? atr * 2 : 1000 * point);

        // 🎯 TP2: Swing High + ATR Buffer
        ESD_current_tp2 = ESD_GetSwingHighWithBuffer();
        if (ESD_current_tp2 <= ESD_current_tp1)
            ESD_current_tp2 = ESD_current_tp1 + (ESD_UseAdaptiveTP ? atr * 3 : 1000 * point);

        // 🎯 TP3: Major HTF Resistance dengan multiplier
        ESD_current_tp3 = ESD_GetMajorResistance();
        if (ESD_current_tp3 <= ESD_current_tp2)
            ESD_current_tp3 = ESD_current_tp2 + (ESD_UseAdaptiveTP ? atr * 4 : 1500 * point);

        // Apply multiplier untuk lebih aggressive
        if (ESD_TP_Multiplier > 1.0)
        {
            double base_move = (ESD_current_tp1 - entry_price) * (ESD_TP_Multiplier - 1.0);
            ESD_current_tp1 += base_move * 0.3;
            ESD_current_tp2 += base_move * 0.5;
            ESD_current_tp3 += base_move * 0.8;
        }
    }
    else
    {
        // 🎯 TP1: Immediate Support (FVG/Liquidity)
        ESD_current_tp1 = ESD_GetNearestBullishLevel(entry_price);
        if (ESD_current_tp1 >= entry_price)
            ESD_current_tp1 = entry_price - (ESD_UseAdaptiveTP ? atr * 2 : 1000 * point);

        // 🎯 TP2: Swing Low + ATR Buffer
        ESD_current_tp2 = ESD_GetSwingLowWithBuffer();
        if (ESD_current_tp2 >= ESD_current_tp1)
            ESD_current_tp2 = ESD_current_tp1 - (ESD_UseAdaptiveTP ? atr * 3 : 1000 * point);

        // 🎯 TP3: Major HTF Support dengan multiplier
        ESD_current_tp3 = ESD_GetMajorSupport();
        if (ESD_current_tp3 >= ESD_current_tp2)
            ESD_current_tp3 = ESD_current_tp2 - (ESD_UseAdaptiveTP ? atr * 4 : 1500 * point);

        // Apply multiplier untuk lebih aggressive
        if (ESD_TP_Multiplier > 1.0)
        {
            double base_move = (entry_price - ESD_current_tp1) * (ESD_TP_Multiplier - 1.0);
            ESD_current_tp1 -= base_move * 0.3;
            ESD_current_tp2 -= base_move * 0.5;
            ESD_current_tp3 -= base_move * 0.8;
        }
    }

    // Reset TP hit flags
    ESD_tp1_hit = ESD_tp2_hit = ESD_tp3_hit = false;

    Print("Enhanced TP Calculated - TP1: ", ESD_current_tp1, " TP2: ", ESD_current_tp2, " TP3: ", ESD_current_tp3);
}

//+------------------------------------------------------------------+
//| Get Nearest Bearish Level (Untuk BUY TP)                        |
//+------------------------------------------------------------------+
double ESD_GetNearestBearishLevel(double current_price)
{
    double levels[10];
    int count = 0;

    // Priority 1: Bearish FVG Top
    if (ESD_bearish_fvg_top != EMPTY_VALUE && ESD_bearish_fvg_top > current_price)
        levels[count++] = ESD_bearish_fvg_top;

    // Priority 2: Bearish Liquidity
    if (ESD_bearish_liquidity != EMPTY_VALUE && ESD_bearish_liquidity > current_price)
        levels[count++] = ESD_bearish_liquidity;

    // Priority 3: Recent Swing High
    double recent_high = ESD_GetRecentSwingHigh();
    if (recent_high > current_price)
        levels[count++] = recent_high;

    // Priority 4: Order Block Resistance
    double ob_resistance = ESD_GetOrderBlockResistance();
    if (ob_resistance > current_price)
        levels[count++] = ob_resistance;

    // Return the nearest level
    if (count > 0)
    {
        double nearest = levels[0];
        for (int i = 1; i < count; i++)
        {
            if (levels[i] < nearest)
                nearest = levels[i];
        }
        return nearest;
    }

    return 0;
}

//+------------------------------------------------------------------+
//| Get Nearest Bullish Level (Untuk SELL TP)                       |
//+------------------------------------------------------------------+
double ESD_GetNearestBullishLevel(double current_price)
{
    double levels[10];
    int count = 0;

    // Priority 1: Bullish FVG Bottom
    if (ESD_bullish_fvg_bottom != EMPTY_VALUE && ESD_bullish_fvg_bottom < current_price)
        levels[count++] = ESD_bullish_fvg_bottom;

    // Priority 2: Bullish Liquidity
    if (ESD_bullish_liquidity != EMPTY_VALUE && ESD_bullish_liquidity < current_price)
        levels[count++] = ESD_bullish_liquidity;

    // Priority 3: Recent Swing Low
    double recent_low = ESD_GetRecentSwingLow();
    if (recent_low < current_price)
        levels[count++] = recent_low;

    // Priority 4: Order Block Support
    double ob_support = ESD_GetOrderBlockSupport();
    if (ob_support < current_price)
        levels[count++] = ob_support;

    // Return the nearest level
    if (count > 0)
    {
        double nearest = levels[0];
        for (int i = 1; i < count; i++)
        {
            if (levels[i] > nearest)
                nearest = levels[i];
        }
        return nearest;
    }

    return 0;
}

//+------------------------------------------------------------------+
//| Execute Partial Close dengan Validation                         |
//+------------------------------------------------------------------+
bool ESD_ExecutePartialClose(ulong ticket, double volume, string reason)
{
    double min_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

    if (volume < min_volume)
    {
        Print("Volume too small for partial close. Required: ", min_volume, " Has: ", volume);
        return false;
    }

    if (ESD_trade.PositionClosePartial(ticket, volume))
    {
        Print("Partial Close (", reason, ") executed: ", volume, " lots");
        return true;
    }
    else
    {
        Print("Partial Close failed: ", ESD_trade.ResultRetcodeDescription());
        return false;
    }
}

//+------------------------------------------------------------------+
//| Profit Protection Logic                                         |
//+------------------------------------------------------------------+
bool ESD_ShouldProtectProfit(ulong ticket, double profit)
{
    double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
    double current_price = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // Jika profit sudah besar tapi harga stuck/menolak di level tertentu
    double profit_points = MathAbs(current_price - open_price) / point;
    double expected_tp1 = ESD_UseAdaptiveTP ? 800 : ESD_PartialTPDistance1;

    // Close jika sudah melebihi TP1 expected distance tapi belum kena TP
    if (profit_points > expected_tp1 * 1.2 && profit > 0)
    {
        // Cek apakah harga sudah mulai reject
        if (ESD_IsPriceRejecting(current_price))
        {
            Print("Profit Protection: Price rejecting at high profit level");
            return true;
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Price Rejection Detection                                       |
//+------------------------------------------------------------------+
bool ESD_IsPriceRejecting(double current_price)
{
    MqlRates rates[];
    ArraySetAsSeries(rates, true);

    if (CopyRates(_Symbol, PERIOD_CURRENT, 0, 3, rates) == 3)
    {
        // Deteksi pin bar atau rejection candle
        if (rates[0].close < rates[0].open &&
            (rates[0].high - rates[0].open) > (rates[0].open - rates[0].close) * 2)
            return true;

        // Deteksi double top/bottom pattern
        if (MathAbs(rates[0].high - rates[2].high) < SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10)
            return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Remove TP Objects                                              |
//+------------------------------------------------------------------+
void ESD_RemoveTPObjects()
{
    string prefix = "ESD_TP_";
    for (int i = ObjectsTotal(0) - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i);
        if (StringFind(name, prefix) != -1)
            ObjectDelete(0, name);
    }
}

//+------------------------------------------------------------------+
//| Helper Functions untuk Enhanced TP                             |
//+------------------------------------------------------------------+

double ESD_GetRecentSwingHigh()
{
    double high_buffer[];
    ArraySetAsSeries(high_buffer, true);
    CopyHigh(_Symbol, PERIOD_CURRENT, 0, 50, high_buffer);
    return high_buffer[ArrayMaximum(high_buffer, 0, 50)];
}

double ESD_GetRecentSwingLow()
{
    double low_buffer[];
    ArraySetAsSeries(low_buffer, true);
    CopyLow(_Symbol, PERIOD_CURRENT, 0, 50, low_buffer);
    return low_buffer[ArrayMinimum(low_buffer, 0, 50)];
}

double ESD_GetSwingHighWithBuffer()
{
    double swing_high = ESD_GetRecentSwingHigh();
    double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
    return swing_high > 0 ? swing_high - (atr * 0.5) : 0;
}

double ESD_GetSwingLowWithBuffer()
{
    double swing_low = ESD_GetRecentSwingLow();
    double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
    return swing_low > 0 ? swing_low + (atr * 0.5) : 0;
}

double ESD_GetMajorResistance()
{
    // Combine HTF swing high dengan volume profile POC
    double htf_high = ESD_GetHTFSwingHigh();
    if (ESD_poc_price > 0 && ESD_poc_price > htf_high)
        return ESD_poc_price;
    return htf_high;
}

double ESD_GetMajorSupport()
{
    // Combine HTF swing low dengan volume profile POC
    double htf_low = ESD_GetHTFSwingLow();
    if (ESD_poc_price > 0 && ESD_poc_price < htf_low)
        return ESD_poc_price;
    return htf_low;
}

//+------------------------------------------------------------------+
//| Get Order Block Resistance Level                                |
//+------------------------------------------------------------------+
double ESD_GetOrderBlockResistance()
{
    // Jika bearish OB tersedia, kembalikan nilai
    if (ESD_bearish_ob_top != EMPTY_VALUE && ESD_bearish_ob_top > 0)
        return ESD_bearish_ob_top;

    // Fallback: cari resistance terdekat dari harga saat ini
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    int bars = 50;
    double high_buffer[];
    ArraySetAsSeries(high_buffer, true);

    if (CopyHigh(_Symbol, PERIOD_CURRENT, 0, bars, high_buffer) > 0)
    {
        // Cari swing high terdekat di atas harga saat ini
        double resistance = 0;
        for (int i = 3; i < bars - 3; i++)
        {
            if (high_buffer[i] > current_price &&
                high_buffer[i] > high_buffer[i - 1] && high_buffer[i] > high_buffer[i - 2] &&
                high_buffer[i] > high_buffer[i + 1] && high_buffer[i] > high_buffer[i + 2])
            {
                if (resistance == 0 || high_buffer[i] < resistance) // Cari yang terdekat
                    resistance = high_buffer[i];
            }
        }

        if (resistance > 0)
            return NormalizeDouble(resistance, _Digits);
    }

    // Final fallback: harga saat ini + buffer
    return NormalizeDouble(current_price + (100 * _Point), _Digits);
}

//+------------------------------------------------------------------+
//| Get Order Block Support Level                                   |
//+------------------------------------------------------------------+
double ESD_GetOrderBlockSupport()
{
    // Jika bullish OB tersedia, kembalikan nilai
    if (ESD_bullish_ob_bottom != EMPTY_VALUE && ESD_bullish_ob_bottom > 0)
        return ESD_bullish_ob_bottom;

    // Fallback: cari support terdekat dari harga saat ini
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    int bars = 50;
    double low_buffer[];
    ArraySetAsSeries(low_buffer, true);

    if (CopyLow(_Symbol, PERIOD_CURRENT, 0, bars, low_buffer) > 0)
    {
        // Cari swing low terdekat di bawah harga saat ini
        double support = 0;
        for (int i = 3; i < bars - 3; i++)
        {
            if (low_buffer[i] < current_price &&
                low_buffer[i] < low_buffer[i - 1] && low_buffer[i] < low_buffer[i - 2] &&
                low_buffer[i] < low_buffer[i + 1] && low_buffer[i] < low_buffer[i + 2])
            {
                if (support == 0 || low_buffer[i] > support) // Cari yang terdekat
                    support = low_buffer[i];
            }
        }

        if (support > 0)
            return NormalizeDouble(support, _Digits);
    }

    // Final fallback: harga saat ini - buffer
    return NormalizeDouble(current_price - (100 * _Point), _Digits);
}

//+------------------------------------------------------------------+
//| Liquidity Zone Trading Settings                                 |
//+------------------------------------------------------------------+
input bool ESD_UseLiquidityZones = true;        // Enable liquidity zone trading
input int ESD_LiquidityZonePoints = 50;         // Zone size in points
input int ESD_LiquidityEntryOffset = 5;         // Entry offset from liquidity level (points)
input int ESD_LiquiditySLPoints = 30;           // SL distance from entry (points)
input int ESD_LiquidityTPPoints = 45;           // TP distance from entry (points)
input double ESD_LiquidityLotSize = 0.8;       // Lot size for liquidity trades
input bool ESD_ShowLiquidityZones = true;       // Show liquidity zones on chart
input color ESD_LiquidityZoneColor = clrYellow; // Liquidity zone color

//+------------------------------------------------------------------+
//| Liquidity Trading Variables                                     |
//+------------------------------------------------------------------+
double ESD_upper_liquidity_zone = EMPTY_VALUE;
double ESD_lower_liquidity_zone = EMPTY_VALUE;
datetime ESD_last_liquidity_update = 0;

//+------------------------------------------------------------------+
//| Detect Liquidity Zones                                          |
//+------------------------------------------------------------------+
void ESD_DetectLiquidityZones()
{
    if (!ESD_UseLiquidityZones)
        return;

    int bars_to_check = 100;
    double high_buffer[], low_buffer[];
    ArraySetAsSeries(high_buffer, true);
    ArraySetAsSeries(low_buffer, true);

    CopyHigh(_Symbol, PERIOD_CURRENT, 0, bars_to_check, high_buffer);
    CopyLow(_Symbol, PERIOD_CURRENT, 0, bars_to_check, low_buffer);

    // Find recent significant highs and lows for liquidity zones
    double recent_high = high_buffer[ArrayMaximum(high_buffer, 0, 20)];
    double recent_low = low_buffer[ArrayMinimum(low_buffer, 0, 20)];

    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double zone_size = ESD_LiquidityZonePoints * point;

    // Update liquidity zones
    ESD_upper_liquidity_zone = recent_high;
    ESD_lower_liquidity_zone = recent_low;

    ESD_last_liquidity_update = TimeCurrent();

    // Draw liquidity zones if enabled
    if (ESD_ShowLiquidityZones)
    {
        ESD_DrawLiquidityZones();
    }
}

//+------------------------------------------------------------------+
//| Draw Liquidity Zones                                            |
//+------------------------------------------------------------------+
void ESD_DrawLiquidityZones()
{
    if (!ESD_ShowLiquidityZones)
        return;

    string upper_zone_name = "ESD_UpperLiquidityZone";
    string lower_zone_name = "ESD_LowerLiquidityZone";

    // Delete old zones
    if (ObjectFind(0, upper_zone_name) >= 0)
        ObjectDelete(0, upper_zone_name);
    if (ObjectFind(0, lower_zone_name) >= 0)
        ObjectDelete(0, lower_zone_name);

    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double zone_size = ESD_LiquidityZonePoints * point;

    // Draw upper liquidity zone
    if (ESD_upper_liquidity_zone != EMPTY_VALUE)
    {
        ObjectCreate(0, upper_zone_name, OBJ_RECTANGLE, 0,
                     iTime(_Symbol, PERIOD_CURRENT, 20), ESD_upper_liquidity_zone,
                     iTime(_Symbol, PERIOD_CURRENT, 0), ESD_upper_liquidity_zone + zone_size);
        ObjectSetInteger(0, upper_zone_name, OBJPROP_COLOR, ESD_LiquidityZoneColor);
        ObjectSetInteger(0, upper_zone_name, OBJPROP_BGCOLOR, ColorToARGB(ESD_LiquidityZoneColor, 40));
        ObjectSetInteger(0, upper_zone_name, OBJPROP_BACK, true);
        ObjectSetInteger(0, upper_zone_name, OBJPROP_SELECTABLE, false);
    }

    // Draw lower liquidity zone
    if (ESD_lower_liquidity_zone != EMPTY_VALUE)
    {
        ObjectCreate(0, lower_zone_name, OBJ_RECTANGLE, 0,
                     iTime(_Symbol, PERIOD_CURRENT, 20), ESD_lower_liquidity_zone - zone_size,
                     iTime(_Symbol, PERIOD_CURRENT, 0), ESD_lower_liquidity_zone);
        ObjectSetInteger(0, lower_zone_name, OBJPROP_COLOR, ESD_LiquidityZoneColor);
        ObjectSetInteger(0, lower_zone_name, OBJPROP_BGCOLOR, ColorToARGB(ESD_LiquidityZoneColor, 40));
        ObjectSetInteger(0, lower_zone_name, OBJPROP_BACK, true);
        ObjectSetInteger(0, lower_zone_name, OBJPROP_SELECTABLE, false);
    }

    // Check entries jika tidak ada posisi terbuka dan trading diaktifkan
    if (ESD_UseLiquidityZones)
    {
        ESD_CheckLiquidityZoneEntries();
    }
}

//+------------------------------------------------------------------+
//| Check Liquidity Zone Entries                                    |
//+------------------------------------------------------------------+
void ESD_CheckLiquidityZoneEntries()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    double entry_offset = ESD_LiquidityEntryOffset * point;
    double sl_distance = ESD_LiquiditySLPoints * point;
    double tp_distance = ESD_LiquidityTPPoints * point;

    // Get current candle for confirmation
    MqlRates current_rates[];
    ArraySetAsSeries(current_rates, true);
    if (CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, current_rates) <= 0)
        return;

    bool current_bullish = (current_rates[0].close > current_rates[0].open);
    bool current_bearish = (current_rates[0].close < current_rates[0].open);

    // Check upper liquidity zone (SELL entries)
    if (ESD_upper_liquidity_zone != EMPTY_VALUE &&
        bid >= ESD_upper_liquidity_zone - entry_offset &&
        bid <= ESD_upper_liquidity_zone + entry_offset)
    {
        if (current_bearish && ESD_IsValidLiquidityEntry(false))
        {
            double entry_price = bid;
            double sl = entry_price + sl_distance;
            double tp = entry_price - tp_distance;

            // Validate SL/TP
            if (sl > entry_price && tp < entry_price)
            {
                string comment = "Liquidity Zone SELL";
                if (ESD_trade.Sell(ESD_LiquidityLotSize, _Symbol, entry_price, sl, tp, comment))
                {
                    Print("Liquidity SELL executed at: ", entry_price, " SL: ", sl, " TP: ", tp);
                }
            }
        }
    }

    // Check lower liquidity zone (BUY entries)
    if (ESD_lower_liquidity_zone != EMPTY_VALUE &&
        ask <= ESD_lower_liquidity_zone + entry_offset &&
        ask >= ESD_lower_liquidity_zone - entry_offset)
    {
        if (current_bullish && ESD_IsValidLiquidityEntry(true))
        {
            double entry_price = ask;
            double sl = entry_price - sl_distance;
            double tp = entry_price + tp_distance;

            // Validate SL/TP
            if (sl < entry_price && tp > entry_price)
            {
                string comment = "Liquidity Zone BUY";
                if (ESD_trade.Buy(ESD_LiquidityLotSize, _Symbol, entry_price, sl, tp, comment))
                {
                    Print("Liquidity BUY executed at: ", entry_price, " SL: ", sl, " TP: ", tp);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Validate Liquidity Zone Entry                                   |
//+------------------------------------------------------------------+
bool ESD_IsValidLiquidityEntry(bool is_buy)
{
    // Additional filters for liquidity zone entries

    // 1. Check if we're not in a strong counter-trend
    if (is_buy && ESD_bearish_trend_strength > 0.7)
        return false;
    if (!is_buy && ESD_bullish_trend_strength > 0.7)
        return false;

    // 2. Check volume/order flow confirmation
    if (ESD_UseOrderFlow && MathAbs(ESD_orderflow_strength) < 20)
        return false;

    // 3. Check heatmap confirmation
    if (ESD_UseHeatmapFilter)
    {
        if (is_buy && ESD_heatmap_strength < -30)
            return false;
        if (!is_buy && ESD_heatmap_strength > 30)
            return false;
    }

    // 4. Check if price is at extreme (overbought/oversold)
    double rsi[];
    ArraySetAsSeries(rsi, true);
    int rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);

    if (CopyBuffer(rsi_handle, 0, 0, 2, rsi) > 0)
    {
        if (is_buy && rsi[0] > 30)
            return true; // Not oversold enough for buy
        if (!is_buy && rsi[0] < 70)
            return true; // Not overbought enough for sell
    }

    return true;
}

// alternatif entry jika sinyal tidak valid
//=== ALTERNATIVE ENTRY SETTINGS ===
input bool ESD_UseAlternativeEntries = true;   // Enable alternative entry methods
input bool ESD_UseFalseBreakoutEntries = true; // False breakout retest entries
input bool ESD_UsePullbackEntries = true;      // Structure pullback entries
input bool ESD_UseMomentumEntries = true;      // Momentum continuation entries
input int ESD_FalseBreakoutLookback = 5;       // Bars to look back for false breakouts
input int ESD_PullbackConfirmationBars = 2;    // Bars for pullback confirmation
input double ESD_MomentumThreshold = 0.6;      // Minimum momentum strength (0-1)
input int ESD_AlternativeSLMultiplier = 2;     // SL multiplier for alternative entries

//--- Variabel untuk Alternative Entries
datetime ESD_last_false_breakout_time = 0;
datetime ESD_last_pullback_time = 0;
datetime ESD_last_momentum_time = 0;
double ESD_false_breakout_level = 0.0;
bool ESD_false_breakout_detected = false;

//+------------------------------------------------------------------+
//| Check Alternative Entry Opportunities                           |
//+------------------------------------------------------------------+
void ESD_CheckAlternativeEntries()
{
    // if (PositionSelect(_Symbol))
    //     return; // Skip jika sudah ada posisi

    // 1. False Breakout Retest Entry
    bool isBullish, isBearish;
    if (ESD_UseFalseBreakoutEntries && ESD_IsFalseBreakoutRetest(isBullish, isBearish))
    {
        ESD_ExecuteFalseBreakoutTrade();
        return;
    }

    // 2. Pullback Entry ke Structure
    if (ESD_UsePullbackEntries && ESD_IsStructurePullback())
    {
        ESD_ExecutePullbackTrade();
        return;
    }

    // 3. Momentum Continuation Entry
    if (ESD_UseMomentumEntries && ESD_IsMomentumContinuation())
    {
        ESD_ExecuteMomentumTrade();
        return;
    }
}

//+------------------------------------------------------------------+
//| Bullish False Breakout Detection (Bear Trap)                    |
//+------------------------------------------------------------------+
bool ESD_IsBullishFalseBreakout(const MqlRates &rates[], int total_bars, double tolerance)
{
    // Pattern: Break below support -> quick reversal -> retest
    if (ESD_last_significant_pl == 0)
        return false;

    for (int i = 2; i < total_bars - 2; i++)
    {
        // Cek break di bawah support level
        bool break_below = rates[i].low < ESD_last_significant_pl - tolerance;

        if (break_below)
        {
            // Cek reversal candle setelah break
            bool strong_reversal = (rates[i - 1].close > rates[i - 1].open) &&
                                   (rates[i - 1].close > rates[i].high);

            // Cek retest dan confirmation
            bool retest_success = rates[0].low > ESD_last_significant_pl - tolerance &&
                                  rates[0].close > ESD_last_significant_pl;

            if (strong_reversal && retest_success)
            {
                Print("Bullish False Breakout detected at: ", ESD_last_significant_pl);
                return true;
            }
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Bearish False Breakout Detection (Bull Trap)                    |
//+------------------------------------------------------------------+
bool ESD_IsBearishFalseBreakout(const MqlRates &rates[], int total_bars, double tolerance)
{
    // Pattern: Break above resistance -> quick reversal -> retest
    if (ESD_last_significant_ph == 0)
        return false;

    for (int i = 2; i < total_bars - 2; i++)
    {
        // Cek break di atas resistance level
        bool break_above = rates[i].high > ESD_last_significant_ph + tolerance;

        if (break_above)
        {
            // Cek reversal candle setelah break
            bool strong_reversal = (rates[i - 1].close < rates[i - 1].open) &&
                                   (rates[i - 1].close < rates[i].low);

            // Cek retest dan confirmation
            bool retest_success = rates[0].high < ESD_last_significant_ph + tolerance &&
                                  rates[0].close < ESD_last_significant_ph;

            if (strong_reversal && retest_success)
            {
                Print("Bearish False Breakout detected at: ", ESD_last_significant_ph);
                return true;
            }
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Structure Pullback Detection                                    |
//+------------------------------------------------------------------+
bool ESD_IsStructurePullback()
{
    if (!ESD_bullish_trend_confirmed && !ESD_bearish_trend_confirmed)
        return false;

    MqlRates rates[];
    ArraySetAsSeries(rates, true);

    if (CopyRates(_Symbol, PERIOD_CURRENT, 0, ESD_PullbackConfirmationBars + 3, rates) < ESD_PullbackConfirmationBars + 3)
        return false;

    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
    double pullback_threshold = atr * 0.5;

    // Bullish trend pullback to support
    if (ESD_bullish_trend_confirmed && ESD_bullish_trend_strength > 0.6)
    {
        // Cek apakah price pullback ke support level (FVG/OB/Swing)
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        bool near_bullish_support = false;

        if (ESD_bullish_fvg_bottom != EMPTY_VALUE)
            near_bullish_support = (current_price <= ESD_bullish_fvg_bottom + pullback_threshold) &&
                                   (current_price >= ESD_bullish_fvg_bottom - pullback_threshold);
        else if (ESD_bullish_ob_bottom != EMPTY_VALUE)
            near_bullish_support = (current_price <= ESD_bullish_ob_bottom + pullback_threshold) &&
                                   (current_price >= ESD_bullish_ob_bottom - pullback_threshold);
        else if (ESD_last_significant_pl != 0)
            near_bullish_support = (current_price <= ESD_last_significant_pl + pullback_threshold) &&
                                   (current_price >= ESD_last_significant_pl - pullback_threshold);

        if (near_bullish_support)
        {
            // Confirmation: minimal 2 bullish candles setelah pullback
            int bullish_confirmation = 0;
            for (int i = 0; i < ESD_PullbackConfirmationBars; i++)
            {
                if (rates[i].close > rates[i].open)
                    bullish_confirmation++;
            }

            if (bullish_confirmation >= 1) // Minimal 1 confirmation candle
            {
                Print("Bullish Pullback detected");
                ESD_last_pullback_time = TimeCurrent();
                return true;
            }
        }
    }

    // Bearish trend pullback to resistance
    if (ESD_bearish_trend_confirmed && ESD_bearish_trend_strength > 0.6)
    {
        // Cek apakah price pullback ke resistance level (FVG/OB/Swing)
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        bool near_bearish_resistance = false;

        if (ESD_bearish_fvg_top != EMPTY_VALUE)
            near_bearish_resistance = (current_price <= ESD_bearish_fvg_top + pullback_threshold) &&
                                      (current_price >= ESD_bearish_fvg_top - pullback_threshold);
        else if (ESD_bearish_ob_top != EMPTY_VALUE)
            near_bearish_resistance = (current_price <= ESD_bearish_ob_top + pullback_threshold) &&
                                      (current_price >= ESD_bearish_ob_top - pullback_threshold);
        else if (ESD_last_significant_ph != 0)
            near_bearish_resistance = (current_price <= ESD_last_significant_ph + pullback_threshold) &&
                                      (current_price >= ESD_last_significant_ph - pullback_threshold);

        if (near_bearish_resistance)
        {
            // Confirmation: minimal 2 bearish candles setelah pullback
            int bearish_confirmation = 0;
            for (int i = 0; i < ESD_PullbackConfirmationBars; i++)
            {
                if (rates[i].close < rates[i].open)
                    bearish_confirmation++;
            }

            if (bearish_confirmation >= 1) // Minimal 1 confirmation candle
            {
                Print("Bearish Pullback detected");
                ESD_last_pullback_time = TimeCurrent();
                return true;
            }
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Momentum Continuation Detection                                 |
//+------------------------------------------------------------------+
bool ESD_IsMomentumContinuation()
{
    if (ESD_heatmap_strength < ESD_MomentumThreshold * 100 &&
        ESD_orderflow_strength < ESD_MomentumThreshold * 100)
        return false;

    MqlRates rates[];
    ArraySetAsSeries(rates, true);

    if (CopyRates(_Symbol, PERIOD_CURRENT, 0, 5, rates) < 5)
        return false;

    // Calculate momentum strength
    double momentum_bullish = 0.0;
    double momentum_bearish = 0.0;

    for (int i = 0; i < 4; i++)
    {
        if (rates[i].close > rates[i + 1].close)
            momentum_bullish += 0.25;
        else if (rates[i].close < rates[i + 1].close)
            momentum_bearish += 0.25;

        if (rates[i].close > rates[i].open)
            momentum_bullish += 0.25;
        else if (rates[i].close < rates[i].open)
            momentum_bearish += 0.25;
    }

    // Strong bullish momentum continuation
    if (momentum_bullish >= ESD_MomentumThreshold &&
        ESD_bullish_trend_confirmed &&
        ESD_heatmap_strength > 30)
    {
        // Cek jika belum overextended - PERBAIKAN DI SINI
        double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
        double current_high = rates[0].high;

        // CARA YANG BENAR: Mencari recent low manual
        double recent_low = rates[0].low;
        for (int i = 1; i < 4; i++)
        {
            if (rates[i].low < recent_low)
                recent_low = rates[i].low;
        }

        if ((current_high - recent_low) < atr * 3) // Tidak overextended
        {
            Print("Bullish Momentum Continuation detected");
            ESD_last_momentum_time = TimeCurrent();
            return true;
        }
    }

    // Strong bearish momentum continuation
    if (momentum_bearish >= ESD_MomentumThreshold &&
        ESD_bearish_trend_confirmed &&
        ESD_heatmap_strength < -30)
    {
        // Cek jika belum overextended - PERBAIKAN DI SINI
        double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
        double current_low = rates[0].low;

        // CARA YANG BENAR: Mencari recent high manual
        double recent_high = rates[0].high;
        for (int i = 1; i < 4; i++)
        {
            if (rates[i].high > recent_high)
                recent_high = rates[i].high;
        }

        if ((recent_high - current_low) < atr * 3) // Tidak overextended
        {
            Print("Bearish Momentum Continuation detected");
            ESD_last_momentum_time = TimeCurrent();
            return true;
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Execute False Breakout Trade                                    |
//+------------------------------------------------------------------+
void ESD_ExecuteFalseBreakoutTrade()
{
    // Hindari entry ganda
    // if (PositionSelect(_Symbol))
    //     return;

    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if (CopyRates(_Symbol, PERIOD_CURRENT, 0, 5, rates) < 5)
        return;

    // --- Deteksi arah false breakout
    bool is_bullish_false_breakout = ESD_IsBullishInducementSignal(rates, point, atr);
    bool is_bearish_false_breakout = ESD_IsBearishInducementSignal(rates, point, atr);

    // --- BUY: False Breakdown (Bear Trap)
    if (is_bullish_false_breakout)
    {
        double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double sl = ESD_last_significant_pl - (atr * ESD_AlternativeSLMultiplier);
        double tp = entry + (entry - sl) * ESD_RiskRewardRatio;

        if (ESD_RegimeFilter(true) && ESD_HeatmapFilter(true))
        {
            string comment = "FalseBreakout BUY";
            ESD_ExecuteTradeWithPartialTP(false, entry, sl, comment);
            Print("✅ False Breakout BUY executed @", entry);
        }
    }

    // --- SELL: False Breakout (Bull Trap)
    else if (is_bearish_false_breakout)
    {
        double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double sl = ESD_last_significant_ph + (atr * ESD_AlternativeSLMultiplier);
        double tp = entry - (sl - entry) * ESD_RiskRewardRatio;

        if (ESD_RegimeFilter(false) && ESD_HeatmapFilter(false))
        {
            string comment = "FalseBreakout SELL";
            ESD_ExecuteTradeWithPartialTP(true, entry, sl, comment);
            Print("✅ False Breakout SELL executed @", entry);
        }
    }
}

//+------------------------------------------------------------------+
//| Execute Pullback Trade                                          |
//+------------------------------------------------------------------+
//=== ENHANCED TIGHT SL SETTINGS ===
input group "=== TIGHT STOP LOSS SETTINGS ===" input bool ESD_UseTightSL = true; // Enable Tight Stop Loss based on lower TF
input ENUM_TIMEFRAMES ESD_TightSL_Timeframe = PERIOD_M5;                         // TF untuk Tight SL calculation
input double ESD_TightSL_ATRMultiplier = 0.6;                                    // ATR multiplier untuk max SL distance
input int ESD_TightSL_BufferPoints = 2;                                          // Buffer dari swing level (points)
input bool ESD_UseM1_Confirmation = true;                                        // Use M1 untuk konfirmasi entry
input double ESD_TightSL_RiskReward = 1.8;                                       // Risk:Reward ratio untuk tight SL

void ESD_ExecutePullbackTrade()
{
    // if (PositionSelect(_Symbol))
    //     return;

    // Update ML model terlebih dahulu
    if (ESD_UseMachineLearning)
        ESD_UpdateMLModel();

    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double atr = iATR(_Symbol, PERIOD_CURRENT, 14);

    // Collect ML features untuk analisis
    ESD_ML_Features features = ESD_CollectMLFeatures();

    if (ESD_bullish_trend_confirmed)
    {
        // BUY Pullback dengan Enhanced Tight SL + ML Integration
        double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double sl = 0.0;

        // ================== TIGHT SL BERDASARKAN TF KECIL ==================
        if (ESD_UseTightSL)
        {
            // Priority 1: M1 candle low dengan buffer ketat
            double m1_low = iLow(_Symbol, PERIOD_M1, 0);
            double m5_swing_low = ESD_GetRecentSwingLow();

            if (ESD_UseM1_Confirmation && m1_low > 0)
            {
                sl = m1_low - (ESD_TightSL_BufferPoints * point);
                Print("Tight SL BUY - M1 Low: ", m1_low, " SL: ", sl);
            }
            else if (m5_swing_low > 0)
            {
                sl = m5_swing_low - (ESD_TightSL_BufferPoints * point);
                Print("Tight SL BUY - M5 Swing Low: ", m5_swing_low, " SL: ", sl);
            }
            else if (ESD_bullish_fvg_bottom != EMPTY_VALUE)
            {
                // FVG bottom dengan buffer ATR yang ketat
                sl = ESD_bullish_fvg_bottom - (atr * 0.25);
                Print("Tight SL BUY - FVG Bottom: ", ESD_bullish_fvg_bottom, " SL: ", sl);
            }
            else
            {
                // Fallback: recent low M5 dengan ATR ketat
                sl = iLow(_Symbol, PERIOD_M5, 1) - (atr * 0.35);
            }

            // Validasi SL distance maksimal
            double max_sl_distance = atr * ESD_TightSL_ATRMultiplier;
            double current_sl_distance = entry - sl;
            if (current_sl_distance > max_sl_distance)
            {
                sl = entry - max_sl_distance;
                Print("Tight SL BUY - Adjusted to max distance: ", sl);
            }
        }
        else
        {
            // Traditional SL method (fallback)
            if (ESD_bullish_fvg_bottom != EMPTY_VALUE)
                sl = ESD_bullish_fvg_bottom - (atr * ESD_AlternativeSLMultiplier);
            else if (ESD_last_significant_pl != 0)
                sl = ESD_last_significant_pl - (atr * ESD_AlternativeSLMultiplier);
            else
                sl = entry - (atr * ESD_AlternativeSLMultiplier * 2);
        }

        // ================== ML CONFIDENCE FILTER ==================
        double ml_buy_signal = ESD_GetMLEntrySignal(true, features);
        double ml_confidence_threshold = 0.50; // Threshold lebih tinggi untuk pullback

        if (ESD_UseMachineLearning && ml_buy_signal < ml_confidence_threshold)
        {
            Print("ML Filter REJECTED Pullback BUY. Confidence: ", ml_buy_signal, " < ", ml_confidence_threshold);
            return;
        }

        // ================== LOWER TF CONFIRMATION ==================
        if (!ESD_HasLowerTFConfirmation(true))
        {
            Print("Lower TF Confirmation FAILED for Pullback BUY");
            return;
        }

        // ================== ENHANCED FILTER DENGAN ML ==================
        if (ESD_RegimeFilter(true) && ESD_HeatmapFilter(true) &&
            ESD_OrderFlowFilter(true) && ESD_StochasticEntryFilter(true))
        {
            // ML-Enhanced position sizing
            double ml_adjusted_lot = ESD_GetMLAdjustedLotSize();

            // Hitung TP dengan risk:reward optimal
            double risk = entry - sl;
            double tp = 0;

            if (ESD_UseTightSL && risk > 0)
            {
                tp = entry + (risk * ESD_TightSL_RiskReward);

                // Adjust TP berdasarkan resistance terdekat
                double nearest_resistance = ESD_GetNearestResistance(PERIOD_M15);
                if (nearest_resistance > entry && tp > nearest_resistance)
                {
                    tp = nearest_resistance - (5 * point);
                    Print("TP adjusted to nearest resistance: ", tp);
                }
            }

            string comment = StringFormat("ML-Pullback BUY (Conf:%.2f RR:%.1f)",
                                          ml_buy_signal, ESD_TightSL_RiskReward);

            // Execute trade dengan parameter ML-enhanced
            if (ESD_UseTightSL && tp > entry)
            {
                // Gunakan fixed TP untuk tight SL mode
                ESD_trade.Buy(ml_adjusted_lot, _Symbol, entry, sl, tp, comment);
                Print("Tight SL Pullback BUY executed | Entry:", entry, " SL:", sl, " TP:", tp);
            }
            else
            {
                // Gunakan partial TP system
                ESD_ExecuteTradeWithPartialTP(true, entry, sl, comment);
                Print("Pullback BUY executed with Partial TP | Entry:", entry, " SL:", sl);
            }
        }
    }
    else if (ESD_bearish_trend_confirmed)
    {
        // SELL Pullback dengan Enhanced Tight SL + ML Integration
        double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double sl = 0.0;

        // ================== TIGHT SL BERDASARKAN TF KECIL ==================
        if (ESD_UseTightSL)
        {
            // Priority 1: M1 candle high dengan buffer ketat
            double m1_high = iHigh(_Symbol, PERIOD_M1, 0);
            double m5_swing_high = ESD_GetRecentSwingHigh();

            if (ESD_UseM1_Confirmation && m1_high > 0)
            {
                sl = m1_high + (ESD_TightSL_BufferPoints * point);
                Print("Tight SL SELL - M1 High: ", m1_high, " SL: ", sl);
            }
            else if (m5_swing_high > 0)
            {
                sl = m5_swing_high + (ESD_TightSL_BufferPoints * point);
                Print("Tight SL SELL - M5 Swing High: ", m5_swing_high, " SL: ", sl);
            }
            else if (ESD_bearish_fvg_top != EMPTY_VALUE)
            {
                // FVG top dengan buffer ATR yang ketat
                sl = ESD_bearish_fvg_top + (atr * 0.25);
                Print("Tight SL SELL - FVG Top: ", ESD_bearish_fvg_top, " SL: ", sl);
            }
            else
            {
                // Fallback: recent high M5 dengan ATR ketat
                sl = iHigh(_Symbol, PERIOD_M5, 1) + (atr * 0.35);
            }

            // Validasi SL distance maksimal
            double max_sl_distance = atr * ESD_TightSL_ATRMultiplier;
            double current_sl_distance = sl - entry;
            if (current_sl_distance > max_sl_distance)
            {
                sl = entry + max_sl_distance;
                Print("Tight SL SELL - Adjusted to max distance: ", sl);
            }
        }
        else
        {
            // Traditional SL method (fallback)
            if (ESD_bearish_fvg_top != EMPTY_VALUE)
                sl = ESD_bearish_fvg_top + (atr * ESD_AlternativeSLMultiplier);
            else if (ESD_last_significant_ph != 0)
                sl = ESD_last_significant_ph + (atr * ESD_AlternativeSLMultiplier);
            else
                sl = entry + (atr * ESD_AlternativeSLMultiplier * 2);
        }

        // ================== ML CONFIDENCE FILTER ==================
        double ml_sell_signal = ESD_GetMLEntrySignal(false, features);
        double ml_confidence_threshold = 0.50; // Threshold lebih tinggi untuk pullback

        if (ESD_UseMachineLearning && ml_sell_signal > -ml_confidence_threshold)
        {
            Print("ML Filter REJECTED Pullback SELL. Confidence: ", MathAbs(ml_sell_signal), " < ", ml_confidence_threshold);
            return;
        }

        // ================== LOWER TF CONFIRMATION ==================
        if (!ESD_HasLowerTFConfirmation(false))
        {
            Print("Lower TF Confirmation FAILED for Pullback SELL");
            return;
        }

        // ================== ENHANCED FILTER DENGAN ML ==================
        if (ESD_RegimeFilter(false) && ESD_HeatmapFilter(false) &&
            ESD_OrderFlowFilter(false) && ESD_StochasticEntryFilter(false))
        {
            // ML-Enhanced position sizing
            double ml_adjusted_lot = ESD_GetMLAdjustedLotSize();

            // Hitung TP dengan risk:reward optimal
            double risk = sl - entry;
            double tp = 0;

            if (ESD_UseTightSL && risk > 0)
            {
                tp = entry - (risk * ESD_TightSL_RiskReward);

                // Adjust TP berdasarkan support terdekat
                double nearest_support = ESD_GetNearestSupport(PERIOD_M15);
                if (nearest_support < entry && tp < nearest_support)
                {
                    tp = nearest_support + (5 * point);
                    Print("TP adjusted to nearest support: ", tp);
                }
            }

            string comment = StringFormat("ML-Pullback SELL (Conf:%.2f RR:%.1f)",
                                          MathAbs(ml_sell_signal), ESD_TightSL_RiskReward);

            // Execute trade dengan parameter ML-enhanced
            if (ESD_UseTightSL && tp < entry)
            {
                // Gunakan fixed TP untuk tight SL mode
                ESD_trade.Sell(ml_adjusted_lot, _Symbol, entry, sl, tp, comment);
                Print("Tight SL Pullback SELL executed | Entry:", entry, " SL:", sl, " TP:", tp);
            }
            else
            {
                // Gunakan partial TP system
                ESD_ExecuteTradeWithPartialTP(false, entry, sl, comment);
                Print("Pullback SELL executed with Partial TP | Entry:", entry, " SL:", sl);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Helper Function: Get Nearest Resistance                        |
//+------------------------------------------------------------------+
double ESD_GetNearestResistance(ENUM_TIMEFRAMES tf)
{
    return ESD_GetRecentSwingHigh();
}

//+------------------------------------------------------------------+
//| Helper Function: Get Nearest Support                           |
//+------------------------------------------------------------------+
double ESD_GetNearestSupport(ENUM_TIMEFRAMES tf)
{
    return ESD_GetRecentSwingLow();
}

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
double counter_price_buy = 0.0;
double counter_price_sell = 0.0;
bool timer_active = false;

//+------------------------------------------------------------------+
//| Execute Momentum Trade (Confirm then Counter Strategy)          |
//+------------------------------------------------------------------+
void ESD_ExecuteMomentumTrade()
{
    // if (PositionSelect(_Symbol))
    //     return; // Sudah ada posisi aktif → jangan eksekusi sinyal baru

    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double atr = iATR(_Symbol, PERIOD_M1, 14);
    double atr_fast = iATR(_Symbol, PERIOD_M1, 5); // ATR lebih cepat untuk SL dinamis

    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    CopyRates(_Symbol, PERIOD_M1, 0, 3, rates);

    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // ==========================================================
    // 📈 BUY MOMENTUM CASE
    // ==========================================================
    if (ESD_bullish_trend_confirmed && rates[0].close > rates[0].open)
    {
        double signal_price = ask;

        if (ESD_RegimeFilter(true) && ESD_HeatmapFilter(true))
        {
            // ✅ MASUK POSISI KONFIRMASI DULU (BUY momentum)
            string comment1 = "BUY Momentum Confirm";
            double sl_confirm = rates[0].low - (atr_fast * 0.2);
            ESD_ExecuteTradeWithPartialTP(true, ask, sl_confirm, comment1);
            Print("BUY Momentum Confirm executed");

            // 🔁 Simpan harga untuk counter (SELL reversal)
            counter_price_sell = signal_price;
            EventSetTimer(1);
        }
    }

    // ==========================================================
    // 📉 SELL MOMENTUM CASE
    // ==========================================================
    else if (ESD_bearish_trend_confirmed && rates[0].close < rates[0].open)
    {
        double signal_price = bid;

        if (ESD_RegimeFilter(false) && ESD_HeatmapFilter(false))
        {
            // ✅ MASUK POSISI KONFIRMASI DULU (SELL momentum)
            string comment1 = "SELL Momentum Confirm";
            double sl_confirm = rates[0].high + (atr_fast * 0.2);
            ESD_ExecuteTradeWithPartialTP(false, bid, sl_confirm, comment1);
            Print("SELL Momentum Confirm executed");

            // 🔁 Simpan harga untuk counter (BUY reversal)
            counter_price_buy = signal_price;
            EventSetTimer(1);
        }
    }
}

//+------------------------------------------------------------------+
//| Timer event untuk cek counter-entry                            |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Jangan counter jika ada posisi aktif di simbol ini
    if (PositionSelect(_Symbol))
        return; // Ada posisi aktif → skip counter

    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double atr = iATR(_Symbol, PERIOD_CURRENT, 14);

    // Jika ada counter BUY (reversal dari SELL momentum)
    if (counter_price_buy > 0 && ask <= counter_price_buy)
    {
        string comment2 = "Counter BUY vs SELL momentum";
        double sl_counter = ask + (atr * 0.5);
        ESD_ExecuteTradeWithPartialTP(true, ask, sl_counter, comment2);
        Print("Counter BUY triggered");
        counter_price_buy = 0;
    }

    // Jika ada counter SELL (reversal dari BUY momentum)
    if (counter_price_sell > 0 && bid >= counter_price_sell)
    {
        string comment2 = "Counter SELL vs BUY momentum";
        double sl_counter = bid - (atr * 0.5);
        ESD_ExecuteTradeWithPartialTP(false, bid, sl_counter, comment2);
        Print("Counter SELL triggered");
        counter_price_sell = 0;
    }
}

//+------------------------------------------------------------------+
//| BSL/SSL Avoidance Settings                                      |
//+------------------------------------------------------------------+
input bool ESD_AvoidBSL_SSL = true;        // Hindari area BSL/SSL untuk entry
input int ESD_BSL_SSL_BufferPoints = 50;   // Buffer dari level BSL/SSL (points)
input bool ESD_ShowBSL_SSL = true;         // Tampilkan level BSL/SSL di chart
input color ESD_BSL_Color = clrDodgerBlue; // Warna BSL level
input color ESD_SSL_Color = clrCrimson;    // Warna SSL level

//+------------------------------------------------------------------+
//| BSL/SSL Detection Variables                                     |
//+------------------------------------------------------------------+
double ESD_bsl_level = EMPTY_VALUE; // Buy Side Liquidity level
double ESD_ssl_level = EMPTY_VALUE; // Sell Side Liquidity level
datetime ESD_last_bsl_ssl_update = 0;

//+------------------------------------------------------------------+
//| Enhanced Entry Settings untuk Short Trading                     |
//+------------------------------------------------------------------+
input bool ESD_EnableShortTrading = true;    // Enable short trading
input bool ESD_UseShortAggressive = true;    // Aggressive mode untuk short
input double ESD_ShortLotSize = 0.08;        // Lot size untuk short trades
input bool ESD_ShortOnBreakdown = true;      // Short pada breakdown structure
input bool ESD_ShortOnBearishFVG = true;     // Short pada bearish FVG
input bool ESD_ShortOnResistanceTest = true; // Short pada resistance test

//+------------------------------------------------------------------+
//| Detect BSL/SSL Levels                                           |
//+------------------------------------------------------------------+
void ESD_DetectBSL_SSLLevels()
{
    if (!ESD_AvoidBSL_SSL)
        return;

    int bars_to_check = 50;
    double high_buffer[], low_buffer[], close_buffer[];
    ArraySetAsSeries(high_buffer, true);
    ArraySetAsSeries(low_buffer, true);
    ArraySetAsSeries(close_buffer, true);

    CopyHigh(_Symbol, PERIOD_CURRENT, 0, bars_to_check, high_buffer);
    CopyLow(_Symbol, PERIOD_CURRENT, 0, bars_to_check, low_buffer);
    CopyClose(_Symbol, PERIOD_CURRENT, 0, bars_to_check, close_buffer);

    // Deteksi BSL (Buy Side Liquidity) - Level dimana buyer biasanya masuk
    // Biasanya di swing lows yang signifikan
    ESD_bsl_level = ESD_FindSignificantSwingLow(low_buffer, high_buffer, bars_to_check);

    // Deteksi SSL (Sell Side Liquidity) - Level dimana seller biasanya masuk
    // Biasanya di swing highs yang signifikan
    ESD_ssl_level = ESD_FindSignificantSwingHigh(high_buffer, low_buffer, bars_to_check);

    // Update waktu terakhir
    ESD_last_bsl_ssl_update = TimeCurrent();

    // Draw levels jika enabled
    if (ESD_ShowBSL_SSL)
    {
        ESD_DrawBSL_SSLLevels();
    }
}

//+------------------------------------------------------------------+
//| Find Significant Swing Low untuk BSL                            |
//+------------------------------------------------------------------+
double ESD_FindSignificantSwingLow(const double &low_buffer[], const double &high_buffer[], int total_bars)
{
    double significant_lows[];
    int count = 0;

    for (int i = 3; i < total_bars - 3; i++)
    {
        // Cek apakah ini swing low yang valid
        if (low_buffer[i] < low_buffer[i - 1] && low_buffer[i] < low_buffer[i - 2] &&
            low_buffer[i] < low_buffer[i + 1] && low_buffer[i] < low_buffer[i + 2])
        {
            // Validasi strength swing (minimal 0.5% dari range)
            double range = high_buffer[i] - low_buffer[i];
            double atr = iATR(_Symbol, PERIOD_CURRENT, 14);

            if (range > atr * 0.3) // Swing yang cukup signifikan
            {
                // Cek apakah level belum ada dalam array
                bool is_duplicate = false;
                for (int j = 0; j < count; j++)
                {
                    if (MathAbs(significant_lows[j] - low_buffer[i]) < atr * 0.1)
                    {
                        is_duplicate = true;
                        break;
                    }
                }

                if (!is_duplicate)
                {
                    ArrayResize(significant_lows, count + 1);
                    significant_lows[count] = low_buffer[i];
                    count++;
                }
            }
        }
    }

    // Return yang terbaru dan paling signifikan
    if (count > 0)
        return significant_lows[0]; // Return yang terbaru

    return EMPTY_VALUE;
}

//+------------------------------------------------------------------+
//| Find Significant Swing High untuk SSL                           |
//+------------------------------------------------------------------+
double ESD_FindSignificantSwingHigh(const double &high_buffer[], const double &low_buffer[], int total_bars)
{
    double significant_highs[];
    int count = 0;

    for (int i = 3; i < total_bars - 3; i++)
    {
        // Cek apakah ini swing high yang valid
        if (high_buffer[i] > high_buffer[i - 1] && high_buffer[i] > high_buffer[i - 2] &&
            high_buffer[i] > high_buffer[i + 1] && high_buffer[i] > high_buffer[i + 2])
        {
            // Validasi strength swing (minimal 0.5% dari range)
            double range = high_buffer[i] - low_buffer[i];
            double atr = iATR(_Symbol, PERIOD_CURRENT, 14);

            if (range > atr * 0.3) // Swing yang cukup signifikan
            {
                // Cek apakah level belum ada dalam array
                bool is_duplicate = false;
                for (int j = 0; j < count; j++)
                {
                    if (MathAbs(significant_highs[j] - high_buffer[i]) < atr * 0.1)
                    {
                        is_duplicate = true;
                        break;
                    }
                }

                if (!is_duplicate)
                {
                    ArrayResize(significant_highs, count + 1);
                    significant_highs[count] = high_buffer[i];
                    count++;
                }
            }
        }
    }

    // Return yang terbaru dan paling signifikan
    if (count > 0)
        return significant_highs[0]; // Return yang terbaru

    return EMPTY_VALUE;
}

//+------------------------------------------------------------------+
//| Draw BSL/SSL Levels                                             |
//+------------------------------------------------------------------+
void ESD_DrawBSL_SSLLevels()
{
    if (!ESD_ShowBSL_SSL)
        return;

    string bsl_name = "ESD_BSL_Level";
    string ssl_name = "ESD_SSL_Level";

    // Hapus level lama
    if (ObjectFind(0, bsl_name) >= 0)
        ObjectDelete(0, bsl_name);
    if (ObjectFind(0, ssl_name) >= 0)
        ObjectDelete(0, ssl_name);

    // Draw BSL level
    if (ESD_bsl_level != EMPTY_VALUE)
    {
        ObjectCreate(0, bsl_name, OBJ_HLINE, 0, 0, ESD_bsl_level);
        ObjectSetInteger(0, bsl_name, OBJPROP_COLOR, ESD_BSL_Color);
        ObjectSetInteger(0, bsl_name, OBJPROP_STYLE, STYLE_DASHDOTDOT);
        ObjectSetInteger(0, bsl_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, bsl_name, OBJPROP_BACK, true);
        ObjectSetString(0, bsl_name, OBJPROP_TEXT, "BSL");

        // Tambahkan area buffer
        string bsl_buffer_name = "ESD_BSL_Buffer";
        if (ObjectFind(0, bsl_buffer_name) >= 0)
            ObjectDelete(0, bsl_buffer_name);

        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double buffer_size = ESD_BSL_SSL_BufferPoints * point;

        ObjectCreate(0, bsl_buffer_name, OBJ_RECTANGLE, 0,
                     iTime(_Symbol, PERIOD_CURRENT, 20), ESD_bsl_level - buffer_size,
                     iTime(_Symbol, PERIOD_CURRENT, 0), ESD_bsl_level + buffer_size);
        ObjectSetInteger(0, bsl_buffer_name, OBJPROP_COLOR, ESD_BSL_Color);
        ObjectSetInteger(0, bsl_buffer_name, OBJPROP_BGCOLOR, ColorToARGB(ESD_BSL_Color, 20));
        ObjectSetInteger(0, bsl_buffer_name, OBJPROP_BACK, true);
    }

    // Draw SSL level
    if (ESD_ssl_level != EMPTY_VALUE)
    {
        ObjectCreate(0, ssl_name, OBJ_HLINE, 0, 0, ESD_ssl_level);
        ObjectSetInteger(0, ssl_name, OBJPROP_COLOR, ESD_SSL_Color);
        ObjectSetInteger(0, ssl_name, OBJPROP_STYLE, STYLE_DASHDOTDOT);
        ObjectSetInteger(0, ssl_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, ssl_name, OBJPROP_BACK, true);
        ObjectSetString(0, ssl_name, OBJPROP_TEXT, "SSL");

        // Tambahkan area buffer
        string ssl_buffer_name = "ESD_SSL_Buffer";
        if (ObjectFind(0, ssl_buffer_name) >= 0)
            ObjectDelete(0, ssl_buffer_name);

        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double buffer_size = ESD_BSL_SSL_BufferPoints * point;

        ObjectCreate(0, ssl_buffer_name, OBJ_RECTANGLE, 0,
                     iTime(_Symbol, PERIOD_CURRENT, 20), ESD_ssl_level - buffer_size,
                     iTime(_Symbol, PERIOD_CURRENT, 0), ESD_ssl_level + buffer_size);
        ObjectSetInteger(0, ssl_buffer_name, OBJPROP_COLOR, ESD_SSL_Color);
        ObjectSetInteger(0, ssl_buffer_name, OBJPROP_BGCOLOR, ColorToARGB(ESD_SSL_Color, 20));
        ObjectSetInteger(0, ssl_buffer_name, OBJPROP_BACK, true);
    }
}

//+------------------------------------------------------------------+
//| Check BSL/SSL Avoidance                                         |
//+------------------------------------------------------------------+
bool ESD_IsInBSL_SSLZone(double price, bool is_buy_signal)
{
    if (!ESD_AvoidBSL_SSL)
        return false;

    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double buffer_size = ESD_BSL_SSL_BufferPoints * point;

    // Untuk buy signal, hindari area di sekitar SSL (resistance)
    if (is_buy_signal && ESD_ssl_level != EMPTY_VALUE)
    {
        if (price >= ESD_ssl_level - buffer_size && price <= ESD_ssl_level + buffer_size)
        {
            Print("Avoid BUY - Price in SSL zone: ", ESD_ssl_level);
            return true;
        }
    }

    // Untuk sell signal, hindari area di sekitar BSL (support)
    if (!is_buy_signal && ESD_bsl_level != EMPTY_VALUE)
    {
        if (price >= ESD_bsl_level - buffer_size && price <= ESD_bsl_level + buffer_size)
        {
            Print("Avoid SELL - Price in BSL zone: ", ESD_bsl_level);
            return true;
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Enhanced Short Trading Logic                                    |
//+------------------------------------------------------------------+
void ESD_CheckForShortEntries()
{
    if (!ESD_EnableShortTrading || PositionSelect(_Symbol))
        return;

    // Update BSL/SSL levels untuk liquidity mapping
    ESD_DetectBSL_SSLLevels();

    // Hanya trade short jika trend bearish confirmed
    if (!ESD_bearish_trend_confirmed || ESD_bearish_trend_strength < ESD_TrendStrengthThreshold)
        return;

    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // 🚫 Hindari zona BSL (buy-side liquidity) - kita mau berburu di SSL
    if (ESD_IsInBSL_SSLZone(bid, false))
    {
        Print("🚫 AVOID - Too close to BSL liquidity zone");
        return;
    }

    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    CopyRates(_Symbol, PERIOD_CURRENT, 0, 3, rates);

    // Konfirmasi candle bearish untuk momentum
    bool current_bearish = (rates[0].close < rates[0].open);
    if (!current_bearish)
        return;

    // ========== PRIORITAS 1: SHORT ON LIQUIDITY HUNT ==========
    if (ESD_ShortOnLiquidityHunt && ESD_IsLiquidityHuntOpportunity(rates, bid, point))
    {
        ESD_ExecuteLiquidityShortTrade("Liquidity Hunt", bid);
        return;
    }

    // ========== PRIORITAS 2: SHORT ON BREAKDOWN ==========
    if (ESD_ShortOnBreakdown && ESD_IsBreakdownOpportunity(rates, bid))
    {
        ESD_ExecuteLiquidityShortTrade("Liquidity Breakdown", bid);
        return;
    }

    // ========== PRIORITAS 3: SHORT ON BEARISH FVG ==========
    if (ESD_ShortOnBearishFVG && ESD_IsBearishFVGOpportunity(bid, point))
    {
        ESD_ExecuteLiquidityShortTrade("Liquidity FVG", bid);
        return;
    }

    // ========== PRIORITAS 4: SHORT ON RESISTANCE TEST ==========
    if (ESD_ShortOnResistanceTest && ESD_IsResistanceTestOpportunity(rates, bid, point))
    {
        ESD_ExecuteLiquidityShortTrade("Liquidity Resistance", bid);
        return;
    }
}

//+------------------------------------------------------------------+
//| NEW: Liquidity Hunt Opportunity Detection                       |
//| LOGIC: Berburu liquidity di SSL dengan konfirmasi rejection    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
bool ESD_ShortOnLiquidityHunt = true; // Enable liquidity hunt strategy

bool ESD_IsLiquidityHuntOpportunity(const MqlRates &rates[], double current_price, double point)
{
    if (ESD_ssl_level == EMPTY_VALUE)
    {
        Print("❌ No SSL level for liquidity hunt");
        return false;
    }

    double tolerance = ESD_ZoneTolerancePoints * point;

    // 🎯 CONDITION 1: Harga sedang berburu liquidity di SSL
    bool liquidity_hunt_zone = (current_price >= ESD_ssl_level - tolerance) &&
                               (current_price <= ESD_ssl_level + tolerance);

    if (!liquidity_hunt_zone)
    {
        Print("❌ Not in liquidity hunt zone");
        return false;
    }

    // 🎯 CONDITION 2: Liquidity terambil (price spike above SSL kemudian rejection)
    bool liquidity_taken = (rates[0].high > ESD_ssl_level + tolerance) &&
                           (rates[0].close < ESD_ssl_level);

    // 🎯 CONDITION 3: Atau rejection langsung di SSL tanpa spike
    bool direct_rejection = (rates[0].high >= ESD_ssl_level) &&
                            (rates[0].close < ESD_ssl_level - (point * 3));

    // 🎯 CONDITION 4: Volume/volatility konfirmasi
    double current_range = rates[0].high - rates[0].low;
    double prev_range = rates[1].high - rates[1].low;
    bool volatility_spike = (current_range > prev_range * 1.3);

    // 🎯 CONDITION 5: Strong bearish momentum setelah liquidity diambil
    bool bearish_momentum = (rates[0].close < rates[0].open) &&
                            (rates[0].close < rates[1].low);

    bool signal = (liquidity_taken || direct_rejection) && volatility_spike && bearish_momentum;

    if (signal)
    {
        if (liquidity_taken)
            Print("🎯 LIQUIDITY HUNT SIGNAL: Price took liquidity above SSL and rejected");
        else
            Print("🎯 LIQUIDITY HUNT SIGNAL: Direct rejection at SSL");
    }

    return signal;
}

//+------------------------------------------------------------------+
//| Modified Breakdown Detection dengan Liquidity Focus             |
//| LOGIC: Breakdown menuju BSL berikutnya (target liquidity)      |
//+------------------------------------------------------------------+
bool ESD_IsBreakdownOpportunity(const MqlRates &rates[], double current_price)
{
    // --- 1. Validasi dasar ---
    if (ESD_last_significant_pl == 0)
        return false;

    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double tolerance = ESD_ZoneTolerancePoints * point;

    // --- 2. Target liquidity: BSL berikutnya harus ada ---
    if (ESD_bsl_level == EMPTY_VALUE || ESD_bsl_level > ESD_last_significant_pl)
    {
        Print("❌ BREAKDOWN: No BSL target below");
        return false;
    }

    // --- 3. Pastikan harga breakdown support ---
    bool breakdown_occurred = (current_price < ESD_last_significant_pl - tolerance);

    if (!breakdown_occurred)
        return false;

    // --- 4. Konfirmasi bearish momentum ---
    bool bearish_confirmation = (rates[0].close < rates[0].open) &&
                                (rates[0].close < rates[1].close);

    // --- 5. Jumlah BSL targets di bawah (liquidity pools) ---
    int bsl_targets_below = ESD_CountBSLTargetsBelow(current_price);

    bool signal = breakdown_occurred && bearish_confirmation && (bsl_targets_below > 0);

    if (signal)
        Print("🎯 BREAKDOWN SIGNAL: Breaking support with ", bsl_targets_below, " BSL targets below");

    return signal;
}

//+------------------------------------------------------------------+
//| Modified Bearish FVG dengan Liquidity Confluence                |
//| LOGIC: FVG yang mengarah ke BSL target                         |
//+------------------------------------------------------------------+
bool ESD_IsBearishFVGOpportunity(double current_price, double point)
{
    if (ESD_bearish_fvg_top == EMPTY_VALUE || ESD_bearish_fvg_bottom == EMPTY_VALUE)
        return false;

    double tolerance = ESD_ZoneTolerancePoints * point;

    bool in_zone = (current_price <= ESD_bearish_fvg_top + tolerance) &&
                   (current_price >= ESD_bearish_fvg_bottom - tolerance);

    bool candle_conf = (iClose(_Symbol, PERIOD_CURRENT, 1) < iOpen(_Symbol, PERIOD_CURRENT, 1));

    double fill_ratio = MathAbs((ESD_bearish_fvg_top - current_price) / (ESD_bearish_fvg_top - ESD_bearish_fvg_bottom));
    bool not_filled = (fill_ratio < 0.8);

    // 🎯 NEW: FVG harus mengarah ke BSL target
    bool has_bsl_target = (ESD_bsl_level != EMPTY_VALUE) && (ESD_bsl_level < ESD_bearish_fvg_bottom);

    bool signal = in_zone && candle_conf && not_filled && has_bsl_target;

    if (signal)
        Print("🎯 FVG SIGNAL: Bearish FVG targeting BSL at ", DoubleToString(ESD_bsl_level, _Digits));

    return signal;
}

//+------------------------------------------------------------------+
//| Modified Resistance Test dengan Liquidity Context               |
//| LOGIC: Test di SSL untuk konfirmasi selling pressure           |
//+------------------------------------------------------------------+
bool ESD_IsResistanceTestOpportunity(const MqlRates &rates[], double current_price, double point)
{
    // Prioritaskan SSL level untuk liquidity hunting
    if (ESD_ssl_level == EMPTY_VALUE)
        return false;

    double resistance_level = ESD_ssl_level;
    double tolerance = ESD_ZoneTolerancePoints * point;

    bool testing_resistance = (current_price >= resistance_level - tolerance) &&
                              (current_price <= resistance_level + tolerance);

    bool rejection_sign = (rates[0].high >= resistance_level) &&
                          (rates[0].close < resistance_level - (point * 2)); // Strong rejection

    // 🎯 NEW: Volume konfirmasi untuk liquidity hunt
    double current_volume = (double)iVolume(_Symbol, PERIOD_CURRENT, 0);
    double avg_volume = (iVolume(_Symbol, PERIOD_CURRENT, 1) + iVolume(_Symbol, PERIOD_CURRENT, 2)) / 2.0;
    bool volume_spike = (current_volume > avg_volume * 1.5);

    bool signal = testing_resistance && rejection_sign && volume_spike;

    if (signal)
        Print("🎯 RESISTANCE SIGNAL: SSL rejection with volume spike");

    return signal;
}

//+------------------------------------------------------------------+
//| NEW: Count BSL Targets Below (Liquidity Pools)                 |
//+------------------------------------------------------------------+
int ESD_CountBSLTargetsBelow(double current_price)
{
    int count = 0;
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // Target 1: BSL level utama
    if (ESD_bsl_level != EMPTY_VALUE && ESD_bsl_level < current_price)
        count++;

    // Target 2: Significant PL sebelumnya (jika ada)
    if (ESD_last_significant_pl != 0 && ESD_last_significant_pl < current_price)
        count++;

    // Target 3: Dynamic level berdasarkan ATR
    double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
    double next_target = current_price - (atr * 1.5);
    if (next_target < current_price)
        count++;

    return count;
}

//+------------------------------------------------------------------+
//| NEW: Execute Liquidity Short Trade dengan SL/TP Tipis          |
//| LOGIC: Quick scalp menuju liquidity target dengan risk kecil   |
//+------------------------------------------------------------------+
void ESD_ExecuteLiquidityShortTrade(string signal_type, double entry_price)
{
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double atr = iATR(_Symbol, PERIOD_CURRENT, 14);

    // === SL & TP SUPER TIPIS (Liquidity Hunting Style) ===
    double sl = 0, tp = 0;

    // 🎯 SL TIPIS: 15-25% dari ATR biasa
    double tight_sl_multiplier = 0.25; // VERY TIGHT
    double quick_tp_multiplier = 0.4;  // Quick profit

    // 🎯 TP TARGET: BSL terdekat atau level support berikutnya
    double nearest_bsl = (ESD_bsl_level != EMPTY_VALUE && ESD_bsl_level < entry_price) ? ESD_bsl_level : entry_price - (atr * 1.0);

    switch (ESD_SlTpMethod)
    {
    case ESD_FIXED_POINTS:
        // SL/TP sangat ketat untuk liquidity hunting
        sl = entry_price + (ESD_StopLossPoints * 0.2 * point); // 20% dari default
        tp = nearest_bsl;                                      // Target BSL terdekat
        break;

    case ESD_STRUCTURE_BASED:
        // SL di atas SSL dengan buffer minimal
        if (ESD_ssl_level != EMPTY_VALUE)
            sl = ESD_ssl_level + (ESD_SlBufferPoints * 0.3 * point); // Buffer tipis
        else
            sl = entry_price + (atr * tight_sl_multiplier);

        tp = nearest_bsl; // Target liquidity pool
        break;

    default:
        sl = entry_price + (atr * tight_sl_multiplier);
        tp = entry_price - (atr * quick_tp_multiplier);
        break;
    }

    // === VALIDASI SL/TP TIPIS ===
    // Pastikan risk:reward minimal 1:1.5
    double risk = MathAbs(sl - entry_price);
    double reward = MathAbs(entry_price - tp);
    double rr_ratio = reward / risk;

    if (rr_ratio < 1.5)
    {
        // Adjust TP untuk maintain RR ratio
        tp = entry_price - (risk * 1.5);
        Print("🔧 Adjusted TP for better RR ratio: 1:", DoubleToString(rr_ratio, 1));
    }

    if (sl <= entry_price)
        sl = entry_price + (atr * 0.2);
    if (tp >= entry_price)
        tp = entry_price - (atr * 0.3);

    // === EKSEKUSI TRADE ===
    string comment = StringFormat("LiquidityHunt-%s|SSL:%.5f|BSL:%.5f",
                                  signal_type,
                                  ESD_ssl_level != EMPTY_VALUE ? ESD_ssl_level : 0,
                                  ESD_bsl_level != EMPTY_VALUE ? ESD_bsl_level : 0);

    double lot_size = ESD_EnableShortTrading ? ESD_ShortLotSize : ESD_LotSize;

    if (ESD_trade.Sell(lot_size, _Symbol, entry_price, tp, sl, comment))
    {
        Print("⚡ LIQUIDITY HUNT SHORT EXECUTED | ", comment,
              " | Entry: ", DoubleToString(entry_price, _Digits),
              " | SL: ", DoubleToString(sl, _Digits), " (", DoubleToString(MathAbs(sl - entry_price) / point, 0), " pips)",
              " | TP: ", DoubleToString(tp, _Digits), " (", DoubleToString(MathAbs(entry_price - tp) / point, 0), " pips)",
              " | RR: 1:", DoubleToString(rr_ratio, 1));
    }
    else if (ESD_trade.Buy(lot_size, _Symbol, entry_price, sl, tp, comment))
    {
        Print("⚡ LIQUIDITY HUNT SHORT EXECUTED | ", comment,
              " | Entry: ", DoubleToString(entry_price, _Digits),
              " | SL: ", DoubleToString(sl, _Digits), " (", DoubleToString(MathAbs(sl - entry_price) / point, 0), " pips)",
              " | TP: ", DoubleToString(tp, _Digits), " (", DoubleToString(MathAbs(entry_price - tp) / point, 0), " pips)",
              " | RR: 1:", DoubleToString(rr_ratio, 1));
    }
}

bool ESD_IsFalseBreakoutRetest(bool &isBullish, bool &isBearish)
{
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
    MqlRates rates[];
    ArraySetAsSeries(rates, true);

    if (CopyRates(_Symbol, PERIOD_CURRENT, 0, 5, rates) < 5)
        return false;

    isBullish = ESD_IsBullishInducementSignal(rates, point, atr);
    isBearish = ESD_IsBearishInducementSignal(rates, point, atr);

    return (isBullish || isBearish);
}

//+------------------------------------------------------------------+
//| Deteksi Bullish Inducement / False Breakdown (Bear Trap)         |
//| Return: true jika ada sinyal BUY false breakout                  |
//+------------------------------------------------------------------+
bool ESD_IsBullishInducementSignal(const MqlRates &rates[], double point, double atr)
{
    // Pastikan minimal 3 candle tersedia
    if (ArraySize(rates) < 3)
        return false;

    // Candle terakhir (current), sebelumnya, dan dua sebelumnya
    double prevLow = rates[1].low;
    double prevClose = rates[1].close;
    double currLow = rates[0].low;
    double currClose = rates[0].close;

    // --- 1. Harga menembus low sebelumnya (breakdown)
    bool brokePrevLow = currLow < prevLow - (atr * 0.1);

    // --- 2. Tapi candle menutup di atas low sebelumnya (false breakdown)
    bool closedAbovePrevLow = currClose > prevLow;

    // --- 3. Candle konfirmasi bullish (body naik)
    bool bullishClose = currClose > rates[0].open;

    // --- 4. Pastikan range valid (bukan noise kecil)
    bool atrEnough = (rates[0].high - rates[0].low) > (atr * 0.5);

    return (brokePrevLow && closedAbovePrevLow && bullishClose && atrEnough);
}

//+------------------------------------------------------------------+
//| Deteksi Bearish Inducement / False Breakout (Bull Trap)          |
//| Return: true jika ada sinyal SELL false breakout                 |
//+------------------------------------------------------------------+
bool ESD_IsBearishInducementSignal(const MqlRates &rates[], double point, double atr)
{
    if (ArraySize(rates) < 3)
        return false;

    double prevHigh = rates[1].high;
    double prevClose = rates[1].close;
    double currHigh = rates[0].high;
    double currClose = rates[0].close;

    // --- 1. Harga menembus high sebelumnya (breakout)
    bool brokePrevHigh = currHigh > prevHigh + (atr * 0.1);

    // --- 2. Tapi candle menutup di bawah high sebelumnya (false breakout)
    bool closedBelowPrevHigh = currClose < prevHigh;

    // --- 3. Candle konfirmasi bearish
    bool bearishClose = currClose < rates[0].open;

    // --- 4. Pastikan range valid
    bool atrEnough = (rates[0].high - rates[0].low) > (atr * 0.5);

    return (brokePrevHigh && closedBelowPrevHigh && bearishClose && atrEnough);
}

bool ESD_TradeAgainstInducement()
{
    if (PositionSelect(_Symbol))
        return false;

    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
    MqlRates rates[];
    ArraySetAsSeries(rates, true);

    if (CopyRates(_Symbol, PERIOD_CURRENT, 0, 5, rates) < 5)
        return false;

    // 🎯 BEARISH INDUCEMENT DETECTED -> ENTRY BUY
    // Pattern: False breakout atas resistance -> reversal bearish -> kita entry BUY
    if (ESD_IsBearishInducementSignal(rates, point, atr))
    {
        double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double tp = ESD_last_significant_ph + (atr * 1.5); // SL di atas false breakout level
        double sl = entry + (atr * 3);                     // TP lebih agresif

        if (ESD_RegimeFilter(true) && ESD_HeatmapFilter(true))
        {
            string comment = "INDUCEMENT_BUY (Bear Trap)";
            ESD_ExecuteTradeWithPartialTP(true, entry, sl, comment);
            Print("🎯 INDUCEMENT BUY - Trading against bear trap");
            return true;
        }
    }

    // 🎯 BULLISH INDUCEMENT DETECTED -> ENTRY SELL
    // Pattern: False breakout bawah support -> reversal bullish -> kita entry SELL
    if (ESD_IsBullishInducementSignal(rates, point, atr))
    {
        double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double tp = ESD_last_significant_pl - (atr * 1.5); // SL di bawah false breakout level
        double sl = entry - (atr * 3);                     // TP lebih agresif

        if (ESD_RegimeFilter(true) && ESD_HeatmapFilter(false))
        {
            string comment = "INDUCEMENT_SELL (Bull Trap)";
            ESD_ExecuteTradeWithPartialTP(false, entry, sl, comment);
            Print("🎯 INDUCEMENT SELL - Trading against bull trap");
            return true;
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Check Lower Timeframe Confirmation untuk entry yang lebih akurat|
//+------------------------------------------------------------------+
bool ESD_HasLowerTFConfirmation(bool is_bullish)
{
    if (!ESD_UseTightSL)
        return true;

    // Konfirmasi trend di M15
    double m15_ema20 = iMA(_Symbol, PERIOD_M15, 20, 0, MODE_EMA, PRICE_CLOSE);
    double m15_price = iClose(_Symbol, PERIOD_M15, 0);

    bool m15_confirmation = is_bullish ? (m15_price > m15_ema20) : (m15_price < m15_ema20);

    // Konfirmasi momentum di M5 dengan RSI
    double m5_rsi = iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);
    bool m5_momentum = is_bullish ? (m5_rsi > 45 && m5_rsi < 75) : // Untuk bullish: RSI tidak overbought, masih ada ruang naik
                           (m5_rsi < 55 && m5_rsi > 25);           // Untuk bearish: RSI tidak oversold, masih ada ruang turun

    // Konfirmasi price action di M1 - candle harus sesuai dengan arah trend
    MqlRates m1_rates[];
    ArraySetAsSeries(m1_rates, true);
    if (CopyRates(_Symbol, PERIOD_M1, 0, 2, m1_rates) >= 2)
    {
        bool m1_direction = is_bullish ? (m1_rates[0].close > m1_rates[0].open) : // Bullish candle untuk buy
                                (m1_rates[0].close < m1_rates[0].open);           // Bearish candle untuk sell

        bool m1_momentum = is_bullish ? (m1_rates[0].close > m1_rates[1].close) : // Momentum naik untuk buy
                               (m1_rates[0].close < m1_rates[1].close);           // Momentum turun untuk sell

        bool m1_confirmation = m1_direction && m1_momentum;

        Print(StringFormat("Lower TF Confirmation - M15: %s, M5_RSI: %.1f, M1: %s",
                           m15_confirmation ? "PASS" : "FAIL", m5_rsi, m1_confirmation ? "PASS" : "FAIL"));

        return (m15_confirmation && m5_momentum && m1_confirmation);
    }

    // Fallback jika tidak bisa dapat data M1
    return (m15_confirmation && m5_momentum);
}

//+------------------------------------------------------------------+
//| Machine Learning Integration untuk Adaptive Parameters          |
//+------------------------------------------------------------------+

//--- ML Settings
input group "=== MACHINE LEARNING SETTINGS ===" input bool ESD_UseMachineLearning = true; // Enable Machine Learning
input int ESD_ML_TrainingPeriod = 1000;                                                   // Training period (bars)
input double ESD_ML_LearningRate = 0.01;                                                  // Learning rate for adaptation
input int ESD_ML_UpdateInterval = 100;                                                    // Bars between ML updates
input bool ESD_ML_AdaptiveSLTP = true;                                                    // Adaptive SL/TP based on ML
input bool ESD_ML_AdaptiveLotSize = true;                                                 // Adaptive lot size based on ML
input bool ESD_ML_DynamicFilter = true;                                                   // Dynamic filter thresholds

//--- ML Variables
double ESD_ml_trend_weight = 1.0;
double ESD_ml_volatility_weight = 1.0;
double ESD_ml_momentum_weight = 1.0;
double ESD_ml_risk_appetite = 0.5;
double ESD_ml_optimal_sl_multiplier = 1.0;
double ESD_ml_optimal_tp_multiplier = 1.0;
double ESD_ml_lot_size_multiplier = 1.0;

//--- Enhanced RL Structures ---
struct Experience
{
    int state;
    int action;
    double reward;
    int next_state;
    bool terminal;
};

struct PerformanceMetrics
{
    double total_profit;
    double total_loss;
    double max_drawdown;
    double sharpe_ratio;
    int consecutive_wins;
    int consecutive_losses;
    double avg_win;
    double avg_loss;
    datetime last_update;
};

//--- ML Performance Tracking
struct ESD_ML_Performance
{
    double win_rate;
    double profit_factor;
    double sharpe_ratio;
    double max_drawdown;
    double volatility;
    datetime last_update;
    int trade_count;
    double total_return;
    double total_profit;
    double total_loss;
    double average_win;
    double average_loss;
    int total_trades;
};

ESD_ML_Performance ESD_ml_performance;

//--- ML Feature Vector
struct ESD_ML_Features
{
    double trend_strength;
    double volatility;
    double momentum;
    double volume_ratio;
    double market_regime;
    double time_of_day;
    double heatmap_strength;
    double orderflow_strength;
    double structure_quality;
    double risk_sentiment;
    double rsi;
    double correlation;
};

//--- Enhanced RL Global Variables ---
#define MAX_EXPERIENCES 1000
#define BATCH_SIZE 32
#define STATES 243 // 3^5 states (5 features, 3 bins each)
#define ACTIONS 9  // More granular actions

static Experience g_experience_buffer[MAX_EXPERIENCES];
static int g_exp_write_idx = 0;
static int g_exp_count = 0;
static double g_Q[STATES][ACTIONS];
static bool g_q_initialized = false;
static PerformanceMetrics g_perf_metrics;
static PerformanceMetrics g_prev_perf_metrics;

//+------------------------------------------------------------------+
//| Initialize Machine Learning System                              |
//+------------------------------------------------------------------+
void ESD_InitializeML()
{
    if (!ESD_UseMachineLearning)
        return;

    Print("Initializing Machine Learning System...");

    // Initialize dengan nilai default
    ESD_ml_trend_weight = 1.0;
    ESD_ml_volatility_weight = 1.0;
    ESD_ml_momentum_weight = 1.0;
    ESD_ml_risk_appetite = 0.5;
    ESD_ml_optimal_sl_multiplier = 1.0;
    ESD_ml_optimal_tp_multiplier = 1.0;
    ESD_ml_lot_size_multiplier = 1.0;

    // Initialize performance tracking
    ESD_ml_performance.win_rate = 0.0;
    ESD_ml_performance.profit_factor = 0.0;
    ESD_ml_performance.sharpe_ratio = 0.0;
    ESD_ml_performance.max_drawdown = 0.0;
    ESD_ml_performance.volatility = 0.0;
    ESD_ml_performance.last_update = TimeCurrent();
    ESD_ml_performance.trade_count = 0;
    ESD_ml_performance.total_return = 0.0;
    ESD_ml_performance.total_profit = 0.0;
    ESD_ml_performance.total_loss = 0.0;
    ESD_ml_performance.average_win = 0.0;
    ESD_ml_performance.average_loss = 0.0;
    ESD_ml_performance.total_trades = 0;

    // Initialize RL system
    g_q_initialized = false;
    g_exp_write_idx = 0;
    g_exp_count = 0;
    ZeroMemory(g_perf_metrics);
    ZeroMemory(g_prev_perf_metrics);

    Print("Machine Learning System Initialized");
}

//+------------------------------------------------------------------+
//| Collect Features untuk Machine Learning                         |
//+------------------------------------------------------------------+
ESD_ML_Features ESD_CollectMLFeatures()
{
    ESD_ML_Features features;

    ENUM_TIMEFRAMES current_tf = Period();

    // Basic technical features
    double ema_fast = iMA(_Symbol, current_tf, 20, 0, MODE_EMA, PRICE_CLOSE);
    double ema_slow = iMA(_Symbol, current_tf, 50, 0, MODE_EMA, PRICE_CLOSE);
    features.trend_strength = MathAbs(ema_fast - ema_slow) / SymbolInfoDouble(_Symbol, SYMBOL_POINT) / 100.0;

    features.volatility = iATR(_Symbol, current_tf, 14) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    features.rsi = iRSI(_Symbol, current_tf, 14, PRICE_CLOSE);

    // Momentum features
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    CopyRates(_Symbol, current_tf, 0, 3, rates);
    features.momentum = (rates[0].close - rates[2].close) / rates[2].close * 100;

    // Additional features bisa ditambahkan di sini
    features.market_regime = 0;
    features.correlation = 0;

    // --- 1. Trend Strength Feature ---
    features.trend_strength = (ESD_bullish_trend_strength + (1.0 - ESD_bearish_trend_strength)) / 2.0;
    features.trend_strength = MathMin(MathMax(features.trend_strength, 0.0), 1.0);

    // --- 2. Volatility Feature (Normalized ATR) ---
    double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if (price > 0.0)
    {
        // ATR relatif terhadap harga, normalisasi ke 0–1
        features.volatility = atr / price;
        features.volatility = MathMin(features.volatility * 100.0, 1.0); // biasanya ATR < 1% harga
    }
    else
        features.volatility = 0.0;

    // --- 3. Momentum Feature (RSI Normalized) ---
    double rsi = 0.5;
    double rsi_buffer[];
    ArraySetAsSeries(rsi_buffer, true);
    int rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
    if (rsi_handle != INVALID_HANDLE && CopyBuffer(rsi_handle, 0, 0, 1, rsi_buffer) > 0)
        rsi = rsi_buffer[0] / 100.0;
    features.momentum = MathMin(MathMax(rsi, 0.0), 1.0);

    // --- 4. Volume Ratio Feature ---
    features.volume_ratio = 1.0;
    if (CopyRates(_Symbol, PERIOD_CURRENT, 0, 2, rates) >= 2 && rates[1].tick_volume > 0)
    {
        double ratio = (double)rates[0].tick_volume / rates[1].tick_volume;
        features.volume_ratio = MathMin(MathMax(ratio, 0.0), 2.0) / 2.0; // normalisasi 0–1
    }

    // --- 5. Market Regime Feature (0–6 → 0–1) ---
    features.market_regime = MathMin(MathMax((double)ESD_current_regime / 6.0, 0.0), 1.0);

    // --- 6. Time of Day Feature (0–24 jam → 0–1) ---
    MqlDateTime time_struct;
    TimeToStruct(TimeCurrent(), time_struct);
    double seconds_in_day = (time_struct.hour * 3600.0 + time_struct.min * 60.0 + time_struct.sec);
    features.time_of_day = MathMin(MathMax(seconds_in_day / 86400.0, 0.0), 1.0);

    // --- 7. Heatmap Strength Feature (±100 → 0–1) ---
    features.heatmap_strength = MathMin(MathMax((ESD_heatmap_strength + 100.0) / 200.0, 0.0), 1.0);

    // --- 8. Order Flow Strength Feature (±100 → 0–1) ---
    features.orderflow_strength = MathMin(MathMax((ESD_orderflow_strength + 100.0) / 200.0, 0.0), 1.0);

    // --- 9. Structure Quality Feature ---
    features.structure_quality = MathMin(MathMax(ESD_GetCurrentZoneQuality(), 0.0), 1.0);

    // --- 10. Risk Sentiment Feature ---
    features.risk_sentiment = MathMin(MathMax(ESD_CalculateRiskSentiment(), 0.0), 1.0);

    return features;
}

void ESD_UpdateMLWeights(const ESD_ML_Features &features)
{
    // --- Default weights (baseline) ---
    double trend_weight_base = 0.35;
    double volatility_weight_base = 0.25;
    double momentum_weight_base = 0.25;
    double risk_weight_base = 0.15;
    double ESD_ml_risk_weight = 0;

    // --- Adaptif terhadap kondisi pasar ---
    // Jika trend kuat, beri bobot lebih besar pada trend & momentum
    if (features.trend_strength > 0.7)
    {
        trend_weight_base += 0.10;
        momentum_weight_base += 0.05;
        volatility_weight_base -= 0.05;
    }

    // Jika volatilitas tinggi, kurangi pengaruh trend, tambahkan safety
    if (features.volatility > 0.6)
    {
        volatility_weight_base += 0.05;
        trend_weight_base -= 0.10;
        risk_weight_base += 0.10;
    }

    // Jika sentiment pasar sangat rendah (ketakutan tinggi), perkuat faktor safety
    if (features.risk_sentiment < 0.4)
    {
        risk_weight_base += 0.10;
        momentum_weight_base -= 0.05;
    }

    // --- Normalisasi total weight = 1.0 ---
    double total = trend_weight_base + volatility_weight_base + momentum_weight_base + risk_weight_base;
    if (total > 0)
    {
        ESD_ml_trend_weight = trend_weight_base / total;
        ESD_ml_volatility_weight = volatility_weight_base / total;
        ESD_ml_momentum_weight = momentum_weight_base / total;
        ESD_ml_risk_weight = risk_weight_base / total;
    }
    else
    {
        // fallback default
        ESD_ml_trend_weight = 0.35;
        ESD_ml_volatility_weight = 0.25;
        ESD_ml_momentum_weight = 0.25;
        ESD_ml_risk_weight = 0.15;
    }
}

//+------------------------------------------------------------------+
//| Calculate Risk Sentiment Indicator                              |
//+------------------------------------------------------------------+
double ESD_CalculateRiskSentiment()
{
    // Simplified risk sentiment based on multiple factors
    double sentiment = 0.5; // Neutral default

    // 1. Volatility component (high volatility = fear)
    double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double norm_vol = atr / price;

    if (norm_vol > 0.005) // High volatility
        sentiment -= 0.3;
    else if (norm_vol < 0.001) // Low volatility
        sentiment += 0.2;

    // 2. Trend component (strong trends = confidence)
    double trend_component = MathMax(ESD_bullish_trend_strength, ESD_bearish_trend_strength);
    sentiment += (trend_component - 0.5) * 0.2;

    // 3. Regime component
    if (ESD_current_regime == REGIME_TRENDING_BULLISH || ESD_current_regime == REGIME_TRENDING_BEARISH)
        sentiment += 0.1;
    else if (ESD_current_regime == REGIME_RANGING_HIGH_VOL || ESD_current_regime == REGIME_TRANSITION)
        sentiment -= 0.1;

    return MathMin(MathMax(sentiment, 0.0), 1.0);
}

//+------------------------------------------------------------------+
//| Enhanced Q-Learning dengan Experience Replay                     |
//+------------------------------------------------------------------+
void ESD_AdaptParametersWithEnhancedRL(ESD_ML_Features &features)
{
    if (!ESD_UseMachineLearning)
        return;

    // --- Hyperparameters ---
    static double alpha = 0.20;   // learning rate (slightly lower for stability)
    static double gamma = 0.95;   // discount factor (higher for long-term)
    static double epsilon = 0.20; // exploration rate
    static double epsilon_min = 0.02;
    static double epsilon_decay = 0.995;
    static int update_counter = 0;
    static int prev_state = -1;
    static int prev_action = -1;

    update_counter++;

    // --- Initialize Q-table ---
    if (!g_q_initialized)
    {
        MathSrand((int)TimeLocal());
        for (int s = 0; s < STATES; s++)
            for (int a = 0; a < ACTIONS; a++)
                g_Q[s][a] = (MathRand() % 200 - 100) / 10000.0; // Small random init

        g_q_initialized = true;
        ZeroMemory(g_perf_metrics);
        ZeroMemory(g_prev_perf_metrics);
    }

    // --- Update performance metrics ---
    ESD_UpdateMLPerformance();

    // --- Get current state ---
    int current_state = EncodeEnhancedState(features);

    // --- Calculate reward from previous action (if exists) ---
    if (prev_state >= 0 && prev_action >= 0)
    {
        double performance_score = ESD_CalculatePerformanceScore();
        double win_rate = ESD_ml_performance.win_rate;

        double old_params[4] = {
            ESD_ml_trend_weight,
            ESD_ml_volatility_weight,
            ESD_ml_momentum_weight,
            ESD_ml_risk_appetite};

        double reward = CalculateEnhancedReward(old_params, old_params,
                                                performance_score, win_rate);

        // Store experience
        bool terminal = (update_counter % 100 == 0); // Episode boundary
        StoreExperience(prev_state, prev_action, reward, current_state, terminal);

        // Learn from experience replay every 5 updates
        if (update_counter % 5 == 0)
        {
            LearnFromExperience(alpha, gamma);
        }
    }

    // --- Epsilon-greedy action selection ---
    int action = 0;
    double rand_val = (double)MathRand() / 32767.0;

    if (rand_val < epsilon)
    {
        // Exploration: random action
        action = MathRand() % ACTIONS;
    }
    else
    {
        // Exploitation: best Q-value action
        double max_q = g_Q[current_state][0];
        action = 0;
        for (int a = 1; a < ACTIONS; a++)
        {
            if (g_Q[current_state][a] > max_q)
            {
                max_q = g_Q[current_state][a];
                action = a;
            }
        }
    }

    // --- Decay epsilon ---
    if (update_counter % 10 == 0)
    {
        epsilon = MathMax(epsilon_min, epsilon * epsilon_decay);
    }

    // --- Action mapping (9 actions untuk kontrol lebih halus) ---
    double delta = ESD_ML_LearningRate * 2.0; // Slightly larger steps
    delta = MathMax(0.02, delta);

    switch (action)
    {
    case 0: // Increase trend weight
        ESD_ml_trend_weight = MathMin(ESD_ml_trend_weight + delta, 2.5);
        break;
    case 1: // Decrease trend weight
        ESD_ml_trend_weight = MathMax(ESD_ml_trend_weight - delta, 0.3);
        break;
    case 2: // Increase volatility weight
        ESD_ml_volatility_weight = MathMin(ESD_ml_volatility_weight + delta, 2.5);
        break;
    case 3: // Decrease volatility weight
        ESD_ml_volatility_weight = MathMax(ESD_ml_volatility_weight - delta, 0.3);
        break;
    case 4: // Increase momentum weight
        ESD_ml_momentum_weight = MathMin(ESD_ml_momentum_weight + delta, 2.5);
        break;
    case 5: // Decrease momentum weight
        ESD_ml_momentum_weight = MathMax(ESD_ml_momentum_weight - delta, 0.3);
        break;
    case 6: // Increase risk appetite
        ESD_ml_risk_appetite = MathMin(ESD_ml_risk_appetite + delta * 0.5, 0.90);
        break;
    case 7: // Decrease risk appetite
        ESD_ml_risk_appetite = MathMax(ESD_ml_risk_appetite - delta * 0.5, 0.15);
        break;
    case 8: // Balanced adjustment based on performance
        if (ESD_ml_performance.win_rate > 0.58)
        {
            // Increase all weights moderately
            ESD_ml_trend_weight = MathMin(ESD_ml_trend_weight + delta * 0.3, 2.5);
            ESD_ml_momentum_weight = MathMin(ESD_ml_momentum_weight + delta * 0.3, 2.5);
            ESD_ml_risk_appetite = MathMin(ESD_ml_risk_appetite + delta * 0.2, 0.90);
        }
        else if (ESD_ml_performance.win_rate < 0.42)
        {
            // Decrease all weights moderately
            ESD_ml_trend_weight = MathMax(ESD_ml_trend_weight - delta * 0.3, 0.3);
            ESD_ml_momentum_weight = MathMax(ESD_ml_momentum_weight - delta * 0.3, 0.3);
            ESD_ml_risk_appetite = MathMax(ESD_ml_risk_appetite - delta * 0.2, 0.15);
        }
        break;
    }

    // --- Constrain parameters ---
    ESD_ml_trend_weight = MathMax(0.3, MathMin(ESD_ml_trend_weight, 2.5));
    ESD_ml_volatility_weight = MathMax(0.3, MathMin(ESD_ml_volatility_weight, 2.5));
    ESD_ml_momentum_weight = MathMax(0.3, MathMin(ESD_ml_momentum_weight, 2.5));
    ESD_ml_risk_appetite = MathMax(0.10, MathMin(ESD_ml_risk_appetite, 0.95));

    // --- Store state and action for next iteration ---
    prev_state = current_state;
    prev_action = action;

    // --- Advanced adaptations ---
    ESD_AdaptSLTPMultipliers(features, ESD_CalculatePerformanceScore());
    ESD_AdaptLotSizeMultiplier(features, ESD_CalculatePerformanceScore());

    // --- Logging (every 50 updates) ---
    if (update_counter % 50 == 0)
    {
        PrintFormat("RL: state=%d action=%d eps=%.3f Q[s][a]=%.4f tr=%.2f vol=%.2f mom=%.2f risk=%.2f",
                    current_state, action, epsilon, g_Q[current_state][action],
                    ESD_ml_trend_weight, ESD_ml_volatility_weight,
                    ESD_ml_momentum_weight, ESD_ml_risk_appetite);
    }
}

//+------------------------------------------------------------------+
//| Fungsi bantu diskretisasi adaptif (3 bins dengan thresholds dinamis) |
//+------------------------------------------------------------------+
int AdaptiveBin3(double value, double &low_threshold, double &high_threshold,
                 double min_val, double max_val, double current_avg)
{
    // Adjust thresholds based on recent average
    low_threshold = current_avg - (current_avg - min_val) * 0.4;
    high_threshold = current_avg + (max_val - current_avg) * 0.4;

    if (value < low_threshold)
        return 0;
    if (value > high_threshold)
        return 2;
    return 1;
}

//+------------------------------------------------------------------+
//| Enhanced State Encoding dengan 5 features (243 states)           |
//+------------------------------------------------------------------+
int EncodeEnhancedState(ESD_ML_Features &features)
{
    static double trend_low = 0.35, trend_high = 0.65;
    static double vol_low = 0.0025, vol_high = 0.0075;
    static double mom_low = 0.35, mom_high = 0.65;
    static double risk_low = 0.33, risk_high = 0.66;
    static double perf_low = 0.4, perf_high = 0.6;

    // Calculate current averages for adaptive binning
    double perf_score = ESD_CalculatePerformanceScore();

    int t_bin = AdaptiveBin3(features.trend_strength, trend_low, trend_high, 0.0, 1.0, 0.5);
    int v_bin = AdaptiveBin3(features.volatility, vol_low, vol_high, 0.001, 0.01, 0.005);
    int m_bin = AdaptiveBin3(features.momentum, mom_low, mom_high, 0.0, 1.0, 0.5);
    int r_bin = AdaptiveBin3(features.risk_sentiment, risk_low, risk_high, 0.0, 1.0, 0.5);
    int p_bin = AdaptiveBin3(perf_score, perf_low, perf_high, 0.0, 1.0, 0.5);

    // Encode: state = t + 3*(v + 3*(m + 3*(r + 3*p)))
    int state = t_bin + 3 * (v_bin + 3 * (m_bin + 3 * (r_bin + 3 * p_bin)));
    return MathMin(state, STATES - 1);
}

//+------------------------------------------------------------------+
//| Calculate Enhanced Reward dengan multiple metrics                |
//+------------------------------------------------------------------+
double CalculateEnhancedReward(double &old_params[], double &new_params[],
                               double perf_score, double win_rate)
{
    double reward = 0.0;

    // 1. Performance improvement reward (40%)
    double perf_improvement = perf_score - 0.5;
    reward += perf_improvement * 1.5;

    // 2. Win rate reward (25%)
    double wr_improvement = (win_rate - 0.5) * 1.0;
    reward += wr_improvement;

    // 3. Profit factor reward (20%)
    double profit_factor = (g_perf_metrics.total_profit > 0 && g_perf_metrics.total_loss != 0)
                               ? g_perf_metrics.total_profit / MathAbs(g_perf_metrics.total_loss)
                               : 1.0;
    if (profit_factor > 1.5)
        reward += 0.3;
    else if (profit_factor < 1.0)
        reward -= 0.3;

    // 4. Drawdown penalty (15%)
    if (g_perf_metrics.max_drawdown > 0.15)
        reward -= 0.4;
    else if (g_perf_metrics.max_drawdown < 0.08)
        reward += 0.2;

    // 5. Consistency bonus (10%)
    if (g_perf_metrics.consecutive_wins >= 3)
        reward += 0.15;
    if (g_perf_metrics.consecutive_losses >= 3)
        reward -= 0.2;

    // 6. Parameter stability penalty - prevent wild swings
    double stability_penalty = 0.0;
    for (int i = 0; i < 4; i++)
    {
        double change = MathAbs(new_params[i] - old_params[i]);
        stability_penalty += change * 0.15;
    }
    reward -= MathMin(stability_penalty, 0.5);

    // 7. Risk-adjusted return bonus
    if (g_perf_metrics.sharpe_ratio > 1.5)
        reward += 0.25;
    else if (g_perf_metrics.sharpe_ratio < 0.5)
        reward -= 0.25;

    // Normalize reward to [-1, 1]
    return MathMax(-1.0, MathMin(1.0, reward));
}

//+------------------------------------------------------------------+
//| Store Experience dalam Replay Buffer                             |
//+------------------------------------------------------------------+
void StoreExperience(int state, int action, double reward, int next_state, bool terminal)
{
    g_experience_buffer[g_exp_write_idx].state = state;
    g_experience_buffer[g_exp_write_idx].action = action;
    g_experience_buffer[g_exp_write_idx].reward = reward;
    g_experience_buffer[g_exp_write_idx].next_state = next_state;
    g_experience_buffer[g_exp_write_idx].terminal = terminal;

    g_exp_write_idx = (g_exp_write_idx + 1) % MAX_EXPERIENCES;
    if (g_exp_count < MAX_EXPERIENCES)
        g_exp_count++;
}

//+------------------------------------------------------------------+
//| Experience Replay - Learn from random batch                      |
//+------------------------------------------------------------------+
void LearnFromExperience(double alpha, double gamma)
{
    if (g_exp_count < BATCH_SIZE)
        return;

    int batch_count = MathMin(BATCH_SIZE, g_exp_count);

    for (int i = 0; i < batch_count; i++)
    {
        // Random sample from experience buffer
        int idx = MathRand() % g_exp_count;
        Experience exp = g_experience_buffer[idx];

        // Calculate TD target
        double max_q_next = g_Q[exp.next_state][0];
        for (int a = 1; a < ACTIONS; a++)
        {
            if (g_Q[exp.next_state][a] > max_q_next)
                max_q_next = g_Q[exp.next_state][a];
        }

        double target = exp.terminal ? exp.reward : exp.reward + gamma * max_q_next;

        // Q-Learning update
        double old_q = g_Q[exp.state][exp.action];
        g_Q[exp.state][exp.action] = old_q + alpha * (target - old_q);
    }
}

//+------------------------------------------------------------------+
//| Update Performance Metrics                                        |
//+------------------------------------------------------------------+
void UpdatePerformanceMetrics()
{
    g_prev_perf_metrics = g_perf_metrics;

    // Update metrics from current trading performance
    g_perf_metrics.total_profit = ESD_ml_performance.total_profit;
    g_perf_metrics.total_loss = MathAbs(ESD_ml_performance.total_loss);
    g_perf_metrics.max_drawdown = ESD_ml_performance.max_drawdown;
    g_perf_metrics.avg_win = ESD_ml_performance.average_win;
    g_perf_metrics.avg_loss = MathAbs(ESD_ml_performance.average_loss);

    // Calculate Sharpe-like ratio (simplified)
    double avg_return = (g_perf_metrics.total_profit - g_perf_metrics.total_loss) /
                        MathMax(1.0, (double)ESD_ml_performance.total_trades);
    double return_std = MathSqrt(MathAbs(g_perf_metrics.avg_win - g_perf_metrics.avg_loss));
    g_perf_metrics.sharpe_ratio = (return_std > 0) ? avg_return / return_std : 0.0;

    g_perf_metrics.last_update = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Update ML Performance Metrics                                   |
//+------------------------------------------------------------------+
void ESD_UpdateMLPerformance()
{
    // Calculate performance metrics dari trading history
    double total_profit = 0;
    double total_loss = 0;
    int wins = 0;
    int losses = 0;
    double returns[];
    int return_count = 0;

    HistorySelect(0, TimeCurrent());
    int total = HistoryDealsTotal();

    for (int i = 0; i < total; i++)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if (HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
            continue;

        if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != ESD_MagicNumber)
            continue;

        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);

        if (profit > 0)
        {
            wins++;
            total_profit += profit;
        }
        else
        {
            losses++;
            total_loss += MathAbs(profit);
        }

        // Collect returns untuk Sharpe ratio
        ArrayResize(returns, return_count + 1);
        returns[return_count] = profit;
        return_count++;
    }

    // Update performance metrics
    ESD_ml_performance.trade_count = wins + losses;
    ESD_ml_performance.total_trades = wins + losses;
    ESD_ml_performance.win_rate = (ESD_ml_performance.trade_count > 0) ? (double)wins / ESD_ml_performance.trade_count : 0.0;
    ESD_ml_performance.profit_factor = (total_loss > 0) ? total_profit / total_loss : (total_profit > 0 ? 999 : 0);
    ESD_ml_performance.sharpe_ratio = ESD_CalculateSharpeRatio(returns);
    ESD_ml_performance.total_return = total_profit - total_loss;
    ESD_ml_performance.total_profit = total_profit;
    ESD_ml_performance.total_loss = total_loss;
    ESD_ml_performance.average_win = (wins > 0) ? total_profit / wins : 0;
    ESD_ml_performance.average_loss = (losses > 0) ? total_loss / losses : 0;
    ESD_ml_performance.last_update = TimeCurrent();

    // Update consecutive wins/losses
    static int last_wins = 0, last_losses = 0;
    if (wins > last_wins)
    {
        g_perf_metrics.consecutive_wins++;
        g_perf_metrics.consecutive_losses = 0;
    }
    else if (losses > last_losses)
    {
        g_perf_metrics.consecutive_losses++;
        g_perf_metrics.consecutive_wins = 0;
    }
    last_wins = wins;
    last_losses = losses;
}

//+------------------------------------------------------------------+
//| Calculate Sharpe Ratio                                          |
//+------------------------------------------------------------------+
double ESD_CalculateSharpeRatio(double &returns[])
{
    int size = ArraySize(returns);
    if (size < 2)
        return 0.0;

    double sum = 0.0;
    for (int i = 0; i < size; i++)
        sum += returns[i];

    double mean = sum / size;

    double variance = 0.0;
    for (int i = 0; i < size; i++)
        variance += MathPow(returns[i] - mean, 2);

    double std_dev = MathSqrt(variance / (size - 1));

    if (std_dev == 0)
        return 0.0;

    return mean / std_dev * MathSqrt(252); // Annualized Sharpe ratio
}

//+------------------------------------------------------------------+
//| Calculate Overall Performance Score                             |
//+------------------------------------------------------------------+
double ESD_CalculatePerformanceScore()
{
    double score = 0.0;
    int factors = 0;

    if (ESD_ml_performance.trade_count >= 10)
    {
        // Win Rate component (30% weight)
        score += ESD_ml_performance.win_rate * 0.3;
        factors++;

        // Profit Factor component (30% weight)
        double pf_score = MathMin(ESD_ml_performance.profit_factor / 3.0, 1.0);
        score += pf_score * 0.3;
        factors++;

        // Sharpe Ratio component (20% weight)
        double sharpe_score = MathMin(ESD_ml_performance.sharpe_ratio / 2.0, 1.0);
        score += sharpe_score * 0.2;
        factors++;

        // Consistency component (20% weight)
        double consistency = 1.0 - (ESD_ml_performance.volatility / 0.1); // Lower volatility better
        score += MathMax(consistency, 0.0) * 0.2;
        factors++;
    }

    return (factors > 0) ? score : 0.5; // Return 0.5 jika belum cukup data
}

//+------------------------------------------------------------------+
//| Adaptive SL/TP Multipliers                                      |
//+------------------------------------------------------------------+
void ESD_AdaptSLTPMultipliers(ESD_ML_Features &features, double performance_score)
{
    if (!ESD_ML_AdaptiveSLTP)
        return;

    // Adaptive SL Multiplier
    if (features.volatility > 0.006) // High volatility
        ESD_ml_optimal_sl_multiplier = MathMin(ESD_ml_optimal_sl_multiplier + ESD_ML_LearningRate, 1.5);
    else if (features.volatility < 0.002 && performance_score > 0.6) // Low volatility + good performance
        ESD_ml_optimal_sl_multiplier = MathMax(ESD_ml_optimal_sl_multiplier - ESD_ML_LearningRate, 0.7);

    // Adaptive TP Multiplier
    if (features.trend_strength > 0.7 && performance_score > 0.6) // Strong trend + good performance
        ESD_ml_optimal_tp_multiplier = MathMin(ESD_ml_optimal_tp_multiplier + ESD_ML_LearningRate, 1.8);
    else if (features.trend_strength < 0.4 || performance_score < 0.4) // Weak trend or poor performance
        ESD_ml_optimal_tp_multiplier = MathMax(ESD_ml_optimal_tp_multiplier - ESD_ML_LearningRate, 0.8);
}

//+------------------------------------------------------------------+
//| Adaptive Lot Size Multiplier                                    |
//+------------------------------------------------------------------+
void ESD_AdaptLotSizeMultiplier(ESD_ML_Features &features, double performance_score)
{
    if (!ESD_ML_AdaptiveLotSize)
        return;

    // Base pada risk appetite dan performance
    double base_multiplier = ESD_ml_risk_appetite;

    // Adjust berdasarkan volatility
    if (features.volatility > 0.007) // Very high volatility
        base_multiplier *= 0.7;
    else if (features.volatility < 0.003 && performance_score > 0.6) // Low volatility + good performance
        base_multiplier *= 1.2;

    // Adjust berdasarkan trend strength
    if (features.trend_strength > 0.75 && performance_score > 0.65)
        base_multiplier *= 1.1;

    // Adjust berdasarkan drawdown protection
    if (ESD_ml_performance.max_drawdown > 0.1) // 10% drawdown
        base_multiplier *= 0.8;

    ESD_ml_lot_size_multiplier = MathMin(MathMax(base_multiplier, 0.3), 2.0);
}

//+------------------------------------------------------------------+
//| Adjust Dynamic Filters berdasarkan ML                          |
//+------------------------------------------------------------------+
void ESD_AdjustDynamicFilters()
{
    if (!ESD_ML_DynamicFilter)
        return;

    // Adaptive Trend Strength Threshold
    if (ESD_ml_performance.win_rate > 0.65 && ESD_ml_trend_weight > 1.2)
        ESD_TrendStrengthThreshold = MathMin(ESD_TrendStrengthThreshold + 0.05, 0.9);
    else if (ESD_ml_performance.win_rate < 0.35 || ESD_ml_trend_weight < 0.8)
        ESD_TrendStrengthThreshold = MathMax(ESD_TrendStrengthThreshold - 0.05, 0.3);

    // Adaptive Zone Quality Filter
    if (ESD_ml_performance.win_rate > 0.7)
        ESD_MinZoneQualityScore = MathMin(ESD_MinZoneQualityScore + 0.05, 0.8);
    else if (ESD_ml_performance.win_rate < 0.4)
        ESD_MinZoneQualityScore = MathMax(ESD_MinZoneQualityScore - 0.05, 0.4);

    // Adaptive Heatmap Threshold
    if (ESD_ml_performance.profit_factor > 2.0)
        ESD_HeatmapStrengthThreshold = MathMin(ESD_HeatmapStrengthThreshold + 5, 85);
    else if (ESD_ml_performance.profit_factor < 1.0)
        ESD_HeatmapStrengthThreshold = MathMax(ESD_HeatmapStrengthThreshold - 5, 50);
}

//+------------------------------------------------------------------+
//| Update Machine Learning Model                                   |
//+------------------------------------------------------------------+
void ESD_UpdateMLModel()
{
    if (!ESD_UseMachineLearning)
        return;

    static int last_update_bar = 0;
    int current_bar = iBars(_Symbol, PERIOD_CURRENT);

    if (current_bar - last_update_bar < ESD_ML_UpdateInterval)
        return;

    // Collect current features
    ESD_ML_Features features = ESD_CollectMLFeatures();

    // Update performance metrics
    ESD_UpdateMLPerformance();

    // Adaptive Parameter Adjustment menggunakan Enhanced Reinforcement Learning
    ESD_AdaptParametersWithEnhancedRL(features);

    // Dynamic Filter Adjustment
    if (ESD_ML_DynamicFilter)
        ESD_AdjustDynamicFilters();

    last_update_bar = current_bar;

    // Log ML status
    if (ESD_ShowObjects && ESD_ShowLabels)
    {
        ESD_DrawTradingDataPanel();
    }
}

//+------------------------------------------------------------------+
//| Get ML-Enhanced Entry Signal                                    |
//+------------------------------------------------------------------+
double ESD_GetMLEntrySignal(bool is_buy_signal, ESD_ML_Features &features)
{
    if (!ESD_UseMachineLearning)
        return 1.0;

    // --- Update weights adaptively ---
    ESD_UpdateMLWeights(features);

    double base_signal = is_buy_signal ? 1.0 : -1.0;
    double ml_confidence = 0.0;
    double ESD_ml_risk_weight = 0.5;

    // --- Weighted aggregation ---
    ml_confidence += features.trend_strength * ESD_ml_trend_weight;
    ml_confidence += (1.0 - features.volatility) * ESD_ml_volatility_weight;
    ml_confidence += (MathAbs(features.momentum - 0.5) * 2.0) * ESD_ml_momentum_weight;
    ml_confidence += features.risk_sentiment * ESD_ml_risk_weight;
    ml_confidence += features.structure_quality * 0.3;
    ml_confidence += features.heatmap_strength * 0.2;
    ml_confidence += features.orderflow_strength * 0.2;

    // --- Sentiment safety multiplier ---
    double sentiment = MathMax(features.risk_sentiment, 0.5);
    ml_confidence *= sentiment;

    // --- Normalize range + offset ---
    ml_confidence = MathMin(MathMax(ml_confidence + 0.2, 0.0), 2.0);

    return base_signal * ml_confidence;
}

//+------------------------------------------------------------------+
//| Get ML-Adjusted Lot Size                                        |
//+------------------------------------------------------------------+
double ESD_GetMLAdjustedLotSize()
{
    if (!ESD_UseMachineLearning || !ESD_ML_AdaptiveLotSize)
        return ESD_LotSize;

    double base_lot = ESD_LotSize;
    double adjusted_lot = base_lot * ESD_ml_lot_size_multiplier;

    // Ensure within broker limits
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

    adjusted_lot = MathMax(adjusted_lot, min_lot);
    adjusted_lot = MathMin(adjusted_lot, max_lot);

    return adjusted_lot;
}

//+------------------------------------------------------------------+
//| Get ML-Adjusted SL/TP                                           |
//+------------------------------------------------------------------+
void ESD_GetMLAdjustedSLTP(bool is_buy, double entry_price, double &sl, double &tp)
{
    if (!ESD_UseMachineLearning || !ESD_ML_AdaptiveSLTP)
        return;

    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // Apply ML multipliers to SL/TP distances
    double sl_points = ESD_StopLossPoints * ESD_ml_optimal_sl_multiplier;
    double tp_points = ESD_TakeProfitPoints * ESD_ml_optimal_tp_multiplier;

    if (is_buy)
    {
        sl = entry_price - sl_points * point;
        tp = entry_price + tp_points * point;
    }
    else
    {
        sl = entry_price + sl_points * point;
        tp = entry_price - tp_points * point;
    }
}

//+------------------------------------------------------------------+
//| Enhanced Entry dengan ML Integration - COMPLETE VERSION         |
//+------------------------------------------------------------------+
void ESD_CheckForEntryWithML()
{
    // Jika sudah ada posisi, tidak usah entry lagi
    if (PositionSelect(_Symbol))
        return;

    // Update ML model
    ESD_UpdateMLModel();

    // Collect features untuk ML
    ESD_ML_Features features = ESD_CollectMLFeatures();

    // Get ML-enhanced signals
    double buy_signal = ESD_GetMLEntrySignal(true, features);
    double sell_signal = ESD_GetMLEntrySignal(false, features);

    // Apply ML confidence threshold
    double ml_confidence_threshold = 0.5;

    // 🎯 PRIORITAS 1: ENTRY BERDASARKAN INDUCEMENT (False Breakout)
    if (ESD_TradeAgainstInducement())
        return;

    // ================== ENHANCED BUY LOGIC DENGAN ML ==================
    if (ESD_bullish_trend_confirmed && ESD_bullish_trend_strength >= ESD_TrendStrengthThreshold)
    {
        // REGIME FILTER untuk BUY
        if (!ESD_RegimeFilter(true))
            return;

        // 🚫 BSL/SSL AVOIDANCE CHECK
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        if (ESD_IsInBSL_SSLZone(ask, true))
            return;

        // ML CONFIDENCE FILTER - ENHANCED
        if (buy_signal < ml_confidence_threshold)
        {
            Print("ML Filter: Buy signal rejected. Confidence: ", buy_signal);
            return;
        }

        // --- ORIGINAL SMC BUY LOGIC + ML ENHANCEMENT ---
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double tolerance = ESD_ZoneTolerancePoints * point;

        // Data candle untuk konfirmasi
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        CopyRates(_Symbol, PERIOD_CURRENT, 0, ESD_RejectionCandleLookback + 2, rates);

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
            return;

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

        // Quality filter check dengan ML enhancement
        double ml_enhanced_quality = zone_quality * (0.7 + buy_signal * 0.3); // Boost quality dengan ML confidence
        if (ESD_EnableQualityFilter && ml_enhanced_quality < ESD_MinZoneQualityScore)
        {
            Print("ML Quality Filter: Buy zone rejected. Quality: ", ml_enhanced_quality);
            is_in_buy_zone = false;
            fvg_just_filled = false;
        }

        // Jika harga berada di zona atau FVG baru saja terisi
        if ((is_in_buy_zone && is_retesting_zone) || fvg_just_filled)
        {
            // Additional confirmation checks
            bool confirmed = true;

            // Rejection candle confirmation
            if (ESD_UseRejectionCandleConfirmation)
                confirmed = ESD_IsRejectionCandle(rates[ESD_RejectionCandleLookback], true);

            // Liquidity sweep confirmation
            if (ESD_EnableLiquiditySweepFilter && ESD_bullish_liquidity != EMPTY_VALUE)
                confirmed = confirmed && ESD_IsLiquiditySweeped(ESD_bullish_liquidity, true);

            // FVG mitigation filter
            if (ESD_UseFvgMitigationFilter && ESD_bullish_fvg_bottom != EMPTY_VALUE)
                confirmed = confirmed && ESD_IsFVGMitigated(ESD_bullish_fvg_top, ESD_bullish_fvg_bottom, true);

            // Heatmap + Order Flow confirmation filter
            if (!ESD_HeatmapFilter(true) || !ESD_OrderFlowFilter(true))
                return;

            // === Stochastic Entry Filter ===
            if (!ESD_StochasticEntryFilter(true))
                return;

            if (confirmed)
            {
                // --- ML-ENHANCED POSITION MANAGEMENT ---
                double adjusted_lot = ESD_GetMLAdjustedLotSize();
                double ml_sl = 0, ml_tp = 0;
                double trigger_price = zone_bottom;

                // Calculate ML-adjusted SL/TP
                ESD_GetMLAdjustedSLTP(true, ask, ml_sl, ml_tp);

                // Jika menggunakan Partial TP, hitung TP level 3
                if (ESD_UsePartialTP)
                {
                    ml_tp = ask + ESD_PartialTPDistance3 * point;

                    // 🆕 SL LEBIH LONGGAR - MENGGUNAKAN ZONE WIDTH ATAU ATR
                    double zone_height = zone_top - zone_bottom;
                    double atr_value = iATR(_Symbol, PERIOD_CURRENT, 14);
                    // Gunakan 1.5x dari zone height atau 2x ATR, mana yang lebih besar
                    double sl_points_fixed = MathMax(ESD_StopLossPoints * 1.5, zone_height / point * 1.2);
                    ml_sl = zone_bottom - sl_points_fixed * point;
                    double structure_sl = ESD_FindSupportBelowZone(zone_bottom);
                    // Fallback: gunakan 1.2x zone height atau 1.8x ATR
                    double fallback_sl = MathMax(zone_height * 1.2, atr_value * 1.8);
                    // Default: gunakan kombinasi zone height dan ATR
                    double default_sl = MathMax(zone_height * 1.1, atr_value * 1.5);

                    switch (ESD_SlTpMethod)
                    {
                    case ESD_FIXED_POINTS:

                        break;
                    case ESD_STRUCTURE_BASED:
                        // Cari support level di bawah zone

                        if (structure_sl > 0 && structure_sl < zone_bottom)
                        {
                            ml_sl = structure_sl - ESD_SlBufferPoints * point;
                        }
                        else
                        {

                            ml_sl = zone_bottom - fallback_sl;
                        }
                        break;
                    default:

                        ml_sl = zone_bottom - default_sl;
                        break;
                    }
                }

                // 🆕 VALIDASI SL MINIMUM - Pastikan SL cukup longgar
                double atr_value = iATR(_Symbol, PERIOD_CURRENT, 14);
                double min_sl_distance = atr_value * 1.2; // Minimum 1.2 ATR
                if ((zone_bottom - ml_sl) < min_sl_distance)
                {
                    ml_sl = zone_bottom - min_sl_distance;
                    Print("SL Adjusted to minimum distance: ", min_sl_distance);
                }

                // Validasi SL/TP agar tidak salah
                if (ml_sl >= ask)
                    ml_sl = ask - min_sl_distance;
                if (ml_tp <= ask)
                    ml_tp = ask + 100 * point;
                if (ml_sl <= 0 || ml_tp <= 0)
                    return;

                string comment = StringFormat("ML-BUY (%s) Q=%.2f Conf=%.2f SL=%.5f",
                                              zone_type, ml_enhanced_quality, buy_signal, ml_sl);

                // 🚀 EXECUTE TRADE DENGAN ML PARAMETERS
                ESD_ExecuteTradeWithPartialTP(true, ask, ml_sl, comment);

                Print("ML Enhanced BUY Executed: ", comment);
                Print("SL Distance: ", (zone_bottom - ml_sl) / point, " points");
                return;
            }
        }
    }

    // ================== ENHANCED SELL LOGIC DENGAN ML ==================
    if (ESD_bearish_trend_confirmed && ESD_bearish_trend_strength >= ESD_TrendStrengthThreshold)
    {
        // REGIME FILTER untuk SELL
        if (!ESD_RegimeFilter(false))
            return;

        // 🚫 BSL/SSL AVOIDANCE CHECK
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        if (ESD_IsInBSL_SSLZone(bid, false))
            return;

        // ML CONFIDENCE FILTER - ENHANCED
        if (sell_signal > -ml_confidence_threshold) // Note: sell_signal negative
        {
            Print("ML Filter: Sell signal rejected. Confidence: ", MathAbs(sell_signal));
            return;
        }

        // --- ORIGINAL SMC SELL LOGIC + ML ENHANCEMENT ---
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double tolerance = ESD_ZoneTolerancePoints * point;

        // Data candle untuk konfirmasi
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        CopyRates(_Symbol, PERIOD_CURRENT, 0, ESD_RejectionCandleLookback + 2, rates);

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
            return;

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

        // 3. Cek apakah FVG baru saja terisi (harga menembus FVG dari atas)
        bool fvg_just_filled = false;
        if (ESD_bearish_fvg_top != EMPTY_VALUE && !is_in_sell_zone)
        {
            if (bid < ESD_bearish_fvg_bottom && rates[1].close > ESD_bearish_fvg_top)
            {
                fvg_just_filled = true;
                zone_top = ESD_bearish_fvg_top;
                zone_bottom = ESD_bearish_fvg_bottom;
                zone_type = "FVG_FILLED";
                is_retesting_zone = true;
                zone_quality = ESD_GetZoneQuality("FVG", iTime(_Symbol, ESD_HigherTimeframe, 0), false);
            }
        }

        // Quality filter check dengan ML enhancement
        double ml_enhanced_quality = zone_quality * (0.7 + MathAbs(sell_signal) * 0.3); // Boost quality dengan ML confidence
        if (ESD_EnableQualityFilter && ml_enhanced_quality < ESD_MinZoneQualityScore)
        {
            Print("ML Quality Filter: Sell zone rejected. Quality: ", ml_enhanced_quality);
            is_in_sell_zone = false;
            fvg_just_filled = false;
        }

        // Jika harga berada di zona atau FVG baru saja terisi
        if (is_in_sell_zone || fvg_just_filled)
        {
            // Additional confirmation checks
            bool confirmed = true;

            // Rejection candle confirmation
            if (ESD_UseRejectionCandleConfirmation)
                confirmed = ESD_IsRejectionCandle(rates[ESD_RejectionCandleLookback], false);

            // Liquidity sweep confirmation
            if (ESD_EnableLiquiditySweepFilter && ESD_bearish_liquidity != EMPTY_VALUE)
                confirmed = confirmed && ESD_IsLiquiditySweeped(ESD_bearish_liquidity, false);

            // FVG mitigation filter
            if (ESD_UseFvgMitigationFilter && ESD_bearish_fvg_top != EMPTY_VALUE)
                confirmed = confirmed && ESD_IsFVGMitigated(ESD_bearish_fvg_top, ESD_bearish_fvg_bottom, false);

            // Heatmap confirmation filter
            if (!ESD_HeatmapFilter(false))
                return;

            // === Stochastic Entry Filter ===
            if (!ESD_StochasticEntryFilter(false))
                return;

            if (confirmed)
            {
                // --- ML-ENHANCED POSITION MANAGEMENT ---
                double adjusted_lot = ESD_GetMLAdjustedLotSize();
                double ml_sl = 0, ml_tp = 0;
                double trigger_price = zone_top;

                // Calculate ML-adjusted SL/TP
                ESD_GetMLAdjustedSLTP(false, bid, ml_sl, ml_tp);

                // Jika menggunakan Partial TP, hitung TP level 3
                if (ESD_UsePartialTP)
                {
                    ml_tp = bid - ESD_PartialTPDistance3 * point;

                    // 🆕 SL LEBIH LONGGAR - MENGGUNAKAN ZONE WIDTH ATAU ATR
                    double zone_height = zone_top - zone_bottom;
                    double atr_value = iATR(_Symbol, PERIOD_CURRENT, 14);
                    // Gunakan 1.5x dari zone height atau 2x ATR, mana yang lebih besar
                    double sl_points_fixed = MathMax(ESD_StopLossPoints * 1.5, zone_height / point * 1.2);
                    // Cari resistance level di atas zone
                    double structure_sl = ESD_FindResistanceAboveZone(zone_top);
                    // Fallback: gunakan 1.2x zone height atau 1.8x ATR
                    double fallback_sl = MathMax(zone_height * 1.2, atr_value * 1.8);
                    // Default: gunakan kombinasi zone height dan ATR
                    double default_sl = MathMax(zone_height * 1.1, atr_value * 1.5);
                    switch (ESD_SlTpMethod)
                    {
                    case ESD_FIXED_POINTS:

                        ml_sl = zone_top + sl_points_fixed * point;
                        break;
                    case ESD_STRUCTURE_BASED:

                        if (structure_sl > 0 && structure_sl > zone_top)
                        {
                            ml_sl = structure_sl + ESD_SlBufferPoints * point;
                        }
                        else
                        {

                            ml_sl = zone_top + fallback_sl;
                        }
                        break;
                    default:

                        ml_sl = zone_top + default_sl;
                        break;
                    }
                }

                // 🆕 VALIDASI SL MINIMUM - Pastikan SL cukup longgar
                double atr_value = iATR(_Symbol, PERIOD_CURRENT, 14);
                double min_sl_distance = atr_value * 1.2; // Minimum 1.2 ATR
                if ((ml_sl - zone_top) < min_sl_distance)
                {
                    ml_sl = zone_top + min_sl_distance;
                    Print("SL Adjusted to minimum distance: ", min_sl_distance);
                }

                // Validasi SL/TP agar tidak salah
                if (ml_sl <= bid)
                    ml_sl = bid + min_sl_distance;
                if (ml_tp >= bid)
                    ml_tp = bid - 100 * point;
                if (ml_sl <= 0 || ml_tp <= 0)
                    return;

                string comment = StringFormat("ML-SELL (%s) Q=%.2f Conf=%.2f SL=%.5f",
                                              zone_type, ml_enhanced_quality, MathAbs(sell_signal), ml_sl);

                // 🚀 EXECUTE TRADE DENGAN ML PARAMETERS
                ESD_ExecuteTradeWithPartialTP(false, bid, ml_sl, comment);

                Print("ML Enhanced SELL Executed: ", comment);
                Print("SL Distance: ", (ml_sl - zone_top) / point, " points");
                return;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Trailing Stop Khusus Entry Tanpa Comment                         |
//| Update SL mengikuti harga terbaru                                |
//+------------------------------------------------------------------+
void ESD_TrailingStop(double trailingDistancePoints, double xauTrailingDistancePoints = 0)
{
    CTrade trade;

    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (ticket <= 0 || !PositionSelectByTicket(ticket))
            continue;

        string symbol = PositionGetString(POSITION_SYMBOL);
        string comment = PositionGetString(POSITION_COMMENT);
        long type = PositionGetInteger(POSITION_TYPE);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentTP = PositionGetDouble(POSITION_TP);
        double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

        // ⚠️ Skip trailing jika posisi punya komentar sinyal
        if (StringLen(comment) > 0)
        {
            // Bisa tambahkan log optional
            // PrintFormat("Skip trailing %s (ticket %d) karena ada komentar: %s", symbol, ticket, comment);
            continue;
        }

        // Tentukan trailing distance berdasarkan simbol
        double trailingDistance = trailingDistancePoints;
        if (xauTrailingDistancePoints > 0 && (symbol == "XAUUSD" || symbol == "GOLD"))
            trailingDistance = xauTrailingDistancePoints;

        double newSL = 0.0;
        bool shouldUpdate = false;

        if (type == POSITION_TYPE_BUY)
        {
            double profitPoints = (bid - openPrice) / point;
            if (profitPoints > trailingDistance)
            {
                newSL = bid - (trailingDistance * point);
                newSL = NormalizeDouble(newSL, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
                if (currentSL == 0 || newSL > currentSL)
                    shouldUpdate = true;
            }
        }
        else if (type == POSITION_TYPE_SELL)
        {
            double profitPoints = (openPrice - ask) / point;
            if (profitPoints > trailingDistance)
            {
                newSL = ask + (trailingDistance * point);
                newSL = NormalizeDouble(newSL, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
                if (currentSL == 0 || newSL < currentSL)
                    shouldUpdate = true;
            }
        }

        if (shouldUpdate)
        {
            if (trade.PositionModify(ticket, newSL, currentTP))
            {
                PrintFormat("SUCCESS: %s SL updated to %.5f (Trailing: %.1f points)",
                            symbol, newSL, trailingDistance);
            }
            else
            {
                PrintFormat("ERROR: Failed to modify %s. Error: %d", symbol, GetLastError());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Fungsi Tunggal: Stochastic + ML + Eksekusi Order                |
//+------------------------------------------------------------------+
void ESD_TryOpenMLStochasticTrade()
{
    // --- 1. Batasi maksimal 5 posisi aktif ---
    int active_positions = 0;
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (PositionSelectByTicket(PositionGetTicket(i)))
        {
            string sym = PositionGetString(POSITION_SYMBOL);
            if (sym == _Symbol)
                active_positions++;
        }
    }

    if (active_positions >= 5)
    {
        Print("⚠️ Batas maksimal posisi (5) tercapai untuk ", _Symbol);
        return;
    }

    // --- 2. Parameter Stochastic ---
    int Kperiod = 14;
    int Dperiod = 3;
    int slowing = 3;
    double overbought = 90.0;
    double oversold = 10.0;

    double K[], D[];
    int handle = iStochastic(_Symbol, PERIOD_CURRENT, Kperiod, Dperiod, slowing, MODE_SMA, STO_LOWHIGH);
    if (handle == INVALID_HANDLE)
        return;

    if (CopyBuffer(handle, 0, 0, 2, K) != 2 || CopyBuffer(handle, 1, 0, 2, D) != 2)
        return;

    double K_prev = K[1], D_prev = D[1];
    double K_cur = K[0], D_cur = D[0];

    // --- 2a. Ambil data Stochastic M1 untuk konfirmasi ---
    double K_M1[], D_M1[];
    int handle_M1 = iStochastic(_Symbol, PERIOD_M1, Kperiod, Dperiod, slowing, MODE_SMA, STO_LOWHIGH);
    bool m1_confirm = false;

    if (handle_M1 != INVALID_HANDLE)
    {
        if (CopyBuffer(handle_M1, 0, 0, 1, K_M1) == 1 && CopyBuffer(handle_M1, 1, 0, 1, D_M1) == 1)
        {
            double K_m1 = K_M1[0], D_m1 = D_M1[0];

            // Konfirmasi M1: harus dalam kondisi overbought/oversold yang sama
            if ((K_cur > overbought && D_cur > overbought && K_m1 > overbought && D_m1 > overbought) ||
                (K_cur < oversold && D_cur < oversold && K_m1 < oversold && D_m1 < oversold))
            {
                m1_confirm = true;
                Print("✅ Konfirmasi M1: Stochastic searah dengan timeframe current");
            }
        }
        IndicatorRelease(handle_M1);
    }

    bool is_buy_signal = false, is_sell_signal = false;

    // Deteksi sinyal dengan konfirmasi M1
    if (K_cur < oversold && D_cur < oversold && K_prev < D_prev && K_cur > D_cur)
    {
        if (m1_confirm)
            is_buy_signal = true;
        else
            Print("ℹ️ Sinyal BUY tapi tanpa konfirmasi M1");
    }
    else if (K_cur > overbought && D_cur > overbought && K_prev > D_prev && K_cur < D_cur)
    {
        if (m1_confirm)
            is_sell_signal = true;
        else
            Print("ℹ️ Sinyal SELL tapi tanpa konfirmasi M1");
    }

    if (!is_buy_signal && !is_sell_signal)
        return; // Tidak ada sinyal

    // --- 3. Kumpulkan fitur ML ---
    ESD_ML_Features features = ESD_CollectMLFeatures();
    if (ESD_UseMachineLearning)
        ESD_UpdateMLWeights(features);

    // --- 4. Hitung confidence ML ---
    double ml_confidence = 0.0;
    if (ESD_UseMachineLearning)
    {
        ml_confidence += features.trend_strength * ESD_ml_trend_weight;
        ml_confidence += (1.0 - features.volatility) * ESD_ml_volatility_weight;
        ml_confidence += (MathAbs(features.momentum - 0.5) * 2.0) * ESD_ml_momentum_weight;
        ml_confidence += features.risk_sentiment * ESD_ml_risk_appetite;
        ml_confidence += features.structure_quality * 0.3;
        ml_confidence += features.heatmap_strength * 0.2;
        ml_confidence += features.orderflow_strength * 0.2;

        double sentiment = MathMax(features.risk_sentiment, 0.5);
        ml_confidence *= sentiment;
        ml_confidence = MathMin(MathMax(ml_confidence + 0.2, 0.0), 2.0);
    }
    else
    {
        ml_confidence = 1.0; // Tanpa ML, gunakan confidence netral
    }

    // Ambang batas eksekusi
    const double CONFIDENCE_THRESHOLD = 0.6;
    if (ml_confidence < CONFIDENCE_THRESHOLD)
        return;

    // --- 5. Tentukan arah & kekuatan sinyal ---
    double signal_strength = ml_confidence;
    bool is_buy = is_buy_signal;

    // --- 6. Hitung ukuran lot ---
    //    double lot = ESD_LotSize;
    //    if (ESD_UseMachineLearning && ESD_ML_AdaptiveLotSize)
    //    {
    //       lot *= ESD_ml_lot_size_multiplier;
    //       double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    //       double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    //       double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    //       lot = MathMax(lot, min_lot);
    //       lot = MathMin(lot, max_lot);
    //       lot = MathFloor(lot / lot_step) * lot_step;
    //    }

    double lot = 0.1;

    // --- 7. Hitung SL & TP (dengan TP lebih optimal) ---
    double sl = 0, tp = 0;
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

    // Tentukan pip yang benar untuk XAUUSD dan simbol lain
    double pip = (digits == 3 || digits == 5) ? point * 10 : point;

    // Minimal jarak stop level broker
    double minStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;

    // Faktor multiplier untuk TP yang lebih jauh
    double tp_multiplier = 3.5; 
    double base_tp_points = ESD_TakeProfitPoints;

    // Harga dasar untuk buy / sell
    double price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // Hitung jarak SL & TP
    double sl_pts, tp_pts;
    if (ESD_UseMachineLearning && ESD_ML_AdaptiveSLTP)
    {
        sl_pts = ESD_StopLossPoints * ESD_ml_optimal_sl_multiplier * pip;
        tp_pts = base_tp_points * ESD_ml_optimal_tp_multiplier * tp_multiplier * pip;
    }
    else
    {
        sl_pts = ESD_StopLossPoints * pip;
        tp_pts = base_tp_points * tp_multiplier * pip;
    }

    // Pastikan tidak lebih kecil dari minimal stop level brokernya
    sl_pts = MathMax(sl_pts, minStopLevel);
    tp_pts = MathMax(tp_pts, minStopLevel);

    // Tetapkan SL & TP final
    if (is_buy)
    {
        sl = price - sl_pts;
        tp = price + tp_pts;
    }
    else
    {
        sl = price + sl_pts;
        tp = price - tp_pts;
    }

    // --- 8. Eksekusi order ---
    string comment = "ESD_Stochastic_ML";
    bool result = false;

    if (is_buy)
    {
        double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        result = ESD_trade.Buy(lot, _Symbol, price, sl, tp, comment);
        if (result)
            Print("✅ BUY dibuka | Conf: ", DoubleToString(ml_confidence, 2),
                  " | Lot: ", DoubleToString(lot, 2), " | TP Optimal: +", DoubleToString(tp_multiplier * 100, 0), "%");
    }
    else
    {
        double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        result = ESD_trade.Sell(lot, _Symbol, price, sl, tp, comment);
        if (result)
            Print("✅ SELL dibuka | Conf: ", DoubleToString(ml_confidence, 2),
                  " | Lot: ", DoubleToString(lot, 2), " | TP Optimal: +", DoubleToString(tp_multiplier * 100, 0), "%");
    }

    if (!result)
        Print("❌ Gagal membuka order: ", GetLastError());
}

//+------------------------------------------------------------------+
//| Execute Trade Function                                          |
//+------------------------------------------------------------------+
bool ESD_ExecuteTrade(bool is_buy, double price, double sl, double tp, double lot, string comment)
{
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);

    // Setup trade request
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lot;
    request.deviation = 10;
    request.magic = 12345;
    request.comment = comment;

    if (is_buy)
    {
        request.type = ORDER_TYPE_BUY;
        request.price = NormalizeDouble(price, _Digits);
        if (sl > 0)
            request.sl = NormalizeDouble(sl, _Digits);
        if (tp > 0)
            request.tp = NormalizeDouble(tp, _Digits);
    }
    else
    {
        request.type = ORDER_TYPE_SELL;
        request.price = NormalizeDouble(price, _Digits);
        if (sl > 0)
            request.sl = NormalizeDouble(sl, _Digits);
        if (tp > 0)
            request.tp = NormalizeDouble(tp, _Digits);
    }

    // Send order
    bool success = OrderSend(request, result);

    if (success && result.retcode == TRADE_RETCODE_DONE)
    {
        Print("Trade executed: ", comment);
        return true;
    }
    else
    {
        Print("Trade failed: ", GetLastError());
        return false;
    }
}

//+------------------------------------------------------------------+
//| Liquidity Grab Confirmation Functions                            |
//+------------------------------------------------------------------+
bool ESD_IsBullishConfirmationCandle()
{
    MqlRates current[];
    ArraySetAsSeries(current, true);
    if (CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, current) > 0)
    {
        bool is_bullish = (current[0].close > current[0].open);
        double body_size = MathAbs(current[0].close - current[0].open);
        double range = current[0].high - current[0].low;
        double body_ratio = (range > 0) ? (body_size / range) : 0;

        return (is_bullish && body_ratio > 0.4);
    }
    return false;
}

bool ESD_IsBearishConfirmationCandle()
{
    MqlRates current[];
    ArraySetAsSeries(current, true);
    if (CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, current) > 0)
    {
        bool is_bearish = (current[0].close < current[0].open);
        double body_size = MathAbs(current[0].close - current[0].open);
        double range = current[0].high - current[0].low;
        double body_ratio = (range > 0) ? (body_size / range) : 0;

        return (is_bearish && body_ratio > 0.4);
    }
    return false;
}

//+------------------------------------------------------------------+
//| Find Resistance Level Above Zone                                |
//+------------------------------------------------------------------+
double ESD_FindResistanceAboveZone(double zone_top)
{
    int bars = 100; // Lookback period
    double high_buffer[];
    ArraySetAsSeries(high_buffer, true);

    // Copy high prices
    if (CopyHigh(_Symbol, PERIOD_CURRENT, 0, bars, high_buffer) < bars)
        return 0;

    double resistance = 0;
    double current_high = high_buffer[0];

    // Cari swing high di atas zone_top
    for (int i = 3; i < bars - 3; i++)
    {
        if (high_buffer[i] > zone_top &&
            high_buffer[i] > high_buffer[i - 1] &&
            high_buffer[i] > high_buffer[i - 2] &&
            high_buffer[i] > high_buffer[i + 1] &&
            high_buffer[i] > high_buffer[i + 2])
        {
            if (resistance == 0 || high_buffer[i] > resistance)
            {
                resistance = high_buffer[i];
            }
        }
    }

    // Jika tidak ditemukan resistance, gunakan level berdasarkan ATR
    if (resistance == 0)
    {
        double atr_value = iATR(_Symbol, PERIOD_CURRENT, 14);
        resistance = zone_top + (atr_value * 2.0);
    }

    return NormalizeDouble(resistance, _Digits);
}

//+------------------------------------------------------------------+
//| Find Support Level Below Zone                                   |
//+------------------------------------------------------------------+
double ESD_FindSupportBelowZone(double zone_bottom)
{
    int bars = 100; // Lookback period
    double low_buffer[];
    ArraySetAsSeries(low_buffer, true);

    // Copy low prices
    if (CopyLow(_Symbol, PERIOD_CURRENT, 0, bars, low_buffer) < bars)
        return 0;

    double support = 0;
    double current_low = low_buffer[0];

    // Cari swing low di bawah zone_bottom
    for (int i = 3; i < bars - 3; i++)
    {
        if (low_buffer[i] < zone_bottom &&
            low_buffer[i] < low_buffer[i - 1] &&
            low_buffer[i] < low_buffer[i - 2] &&
            low_buffer[i] < low_buffer[i + 1] &&
            low_buffer[i] < low_buffer[i + 2])
        {
            if (support == 0 || low_buffer[i] < support)
            {
                support = low_buffer[i];
            }
        }
    }

    // Jika tidak ditemukan support, gunakan level berdasarkan ATR
    if (support == 0)
    {
        double atr_value = iATR(_Symbol, PERIOD_CURRENT, 14);
        support = zone_bottom - (atr_value * 2.0);
    }

    return NormalizeDouble(support, _Digits);
}

//+------------------------------------------------------------------+
//| Hedge Fund Master dengan Machine Learning Integration           |
//+------------------------------------------------------------------+
void ESD_HedgeFundMasterML()
{
    // Update ML performance metrics terlebih dahulu
    ESD_UpdateMLPerformance();

    // Get current timeframe
    ENUM_TIMEFRAMES current_tf = Period();

    // Calculate technical indicators menggunakan current timeframe
    double ema_fast = iMA(_Symbol, current_tf, 20, 0, MODE_EMA, PRICE_CLOSE);
    double ema_slow = iMA(_Symbol, current_tf, 50, 0, MODE_EMA, PRICE_CLOSE);
    double rsi = iRSI(_Symbol, current_tf, 14, PRICE_CLOSE);
    double atr = iATR(_Symbol, current_tf, 14);
    double stoch_main = iStochastic(_Symbol, current_tf, 14, 3, 3, MODE_SMA, STO_LOWHIGH);

    // Get price data
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    CopyRates(_Symbol, current_tf, 0, 5, rates);

    // Calculate trend strength
    double trend_strength = MathAbs(ema_fast - ema_slow) / SymbolInfoDouble(_Symbol, SYMBOL_POINT) / 100.0;

    // Calculate momentum
    double momentum = (rates[0].close - rates[3].close) / rates[3].close * 100;

    // Calculate volatility
    double volatility = atr / SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // Collect ML features
    ESD_ML_Features features;
    features.volatility = volatility;
    features.trend_strength = trend_strength;
    features.momentum = momentum;
    features.rsi = rsi;
    features.market_regime = 0;
    features.correlation = 0;

    // Calculate ML performance score
    double performance_score = ESD_CalculatePerformanceScore();

    // Adaptive ML adjustments
    if (ESD_UseMachineLearning)
    {
        ESD_AdaptSLTPMultipliers(features, performance_score);
        ESD_AdaptLotSizeMultiplier(features, performance_score);
        ESD_AdjustDynamicFilters();
    }

    // MODIFIED: Priority-based signal system - MORE AGGRESSIVE
    int high_priority_signal = 0;
    int medium_priority_signal = 0;
    int low_priority_signal = 0;

    // Determine market regime dengan bantuan ML - SIMPLIFIED
    int market_regime = 0;
    if (ema_fast > ema_slow)
        market_regime = 1; // Trending Bull
    else if (ema_fast < ema_slow)
        market_regime = 2; // Trending Bear
    else
        market_regime = 4; // Ranging/Low Volatility

    // MODIFIED: Relaxed ML approval conditions
    bool ml_approved = (performance_score >= 0.1 || ESD_ml_performance.trade_count <= 50);     // Lower threshold
    bool basic_approved = (performance_score >= 0.05 || ESD_ml_performance.trade_count <= 25); // Much lower threshold

    // Generate signals berdasarkan priority - MORE AGGRESSIVE CONDITIONS
    double range_high = MathMax(rates[0].high, MathMax(rates[1].high, MathMax(rates[2].high, rates[3].high)));
    double range_low = MathMin(rates[0].low, MathMin(rates[1].low, MathMin(rates[2].low, rates[3].low)));
    MqlTick current_tick;
    SymbolInfoTick(_Symbol, current_tick);

    // HIGH PRIORITY: Relaxed ML-confirmed signals
    if (ml_approved)
    {
        switch (market_regime)
        {
        case 1:                                                 // Trending Bull Market - MORE AGGRESSIVE
            if (rsi < 70 && stoch_main < 90 && momentum > -2.0) // Relaxed RSI and momentum
            {
                if (ESD_ml_performance.win_rate > 0.3 || performance_score > 0.3) // Lower requirements
                    high_priority_signal = 1;
            }
            break;

        case 2:                                                // Trending Bear Market - MORE AGGRESSIVE
            if (rsi > 30 && stoch_main > 10 && momentum < 2.0) // Relaxed RSI and momentum
            {
                if (ESD_ml_performance.win_rate > 0.3 || performance_score > 0.3) // Lower requirements
                    high_priority_signal = -1;
            }
            break;

        case 4:                                            // Low Volatility/Ranging - MORE AGGRESSIVE
            if (current_tick.ask > range_high + atr * 0.2) // Smaller breakout threshold
            {
                if (ESD_ml_performance.sharpe_ratio > 0.2) // Lower requirement
                    high_priority_signal = 1;
            }
            else if (current_tick.bid < range_low - atr * 0.2) // Smaller breakout threshold
            {
                if (ESD_ml_performance.sharpe_ratio > 0.2) // Lower requirement
                    high_priority_signal = -1;
            }
            break;
        }
    }

    // MEDIUM PRIORITY: Very relaxed conditions
    if (basic_approved && high_priority_signal == 0)
    {
        switch (market_regime)
        {
        case 1: // Trending Bull - very relaxed
            if (rsi < 75 && stoch_main < 95 && momentum > -3.0)
            {
                medium_priority_signal = 1; // Remove ML performance check
            }
            break;

        case 2: // Trending Bear - very relaxed
            if (rsi > 25 && stoch_main > 5 && momentum < 3.0)
            {
                medium_priority_signal = -1; // Remove ML performance check
            }
            break;

        case 4: // Low Volatility - very relaxed
            if (current_tick.ask > range_high + atr * 0.1)
            {
                medium_priority_signal = 1;
            }
            else if (current_tick.bid < range_low - atr * 0.1)
            {
                medium_priority_signal = -1;
            }
            break;
        }
    }

    // LOW PRIORITY: Extended conditions for more entries
    if (high_priority_signal == 0 && medium_priority_signal == 0)
    {
        // MODIFIED: More liberal extreme conditions
        if (rsi > 75 || (rsi > 70 && stoch_main > 80))
        {
            low_priority_signal = -1;
        }
        else if (rsi < 25 || (rsi < 30 && stoch_main < 20))
        {
            low_priority_signal = 1;
        }
        // ADDED: Trend-following signals when no clear extremes
        else if (market_regime == 1 && ema_fast > ema_slow && momentum > 0)
        {
            low_priority_signal = 1;
        }
        else if (market_regime == 2 && ema_fast < ema_slow && momentum < 0)
        {
            low_priority_signal = -1;
        }
    }

    // FINAL SIGNAL SELECTION dengan risk adjustment - MORE AGGRESSIVE
    int final_signal = 0;
    double risk_multiplier = 1.0;

    if (high_priority_signal != 0)
    {
        final_signal = high_priority_signal;
        risk_multiplier = 1.0; // Full size
    }
    else if (medium_priority_signal != 0)
    {
        final_signal = medium_priority_signal;
        risk_multiplier = 0.8; // Slightly reduced size (was 0.7)
    }
    else if (low_priority_signal != 0)
    {
        final_signal = low_priority_signal;
        risk_multiplier = 0.6; // Reduced but not too much (was 0.5)
    }

    // MODIFIED: Allow trades even with fewer historical trades
    if (final_signal == 0)
        return;

    // MODIFIED: Relaxed trading conditions
    if (!ESD_CheckTradingConditionsML())
    {
        // ADDED: Override for strong signals
        if (high_priority_signal != 0 && performance_score > 0.4)
        {
            Print("Overriding trading conditions for strong ML signal");
        }
        else
        {
            return;
        }
    }

    // Calculate position size dengan ML multiplier dan risk adjustment
    double base_lot_size = ESD_CalculatePositionSizeML();
    double lot_size = base_lot_size * risk_multiplier;

    // Get current tick
    SymbolInfoTick(_Symbol, current_tick);

    // Execute order berdasarkan final_signal dengan adaptive SL/TP
    if (final_signal == 1) // BUY
    {
        double sl_price = current_tick.bid - (atr * 2 * ESD_ml_optimal_sl_multiplier);
        double tp_price = current_tick.bid + (atr * 3 * ESD_ml_optimal_tp_multiplier);
        string comment = StringFormat("HF_ML_B_%s_R%d_PS%.2f_P%d", EnumToString(current_tf), market_regime, performance_score,
                                      (final_signal == high_priority_signal) ? 1 : (final_signal == medium_priority_signal) ? 2
                                                                                                                            : 3);

        if (ESD_trade.Buy(lot_size, _Symbol, current_tick.ask, sl_price, tp_price, comment))
        {
            Print("ML BUY Executed: ", lot_size, " lots, Score: ", performance_score, " Priority: ",
                  (final_signal == high_priority_signal) ? "HIGH" : (final_signal == medium_priority_signal) ? "MEDIUM"
                                                                                                             : "LOW");
        }
    }
    else if (final_signal == -1) // SELL
    {
        double sl_price = current_tick.ask + (atr * 2 * ESD_ml_optimal_sl_multiplier);
        double tp_price = current_tick.ask - (atr * 3 * ESD_ml_optimal_tp_multiplier);
        string comment = StringFormat("HF_ML_S_%s_R%d_PS%.2f_P%d", EnumToString(current_tf), market_regime, performance_score,
                                      (final_signal == high_priority_signal) ? 1 : (final_signal == medium_priority_signal) ? 2
                                                                                                                            : 3);

        if (ESD_trade.Sell(lot_size, _Symbol, current_tick.bid, sl_price, tp_price, comment))
        {
            Print("ML SELL Executed: ", lot_size, " lots, Score: ", performance_score, " Priority: ",
                  (final_signal == high_priority_signal) ? "HIGH" : (final_signal == medium_priority_signal) ? "MEDIUM"
                                                                                                             : "LOW");
        }
    }
}

//+------------------------------------------------------------------+
//| Check Trading Conditions dengan ML Enhancement                  |
//+------------------------------------------------------------------+
bool ESD_CheckTradingConditionsML()
{
    // Basic conditions
    int current_positions = 0;
    int total = PositionsTotal();
    for (int i = 0; i < total; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionGetInteger(POSITION_MAGIC) == ESD_MagicNumber)
            current_positions++;
    }

    // Market hours
    MqlDateTime dt;
    TimeCurrent(dt);
    if (dt.day_of_week == 0 || dt.day_of_week == 6)
        return false;

    // Daily drawdown dengan ML awareness
    double daily_pnl = 0;
    MqlDateTime today;
    TimeCurrent(today);
    today.hour = 0;
    today.min = 0;
    today.sec = 0;
    datetime today_start = StructToTime(today);

    HistorySelect(today_start, TimeCurrent());
    int total_deals = HistoryDealsTotal();
    for (int i = 0; i < total_deals; i++)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if (HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT &&
            HistoryDealGetInteger(ticket, DEAL_MAGIC) == ESD_MagicNumber)
        {
            daily_pnl += HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                         HistoryDealGetDouble(ticket, DEAL_SWAP) +
                         HistoryDealGetDouble(ticket, DEAL_COMMISSION);
        }
    }

    // Adaptive drawdown limit berdasarkan ML performance
    double adaptive_drawdown_limit = 0.30; // 30% drawdown
    if (ESD_ml_performance.win_rate < 0.4)
        adaptive_drawdown_limit *= 0.7; // Reduce risk if performance poor
    else if (ESD_ml_performance.win_rate > 0.6)
        adaptive_drawdown_limit *= 1.2; // Increase risk if performance good

    if (daily_pnl < -adaptive_drawdown_limit * AccountInfoDouble(ACCOUNT_BALANCE))
        return false;

    // Spread check
    double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if (spread > 0.0005)
        return false;

    return true;
}

//+------------------------------------------------------------------+
//| Calculate Position Size dengan ML Multiplier                    |
//+------------------------------------------------------------------+
double ESD_CalculatePositionSizeML()
{
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double base_risk = equity * 0.30; // 30% risk dari equity

    // Get current volatility
    double atr = iATR(_Symbol, Period(), 14);
    double volatility_adjustment = 1.0;

    if (atr > 0.0010)
        volatility_adjustment = 0.7;
    else if (atr < 0.0003)
        volatility_adjustment = 1.3;

    // ML performance-based adjustment
    double performance_adjustment = 1.0;
    double performance_score = ESD_CalculatePerformanceScore();

    if (performance_score > 0.7)
        performance_adjustment = 1.3;
    else if (performance_score > 0.5)
        performance_adjustment = 1.1;
    else if (performance_score < 0.3)
        performance_adjustment = 0.6;

    // Apply ML lot size multiplier
    double ml_multiplier = ESD_ml_lot_size_multiplier;

    double final_risk = base_risk * volatility_adjustment * performance_adjustment * ml_multiplier;
    double lot_size = final_risk / 100000.0;

    return NormalizeDouble(MathMax(lot_size, 0.01), 2);
}

//+------------------------------------------------------------------+
//|  Fungsi: Tutup posisi jika muncul sinyal reversal Price Action   |
//|  Deteksi: Engulfing, Hammer, Shooting Star                       |
//|  Author: ChatGPT (GPT-5)                                         |
//+------------------------------------------------------------------+
void ESD_CloseOnPriceAction()
{
    CTrade trade;

    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (!PositionSelectByTicket(PositionGetTicket(i)))
            continue;

        string symbol = PositionGetString(POSITION_SYMBOL);
        long type = PositionGetInteger(POSITION_TYPE);
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentTP = PositionGetDouble(POSITION_TP);
        double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentProfit = PositionGetDouble(POSITION_PROFIT);
        ulong ticket = PositionGetInteger(POSITION_TICKET);

        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        if (CopyRates(symbol, PERIOD_M15, 0, 5, rates) < 5)
            continue;

        double open1 = rates[1].open;
        double close1 = rates[1].close;
        double high1 = rates[1].high;
        double low1 = rates[1].low;
        double currentClose = rates[0].close;

        // Kriteria yang lebih selektif - hanya close pada sinyal kuat
        bool strongBearishSignal = (close1 < open1 &&
                                    (close1 < rates[2].low) &&
                                    (high1 - MathMax(open1, close1) > MathAbs(open1 - close1) * 1.5) && // Upper wick sangat dominan
                                    (close1 < rates[3].close) &&                                        // Trend bearish konfirmasi
                                    (rates[1].close < rates[1].open && rates[2].close < rates[2].open)  // Dua candle merah berturut-turut
        );

        bool strongBullishSignal = (close1 > open1 &&
                                    (close1 > rates[2].high) &&
                                    (MathMin(open1, close1) - low1 > MathAbs(open1 - close1) * 1.5) && // Lower wick sangat dominan
                                    (close1 > rates[3].close) &&                                       // Trend bullish konfirmasi
                                    (rates[1].close > rates[1].open && rates[2].close > rates[2].open) // Dua candle hijau berturut-turut
        );

        bool closePosition = false;

        // Hanya close position jika profit sudah cukup atau sinyal sangat kuat
        double minProfitToClose = CalculateMinProfitToClose(symbol, entryPrice, currentClose, type);

        if (type == POSITION_TYPE_BUY && strongBearishSignal && currentProfit >= minProfitToClose)
            closePosition = true;
        else if (type == POSITION_TYPE_SELL && strongBullishSignal && currentProfit >= minProfitToClose)
            closePosition = true;

        // SET STOP LOSS & TAKE PROFIT yang lebih longgar
        SetDynamicStopLossAndTakeProfit(symbol, type, ticket, entryPrice, currentClose, currentSL, currentTP, currentProfit);

        if (closePosition)
        {
            PrintFormat("SELECTIVE CLOSE - Menutup posisi %s dengan profit: %.2f", symbol, currentProfit);
            trade.PositionClose(symbol);
        }
    }
}

// Hitung profit minimum sebelum boleh close
double CalculateMinProfitToClose(string symbol, double entryPrice, double currentPrice, long type)
{
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double atr = iATR(symbol, PERIOD_H1, 14);
    double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * point;

    // Minimum profit harus 1.5x ATR atau 2% dari entry price (ambil yang lebih besar)
    double atrProfit = atr * 1.5;
    double percentageProfit = MathAbs(entryPrice - currentPrice) * 0.02;

    return MathMax(atrProfit, percentageProfit);
}

// Fungsi untuk mengatur Stop Loss dan Take Profit yang lebih longgar
void SetDynamicStopLossAndTakeProfit(string symbol, long positionType, ulong ticket, double entryPrice,
                                     double currentClose, double currentSL, double currentTP, double currentProfit)
{
    CTrade trade;
    double newSL = currentSL;
    double newTP = currentTP;
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * point;
    double atr = iATR(symbol, PERIOD_M15, 14);
    double atrDaily = iATR(symbol, PERIOD_H1, 14);

    // Hitung jarak dari entry price
    double distanceFromEntry = MathAbs(currentClose - entryPrice);

    if (positionType == POSITION_TYPE_BUY)
    {
        // Untuk posisi BUY - Beri ruang lebih besar untuk profit
        if (currentProfit > 0)
        {
            double breakEvenSL = entryPrice + spread;

            // Fase 1: Profit kecil (< 0.5 ATR) - set break even
            if (currentClose > entryPrice && distanceFromEntry < atr * 0.5)
            {
                newSL = breakEvenSL;
                // TP awal yang longgar: 3x ATR
                if (newTP == 0 || newTP < entryPrice + (atr * 3))
                    newTP = entryPrice + (atr * 3);
            }

            // Fase 2: Profit sedang (0.5-1 ATR) - naikkan SL sedikit
            else if (currentClose > entryPrice + atr * 0.5)
            {
                newSL = entryPrice + (atr * 0.3); // Biarkan room untuk volatilitas
                // TP lebih tinggi: 4-5x ATR
                if (newTP < entryPrice + (atr * 4))
                    newTP = entryPrice + (atr * 4);
            }

            // Fase 3: Profit besar (> 1 ATR) - trailing dengan jarak longgar
            else if (currentClose > entryPrice + atr)
            {
                newSL = currentClose - (atr * 1.2); // Beri ruang 1.2 ATR untuk volatilitas
                // Gunakan TP trailing yang naik secara progresif
                if (newTP < currentClose + (atr * 2))
                    newTP = currentClose + (atr * 2);
            }

            // Fase 4: Profit sangat besar (> 2 ATR) - gunakan daily ATR untuk TP
            if (currentClose > entryPrice + (atr * 2))
            {
                newSL = currentClose - (atrDaily * 0.8); // Lebih longgar dengan ATR daily
                if (newTP < entryPrice + (atrDaily * 3))
                    newTP = entryPrice + (atrDaily * 3);
            }
        }
        else if (currentProfit < 0)
        {
            // Saat rugi, beri ruang lebih besar untuk rebound
            double maxRisk = entryPrice - (atr * 1.5); // Risk 1.5 ATR dari entry

            if (currentSL == 0 || currentSL < maxRisk)
            {
                newSL = maxRisk;
            }

            // Tetap set TP yang optimis untuk jangka panjang
            if (newTP == 0 || newTP < entryPrice + (atrDaily * 4))
            {
                newTP = entryPrice + (atrDaily * 4);
            }
        }
    }
    else if (positionType == POSITION_TYPE_SELL)
    {
        // Untuk posisi SELL - Logika mirror dari BUY
        if (currentProfit > 0)
        {
            double breakEvenSL = entryPrice - spread;

            if (currentClose < entryPrice && distanceFromEntry < atr * 0.5)
            {
                newSL = breakEvenSL;
                if (newTP == 0 || newTP > entryPrice - (atr * 3))
                    newTP = entryPrice - (atr * 3);
            }
            else if (currentClose < entryPrice - atr * 0.5)
            {
                newSL = entryPrice - (atr * 0.3);
                if (newTP > entryPrice - (atr * 4))
                    newTP = entryPrice - (atr * 4);
            }
            else if (currentClose < entryPrice - atr)
            {
                newSL = currentClose + (atr * 1.2);
                if (newTP > currentClose - (atr * 2))
                    newTP = currentClose - (atr * 2);
            }

            if (currentClose < entryPrice - (atr * 2))
            {
                newSL = currentClose + (atrDaily * 0.8);
                if (newTP > entryPrice - (atrDaily * 3))
                    newTP = entryPrice - (atrDaily * 3);
            }
        }
        else if (currentProfit < 0)
        {
            double maxRisk = entryPrice + (atr * 1.5);

            if (currentSL == 0 || currentSL > maxRisk)
            {
                newSL = maxRisk;
            }

            if (newTP == 0 || newTP > entryPrice - (atrDaily * 4))
            {
                newTP = entryPrice - (atrDaily * 4);
            }
        }
    }

    // Apply new Stop Loss dan Take Profit jika berbeda
    if ((newSL != currentSL || newTP != currentTP) && newSL != 0 && newTP != 0)
    {
        // Pastikan SL dan TP masuk akal
        if ((positionType == POSITION_TYPE_BUY && newSL < currentClose && newTP > currentClose) ||
            (positionType == POSITION_TYPE_SELL && newSL > currentClose && newTP < currentClose))
        {
            if (trade.PositionModify(ticket, newSL, newTP))
            {
                PrintFormat("SL/TP LONGGAR - %s: SL=%.5f, TP=%.5f (Profit: %.2f, ATR: %.5f)",
                            symbol, newSL, newTP, currentProfit, atr);
            }
        }
    }
}

// Fungsi untuk mengecek trend jangka panjang
bool IsStrongTrend(string symbol, long positionType)
{
    MqlRates currentM15[];
    double ema20[], ema50[], ema100[];

    // Copy data dengan benar
    if (CopyRates(symbol, PERIOD_M15, 0, 1, currentM15) < 1)
        return false;
    if (CopyBuffer(iMA(symbol, PERIOD_M15, 20, 0, MODE_EMA, PRICE_CLOSE), 0, 0, 1, ema20) < 1)
        return false;
    if (CopyBuffer(iMA(symbol, PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE), 0, 0, 1, ema50) < 1)
        return false;
    if (CopyBuffer(iMA(symbol, PERIOD_H1, 100, 0, MODE_EMA, PRICE_CLOSE), 0, 0, 1, ema100) < 1)
        return false;

    if (positionType == POSITION_TYPE_BUY)
    {
        return (ema20[0] > ema50[0] && ema50[0] > ema100[0] && currentM15[0].close > ema20[0]);
    }
    else
    {
        return (ema20[0] < ema50[0] && ema50[0] < ema100[0] && currentM15[0].close < ema20[0]);
    }
}

// Fungsi alternatif dengan TP yang sangat longgar (untuk trend kuat)
void SetVeryLooseTakeProfit(string symbol, long positionType, ulong ticket, double entryPrice)
{
    CTrade trade;

    // Gunakan ATR yang lebih panjang untuk TP
    double atrDaily = iATR(symbol, PERIOD_M15, 14);
    double newTP = 0;

    if (positionType == POSITION_TYPE_BUY)
    {
        newTP = entryPrice + (atrDaily * 3); // TP 3x ATR daily (lebih longgar)
    }
    else if (positionType == POSITION_TYPE_SELL)
    {
        newTP = entryPrice - (atrDaily * 3); // TP 3x ATR daily (lebih longgar)
    }

    double currentTP = PositionGetDouble(POSITION_TP);
    double currentSL = PositionGetDouble(POSITION_SL);

    // Hanya naikkan TP, jangan turunkan
    if ((positionType == POSITION_TYPE_BUY && newTP > currentTP) ||
        (positionType == POSITION_TYPE_SELL && newTP < currentTP))
    {
        if (trade.PositionModify(ticket, currentSL, newTP))
        {
            PrintFormat("TP Longgar - %s: TP diubah menjadi %.5f (ATR Daily: %.5f)", symbol, newTP, atrDaily);
        }
    }
}

// === Fungsi: Update SL maksimal 300 pip & auto reversal dengan comment di entry ===
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

// Input parameters
input double DragonScale = 0.03;
input int FireBreath = 700;
input int SkyReach = 1400;
input double MinDragonPower = 0.0005;
input double SoulEssence = 0.7;
input int EMA_Period = 10;
input double Max_Deviation_Pips = 20.0;

// Global variables
int mysticalSeal = 888888;
datetime lastCandleTime = 0;
int emaHandle;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Dragon Momentum Function dengan Filter EMA Logic Baru           |
//+------------------------------------------------------------------+
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
//+------------------------------------------------------------------+