; ============================================================================
;  荆楚理工学院 VPN 客户端  —  Inno Setup 安装脚本(双架构 32/64 合一)
;  打包:OpenVPN 运行时 + Wintun + 交互服务 + 定制 GUI + 配置
;
;  CI 传入的 /D 定义:
;    /DAppVer=1.0.0
;    /DServiceArgs=""          ← 留空:openvpnserv.exe 裸跑即默认交互服务
;    /DHaveX86=1            ← 仅当成功组装出 32 位 payload 时由 CI 传入
; ============================================================================

#ifndef AppVer
  #define AppVer "1.0.0"
#endif
#ifndef ServiceArgs
  #define ServiceArgs ""
#endif
#if FileExists("app.ico")
  #define HaveIcon
#endif

#define MyAppName       "荆楚理工学院VPN"
#define MyAppPublisher  "湖北摇光科技有限公司"
#define MyAppURL        "https://www.jcut.edu.cn"
#define GuiExe          "openvpn-gui.exe"
#define OvpnConfig      "JCUT-教育网.ovpn"
#define PayloadDir      "payload"
#define SvcName         "OpenVPNServiceInteractive"
#define WintunAdapter   "JCUTVPN"

[Setup]
AppId={{29fcf139-7be8-4080-b5e3-ab2f50568d59}
AppName={#MyAppName}
AppVersion={#AppVer}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\JCUTVPN
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=JCUTVPN-Setup-{#AppVer}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
; 有 32 位 payload 才允许在纯 32 位系统上运行;否则限定 64 位
#ifdef HaveX86
ArchitecturesAllowed=x86compatible
#else
ArchitecturesAllowed=x64compatible
#endif
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no
#ifdef HaveIcon
SetupIconFile=app.ico
#endif
UninstallDisplayIcon={app}\bin\{#GuiExe}

[Languages]
Name: "chs"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务:"
Name: "autostart";   Description: "开机时自动启动客户端"; GroupDescription: "附加任务:"; Flags: unchecked

[Dirs]
Name: "{app}\config"; Permissions: users-modify
Name: "{app}\log";    Permissions: users-modify

[Files]
; 64 位运行时(64 位安装模式时)
Source: "{#PayloadDir}\x64\bin\*"; DestDir: "{app}\bin"; Check: Is64BitInstallMode; Flags: recursesubdirs ignoreversion
#ifdef HaveX86
; 32 位运行时(32 位安装模式时)
Source: "{#PayloadDir}\x86\bin\*"; DestDir: "{app}\bin"; Check: not Is64BitInstallMode; Flags: recursesubdirs ignoreversion
#endif
; 配置文件
Source: "{#PayloadDir}\config\{#OvpnConfig}"; DestDir: "{app}\config"; Flags: ignoreversion
#ifdef HaveIcon
Source: "app.ico"; DestDir: "{app}"; Flags: ignoreversion
#endif

[Icons]
#ifdef HaveIcon
Name: "{group}\{#MyAppName}";       Filename: "{app}\bin\{#GuiExe}"; Parameters: "--connect ""{#OvpnConfig}"""; IconFilename: "{app}\app.ico"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\bin\{#GuiExe}"; Parameters: "--connect ""{#OvpnConfig}"""; IconFilename: "{app}\app.ico"; Tasks: desktopicon
#else
Name: "{group}\{#MyAppName}";       Filename: "{app}\bin\{#GuiExe}"; Parameters: "--connect ""{#OvpnConfig}"""
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\bin\{#GuiExe}"; Parameters: "--connect ""{#OvpnConfig}"""; Tasks: desktopicon
#endif
Name: "{group}\卸载 {#MyAppName}";   Filename: "{uninstallexe}"
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\bin\{#GuiExe}"; Parameters: "--connect ""{#OvpnConfig}"""; Tasks: autostart

[Run]
Filename: "{app}\bin\{#GuiExe}"; Parameters: "--connect ""{#OvpnConfig}"""; Description: "立即启动 {#MyAppName}"; Flags: nowait postinstall skipifsilent

[Code]
procedure RunHidden(const Cmd: String);
var RC: Integer;
begin
  Exec(ExpandConstant('{cmd}'), '/C ' + Cmd, '', SW_HIDE, ewWaitUntilTerminated, RC);
end;

{ 经 cmd /C 执行并返回退出码,供需要判断成功失败的调用使用。 }
function RunHiddenExitCode(const Cmd: String): Integer;
var RC: Integer;
begin
  Exec(ExpandConstant('{cmd}'), '/C ' + Cmd, '', SW_HIDE, ewWaitUntilTerminated, RC);
  Result := RC;
end;

procedure KillGui;
var RC: Integer;
begin
  Exec('taskkill.exe', '/F /IM {#GuiExe}', '', SW_HIDE, ewWaitUntilTerminated, RC);
end;

function InitializeSetup(): Boolean;
begin
  KillGui;
  Result := True;
end;

{ 用 reg.exe 显式写入指定视图(64/32),绕过 Inno 默认视图可能造成的 WOW6432 重定向 }
procedure RegSet(const Key, Name, Data, View: String);
begin
  RunHidden(Format('reg add "%s" /v %s /t REG_SZ /d "%s" /f /reg:%s', [Key, Name, Data, View]));
end;

{ 写键的“默认值”(空名 @)。reg add 用 /ve 而非 /v。 }
procedure RegSetDefault(const Key, Data, View: String);
begin
  RunHidden(Format('reg add "%s" /ve /t REG_SZ /d "%s" /f /reg:%s', [Key, Data, View]));
end;

{ 注册并启动交互服务,失败则抛错中止安装。
  ★ 关键:openvpnserv.exe 裸跑(不带任何参数)时默认就是交互服务
  (service.c:dispatchTable_shared → ServiceStartInteractive),
  named pipe 为 \\.\pipe\openvpn\service,正是 GUI 连接的路径。
  千万不要加 -instance interactive [id] —— 那会切到“备用实例”模式,
  pipe 变成 \\.\pipe\openvpn<id>\service,GUI 连不上 → msg_channel=0
  → “未启动 OpenVPNServiceInteractive。Wintun 无法工作”。
  binPath 无额外参数,只需给可执行路径加引号(路径含空格),无嵌套引号。 }
procedure RegisterAndStartService(const ServExe: String);
var BinPath, Err: String;
    RC: Integer;
begin
  BinPath := '"' + ServExe + '"';

  { 若已存在(旧版残留)先删除,确保 binPath 是最新正确的 }
  RunHidden('sc stop {#SvcName}');
  RunHidden('sc delete {#SvcName}');

  RC := RunHiddenExitCode('sc create {#SvcName} binPath= ' + BinPath + ' start= auto DisplayName= "荆楚理工学院VPN服务"');
  if RC <> 0 then
  begin
    Err := '创建交互服务失败(sc create 返回 ' + IntToStr(RC) + ')。binPath=' + BinPath;
    RaiseException(Err);
  end;

  { 设描述(可选,忽略错误)}
  RunHidden('sc description {#SvcName} "荆楚理工学院 VPN 交互服务:代为执行需要管理员权限的网络配置"');

  RC := RunHiddenExitCode('sc start {#SvcName}');
  if RC <> 0 then
  begin
    Err := '启动交互服务失败(sc start 返回 ' + IntToStr(RC) + ')。请检查 openvpnserv.exe 是否存在、binPath 是否正确。';
    RaiseException(Err);
  end;
end;

{ 确保 wintun 适配器存在:用 tapctl create --hwid wintun 预创建一个持久适配器。
  ★ 关键:wintun 适配器必须在 openvpn 连接前就存在于系统网卡列表。
  openvpn.exe 只“打开”已有适配器(CreateFile + 注册 ring buffer,后者经交互服务),
  并不创建适配器;交互服务(interactive.c HandleMessage)也只配置地址/路由/DNS/ring,
  不创建适配器。若无 wintun 适配器,get_tap_reg() 枚举为空 →
  “There are no TAP-Windows, Wintun or ovpn-dco adapters” 致命错误。
  tapctl 在 bin 目录,与 openvpn.exe 同目录。 }
procedure EnsureWintunAdapter(const Tapctl: String);
var RC: Integer;
begin
  { 已存在则跳过(tapctl create 同名会失败,忽略即可) }
  RC := RunHiddenExitCode('"' + Tapctl + '" create --hwid wintun --name {#WintunAdapter}');
  if RC <> 0 then
  begin
    { 可能适配器已存在(返回非0),不视为致命错误:列出确认一下 }
    RunHidden('"' + Tapctl + '" list --hwid wintun');
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var App, Bin, Cfg, Lg, View, ServExe: String;
begin
  if CurStep = ssPostInstall then
  begin
    App := ExpandConstant('{app}');
    Bin := ExpandConstant('{app}\bin');
    Cfg := ExpandConstant('{app}\config');
    Lg  := ExpandConstant('{app}\log');
    if Is64BitInstallMode then View := '64' else View := '32';

    { ★ 修复“读取系统注册表值 openvpn 时发生错误”:
      GUI 用 RegOpenKeyEx(不带 WOW64 标志)打开 HKLM\Software\OpenVPN,
      再用 GetRegistryValue(regkey, "") 读键的【默认值】作为 install_path。
      默认值为空或非 REG_SZ → 报 IDS_ERR_READING_REGISTRY。
      故必须写默认值 @ = 安装目录。 }
    RegSetDefault('HKLM\Software\OpenVPN', App, View);
    RegSet('HKLM\Software\OpenVPN', 'exe_path',         Bin + '\openvpn.exe',     View);
    RegSet('HKLM\Software\OpenVPN', 'config_dir',       Cfg,                      View);
    RegSet('HKLM\Software\OpenVPN', 'config_ext',       'ovpn',                   View);
    RegSet('HKLM\Software\OpenVPN', 'log_dir',          Lg,                       View);
    RegSet('HKLM\Software\OpenVPN', 'log_append',       '0',                      View);
    RegSet('HKLM\Software\OpenVPN', 'priority',         'NORMAL_PRIORITY_CLASS',  View);
    RegSet('HKLM\Software\OpenVPN', 'ovpn_admin_group', 'OpenVPN Administrators', View);
    RegSet('HKLM\Software\OpenVPN-GUI', 'exe_path',     Bin + '\openvpn.exe',     View);
    RegSet('HKLM\Software\OpenVPN-GUI', 'config_dir',   Cfg,                      View);

    { 注册并启动交互服务。
      ★ 服务名必须是 OpenVPNServiceInteractive —— GUI 硬编码查这个名
      (service.c OPENVPN_SERVICE_NAME_OVPN2),名字对不上会提示
      “未安装 OpenVPNServiceInteractive”。
      ★ binPath 必须是合法的命令行:sc.exe 要求 binPath= 后面用引号把
      “可执行路径 + 参数”包成一个整体,且引号内不能再嵌引号。
      直接调 sc.exe(不经 cmd /C)并把参数拆成数组式传参,避免 cmd 的
      引号转义把 binPath 弄成畸形字符串、导致服务创建出来却启动失败
      (表现即“未启动 OpenVPNServiceInteractive。Wintun 无法工作”)。 }
    ServExe := Bin + '\openvpnserv.exe';
    RegisterAndStartService(ServExe);

    { 预创建 wintun 适配器(openvpn 连接前必须存在) }
    EnsureWintunAdapter(Bin + '\tapctl.exe');
  end;
end;

function InitializeUninstall(): Boolean;
var RC: Integer;
begin
  Exec('taskkill.exe', '/F /IM {#GuiExe}', '', SW_HIDE, ewWaitUntilTerminated, RC);
  Exec(ExpandConstant('{cmd}'), '/C sc stop {#SvcName}',   '', SW_HIDE, ewWaitUntilTerminated, RC);
  Exec(ExpandConstant('{cmd}'), '/C sc delete {#SvcName}', '', SW_HIDE, ewWaitUntilTerminated, RC);
  { 删除 wintun 适配器(tapctl.exe 尚未被删,在 bin 目录);忽略错误 }
  Exec(ExpandConstant('{cmd}'), '/C ""' + ExpandConstant('{app}\bin\tapctl.exe') + '" delete {#WintunAdapter}"', '', SW_HIDE, ewWaitUntilTerminated, RC);
  { 两个视图都清,忽略错误(前提:目标机器未同时安装官方 OpenVPN) }
  Exec(ExpandConstant('{cmd}'), '/C reg delete "HKLM\Software\OpenVPN" /f /reg:64',     '', SW_HIDE, ewWaitUntilTerminated, RC);
  Exec(ExpandConstant('{cmd}'), '/C reg delete "HKLM\Software\OpenVPN" /f /reg:32',     '', SW_HIDE, ewWaitUntilTerminated, RC);
  Exec(ExpandConstant('{cmd}'), '/C reg delete "HKLM\Software\OpenVPN-GUI" /f /reg:64', '', SW_HIDE, ewWaitUntilTerminated, RC);
  Exec(ExpandConstant('{cmd}'), '/C reg delete "HKLM\Software\OpenVPN-GUI" /f /reg:32', '', SW_HIDE, ewWaitUntilTerminated, RC);
  Result := True;
end;
