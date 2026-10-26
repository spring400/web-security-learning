#Requires -Version 5.1
<#
.SYNOPSIS
    Web 渗透测试本地靶场一键管理脚本

.DESCRIPTION
    管理 dvwa / juice-shop / bwapp / webgoat 四个靶场容器。
    所有端口仅绑定 127.0.0.1，不会暴露到局域网。

.PARAMETER Action
    check    环境自检（Docker、WSL、端口占用）
    up       启动靶场
    down     停止并移除容器
    restart  重启
    status   查看运行状态 + 健康探测
    reset    清空数据并重建（危险，会丢失靶场进度）
    logs     查看日志
    open     浏览器打开靶场
    help     显示帮助

.PARAMETER Profile
    all / dvwa / juice / bwapp / webgoat

.EXAMPLE
    .\lab.ps1 check
    .\lab.ps1 up
    .\lab.ps1 up -Profile dvwa
    .\lab.ps1 reset -Force
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('check', 'up', 'down', 'restart', 'status', 'reset', 'logs', 'open', 'help')]
    [string]$Action = 'help',

    [ValidateSet('all', 'dvwa', 'juice', 'bwapp', 'webgoat')]
    [string]$Profile = 'all',

    [string]$Service = 'all',

    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ComposeFile = Join-Path $Root 'docker-compose.yml'

$Services = @(
    [pscustomobject]@{ Key = 'dvwa';    Container = 'lab-dvwa';    Port = 8081; Url = 'http://127.0.0.1:8081'; Account = 'admin / password' }
    [pscustomobject]@{ Key = 'juice';   Container = 'lab-juice';   Port = 3000; Url = 'http://127.0.0.1:3000'; Account = '自行注册' }
    [pscustomobject]@{ Key = 'bwapp';   Container = 'lab-bwapp';   Port = 8082; Url = 'http://127.0.0.1:8082'; Account = 'bee / bug' }
    [pscustomobject]@{ Key = 'webgoat'; Container = 'lab-webgoat'; Port = 8083; Url = 'http://127.0.0.1:8083'; Account = '自行注册' }
)

# ---------------------------------------------------------------- 工具函数

function Write-Ok    { param($m) Write-Host "  [OK]   $m" -ForegroundColor Green }
function Write-Bad   { param($m) Write-Host "  [FAIL] $m" -ForegroundColor Red }
function Write-Warn2 { param($m) Write-Host "  [WARN] $m" -ForegroundColor Yellow }
function Write-Info  { param($m) Write-Host "  [..]   $m" -ForegroundColor DarkGray }
function Write-Title { param($m) Write-Host "`n$m" -ForegroundColor Cyan }

function Test-CommandExists {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-PortInUse {
    param([int]$Port)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect('127.0.0.1', $Port, $null, $null)
        $connected = $iar.AsyncWaitHandle.WaitOne(300)
        if ($connected) { $client.EndConnect($iar) | Out-Null; return $true }
        return $false
    }
    catch { return $false }
    finally { $client.Close() }
}

function Test-HttpUrl {
    param([string]$Url)
    try {
        $r = Invoke-WebRequest -Uri $Url -TimeoutSec 4 -UseBasicParsing -ErrorAction Stop
        return $r.StatusCode
    }
    catch {
        if ($_.Exception.Response) { return [int]$_.Exception.Response.StatusCode }
        return $null
    }
}

function Invoke-Compose {
    param([string[]]$Arguments)
    & docker compose --file $ComposeFile @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose 执行失败（退出码 $LASTEXITCODE）：$($Arguments -join ' ')"
    }
}

function Assert-Preflight {
    if (-not (Test-CommandExists 'docker')) {
        throw "未检测到 docker 命令。请先安装并启动 Docker Desktop（见 03-靶场搭建指南.md 第 2 节）。"
    }
    & docker info *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker 引擎未运行。请启动 Docker Desktop，等待左下角显示 Engine running。"
    }
    if (-not (Test-Path $ComposeFile)) {
        throw "找不到 docker-compose.yml：$ComposeFile"
    }
}

