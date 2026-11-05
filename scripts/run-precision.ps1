param(
  [string]$WorkDir = "work/precision-benchmark",
  [string]$Gh = "gh",
  [switch]$UpdateBaseline
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$corpusPath = Join-Path $repoRoot "benchmarks/precision-corpus.json"
$baselinePath = Join-Path $repoRoot "benchmarks/precision-baseline.json"
$workRoot = if ([IO.Path]::IsPathRooted($WorkDir)) {
  $WorkDir
} else {
  Join-Path $repoRoot $WorkDir
}
$archiveRoot = Join-Path $workRoot "archives"
$sourceRoot = Join-Path $workRoot "sources"
$reportRoot = Join-Path $workRoot "reports"

New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null
New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null

if (-not (Get-Command $Gh -ErrorAction SilentlyContinue)) {
  throw "GitHub CLI was not found. Install gh or pass -Gh <path>."
}
if (-not (Get-Command tar -ErrorAction SilentlyContinue)) {
  throw "tar is required to extract repository snapshots."
}
if (-not (Get-Command moon -ErrorAction SilentlyContinue)) {
  throw "MoonBit toolchain 'moon' is required."
}

$corpus = Get-Content $corpusPath -Raw | ConvertFrom-Json
$baseline = Get-Content $baselinePath -Raw | ConvertFrom-Json
$rules = @(
  "HERM-CLOCK",
  "HERM-RAND",
  "HERM-ENV",
  "HERM-NET",
  "HERM-PROC",
  "HERM-FS",
  "HERM-SLEEP"
)

function Invoke-GhDownload {
  param(
    [string]$Endpoint,
    [string]$Destination
  )

  $startInfo = [Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = (Get-Command $Gh).Source
  $startInfo.Arguments = "api $Endpoint"
  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true

  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  [void]$process.Start()
  $stderr = $process.StandardError.ReadToEndAsync()
  $stream = [IO.File]::Create($Destination)
  try {
    $process.StandardOutput.BaseStream.CopyTo($stream)
  } finally {
    $stream.Dispose()
  }
  $process.WaitForExit()
  $errorText = $stderr.Result.Trim()
  if ($process.ExitCode -ne 0) {
    throw "gh api failed for '$Endpoint': $errorText"
  }
  if ((Get-Item $Destination).Length -eq 0) {
    throw "gh api returned an empty archive for '$Endpoint'."
  }
}

function Expand-MoonBitSources {
  param(
    [string]$Archive,
    [string]$Destination
  )

  New-Item -ItemType Directory -Path $Destination -Force | Out-Null
  $entries = @(
    & tar -tzf $Archive |
      Where-Object { $_ -match "\.mbt$" }
  )
  if ($LASTEXITCODE -ne 0) {
    throw "Cannot list archive '$Archive'."
  }

  for ($index = 0; $index -lt $entries.Count; $index += 40) {
    $end = [Math]::Min($index + 39, $entries.Count - 1)
    $batch = $entries[$index..$end]
    & tar -xzf $Archive -C $Destination --strip-components=1 @batch
    if ($LASTEXITCODE -ne 0) {
      throw "Cannot extract MoonBit sources from '$Archive'."
    }
  }
  $entries.Count
}

function Get-RuleCounts {
  param($Findings)

  $counts = [ordered]@{}
  foreach ($rule in $rules) {
    $counts[$rule] = @($Findings | Where-Object ruleId -eq $rule).Count
  }
  $counts
}

$actualRepositories = @()
$failures = @()

Push-Location $repoRoot
try {
  & moon build cmd/main
  if ($LASTEXITCODE -ne 0) {
    throw "moon build cmd/main failed."
  }

  foreach ($repository in $corpus.repositories) {
    $shortCommit = $repository.commit.Substring(0, 7)
    $archive = Join-Path $archiveRoot "$($repository.id)-$shortCommit.tar.gz"
    $source = Join-Path $sourceRoot "$($repository.id)-$shortCommit"
    $report = Join-Path $reportRoot "$($repository.id).json"

    if (-not (Test-Path $archive) -or (Get-Item $archive).Length -eq 0) {
      $endpoint = "repos/$($repository.repository)/tarball/$($repository.commit)"
      Invoke-GhDownload -Endpoint $endpoint -Destination $archive
    }

    $sourceFiles = Expand-MoonBitSources -Archive $archive -Destination $source
    & moon run cmd/main -- $source --no-config --format json --fail-on never |
      Out-File -Encoding utf8 $report
    if ($LASTEXITCODE -ne 0) {
      throw "MoonHermetic failed while scanning '$($repository.id)'."
    }

    $scan = Get-Content $report -Raw | ConvertFrom-Json
    $actual = [ordered]@{
      id = $repository.id
      testFiles = $scan.summary.scannedFiles
      findings = $scan.summary.findings
      byRule = Get-RuleCounts -Findings $scan.findings
    }
    $actualRepositories += $actual

    $expected = $baseline.repositories |
      Where-Object id -eq $repository.id |
      Select-Object -First 1
    $repositoryFailures = @()
    if ($null -eq $expected) {
      $repositoryFailures += "baseline entry is missing"
    } else {
      if ($actual.testFiles -ne $expected.testFiles) {
        $repositoryFailures +=
          "testFiles $($actual.testFiles) != $($expected.testFiles)"
      }
      if ($actual.findings -ne $expected.findings) {
        $repositoryFailures +=
          "findings $($actual.findings) != $($expected.findings)"
      }
      foreach ($rule in $rules) {
        if ($actual.byRule[$rule] -ne $expected.byRule.$rule) {
          $repositoryFailures +=
            "$rule $($actual.byRule[$rule]) != $($expected.byRule.$rule)"
        }
      }
    }

    if ($repositoryFailures.Count -eq 0) {
      Write-Host (
        "[PASS] {0}: {1} test files, {2} findings ({3} MoonBit files)" -f
          $repository.id,
          $actual.testFiles,
          $actual.findings,
          $sourceFiles
      )
    } else {
      Write-Host (
        "[FAIL] {0}: {1}" -f
          $repository.id,
          ($repositoryFailures -join "; ")
      )
      $failures += "$($repository.id): $($repositoryFailures -join '; ')"
    }
  }
} finally {
  Pop-Location
}

$totalTestFiles = (
  $actualRepositories |
    ForEach-Object { $_.testFiles } |
    Measure-Object -Sum
).Sum
$totalFindings = (
  $actualRepositories |
    ForEach-Object { $_.findings } |
    Measure-Object -Sum
).Sum
$totalByRule = [ordered]@{}
foreach ($rule in $rules) {
  $totalByRule[$rule] = (
    $actualRepositories |
      ForEach-Object { $_.byRule[$rule] } |
      Measure-Object -Sum
  ).Sum
}

$updatedBaseline = [ordered]@{
  schema = "moonhermetic/precision-baseline-v1"
  scannerVersion = $baseline.scannerVersion
  recordedAt = (Get-Date -Format "yyyy-MM-dd")
  summary = [ordered]@{
    repositories = $actualRepositories.Count
    testFiles = $totalTestFiles
    findings = $totalFindings
    byRule = $totalByRule
  }
  repositories = $actualRepositories
}

Write-Host (
  "TOTAL: {0} repositories, {1} test files, {2} findings" -f
    $actualRepositories.Count,
    $totalTestFiles,
    $totalFindings
)

if ($UpdateBaseline) {
  $updatedBaseline |
    ConvertTo-Json -Depth 8 |
    Set-Content -Path $baselinePath -Encoding utf8
  Write-Host "Updated $baselinePath"
} elseif ($failures.Count -gt 0) {
  throw "Precision baseline changed:`n$($failures -join "`n")"
}
