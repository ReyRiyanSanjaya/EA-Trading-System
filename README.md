<p align="center">
  <img src="https://img.shields.io/badge/Platform-MetaTrader%205-blue?style=for-the-badge&logo=metatrader" alt="Platform">
  <img src="https://img.shields.io/badge/Language-MQL5-orange?style=for-the-badge" alt="Language">
  <img src="https://img.shields.io/badge/Version-2.1-green?style=for-the-badge" alt="Version">
  <img src="https://img.shields.io/badge/License-MIT-purple?style=for-the-badge" alt="License">
</p>

<h1 align="center">
  🐲 ESD Trading System v2.1
</h1>

<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=gradient&customColorList=10,20,40&height=120&section=header&text=ESD%20TRADING%20SYSTEM&fontSize=40&fontColor=ffffff&fontAlign=50&animation=fadeIn" alt="Header">
</p>

<p align="center">
  <strong>🚀 Next-Gen Expert Advisor: SMC • Machine Learning • Dragon Momentum</strong>
</p>

<p align="center">
  <a href="#-fitur-utama">Fitur</a> •
  <a href="#-instalasi">Instalasi</a> •
  <a href="#-cara-kerja">Cara Kerja</a> •
  <a href="#-konfigurasi">Konfigurasi</a> •
  <a href="#-dokumentasi">Dokumentasi</a>
</p>

---

## ✨ Fitur Utama

<table>
<tr>
<td width="50%">

### 🎯 Smart Money Concepts
- ✅ Break of Structure (BoS)
- ✅ Change of Character (CHoCH)
- ✅ Order Blocks (OB)
- ✅ Fair Value Gaps (FVG)
- ✅ Liquidity Detection
- ✅ Market Structure Shift (MSS)

</td>
<td width="50%">

### 🤖 Machine Learning
- ✅ Q-Learning dengan Experience Replay
- ✅ Adaptive SL/TP Optimization
- ✅ Feature Importance Tracking
- ✅ Overfitting Prevention (Validation Split)
- ✅ Confidence Threshold Filtering

</td>
</tr>
<tr>
<td width="50%">

### 📰 News Filter
- ✅ Forex Factory API Integration
- ✅ Auto-refresh setiap 4 jam
- ✅ High/Medium Impact Filtering
- ✅ Configurable Buffer Times
- ✅ Manual Fallback (NFP, FOMC, CPI)

</td>
<td width="50%">

### 🐉 Dragon Strategy (New v2.0)
- ✅ Dynamic ATR-Based Stops
- ✅ Time Filter (Sydney/Tokyo Sessions)
- ✅ Momentum Candle Detection
- ✅ EMA Deviation Logic
- ✅ Auto-reversal on Max Loss

</td>
</tr>
<tr>
<td width="50%">

### 📊 Risk Management
- ✅ Market Regime Detection
- ✅ BSL/SSL Avoidance
- ✅ Multi-level Partial Take Profit
- ✅ Structure-based Trailing Stop
- ✅ Adaptive Lot Sizing

</td>
</tr>
### 🛡️ Advanced Confirmation
- ✅ Stochastic Filter (No Buy in Overbought)
- ✅ Candle Rejection Confirmation
- ✅ Heatmap & Order Flow Analysis
- ✅ Aggressive FVG Entry (Scalping)
- ✅ Inducement Liquidity Logic

</td>
</tr>
</table>

<p align="center">
  <a href="docs/visualization.html">
    <img src="https://img.shields.io/badge/VIEW_LIVE_ARCHITECTURE-000000?style=for-the-badge&logo=html5&logoColor=white" alt="Live View">
  </a>
</p>

---

## 🚀 Instalasi

### Persyaratan
- MetaTrader 5 (Build 3000+)
- Windows 10/11
- Koneksi Internet (untuk News Filter)

### Langkah Instalasi

```bash
# 1. Clone repository
git clone https://github.com/ReyRiyanSanjaya/EA-Trading-System.git

# 2. Copy ke folder MT5
# Copy folder ke: [MT5 Data Folder]/MQL5/
```

