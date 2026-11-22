param(
  [int]$DurationSeconds = 150,
  [int]$FramesPerSecond = 2
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$repoRoot = Split-Path -Parent $PSScriptRoot
$frameDir = Join-Path $repoRoot "dist\demo-frames"
$posterPath = Join-Path $repoRoot "dist\moonhermetic-demo-poster.jpg"
New-Item -ItemType Directory -Force -Path $frameDir | Out-Null
Get-ChildItem -LiteralPath $frameDir -Filter "frame-*.jpg" -File | Remove-Item -Force

$width = 1280
$height = 720
$frameCount = $DurationSeconds * $FramesPerSecond
$bitmap = New-Object System.Drawing.Bitmap($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

$bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(8, 16, 24))
$panelBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(16, 28, 39))
$panel2Brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(13, 23, 32))
$linePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(34, 54, 70), 2)
$gridPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(18, 30, 40), 1)
$textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(231, 240, 247))
$mutedBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(145, 166, 183))
$greenBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(105, 230, 166))
$cyanBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(99, 216, 255))
$yellowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 209, 102))
$redBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 123, 123))

$fontUi = New-Object System.Drawing.Font("Microsoft YaHei UI", 24)
$fontUiSmall = New-Object System.Drawing.Font("Microsoft YaHei UI", 20)
$fontUiMedium = New-Object System.Drawing.Font("Microsoft YaHei UI", 32)
$fontUiLarge = New-Object System.Drawing.Font("Microsoft YaHei UI", 52, [System.Drawing.FontStyle]::Bold)
$fontUiHero = New-Object System.Drawing.Font("Microsoft YaHei UI", 72, [System.Drawing.FontStyle]::Bold)
$fontMono = New-Object System.Drawing.Font("Cascadia Mono", 22)
$fontMonoSmall = New-Object System.Drawing.Font("Cascadia Mono", 18)
$fontMonoBold = New-Object System.Drawing.Font("Cascadia Mono", 28, [System.Drawing.FontStyle]::Bold)

function Draw-RoundPanel {
  param([float]$X, [float]$Y, [float]$W, [float]$H)
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $radius = 18
  $path.AddArc($X, $Y, $radius, $radius, 180, 90)
  $path.AddArc($X + $W - $radius, $Y, $radius, $radius, 270, 90)
  $path.AddArc($X + $W - $radius, $Y + $H - $radius, $radius, $radius, 0, 90)
  $path.AddArc($X, $Y + $H - $radius, $radius, $radius, 90, 90)
  $path.CloseFigure()
  $graphics.FillPath($panelBrush, $path)
  $graphics.DrawPath($linePen, $path)
  $path.Dispose()
}

function Draw-Base {
  param([double]$Second)
  $graphics.FillRectangle($bgBrush, 0, 0, $width, $height)
  for ($x = 0; $x -lt $width; $x += 32) {
    $graphics.DrawLine($gridPen, $x, 0, $x, $height)
  }
  for ($y = 0; $y -lt $height; $y += 32) {
    $graphics.DrawLine($gridPen, 0, $y, $width, $y)
  }
  $graphics.DrawString(
    "MoonHermetic · MoonBit 测试可达性审计",
    $fontMonoSmall,
    $mutedBrush,
    54,
    36
  )
  $minutes = [Math]::Floor($Second / 60)
  $seconds = [Math]::Floor($Second % 60)
  $timeText = "{0}:{1:D2}" -f [int]$minutes, [int]$seconds
  $graphics.DrawString(
    $timeText,
    $fontMonoSmall,
    $mutedBrush,
    1160,
    36
  )
  $graphics.DrawLine($linePen, 54, 684, 1226, 684)
  $progress = [Math]::Min($Second / $DurationSeconds, 1.0)
  $graphics.DrawLine(
    (New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(105, 230, 166), 4)),
    54,
    684,
    54 + (1172 * $progress),
    684
  )
}

function Get-Scene {
  param([double]$Second)
  if ($Second -lt 15) { return 0 }
  if ($Second -lt 40) { return 1 }
  if ($Second -lt 75) { return 2 }
  if ($Second -lt 105) { return 3 }
  if ($Second -lt 135) { return 4 }
  return 5
}

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
  Where-Object { $_.MimeType -eq "image/jpeg" } |
  Select-Object -First 1
$encoderParameters = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encoderParameters.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
  [System.Drawing.Imaging.Encoder]::Quality,
  [long]88
)

