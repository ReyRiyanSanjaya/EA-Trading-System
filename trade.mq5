//+------------------------------------------------------------------+
//|                        ESD TRADING FRAMEWORK                      |
//|                             trade.mq5                             |
//+------------------------------------------------------------------+
//| MAIN EA FILE: ESD SMC Trading System v2.1
//|
//| DESCRIPTION:
//|   Expert Advisor combining Smart Money Concepts (SMC), Machine
//|   Learning optimization, News filtering, and multiple trading
//|   strategies for XAUUSD and other pairs.
//|
//| MODULES:
//|   - ESD_Types.mqh     : Type definitions and structures
//|   - ESD_Inputs.mqh    : User input parameters
//|   - ESD_Globals.mqh   : Global variables and state
//|   - ESD_Visuals.mqh   : Visual objects and dashboard
//|   - ESD_Risk.mqh      : Risk management and regime detection
//|   - ESD_News.mqh      : Economic news filter (NEW)
//|   - ESD_Trend.mqh     : Trend analysis
//|   - ESD_SMC.mqh       : Smart Money Concepts detection
//|   - ESD_ML.mqh        : Machine Learning system
//|   - ESD_Core.mqh      : Core analysis functions
//|   - ESD_Execution.mqh : Trade execution
//|   - ESD_Entry.mqh     : Entry signal logic
//|   - ESD_Dragon.mqh    : Dragon momentum strategy
//|
//| VERSION: 2.1
//| LAST UPDATED: 2025-12-17
//+------------------------------------------------------------------+
#property copyright "SMC"
#property link      "https://www.mql5.com"
#property version   "2.10"

//--- Includes must be in dependency order
#include "Include/ESD/ESD_Types.mqh"
#include "Include/ESD/ESD_Inputs.mqh"
#include "Include/ESD/ESD_Globals.mqh"
#include "Include/ESD/ESD_Visuals.mqh"
#include "Include/ESD/ESD_Risk.mqh"
#include "Include/ESD/ESD_News.mqh"        // NEW: News Filter Module
#include "Include/ESD/ESD_Trend.mqh"
#include "Include/ESD/ESD_SMC.mqh"
#include "Include/ESD/ESD_ML.mqh"
#include "Include/ESD/ESD_Core.mqh"
#include "Include/ESD/ESD_Execution.mqh"
#include "Include/ESD/ESD_Entry.mqh"
#include "Include/ESD/ESD_Dragon.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("═══════════════════════════════════════════════════════");
    Print("         ESD TRADING SYSTEM v2.1 INITIALIZING           ");
    Print("═══════════════════════════════════════════════════════");
    
    // Initialize Trade Object
    ESD_trade.SetExpertMagicNumber(ESD_MagicNumber);
    ESD_trade.SetDeviationInPoints(ESD_Slippage);
    ESD_trade.SetTypeFilling(ORDER_FILLING_IOC); 

    // Initialize News Filter (NEW)
    if (ESD_UseNewsFilter)
    {
        ESD_InitializeNewsFilter();
    }

    // Initialize Machine Learning
    if (ESD_UseMachineLearning)
    {
        ESD_InitializeML();
    }

    // Initialize Dragon Strategy
    if (OnInitDragon() != INIT_SUCCEEDED)
    {
        Print("❌ Dragon Strategy initialization failed!");
        return INIT_FAILED;
    }

    // Initialize Monitoring Panels (Data & Filters)
    ESD_InitializeMonitoringPanels();

    // Detect Initial Trend
    ESD_DetectInitialTrend();

    Print("═══════════════════════════════════════════════════════");
    Print("         ✅ ESD TRADING SYSTEM READY                     ");
    Print("═══════════════════════════════════════════════════════");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up objects if enabled
    if (ESD_ShowObjects)
    {
        ObjectsDeleteAll(0, "ESD_");
    }
    
    // Dragon Indicator Release
    IndicatorRelease(emaHandle);
    
    Print("ESD Trading System Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // ═══════════════════════════════════════════════════════════════
    // PHASE 1: POSITION MANAGEMENT
    // ═══════════════════════════════════════════════════════════════
    ESD_UpdateMaxLossSL_AndReversal(300); // Protection mechanism
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 2: NEWS FILTER CHECK (NEW - Early exit if news active)
    // ═══════════════════════════════════════════════════════════════
    if (ESD_UseNewsFilter)
    {
        ESD_UpdateNewsCalendar();
        ESD_DrawNewsIndicator();
        
        // If news filter blocks trading, skip entry logic
        if (!ESD_NewsFilter())
        {
            // Still update analysis for visual purposes
            ESD_UpdateAnalysis();
            return; // Exit early - no new trades during news
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 3: UPDATE ANALYSIS
    // ═══════════════════════════════════════════════════════════════
    ESD_UpdateAnalysis();
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 4: ENTRY LOGIC (Only if news filter passes)
    // ═══════════════════════════════════════════════════════════════
    
    // Main Strategy Entry (SMC + ML if enabled)
    if (ESD_UseMachineLearning)
    {
        ESD_CheckForEntryWithML();
        ESD_CheckMLAggressiveAlternativeEntries();
    }
    else
    {
        ESD_CheckForEntry();
    }
    
    // Short Opportunities (Liquidity Hunting)
    if (ESD_EnableShortTrading)
    {
        ESD_CheckForShortEntries();
    }
    
    // Aggressive Entries
    ESD_CheckForAggressiveEntry();
}

//+------------------------------------------------------------------+
//| Update All Analysis Functions                                     |
//+------------------------------------------------------------------+
void ESD_UpdateAnalysis()
{
    // Update ML Model periodically
    if (ESD_UseMachineLearning)   
        ESD_UpdateMLModel();
        
    // Update Dragon Momentum
    DragonMomentum();
    
    // Update SMC Structures
    ESD_DetectSMC();
    
    // Update Trend Analysis
    ESD_DetectSupremeTimeframeTrend();
    
    // Update Market Regime
    ESD_DetectMarketRegime();
    
    // Update Liquidity Levels
    ESD_DetectBSL_SSLLevels();

    // Update Core Analysis
    ESD_AnalyzeHeatmap();
    ESD_AnalyzeOrderFlow();
    ESD_UpdateFilterStatus();
    ESD_UpdateTradingData();
}

//+------------------------------------------------------------------+
//| Trade Transaction Handler                                        |
//+------------------------------------------------------------------+
void OnTrade()
{
   // Optional: Handle trade events immediately
}