# ---------------------------------------------------------------- 动作

function Invoke-Check {
    Write-Title '环境自检'

    Write-Host ' Docker'
    if (Test-CommandExists 'docker') {
        $v = (& docker --version 2>$null)
        Write-Ok "$v"
        & docker info *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok 'Docker 引擎运行中'
        }
        else {
            Write-Bad 'Docker 引擎未运行 —— 请启动 Docker Desktop，等托盘图标变绿'
            Write-Info '提示：Docker Desktop 启动通常需要 30-60 秒'
        }
        & docker compose version *> $null
        if ($LASTEXITCODE -eq 0) { Write-Ok 'Compose v2 插件可用' }
        else { Write-Bad '缺少 docker compose 插件（请升级 Docker Desktop）' }
    }
    else {
        Write-Bad '未安装 docker'
        Write-Info '安装方法见 03-靶场搭建指南.md 第 2 节'
    }

    Write-Host "`n WSL"
    if (Test-CommandExists 'wsl') {
        Write-Ok 'wsl 命令可用'
        $oldEnc = [Console]::OutputEncoding
        $distros = @()
        $wslExit = 1
        try {
            [Console]::OutputEncoding = [System.Text.Encoding]::Unicode
            $distros = @(& wsl.exe -l -q 2>$null | Where-Object { $_ -and $_.Trim() -ne '' } | ForEach-Object { $_.Trim() })
            $wslExit = $LASTEXITCODE
        }
        catch { $wslExit = 1 }
        finally { [Console]::OutputEncoding = $oldEnc }

        if ($wslExit -eq 0 -and $distros.Count -gt 0) {
            Write-Ok "已安装发行版：$($distros -join ', ')"
        }
        else {
            Write-Warn2 '尚未安装 Linux 发行版 —— 执行 wsl --install 后重启电脑'
        }
    }
    else {
        Write-Warn2 '未检测到 wsl（若使用 Hyper-V 后端可忽略）'
    }

    Write-Host "`n 端口占用（期望全部空闲）"
    foreach ($s in $Services) {
        if (Test-PortInUse -Port $s.Port) {
            Write-Warn2 "$($s.Port) 已被占用 —— 若已有容器在跑可忽略，否则请释放该端口"
        }
        else {
            Write-Ok "$($s.Port) 空闲（$($s.Key)）"
        }
    }

    Write-Host "`n 配置文件"
    if (Test-Path $ComposeFile) { Write-Ok "docker-compose.yml 存在" }
    else { Write-Bad "缺少 docker-compose.yml：$ComposeFile" }

    Write-Host ''
}

function Invoke-Up {
    Assert-Preflight
    Write-Title "启动靶场（profile: $Profile）"
    Write-Info '首次启动需要拉取镜像，可能耗时数分钟，请耐心等待…'
    Invoke-Compose @('--profile', $Profile, 'up', '-d')
    Write-Host ''
    Start-Sleep -Seconds 3
    Show-Urls
    Write-Host "`n提示：DVWA 首次访问需点左下角 'Setup / Reset DB' → 'Create / Reset Database'" -ForegroundColor DarkGray
}

function Invoke-Down {
    Assert-Preflight
    Write-Title '停止靶场'
    Invoke-Compose @('--profile', 'all', 'down')
    Write-Ok '已停止并移除容器（数据卷保留，用 reset 清空）'
}

function Invoke-Restart {
    Assert-Preflight
    Write-Title '重启靶场'
    Invoke-Compose @('--profile', 'all', 'restart')
    Start-Sleep -Seconds 2
    Show-Urls
}