for ($frame = 0; $frame -lt $frameCount; $frame++) {
  $second = $frame / $FramesPerSecond
  Draw-Base $second
  switch (Get-Scene $second) {
    0 {
      $graphics.DrawString("MOONBIT HACKATHON · V0.16.1", $fontMono, $greenBrush, 130, 200)
      $graphics.DrawString("MoonHermetic", $fontUiHero, $textBrush, 124, 252)
      $graphics.DrawString("在测试运行前，看见隐藏的宿主边界", $fontUiMedium, $cyanBrush, 130, 360)
      Draw-RoundPanel 130 440 1020 116
      $graphics.DrawString(
        "MoonBit 原生 · 跨文件调用链 · JSON / SARIF · GitHub Action",
        $fontUi,
        $textBrush,
        168,
        480
      )
    }
    1 {
      $graphics.DrawString("问题不是「测试有没有跑」，而是它依赖了什么", $fontUiLarge, $textBrush, 100, 155)
      $cards = @(
        @("时间与随机", "今天通过，明天失败", $yellowBrush),
        @("环境与网络", "本地通过，CI 失败", $cyanBrush),
        @("文件与子进程", "机器状态泄漏进测试", $greenBrush)
      )
      for ($i = 0; $i -lt $cards.Count; $i++) {
        $x = 100 + $i * 365
        Draw-RoundPanel $x 250 320 220
        $graphics.DrawString($cards[$i][0], $fontMonoBold, $cards[$i][2], ($x + 28), 295)
        $graphics.DrawString($cards[$i][1], $fontUiSmall, $mutedBrush, ($x + 28), 365)
      }
      Draw-RoundPanel 100 520 1080 92
      $graphics.DrawString(
        "MoonHermetic → 源码位置 + 所属测试 + 完整调用链",
        $fontMono,
        $textBrush,
        135,
        550
      )
    }
    2 {
      $graphics.DrawString("同包跨文件调用链", $fontUiLarge, $textBrush, 100, 125)
      Draw-RoundPanel 120 210 1040 390
      $lines = @(
        @("test", "cross-file request reads an ambient token", $yellowBrush),
        @("  →", "prepare_request", $cyanBrush),
        @("  →", "read_ambient_token", $cyanBrush),
        @("  →", "@env.get_env_var(`"TOKEN`")", $redBrush),
        @("", "", $textBrush),
        @("✓", "未使用 helper 中的 fetch() 不报告", $greenBrush),
        @("✓", "不同 package 中的同名函数不误连", $greenBrush)
      )
      for ($i = 0; $i -lt $lines.Count; $i++) {
        $graphics.DrawString($lines[$i][0], $fontMono, $lines[$i][2], 155, 250 + $i * 43)
        $graphics.DrawString($lines[$i][1], $fontMono, $textBrush, 250, 250 + $i * 43)
      }
    }
    3 {
      $graphics.DrawString("从代码审查到 CI 门禁", $fontUiLarge, $textBrush, 100, 125)
      Draw-RoundPanel 120 210 500 370
      Draw-RoundPanel 660 210 500 370
      $graphics.DrawString("JSON", $fontMonoBold, $cyanBrush, 150, 240)
      $jsonLines = @(
        '"testName": "cross-file ..."',
        '"callPath": [',
        '  "prepare_request",',
        '  "read_ambient_token"',
        "]"
      )
      for ($i = 0; $i -lt $jsonLines.Count; $i++) {
        $graphics.DrawString($jsonLines[$i], $fontMonoSmall, $textBrush, 150, 300 + $i * 42)
      }
      $graphics.DrawString("SARIF 2.1.0", $fontMonoBold, $greenBrush, 690, 240)
      $outLines = @(
        "✓ GitHub Code Scanning",
        "✓ Job Summary",
        "✓ Managed PR Comment",
        "✓ Diff-aware filtering"
      )
      for ($i = 0; $i -lt $outLines.Count; $i++) {
        $graphics.DrawString($outLines[$i], $fontMonoSmall, $textBrush, 690, 305 + $i * 45)
      }
      $graphics.DrawString(
        "同一发现，四种可消费格式，不靠解析终端文本。",
        $fontUiSmall,
        $mutedBrush,
        125,
        610
      )
    }
    4 {
      $graphics.DrawString("v0.16.1 已完整交付", $fontUiLarge, $textBrush, 100, 155)
      $metrics = @(
        @("74 / 74", "四目标测试", $greenBrush),
        @("3 / 3", "系统平台 CI", $cyanBrush),
        @("77", "打包条目", $yellowBrush),
        @("70 行", "申报书", $redBrush)
      )
      for ($i = 0; $i -lt $metrics.Count; $i++) {
        $x = 95 + $i * 282
        Draw-RoundPanel $x 250 245 190
        $graphics.DrawString($metrics[$i][0], $fontMonoBold, $metrics[$i][2], ($x + 28), 295)
        $graphics.DrawString($metrics[$i][1], $fontUiSmall, $mutedBrush, ($x + 28), 365)
      }
      Draw-RoundPanel 95 495 1090 105
      $graphics.DrawString(
        "Linux · macOS · Windows · Mooncakes ZIP · SHA-256",
        $fontMono,
        $textBrush,
        135,
        535
      )
    }
    5 {
      $graphics.DrawString("AUDIT BEFORE FAILURE", $fontMono, $greenBrush, 410, 190)
      $graphics.DrawString("MoonHermetic", $fontUiHero, $textBrush, 350, 255)
      $graphics.DrawString(
        "让 MoonBit 测试依赖变得可见、可解释、可门禁",
        $fontUiMedium,
        $cyanBrush,
        230,
        365
      )
      $graphics.DrawString(
        "github.com/kobe108/moonhermetic",
        $fontMono,
        $mutedBrush,
        360,
        500
      )
    }
  }
  $framePath = Join-Path $frameDir ("frame-{0:D3}.jpg" -f $frame)
  $bitmap.Save(
    $framePath,
    $jpegCodec,
    $encoderParameters
  )
  if ($frame -eq 0) {
    $bitmap.Save($posterPath, $jpegCodec, $encoderParameters)
  }
}

$graphics.Dispose()
$bitmap.Dispose()
Write-Output "rendered $frameCount frames at ${FramesPerSecond} fps"
Write-Output "frames: $frameDir"
Write-Output "poster: $posterPath"
