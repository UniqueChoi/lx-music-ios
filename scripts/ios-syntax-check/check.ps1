# iOS 原生代码语法编译检查（Windows / 无 Xcode 环境）
#
# 背景：iOS 正式构建只能在 macOS + Xcode 上做。在 Windows 上改动 ios/LxModules 时，
#      没有任何反馈手段。本脚本用 zig 自带的 clang + 一套手写 SDK 桩头文件，
#      对 Objective-C 源码做**真实编译**（生成目标文件），用于快速发现问题。
#
# 它能查出：语法错误、拼错的 selector、参数个数/类型不匹配、未声明的标识符、
#          未导入的头文件、方法签名与实际调用不符。
# 它查不出：与真实 Apple SDK 的差异、链接错误、运行时行为、资源打包问题。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts\ios-syntax-check\check.ps1
# 前置：zig（winget install zig.zig）

# 注意：不能设为 Stop。Windows PowerShell 5.1 会把原生命令的 stderr 输出
# 当作终止性错误抛出，而 clang 的正常诊断信息就是走 stderr 的。
$ErrorActionPreference = 'Continue'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$srcDir = Join-Path $repoRoot 'ios\LxModules\ios'
$stubDir = Join-Path $PSScriptRoot 'stubs'
$outDir = Join-Path $env:TEMP 'lx-ios-syntax-check'

$cmd = Get-Command zig -ErrorAction SilentlyContinue
$zig = $null
if ($cmd) { $zig = $cmd.Source }
if (-not $zig) {
  $found = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter 'zig.exe' -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($found) { $zig = $found.FullName }
}
if (-not $zig) {
  Write-Host '未找到 zig。请先安装：winget install zig.zig' -ForegroundColor Red
  exit 2
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$sources = Get-ChildItem $srcDir -Filter *.m | Select-Object -ExpandProperty Name
if ($sources.Count -eq 0) {
  Write-Host "未在 $srcDir 找到 .m 文件" -ForegroundColor Red
  exit 2
}

$failed = 0
foreach ($file in $sources) {
  $obj = Join-Path $outDir ($file -replace '\.m$', '.o')
  $log = & $zig cc -c -x objective-c -fobjc-arc -fblocks -Wall -Wextra `
    '-fobjc-runtime=macosx-10.15' -I $stubDir -I $srcDir -o $obj (Join-Path $srcDir $file) 2>&1

  # 只匹配真正的诊断行（形如 path:12:34: error: ...）。
  # 不能简单匹配 'error:'，因为源码回显行里也有 error:(NSError **) 字样。
  $errors = @($log | Where-Object { "$_" -match ':\d+:\d+: error:' })
  $ownWarnings = @($log | Where-Object { "$_" -match 'LxModules.*:\d+:\d+: warning:' })

  if ($LASTEXITCODE -ne 0 -or $errors.Count -gt 0) {
    $failed++
    Write-Host "FAIL  $file" -ForegroundColor Red
    $errors | Select-Object -First 10 | ForEach-Object { Write-Host "        $_" -ForegroundColor DarkRed }
  } elseif ($ownWarnings.Count -gt 0) {
    Write-Host "WARN  $file ($($ownWarnings.Count) warnings)" -ForegroundColor Yellow
    $ownWarnings | Select-Object -First 10 | ForEach-Object { Write-Host "        $_" -ForegroundColor DarkYellow }
  } else {
    Write-Host "OK    $file" -ForegroundColor Green
  }
}

Write-Host ''
if ($failed -eq 0) {
  Write-Host "全部 $($sources.Count) 个文件编译通过（基于桩头文件）" -ForegroundColor Green
  Write-Host '注意：这不等于真机可编译，仍需在 macOS + Xcode 上验证一次。' -ForegroundColor DarkGray
  exit 0
} else {
  Write-Host "$failed 个文件失败" -ForegroundColor Red
  exit 1
}
