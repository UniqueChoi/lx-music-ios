# 一键发布并触发 iOS 构建
#
# 前置（只需做一次）：
#   gh auth login
#   → 选择 GitHub.com → HTTPS → Login with a web browser
#   → 在浏览器里输入一次性验证码完成授权
#
# 之后运行：
#   powershell -ExecutionPolicy Bypass -File scripts/publish-ios.ps1 -RepoName lx-music-ios
#
# 参数：
#   -RepoName   要创建的仓库名（默认 lx-music-ios）
#   -Private    创建为私有仓库（默认公开；私有仓库 macOS 额度约 200 分钟/月）
#   -SkipRun    只推送，不自动触发构建

param(
  [string]$RepoName = 'lx-music-ios',
  [switch]$Private,
  [switch]$SkipRun
)

$ErrorActionPreference = 'Stop'

function Find-Gh {
  $c = Get-Command gh -ErrorAction SilentlyContinue
  if ($c) { return $c.Source }
  foreach ($p in @("$env:ProgramFiles\GitHub CLI\gh.exe", "${env:ProgramFiles(x86)}\GitHub CLI\gh.exe")) {
    if (Test-Path $p) { return $p }
  }
  throw '未找到 gh。请先安装：winget install GitHub.cli'
}

$gh = Find-Gh
$repo = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $repo
try {
  Write-Host '==> 检查登录状态'
  & $gh auth status 2>&1 | Out-String | Write-Host
  if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host '尚未登录。请先执行：' -ForegroundColor Yellow
    Write-Host '    gh auth login' -ForegroundColor Cyan
    Write-Host '选择 GitHub.com → HTTPS → Login with a web browser' -ForegroundColor Gray
    exit 1
  }

  $user = (& $gh api user --jq .login).Trim()
  Write-Host "==> 当前账号: $user"

  $full = "$user/$RepoName"
  $visibility = if ($Private) { 'private' } else { 'public' }

  Write-Host "==> 创建仓库 $full ($visibility)"
  $exists = $true
  & $gh repo view $full --json name 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { $exists = $false }

  if ($exists) {
    Write-Host "    仓库已存在，直接复用"
  } else {
    & $gh repo create $full "--$visibility" --description 'LX Music iOS 适配版（个人自用构建）' 2>&1 | Out-String | Write-Host
    if ($LASTEXITCODE -ne 0) { throw '创建仓库失败' }
  }

  Write-Host '==> 配置远程并推送'
  $remoteUrl = "https://github.com/$full.git"
  & git remote remove origin 2>&1 | Out-Null
  & git remote add origin $remoteUrl

  # 用 gh 的凭据填充 git 的 credential helper，避免交互式输入密码
  & $gh auth setup-git 2>&1 | Out-Null

  & git branch -M master 2>&1 | Out-Null
  & git push -u origin master --force 2>&1 | Out-String | Write-Host
  if ($LASTEXITCODE -ne 0) { throw '推送失败' }

  Write-Host ''
  Write-Host "==> 推送完成: https://github.com/$full" -ForegroundColor Green

  if (-not $SkipRun) {
    Write-Host '==> 触发 iOS Build 工作流'
    Start-Sleep -Seconds 3
    & $gh workflow run ios-build.yml --repo $full --ref master 2>&1 | Out-String | Write-Host
    if ($LASTEXITCODE -ne 0) {
      Write-Host '自动触发失败（可能 workflow 尚未被 GitHub 索引）。' -ForegroundColor Yellow
      Write-Host "请手动打开: https://github.com/$full/actions" -ForegroundColor Cyan
    } else {
      Write-Host '已触发。等待几秒后可查看：' -ForegroundColor Green
      Write-Host "    gh run watch --repo $full" -ForegroundColor Cyan
      Write-Host "    gh run list  --repo $full" -ForegroundColor Cyan
    }
  }

  Write-Host ''
  Write-Host "Actions 页面: https://github.com/$full/actions" -ForegroundColor Cyan
} finally {
  Pop-Location
}
