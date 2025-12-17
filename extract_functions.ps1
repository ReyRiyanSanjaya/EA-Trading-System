
$sourceFile = "trade_backup.mq5"
$outputDir = "Include\ESD"
$enc = [System.Text.Encoding]::UTF8

$mapping = @{
    "ESD_Visuals.mqh" = @(
        "ESD_DrawHistoricalStructures", "ESD_DrawBreakStructure", "ESD_DrawSwingPoint", "ESD_DrawOrderBlock", "ESD_DrawFVG",
        "ESD_DeleteObjects", "ESD_DeleteObjectsByPrefix", "ESD_DrawLabel", "ESD_DrawLiquidityLine", "ESD_DrawOrderFlowIndicators",
        "ESD_DrawSystemInfoPanel", "ESD_DrawUnifiedDashboard", "ESD_DrawFilterMonitor", "ESD_DrawTradingDataPanel",
        "ESD_DebugPanelStatus", "ESD_DrawTPObjects", "ESD_CreateTPLine", "ESD_RemoveTPObjects", "DrawLabelSL",
        "FadeInPanel", "AddLine", "AddLineSimple", "AddStyledLineWithPos", "GetRValue", "GetGValue", "GetBValue",
        "ESD_DrawLiquidityZones", "ESD_DrawBSL_SSLLevels", "ESD_DrawRegimeIndicator"
    )
    "ESD_Trend.mqh" = @(
        "ESD_DetectInitialTrend", "ESD_CalculateTrendStrength", "ESD_DetectSupremeTimeframeTrend",
        "ESD_DetectMarketStructureShift", "ESD_ConfirmBreak", "ESD_IsValidMomentum", "ESD_CalculateTimeframeStrength"
    )
    "ESD_SMC.mqh" = @(
        "ESD_DetectSMC", "ESD_FindPivotHighIndex", "ESD_FindPivotLowIndex", "ESD_CalculatePivotQuality", "ESD_CalculateBreakQuality",
        "ESD_CalculateOrderBlockQuality", "ESD_CalculateFVGQuality", "ESD_AddToHistoricalStructures", "ESD_GetZoneQuality", "ESD_GetCurrentZoneQuality",
        "ESD_IsRejectionCandle", "ESD_IsLiquiditySweeped", "ESD_IsFVGMitigated", "ESD_GetHTFSwingHigh", "ESD_GetHTFSwingLow",
        "ESD_GetRecentSwingHigh", "ESD_GetRecentSwingLow", "ESD_UpdateSwingLevels"
    )
    "ESD_Risk.mqh" = @(
        "ESD_DetectMarketRegime", "ESD_IsRegimeConfirmed", "ESD_UpdateRegimeFilterStatus", "ESD_IsRegimeFavorable",
        "ESD_GetRegimeDescription", "ESD_RegimeFilter", "ESD_GetRegimeAdjustedLotSize"
    )
    "ESD_Core.mqh" = @(
        "ESD_InitializeTradingData", "ESD_UpdateTradingData", "ESD_AnalyzeHeatmap", "ESD_HeatmapFilter", "ESD_AnalyzeOrderFlow",
        "ESD_DetectAbsorption", "ESD_DetectImbalance", "ESD_OrderFlowFilter", "ESD_InitializeFilterMonitoring", "ESD_UpdateFilterStatus",
        "ESD_DeleteFilterMonitor", "ESD_DeleteDataPanels", "ESD_DeleteAllMonitoringPanels", "ESD_InitializeMonitoringPanels",
        "ESD_GetSystemInfo"
    )
    "ESD_Entry.mqh" = @(
        "ESD_CheckForEntry", "ESD_CheckForAggressiveEntry", "ESD_CheckMLAggressiveAlternativeEntries", "ESD_HasRetestOccurred",
        "ESD_TradeAgainstInducement", "ESD_StochasticEntryFilter"
    )
    "ESD_Execution.mqh" = @(
        "ESD_ExecuteAggressiveBuy", "ESD_ExecuteAggressiveSell", "ESD_ExecuteMLAggressiveBuy", "ESD_ExecuteMLAggressiveSell",
        "ESD_ExecuteTradeWithPartialTP", "ESD_ManagePartialTP", "ESD_ExecutePartialTPBuy", "ESD_ExecutePartialTPSell",
        "ESD_ManageStructureTrailing", "ESD_UpdateBuyTrailing", "ESD_UpdateSellTrailing", "ManagePositionsSL", "ESD_ExecutePartialClose",
        "ESD_ShouldProtectProfit", "ESD_CalculateEnhancedTP", "ESD_GetNearestBearishLevel", "ESD_GetNearestBullishLevel",
        "ESD_IsPriceRejecting", "PriceRejection"
    )
    "ESD_ML.mqh" = @(
        "ESD_UpdateMLModel", "ESD_CollectMLFeatures", "ESD_GetMLEntrySignal"
    )
    "ESD_Dragon.mqh" = @(
        "OnInitDragon", "DragonMomentum", "UpdateMaxLossSL_AndReversal"
    )
}