**Atau manual:**

1️⃣ Download ZIP dari GitHub

2️⃣ Extract ke folder MT5 Data:
```
📁 MQL5/
├── 📁 Experts/
│   └── 📄 trade.mq5
└── 📁 Include/
    └── 📁 ESD/
        ├── 📄 ESD_Types.mqh
        ├── 📄 ESD_Inputs.mqh
        ├── 📄 ESD_Globals.mqh
        ├── 📄 ESD_Risk.mqh
        ├── 📄 ESD_News.mqh
        ├── 📄 ESD_SMC.mqh
        ├── 📄 ESD_ML.mqh
        ├── 📄 ESD_Core.mqh
        ├── 📄 ESD_Entry.mqh
        ├── 📄 ESD_Trend.mqh
        ├── 📄 ESD_Visuals.mqh
        ├── 📄 ESD_Dragon.mqh
        └── 📄 ESD_Execution.mqh
```

3️⃣ Compile `trade.mq5` di MetaEditor

4️⃣ **PENTING!** Enable WebRequest:
```
Tools > Options > Expert Advisors > Allow WebRequest for listed URL
URL: https://nfs.faireconomy.media/ff_calendar_thisweek.json
```

5️⃣ Attach EA ke chart (M5 atau M15 recommended)

---

## 🧠 Cara Kerja

### Trading Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        📊 OnTick()                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │     📰 News Filter Check      │
              │  (Apakah ada news penting?)   │
              └───────────────────────────────┘
                     │              │
                  BLOCKED          PASS
                     │              │
                     ▼              ▼
              ┌──────────┐  ┌──────────────────────────────┐
              │   SKIP   │  │  🔍 Update Market Analysis   │
              │  ENTRY   │  │  - Trend Detection           │
              └──────────┘  │  - SMC Structure             │
                            │  - Heatmap & Order Flow      │
                            └──────────────────────────────┘
                                          │
                                          ▼
                            ┌──────────────────────────────┐
                            │     🎯 Regime Detection      │
                            │  Trending? Ranging? Volatile?│
                            └──────────────────────────────┘
                                          │
                                          ▼
                            ┌──────────────────────────────┐
                            │   🤖 ML Confidence Check     │
                            │   Confidence > 0.65?         │
                            └──────────────────────────────┘
                                   │            │
                                 LOW          HIGH
                                   │            │
                                   ▼            ▼
                            ┌──────────┐  ┌──────────────────┐
                            │   SKIP   │  │ 💹 EXECUTE TRADE │
                            └──────────┘  │  - Entry Signal  │
                            │  - Entry Signal  │
                                          │  - SL/TP Calc    │
                                          │  - Lot Sizing    │
                                          └──────────────────┘
```

---

### 📐 SMC Logic

#### Break of Structure (BoS)
```
Bullish BoS:
     PH ─────────────── BREAK! ──────────▶
    /  \                    /
   /    \                  /  ← Entry Zone
  /      \                /
 PL       PL ────────────┘

Bearish BoS:
 PH        PH ────────────┐
  \      /                \  ← Entry Zone
   \    /                  \
    \  /                    \
     PL ─────────────── BREAK! ──────────▶
```

#### Order Block Detection
```
    │▓▓▓▓▓▓▓▓▓│  ← Bearish OB (Last bullish before down move)
    │         │
    │    ↓    │
    │         │
    │▓▓▓▓▓▓▓▓▓│  ← Bullish OB (Last bearish before up move)
    │    ↑    │
```

#### Fair Value Gap (FVG)
```
    Candle 1  │████│
                      ╔═══════════╗
    Candle 2          ║   FVG     ║  Gap between High[0] and Low[2]
                      ╚═══════════╝
    Candle 3              │████│