function Invoke-Reset {
    Assert-Preflight
    if (-not $Force) {
        Write-Host ''
        Write-Host '  警告：该操作会删除全部靶场容器和数据卷，DVWA 里的练习记录将丢失。' -ForegroundColor Yellow
        $answer = Read-Host '  确认重置？输入 yes 继续'
        if ($answer -notin @('yes', 'y', 'Y', 'YES')) {
            Write-Info '已取消'
            return
        }
    }
    Write-Title '重置靶场'
    Invoke-Compose @('--profile', 'all', 'down', '--volumes', '--remove-orphans')
    Invoke-Compose @('--profile', $Profile, 'up', '-d')
    Start-Sleep -Seconds 3
    Write-Ok '已重置完成'
    Show-Urls
}

function Invoke-Status {
    Assert-Preflight
    Write-Title '容器状态'
    Invoke-Compose @('--profile', 'all', 'ps')

    Write-Title '健康探测'
    foreach ($s in $Services) {
        $code = Test-HttpUrl -Url $s.Url
        if ($code) { Write-Ok "$($s.Key.PadRight(8)) $($s.Url)  HTTP $code" }
        else { Write-Info "$($s.Key.PadRight(8)) $($s.Url)  无响应（未启动？）" }
    }
    Write-Host ''
}

function Invoke-Logs {
    Assert-Preflight
    Write-Title "日志（$Service，Ctrl+C 退出）"
    if ($Service -eq 'all') { Invoke-Compose @('--profile', 'all', 'logs', '-f', '--tail', '80') }
    else { Invoke-Compose @('logs', '-f', '--tail', '80', $Service) }
}

function Invoke-Open {
    Write-Title '打开靶场'
    $targets = if ($Profile -eq 'all') { $Services } else { $Services | Where-Object { $_.Key -eq $Profile } }
    foreach ($s in $targets) {
        $code = Test-HttpUrl -Url $s.Url
        if ($code) {
            Start-Process $s.Url
            Write-Ok "$($s.Url)  账号：$($s.Account)"
        }
        else {
            Write-Warn2 "$($s.Url) 无响应，跳过（先执行 .\lab.ps1 up）"
        }
    }
}

function Show-Urls {
    Write-Host ' 靶场地址（仅本机可访问）' -ForegroundColor Cyan
    foreach ($s in $Services) {
        Write-Host ("   {0,-9} {1,-28} {2}" -f $s.Key, $s.Url, $s.Account)
    }
    Write-Host ''
    Write-Host ' 注意：端口只绑 127.0.0.1，局域网内其他设备访问不到 —— 这是有意为之。' -ForegroundColor DarkGray
}

function Show-Help {
    Write-Host @'
Web 渗透测试本地靶场管理脚本

用法：
  .\lab.ps1 <动作> [-Profile <靶场>] [-Force]

动作：
  check      环境自检（Docker / WSL / 端口）
  up         启动靶场
  down       停止并移除容器
  restart    重启
  status     查看状态 + 健康探测
  reset      清空数据并重建
  logs       实时日志（-Service dvwa 指定容器）
  open       浏览器打开靶场
  help       本帮助

靶场（-Profile）：
  all（默认） dvwa  juice  bwapp  webgoat

示例：
  .\lab.ps1 check
  .\lab.ps1 up
  .\lab.ps1 up -Profile dvwa
  .\lab.ps1 reset -Force
  .\lab.ps1 logs -Service dvwa

地址：
  DVWA        http://127.0.0.1:8081   admin / password
  Juice Shop  http://127.0.0.1:3000   自行注册
  bWAPP       http://127.0.0.1:8082   bee / bug
  WebGoat     http://127.0.0.1:8083   自行注册
'@
}

# ---------------------------------------------------------------- 分发

try {
    switch ($Action) {
        'check'   { Invoke-Check }
        'up'      { Invoke-Up }
        'down'    { Invoke-Down }
        'restart' { Invoke-Restart }
        'status'  { Invoke-Status }
        'reset'   { Invoke-Reset }
        'logs'    { Invoke-Logs }
        'open'    { Invoke-Open }
        'help'    { Show-Help }
    }
}
catch {
    Write-Host ''
    Write-Host "  [错误] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ''
    exit 1
}
