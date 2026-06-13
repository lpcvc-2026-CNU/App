param(
    [string]$SourceDir = $env:LANDMARK_MODEL_ARTIFACT_SOURCE,
    [string]$TargetDir = "assets\mobile_artifacts_fp16"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if (-not [System.IO.Path]::IsPathRooted($TargetDir)) {
    $TargetDir = Join-Path $RepoRoot $TargetDir
}

if ([string]::IsNullOrWhiteSpace($SourceDir)) {
    throw "Model artifact source directory is required. Pass -SourceDir or set LANDMARK_MODEL_ARTIFACT_SOURCE."
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
    "confidence_policy.json",
    "tokenizer_bundle.json",
    "text_index.json",
    "text_search_policy.json",
    "text_query_regression_set.json",
    "text_search_eval_report.json",
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

$manifestPath = Join-Path $TargetDir "manifest.json"
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.PSObject.Properties.Name -contains "checkpoint") {
    $artifactRunDir = Split-Path (Split-Path $SourceDir -Parent) -Parent
    $artifactRunName = Split-Path $artifactRunDir -Leaf
    $manifest.checkpoint = "$artifactRunName/best.pt"
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    Write-Output "[normalized] manifest checkpoint is repo-portable: $($manifest.checkpoint)"
}

Write-Output "[done] Model artifacts synced to $TargetDir"