```

---

### 🤖 Machine Learning System

```
┌────────────────────────────────────────────────────────────┐
│                   Q-LEARNING ENGINE                        │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  State Encoding (243 states):                              │
│  ┌─────────┬─────────┬─────────┬─────────┬─────────┐      │
│  │  Trend  │Volatility│Momentum │ Regime  │ Quality │      │
│  │ (Low/   │ (Low/   │ (Low/   │ (Trend/ │ (Low/   │      │
│  │ Med/Hi) │ Med/Hi) │ Med/Hi) │ Range/  │ Med/Hi) │      │
│  └─────────┴─────────┴─────────┴─────────┴─────────┘      │
│                         │                                  │
│                         ▼                                  │
│  ┌──────────────────────────────────────────────────┐     │
│  │              Q-Table [243 x 9]                   │     │
│  │  Actions: Adjust weights, SL/TP, lot size, etc. │     │
│  └──────────────────────────────────────────────────┘     │
│                         │                                  │
│                         ▼                                  │
│  ┌──────────────────────────────────────────────────┐     │
│  │           Experience Replay Buffer              │     │
│  │        (1000 experiences, batch 32)             │     │
│  └──────────────────────────────────────────────────┘     │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

**Feature Importance Tracking:**
| Feature | Impact |
|---------|--------|
| 📈 Trend Strength | High |
| 📊 Volatility | Medium |
| 🔄 Momentum | High |
| 📉 Order Flow | Medium |
| 🔥 Heatmap | Low |
| 🏗️ Structure | High |
| 🎯 Regime | Medium |

---

### 🎨 Visual Dashboard

Sistem ini menampilkan dashboard interaktif pada chart untuk monitoring real-time:

```
┌──────────────────────────────────────────────────────────────┐
│  ⚡ SMC TRADING DASHBOARD ⚡                                 │
│  2025.12.17 14:30 • 45 Objects Active                        │
│                                           ● PASS | 85% | 8/9 │
├──────────────────────────────┬───────────────────────────────┤
│ 🛡 FILTERS                   │ 📊 PERFORMANCE                │
│                              │                               │
│  ● Spread Check              │  Trades: 142 • Win: 68.5%     │
│  ● News Filter               │  Expectancy: $12.50           │
│  ● Market Regime             │  ──────────────────────────   │
│  ● Daily Bias                │  💰 ACCOUNT                   │
│  ● Time Filter               │  Bal: $10,500 • Eq: $10,650   │
│  ● Free: $9,800                 │
│  ● Generic Order Flow        │  ──────────────────────────   │
│  ○ Volatility                │  📍 POSITIONS                 │
│                              │  Buy: 1 • Sell: 0 • Float: $150│
│                              │  Spread: 12 pts • Lot: 0.10   │
│                              │                               │
│                              │ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                              │                               │
│                              │ 🤖 AI OPTIMIZATION            │
│                              │                               │
│                              │  Acc: 72.4% • Risk: 1.25      │
│                              │  Vol: 0.85 • Lot: 1.1x        │
│                              │  SL: 1.5x • TP: 2.0x          │
│                              │                               │
│                              │ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                              │                               │
│                              │ 🐲 DRAGON V2                  │
│                              │                               │
│                              │  Status: Active ✅            │
│                              │  Mode: ATR: 1.5x/3.0x         │
└──────────────────────────────┴───────────────────────────────┘
```

**Indikator Visual:**
- 🟦 **Blue Rectangle**: Bullish Order Block (OB)
- 🟥 **Red Rectangle**: Bearish Order Block (OB)
- 🟩 **Green Shade**: Fair Value Gap (FVG)
- 📉 **Trend Lines**: Break of Structure (BoS) & CHoCH
- 🏷️ **Labels**: MSS, Swing High/Low, Liquidity Sweeps

---

## ⚙️ Konfigurasi

### Quick Settings

| Setting | Default | Recommended |
|---------|---------|-------------|
| `ESD_HigherTimeframe` | H1 | H1 untuk XAUUSD |
| `ESD_LotSize` | 0.01 | Sesuaikan risk |
| `ESD_StopLossPoints` | 300 | 200-500 |
| `ESD_TakeProfitPoints` | 900 | 600-1200 |
| `ESD_UseNewsFilter` | true | ✅ Recommended |
| `ESD_UseMachineLearning` | true | ✅ Recommended |

### News Filter Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ESD_NewsBufferMinutesBefore` | 30 | Stop trading sebelum news |
| `ESD_NewsBufferMinutesAfter` | 15 | Resume setelah news |
| `ESD_FilterHighImpact` | true | Filter news high-impact |
| `ESD_FilterMediumImpact` | false | Filter medium-impact |

### ML Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ESD_ML_LearningRate` | 0.1 | Learning rate Q-Learning |
| `ESD_ML_ConfidenceThreshold` | 0.65 | Min confidence untuk entry |
| `ESD_ML_AdaptiveSLTP` | true | Dynamic SL/TP adjustment |

---

## 📁 Struktur File

```
📦 ESD Trading System
├── 📄 trade.mq5              # Main EA file
└── 📁 Include/ESD/
    ├── 📄 ESD_Types.mqh      # Type definitions
    ├── 📄 ESD_Inputs.mqh     # Input parameters  
    ├── 📄 ESD_Globals.mqh    # Global variables
    ├── 📄 ESD_Risk.mqh       # Risk management 🛡️
    ├── 📄 ESD_News.mqh       # News filter 📰
    ├── 📄 ESD_SMC.mqh        # SMC detection 🎯
    ├── 📄 ESD_ML.mqh         # Machine learning 🤖
    ├── 📄 ESD_Core.mqh       # Core functions ⚙️
    ├── 📄 ESD_Entry.mqh      # Entry logic 📈
    ├── 📄 ESD_Trend.mqh      # Trend analysis 📊
    ├── 📄 ESD_Visuals.mqh    # Chart objects 🎨
    ├── 📄 ESD_Dragon.mqh     # Dragon strategy 🐉
    └── 📄 ESD_Execution.mqh  # Trade execution 💰
```

---

## 🔧 Troubleshooting

<details>
<summary><b>❓ News Filter tidak berfungsi</b></summary>

1. Pastikan WebRequest URL sudah ditambahkan di MT5 Options
2. Check koneksi internet
3. Lihat tab "Experts" di MT5 untuk error messages

</details>

<details>
<summary><b>❓ ML tidak adaptif</b></summary>

1. ML butuh minimal 10 trades untuk mulai learning
2. Tunggu beberapa jam untuk experience buffer terisi
3. Check `ESD_UseMachineLearning = true`

</details>

<details>
<summary><b>❓ Entry tidak terjadi</b></summary>

1. Check Filter Monitor panel
2. Pastikan market sedang trending (bukan ranging)
3. Pastikan tidak dalam news window
4. Check level BSL/SSL avoidance

</details>

<details>
<summary><b>❓ Compile error</b></summary>

1. Pastikan file structure benar
2. Pastikan folder ESD ada di `Include/`
3. Check semua dependencies di header files

</details>

---

## 📈 Performance Tips

| Tip | Description |
|-----|-------------|
| 🕐 **Best Sessions** | London & New York overlap (14:00-22:00 WIB) |
| 📊 **Best Pairs** | XAUUSD, EURUSD, GBPUSD |
| ⏱️ **Best Timeframe** | M5 atau M15 |
| 💰 **Risk Management** | Max 2% per trade |
| 📰 **News** | Hindari trading saat NFP, FOMC, CPI |

---

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first.

---

## 📜 License

This project is licensed under the MIT License.

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/ReyRiyanSanjaya">Rey Riyan Sanjaya</a>
</p>

<p align="center">
  <img src="https://img.shields.io/github/stars/ReyRiyanSanjaya/EA-Trading-System?style=social" alt="Stars">
  <img src="https://img.shields.io/github/forks/ReyRiyanSanjaya/EA-Trading-System?style=social" alt="Forks">
</p>
