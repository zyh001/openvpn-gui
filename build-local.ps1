# build-local.ps1 — 本地一键打包(可选,用于不想等 CI 时本地快速验证)
# 前置:本机已安装 官方 OpenVPN 和 Inno Setup 6
# 用法:
#   powershell -ExecutionPolicy Bypass -File build-local.ps1
#   powershell -ExecutionPolicy Bypass -File build-local.ps1 -GuiExe "build\x64\Release\openvpn-gui.exe"

param(
  [string]$GuiExe     = "",
  [string]$OvpnSrc    = "installer\JCUT-教育网.ovpn",
  [string]$OpenVpnBin = "C:\Program Files\OpenVPN\bin",
  [string]$Iscc       = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
)
$ErrorActionPreference = "Stop"

$bin = "installer\payload\bin"
$cfg = "installer\payload\config"
Remove-Item "installer\payload" -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $bin, $cfg | Out-Null

Copy-Item "$OpenVpnBin\*" $bin -Recurse -Force

if ($GuiExe -and (Test-Path $GuiExe)) {
  Copy-Item $GuiExe "$bin\openvpn-gui.exe" -Force
  Write-Host "[OK] 使用定制 GUI: $GuiExe"
} else {
  Write-Host "[!] 未指定定制 GUI,使用官方 openvpn-gui.exe"
}

Copy-Item $OvpnSrc $cfg -Force

foreach ($f in @("openvpn.exe","openvpnserv.exe","wintun.dll","openvpn-gui.exe")) {
  if (-not (Test-Path "$bin\$f")) { throw "payload 缺少 $f" }
}

& $Iscc "installer\installer.iss"
Write-Host "`n[完成] 安装包在 installer\Output\"
