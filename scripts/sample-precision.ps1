param(
  [string]$WorkDir = "work/precision-benchmark",
  [int]$PerRule = 5,
  [string]$Seed = "moonhermetic-precision-v1",
  [string]$Output = "work/stratified-review-queue.json"
)

$ErrorActionPreference = "Stop"
if ($PerRule -lt 1) {
  throw "-PerRule must be at least 1."
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$workRoot = if ([IO.Path]::IsPathRooted($WorkDir)) {
  $WorkDir
} else {
  Join-Path $repoRoot $WorkDir
}
$sourceRoot = Join-Path $workRoot "sources"
$reportRoot = Join-Path $workRoot "reports"
$corpusPath = Join-Path $repoRoot "benchmarks/precision-corpus.json"
$outputPath = if ([IO.Path]::IsPathRooted($Output)) {
  $Output
} else {
  Join-Path $repoRoot $Output
}

if (-not (Test-Path $reportRoot)) {
  throw "Benchmark reports not found at '$reportRoot'. Run run-precision.ps1 first."
}

$corpus = Get-Content $corpusPath -Raw | ConvertFrom-Json
$repositoryMap = @{}
foreach ($repository in $corpus.repositories) {
  $repositoryMap[$repository.id] = $repository
}

function Get-StableHash {
  param([string]$Value)

  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

function Get-RelativeFindingPath {
  param(
    [string]$Repository,
    [string]$Path
  )

  $entry = $repositoryMap[$Repository]
  $shortCommit = $entry.commit.Substring(0, 7)
  $source = [IO.Path]::GetFullPath(
    (Join-Path $sourceRoot "$Repository-$shortCommit")
  ).Replace("\", "/")
  $normalized = $Path.Replace("\", "/")
  $prefix = "$source/"
  if (-not $normalized.StartsWith($prefix)) {
    throw "Finding path '$Path' is outside '$source'."
  }
  $normalized.Substring($prefix.Length)
}

$candidates = @()
foreach ($reportFile in Get-ChildItem $reportRoot -Filter *.json) {
  if ($reportFile.Name -eq "reviewed-summary.json") {
    continue
  }
  $repository = $reportFile.BaseName
  $report = Get-Content $reportFile.FullName -Raw | ConvertFrom-Json
  foreach ($finding in $report.findings) {
    $relativePath = Get-RelativeFindingPath -Repository $repository -Path $finding.path
    $key = "$Seed|$repository|$relativePath|$($finding.line)|$($finding.ruleId)"
    $candidates += [pscustomobject]@{
      id = "$($finding.ruleId.ToLowerInvariant())-$repository-$($finding.line)"
      repository = $repository
      path = $relativePath
      line = [int]$finding.line
      column = [int]$finding.column
      ruleId = $finding.ruleId
      evidence = $finding.evidence
      label = ""
      reason = ""
      stableHash = Get-StableHash -Value $key
    }
  }
}

$selected = @()
foreach ($group in ($candidates | Group-Object ruleId | Sort-Object Name)) {
  $selected += $group.Group |
    Sort-Object stableHash |
    Select-Object -First $PerRule
}

$queue = [ordered]@{
  schema = "moonhermetic/stratified-review-v1"
  seed = $Seed
  perRule = $PerRule
  cases = @(
    $selected |
      Sort-Object ruleId, stableHash |
      ForEach-Object {
        [ordered]@{
          id = $_.id
          repository = $_.repository
          path = $_.path
          line = $_.line
          column = $_.column
          ruleId = $_.ruleId
          evidence = $_.evidence
          label = ""
          reason = ""
          stableHash = $_.stableHash
        }
      }
  )
}

$queue |
  ConvertTo-Json -Depth 8 |
  Set-Content -Path $outputPath -Encoding utf8
Write-Host "Wrote $($selected.Count) cases to $outputPath"
