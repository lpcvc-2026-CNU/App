param(
    [string]$SourceDir = "D:\mobileclip2_s3_server_full_ce_hardneg_fold3_20260611_214421\mobile_artifacts\fp16",
    [string]$TargetDir = "assets\mobile_artifacts_fp16"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if (-not [System.IO.Path]::IsPathRooted($TargetDir)) {
    $TargetDir = Join-Path $RepoRoot $TargetDir
}

$requiredFiles = @(
    "manifest.json",
    "classes.json",
    "prototype_index.json",
    "preprocessing.json",
    "tokenizer.json",
    "labels_master.json",
    "config.yaml",
    "README.txt",
    "mobileclip2_s3_server_full_ce_hardneg_image_encoder_fp16_mixed.onnx",
    "mobileclip2_s3_server_full_ce_hardneg_image_encoder_fp16_mixed.onnx.data",
    "mobileclip2_s3_server_full_ce_hardneg_text_encoder_fp16_mixed.onnx",
    "mobileclip2_s3_server_full_ce_hardneg_text_encoder_fp16_mixed.onnx.data"
)

if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
    throw "Model artifact source directory not found: $SourceDir"
}

New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null

$missing = @()
foreach ($file in $requiredFiles) {
    $sourcePath = Join-Path $SourceDir $file
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        $missing += $file
    }
}

if ($missing.Count -gt 0) {
    throw "Missing required source artifact file(s): $($missing -join ', ')"
}

foreach ($file in $requiredFiles) {
    $sourcePath = Join-Path $SourceDir $file
    $targetPath = Join-Path $TargetDir $file
    Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
    $size = (Get-Item -LiteralPath $targetPath).Length
    Write-Output ("[copied] {0} ({1:N0} bytes)" -f $file, $size)
}

Write-Output "[done] Model artifacts synced to $TargetDir"
