param(
  [switch]$SkipPackage
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot

function Invoke-AcceptanceStep {
  param(
    [string]$Name,
    [scriptblock]$Command
  )

  Write-Host "== $Name ==" -ForegroundColor Cyan
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Name failed with exit code $LASTEXITCODE"
  }
}

try {
  if (-not (Get-Command moon -ErrorAction SilentlyContinue)) {
    throw "moon is required for acceptance verification"
  }
  if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "node is required for report and packaging verification"
  }

  Invoke-AcceptanceStep "MoonBit check" {
    moon check --target all --deny-warn
  }

  foreach ($target in @("native", "wasm", "wasm-gc", "js")) {
    Invoke-AcceptanceStep "MoonBit tests ($target)" {
      moon test --target $target --deny-warn
    }
  }

  Invoke-AcceptanceStep "Cross-file semantic report" {
    $script:semanticJson = (
      moon run cmd/main -- examples/semantic/cross_file `
        --no-config --format json --fail-on never
    ) -join "`n"
  }
  if ($LASTEXITCODE -ne 0) {
    throw "cross-file semantic scan failed"
  }
  $env:MOONHERMETIC_ACCEPTANCE_JSON = $semanticJson
  node scripts/verify-semantic-contract.mjs semantic
  if ($LASTEXITCODE -ne 0) {
    throw "cross-file JSON contract failed"
  }

  Invoke-AcceptanceStep "Legacy comparison" {
    $script:legacyJson = (
      moon run cmd/main -- examples/semantic/cross_file `
        --no-config --no-reachability --format json --fail-on never
    ) -join "`n"
  }
  if ($LASTEXITCODE -ne 0) {
    throw "legacy comparison scan failed"
  }
  $env:MOONHERMETIC_ACCEPTANCE_LEGACY = $legacyJson
  node scripts/verify-semantic-contract.mjs legacy
  if ($LASTEXITCODE -ne 0) {
    throw "legacy comparison contract failed"
  }

  Invoke-AcceptanceStep "Node and Action tests" {
    foreach (
      $testFile in @(
        "tests/action-binary.test.mjs",
        "tests/action-runner.test.mjs",
        "tests/github-report.test.mjs",
        "tests/package.test.mjs"
      )
    ) {
      node $testFile
      if ($LASTEXITCODE -ne 0) {
        throw "$testFile failed"
      }
    }
  }

  Invoke-AcceptanceStep "Reviewed false-positive boundaries" {
    node scripts/render-reviewed-cases.mjs
  }

  if (-not $SkipPackage) {
    Invoke-AcceptanceStep "Mooncakes package validation" {
      moon package --list | Out-Null
      if ($LASTEXITCODE -ne 0) {
        throw "moon package --list failed"
      }
      node scripts/validate-package.mjs --output dist
    }
  }

  $applicationText = [IO.File]::ReadAllText(
    (Join-Path $repoRoot "docs/APPLICATION.zh.md"),
    [Text.Encoding]::UTF8
  )
  $applicationLines = (
    [Text.RegularExpressions.Regex]::Split($applicationText.TrimEnd(), "\r?\n")
  ).Count
  if ($applicationLines -ne 70) {
    throw "application must contain 70 lines; found $applicationLines"
  }

  Write-Host ""
  Write-Host "ACCEPTANCE PASSED" -ForegroundColor Green
  Write-Host "Four MoonBit targets, cross-file semantics, legacy comparison,"
  Write-Host "Node tests, package validation, and the 70-line application passed."
}
finally {
  Remove-Item Env:MOONHERMETIC_ACCEPTANCE_JSON -ErrorAction SilentlyContinue
  Remove-Item Env:MOONHERMETIC_ACCEPTANCE_LEGACY -ErrorAction SilentlyContinue
  Pop-Location
}
