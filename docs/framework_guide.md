# 📚 ESD Trading Framework - Technical Guide

> Complete technical documentation for developers and advanced users.

---

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Module Reference](#module-reference)
3. [API Documentation](#api-documentation)
4. [Extension Guide](#extension-guide)
5. [Best Practices](#best-practices)

---

## 🏗️ Architecture Overview

### Design Philosophy

ESD Framework menggunakan **Controller Architecture Pattern** dengan 3-layer design:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          ENTRY POINT                                    │
│                         trade.mq5 (67 lines)                            │
│              OnInit() → OnTick() → OnDeinit()                           │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       ESD_Controller.mqh                                │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                     SUBSYSTEM MANAGERS                          │   │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌───────────┐ │   │
│  │  │ ML_Mgr  │ │ SMC_Mgr │ │Risk_Mgr │ │News_Mgr │ │ Trade_Mgr │ │   │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └───────────┘ │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
         ┌────────────────────────┼────────────────────────┐
         ▼                        ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   LAYER 1       │    │   LAYER 2       │    │   LAYER 3       │
│   FOUNDATION    │    │   ANALYSIS      │    │   EXECUTION     │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ ESD_Types       │    │ ESD_Trend       │    │ ESD_Entry       │
│ ESD_Inputs      │    │ ESD_SMC         │    │ ESD_Execution   │
│ ESD_Globals     │    │ ESD_ML          │    │ ESD_Dragon      │
│ ESD_Utils       │    │ ESD_Risk        │    │ ESD_Confirmation│
│ ESD_Visuals     │    │ ESD_Core        │    │                 │
│                 │    │ ESD_News        │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Tick Execution Flow

```
OnTick()
    │
    ├──► Phase 0: Virtual Learning (ML ghost trades)
    │
    ├──► Phase 1: Position Protection (MaxLoss, Trailing)
    │
    ├──► Phase 2: News Filter Check
    │         │
    │         └── If blocked → Update visuals only → Return
    │
    ├──► Phase 3: Update Analysis
    │         ├── SMC Detection
    │         ├── Trend Analysis
    │         ├── Heatmap & Order Flow
    │         └── ML Model Update
    │
    └──► Phase 4: Entry Logic
              ├── ML Entry (if enabled)
              ├── Stochastic ML Entry
              ├── SMC Entry
              └── Aggressive Entry
```

---

## 📦 Module Reference

### Layer 1: Foundation

| Module | Size | Description |
|--------|------|-------------|
| `ESD_Types.mqh` | 6KB | Struct definitions: `ESD_ML_Features`, `ESD_FilterStatus`, enums |
| `ESD_Inputs.mqh` | 12KB | All user-configurable input parameters |
| `ESD_Globals.mqh` | 6KB | Global state variables, CTrade instance |
| `ESD_Utils.mqh` | 14KB | Utility functions (price, array, time, math, debug) |
| `ESD_Visuals.mqh` | 62KB | Dashboard, chart objects, monitoring panels |

### Layer 2: Analysis

| Module | Size | Description |
|--------|------|-------------|
| `ESD_Trend.mqh` | 15KB | Supreme timeframe analysis, trend detection |
| `ESD_SMC.mqh` | 51KB | BoS, CHoCH, FVG, Order Blocks, liquidity |
| `ESD_ML.mqh` | 68KB | Q-Learning, Dual Brain, PER, Ghost Trading |
| `ESD_Risk.mqh` | 22KB | Regime detection, BSL/SSL, circuit breakers |
| `ESD_Core.mqh` | 27KB | Heatmap, Order Flow, filter status |
| `ESD_News.mqh` | 23KB | Forex Factory API, economic calendar |

### Layer 3: Execution

| Module | Size | Description |
|--------|------|-------------|
| `ESD_Entry.mqh` | 29KB | Entry signals, ML Stochastic strategy |
| `ESD_Execution.mqh` | 34KB | Order execution, partial TP, SL management |
| `ESD_Dragon.mqh` | 10KB | Dragon momentum strategy |
| `ESD_Confirmation.mqh` | 26KB | 5 advanced confirmation filters |

### Controller

| Module | Size | Description |
|--------|------|-------------|
| `ESD_Controller.mqh` | 17KB | Central orchestrator, subsystem managers |

---

## 🔌 API Documentation

### ESD_Utils.mqh - Utility Functions

#### Price Utilities
```mql5
double ESD_GetAsk()                    // Current Ask price
double ESD_GetBid()                    // Current Bid price
double ESD_GetSpreadPoints()           // Spread in points
double ESD_GetPoint()                  // Symbol point value
double ESD_PointsToPrice(int points)   // Convert points to price
int    ESD_PriceToPoints(double diff)  // Convert price to points
double ESD_NormalizePrice(double p)    // Normalize to digits
```

#### Array Utilities
```mql5
void   ESD_ArrayPush(double &arr[], double value)
double ESD_ArrayAverage(const double &arr[])
double ESD_ArrayMaxValue(const double &arr[])
double ESD_ArrayMinValue(const double &arr[])
```

#### Time Utilities
```mql5
bool   ESD_IsNewBar(ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
int    ESD_GetCurrentHour()
int    ESD_GetDayOfWeek()
bool   ESD_IsWithinTradingHours(int start, int end)
string ESD_FormatTime(datetime time)
```

#### Math Utilities
```mql5
double ESD_Clamp(double value, double min, double max)
double ESD_MapRange(double v, double in_min, double in_max, double out_min, double out_max)
double ESD_Lerp(double a, double b, double t)
double ESD_PercentChange(double old_val, double new_val)
```

#### Debug Utilities
```mql5
void   ESD_Log(string message, int level = ESD_LOG_INFO)
void   ESD_Debug(string func_name, string message)
void   ESD_Error(string func_name, string error)
string ESD_GetSystemInfo()
```

#### Indicator Helpers
```mql5
double ESD_GetATR(int period = 14, int shift = 0)
double ESD_GetRSI(int period = 14, int shift = 0)
double ESD_GetEMA(int period, int shift = 0)
```

#### Market Session Utilities
```mql5
bool   ESD_IsSydneySession()           // Check Sydney session
bool   ESD_IsTokyoSession()            // Check Tokyo session
bool   ESD_IsLondonSession()           // Check London session
bool   ESD_IsNewYorkSession()          // Check New York session
string ESD_GetCurrentSession()         // Get session name
bool   ESD_IsInMajorSession()          // London or NY
bool   ESD_IsInOverlap()               // London-NY overlap
```

#### Position Management
```mql5
int    ESD_CountPositions(ulong magic = 0)     // Count all positions
int    ESD_CountBuyPositions(ulong magic = 0)  // Count buy positions
int    ESD_CountSellPositions(ulong magic = 0) // Count sell positions
double ESD_GetTotalProfit(ulong magic = 0)     // Get floating P/L
```

#### Breakeven Utilities
```mql5
bool ESD_MoveToBreakeven(ulong ticket, int buffer = 10)
void ESD_AutoBreakeven(int activation, int buffer = 10, ulong magic = 0)
```

#### Risk Calculation
```mql5
double ESD_CalculateLotSize(double risk_percent, int sl_points)
double ESD_GetDailyProfitLoss()
bool   ESD_IsDailyLossLimitReached(double max_loss_percent)
```

---

### ESD_Controller.mqh - Controller Functions

#### Lifecycle
```mql5
bool ESD_Controller_Init()           // Initialize all subsystems
void ESD_Controller_OnTick()         // Main tick handler
void ESD_Controller_Deinit(int r)    // Cleanup all subsystems
```

#### Managers
```mql5
void ESD_MLManager_VirtualTrades()   // ML virtual trade management
void ESD_MLManager_Update()          // ML model update
void ESD_RiskManager_Protect()       // Risk protection
bool ESD_NewsManager_CanTrade()      // News filter check
void ESD_AnalysisManager_Update()    // All analysis functions
void ESD_SMCManager_Update()         // SMC detection
void ESD_TradeManager_CheckEntries() // Entry execution
```

#### Status
```mql5
string ESD_Controller_GetStatus()    // Get system status
bool   ESD_IsReadyToTrade()          // Trade readiness check
void   ESD_LogSystemState()          // Debug logging
```

---

### ESD_Confirmation.mqh - Confirmation Filters

```mql5
// Stochastic Filter
bool ESD_ConfirmationStochasticFilter(bool is_buy)
bool ESD_IsStochasticOverbought()
bool ESD_IsStochasticOversold()

// Candle Rejection
bool ESD_ConfirmationRejectionCandle(MqlRates &candle, bool is_bullish)
bool ESD_IsPinBar(MqlRates &candle, bool is_bullish)
double ESD_GetWickRatio(MqlRates &candle, bool upper)

// Heatmap & Order Flow
void   ESD_ConfirmationAnalyzeHeatmap()
bool   ESD_ConfirmationHeatmapFilter(bool proposed_buy)
void   ESD_ConfirmationAnalyzeOrderFlow()
bool   ESD_ConfirmationOrderFlowFilter(bool proposed_buy)

// Aggressive FVG
bool   ESD_CheckAggressiveFVGEntry()
double ESD_ConfirmationCalculateFVGQuality(bool is_bullish)

// Inducement
bool   ESD_ConfirmationTradeAgainstInducement()
bool   ESD_ConfirmationBullishInducementSignal()
bool   ESD_ConfirmationBearishInducementSignal()

// Master Function
bool   ESD_RunAllConfirmations(bool is_buy)
```

---

## 🔧 Extension Guide

### Adding a New Entry Strategy

1. **Create function in `ESD_Entry.mqh`:**
```mql5
void ESD_TryMyNewStrategy()
{
    // 1. Check position limits
    if (ESD_GetActivePositions() >= 5) return;
    
    // 2. Get signals
    bool is_buy = MyBuyCondition();
    bool is_sell = MySellCondition();
    if (!is_buy && !is_sell) return;
    
    // 3. Run confirmations
    if (!ESD_RunAllConfirmations(is_buy)) return;
    
    // 4. Execute trade
    if (is_buy)
        ESD_trade.Buy(lot, _Symbol, price, sl, tp, "MyStrategy");
    else
        ESD_trade.Sell(lot, _Symbol, price, sl, tp, "MyStrategy");
}
```

2. **Register in Controller (`ESD_Controller.mqh`):**
```mql5
void ESD_TradeManager_CheckEntries()
{
    // ... existing entries ...
    
    // Add your strategy
    ESD_TryMyNewStrategy();
}
```

### Adding a New Confirmation Filter

1. **Add to `ESD_Confirmation.mqh`:**
```mql5
bool ESD_MyCustomFilter(bool is_buy)
{
    // Your filter logic
    return true; // Pass or fail
}
```

2. **Add to master function:**
```mql5
bool ESD_RunAllConfirmations(bool is_buy)
{
    // ... existing checks ...
    if (!ESD_MyCustomFilter(is_buy)) return false;
    return true;
}
```

---

## 📌 Best Practices

### 1. Use Utility Functions
```mql5
// ❌ Don't repeat code
double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

// ✅ Use utilities
double ask = ESD_GetAsk();
double bid = ESD_GetBid();
```

### 2. Follow Naming Convention
```mql5
// Functions: ESD_ModuleName_FunctionName
void ESD_Confirmation_MyFilter() { }

// Variables: ESD_variable_name
double ESD_my_threshold = 0.5;

// Constants: UPPERCASE
#define ESD_MAX_POSITIONS 5
```

### 3. Use Debug Logging
```mql5
// ✅ Good debugging
ESD_Debug("MyFunction", "Processing signal: " + (is_buy ? "BUY" : "SELL"));
ESD_Error("MyFunction", "Failed: " + IntegerToString(GetLastError()));
```

### 4. Check Readiness Before Trading
```mql5
if (!ESD_IsReadyToTrade())
{
    ESD_Log("System not ready", ESD_LOG_WARNING);
    return;
}
```

---

## 📊 Performance Metrics

| Metric | Target | Current |
|--------|--------|---------|
| Compile Time | < 5s | ~3s |
| Memory Usage | < 50MB | ~35MB |
| Tick Processing | < 10ms | ~5ms |
| Total Modules | - | 16 |
| Total Lines | - | ~15,000 |
| Total Size | - | ~420KB |

---

## 📝 Changelog

### v2.2 (2025-12-18)
- ✅ Added ESD_Controller.mqh (Controller Architecture)
- ✅ Added ESD_Utils.mqh (Utility Functions)
- ✅ Added ESD_Confirmation.mqh (5 Confirmation Filters)
- ✅ Added ML Stochastic Entry Strategy
- ✅ Simplified trade.mq5 (221 → 67 lines)
- ✅ Updated README with architecture diagrams

### v2.1 (2025-12-17)
- ✅ Added Machine Learning visualization
- ✅ Added Q-Lambda, Dual Brain Architecture
- ✅ Added News Filter integration

---

*Last Updated: 2025-12-18*
