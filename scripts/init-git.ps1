param(
  [string]$RemoteUrl = ""
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw "Git is not installed or is not available on PATH."
}

git init
git branch -M main
git config user.name "kobe108"
git config user.email "3360944005@qq.com"
git add .
git commit -m "feat: initial MoonHermetic MVP"

if ($RemoteUrl) {
  if (git remote get-url origin 2>$null) {
    git remote set-url origin $RemoteUrl
  } else {
    git remote add origin $RemoteUrl
  }
  Write-Host "Remote configured. Review the commit, then run: git push -u origin main"
}