$content = Get-Content $sourceFile -Encoding UTF8

foreach ($file in $mapping.Keys) {
    $targetPath = Join-Path $outputDir $file
    $funcs = $mapping[$file]
    
    $header = @"
//+------------------------------------------------------------------+
//|                                                      $file |
//|                                                              SMC |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "SMC"
#property link      "https://www.mql5.com"

#include "ESD_Globals.mqh"
#include "ESD_Inputs.mqh"

"@
    if ($file -eq "ESD_SMC.mqh") { $header += "`n#include `"ESD_Visuals.mqh`"" }
    if ($file -eq "ESD_Entry.mqh") { $header += "`n#include `"ESD_SMC.mqh`"`n#include `"ESD_Trend.mqh`"`n#include `"ESD_Execution.mqh`"`n#include `"ESD_Risk.mqh`"`n#include `"ESD_Core.mqh`"" }
    if ($file -eq "ESD_Core.mqh") { $header += "`n#include `"ESD_Visuals.mqh`"" }
    if ($file -eq "ESD_Execution.mqh") { $header += "`n#include `"ESD_Globals.mqh`"`n#include `"ESD_Inputs.mqh`"" }
    if ($file -eq "ESD_Dragon.mqh") { 
        $header += "`nint emaHandle = INVALID_HANDLE;`ndatetime lastCandleTime = 0;"
    }


    Set-Content -Path $targetPath -Value $header -Encoding UTF8
    
    foreach ($func in $funcs) {
        $found = $false
        $braceCount = 0
        $capturing = $false
        $funcBody = @()
        
        for ($i = 0; $i -lt $content.Count; $i++) {
            $line = $content[$i]
            
            if (-not $capturing) {
                if ($line -match "(void|bool|double|int|string)\s+$func\s*\(") {
                   $capturing = $true
                   $found = $true
                   $funcBody += $line
                   $braceCount += $line.ToCharArray() | Where-Object { $_ -eq '{' } | Measure-Object | Select-Object -ExpandProperty Count
                   $braceCount -= $line.ToCharArray() | Where-Object { $_ -eq '}' } | Measure-Object | Select-Object -ExpandProperty Count
                   continue
                }
            }
            
            if ($capturing) {
                $funcBody += $line
                $braceCount += $line.ToCharArray() | Where-Object { $_ -eq '{' } | Measure-Object | Select-Object -ExpandProperty Count
                $braceCount -= $line.ToCharArray() | Where-Object { $_ -eq '}' } | Measure-Object | Select-Object -ExpandProperty Count
                
                if ($braceCount -le 0) {
                     $capturing = $false
                     break
                }
            }
        }
        
        if ($found) {
            Add-Content -Path $targetPath -Value ($funcBody -join "`r`n") -Encoding UTF8
            Add-Content -Path $targetPath -Value "`r`n" -Encoding UTF8
        } else {
            Write-Host "Warning: Function $func not found in source file"
        }
    }
}
