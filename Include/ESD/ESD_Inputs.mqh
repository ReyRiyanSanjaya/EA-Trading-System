//+------------------------------------------------------------------+
//|                        ESD TRADING FRAMEWORK                      |
//|                          ESD_Inputs.mqh                           |
//+------------------------------------------------------------------+
//| MODULE: Input Parameters
//|
//| DESCRIPTION:
//|   All user-configurable input parameters for the EA including
//|   SMC settings, trade parameters, ML options, and visual configs.
//|
//| PARAMETER GROUPS:
//|   - SMC Analysis Settings       : Timeframes, lookbacks
//|   - Trade Parameters            : Lot size, SL/TP
//|   - Partial TP Settings         : Multi-level take profit
//|   - Aggressive Mode             : Fast entry options
//|   - Heatmap/Order Flow          : Analysis filters
//|   - Machine Learning            : Q-Learning parameters
//|   - News Filter                 : Economic calendar
//|   - Visual Settings             : Display options
//|
//| VERSION: 2.1 | LAST UPDATED: 2025-12-17
//+------------------------------------------------------------------+
#property copyright "SMC"
#property link      "https://www.mql5.com"

#include "ESD_Types.mqh"

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
input bool ESD_UseMultiTimeframeAnalysis = false; // Use multiple timeframe analysis
input bool ESD_UseVolumeConfirmation = false;     // Use volume for confirmation (if available)
input bool ESD_UseMarketStructureShift = true;    // Detect Market Structure Shift (MSS)

//--- Liquidity Grab Strategy
input group "=== Liquidity Grab Strategy ==="
input bool ESD_UseLiquidityGrabStrategy = true;
input int ESD_LiquidityGrabCooldown = 3600;
input int ESD_LiquidityGrabTimeout = 300;
input double ESD_LiquidityGrabLotSize = 0.08;

//--- Enhanced Entry Settings
input bool ESD_UseRejectionCandleConfirmation = false; // Use rejection candle confirmation
input int ESD_RejectionCandleLookback = 1;             // Candle ke berapa yang diperiksa untuk konfirmasi
input bool ESD_EnableLiquiditySweepFilter = true;      // Enable liquidity sweep filter
input double ESD_ZoneTolerancePoints = 200;            // Tolerance for zone triggers
input bool ESD_EnableQualityFilter = true;             // Enable quality filter for zones

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

//--- Heatmap Integration Settings
input bool ESD_UseHeatmapFilter = true;          // Enable Heatmap filtering
input bool ESD_UseSectorStrength = true;         // Use sector strength confirmation
input int ESD_HeatmapCheckBars = 5;              // Bars to check for heatmap consistency
input color ESD_StrongBullishColor = clrLime;    // Color for strong bullish
input color ESD_WeakBullishColor = clrGreen;     // Color for weak bullish
input color ESD_StrongBearishColor = clrRed;     // Color for strong bearish
input color ESD_WeakBearishColor = clrOrangeRed; // Color for weak bearish

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

//--- Dragon Strategy Inputs
input double DragonScale = 0.03;
input int FireBreath = 700;
input int SkyReach = 1400;
input double MinDragonPower = 0.0005;
input double SoulEssence = 0.7;
input int EMA_Period = 10;
input double Max_Deviation_Pips = 20.0;

//--- Machine Learning Settings
input group "=== MACHINE LEARNING SETTINGS ==="
input bool ESD_UseMachineLearning = true;      // Enable Machine Learning
input int ESD_ML_TrainingPeriod = 1000;        // Training period candles
input double ESD_ML_LearningRate = 0.01;       // Learning rate
input int ESD_ML_UpdateInterval = 100;         // Bars between updates
input bool ESD_ML_AdaptiveSLTP = true;         // Adaptive SL/TP
input bool ESD_ML_AdaptiveLotSize = true;      // Adaptive lot sizing
input bool ESD_ML_DynamicFilter = true;        // Dynamic filtering based on confidence
input double ESD_ML_ConfidenceThreshold = 0.65; // Minimum ML confidence for entry (0.0-1.0)


//--- Short Strategy Inputs
input bool ESD_UseShortAggressive = true;      // Aggressive mode untuk short
input double ESD_ShortLotSize = 0.08;          // Lot size untuk short trades
input bool ESD_ShortOnBreakdown = true;        // Short pada breakdown structure
input bool ESD_ShortOnBearishFVG = true;       // Short pada bearish FVG
input bool ESD_ShortOnResistanceTest = true;   // Short pada resistance test

//--- Misc Placeholders
input double ESD_PartialTPDistance1 = 1000;
input double ESD_PartialTPDistance3 = 3000;

//--- News Filter Settings
input group "=== NEWS FILTER SETTINGS ==="
input bool ESD_UseNewsFilter = true;              // Enable News Filter
input int ESD_NewsBufferMinutesBefore = 30;       // Minutes before news to stop trading
input int ESD_NewsBufferMinutesAfter = 15;        // Minutes after news to resume trading
input bool ESD_FilterHighImpact = true;           // Filter High Impact News
input bool ESD_FilterMediumImpact = false;        // Filter Medium Impact News
input bool ESD_ClosePositionsBeforeNews = false;  // Close profitable positions before news

//--- Regime Detection Settings
input group "=== REGIME DETECTION SETTINGS ==="
input bool ESD_UseRegimeDetection = true;         // Enable Market Regime Detection
input int ESD_RegimeSmoothingPeriod = 20;         // Smoothing period for regime detection
input int ESD_RegimeConfirmationBars = 3;         // Bars to confirm regime change
input double ESD_VolatilityThreshold = 0.02;      // Volatility threshold for regime
input double ESD_TrendThreshold = 0.0005;         // Trend threshold for regime

//--- BSL/SSL Avoidance Settings
input group "=== BSL/SSL AVOIDANCE SETTINGS ==="
input bool ESD_AvoidBSL_SSL = true;               // Avoid BSL/SSL zones for entry
input int ESD_BSL_SSL_BufferPoints = 50;          // Buffer from BSL/SSL levels (points)
input bool ESD_ShowBSL_SSL = true;                // Show BSL/SSL levels on chart
input color ESD_BSL_Color = clrDodgerBlue;        // BSL level color
input color ESD_SSL_Color = clrCrimson;           // SSL level color
