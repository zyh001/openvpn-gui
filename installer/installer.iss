; ============================================================================
;  荆楚理工学院 VPN 客户端  —  Inno Setup 安装脚本(双架构 32/64 合一)
;  打包:OpenVPN 运行时 + Wintun + 交互服务 + 定制 GUI + 配置
;
;  CI 传入的 /D 定义:
;    /DAppVer=1.0.0
;    /DServiceArgs="-instance interactive"
;    /DHaveX86=1            ← 仅当成功组装出 32 位 payload 时由 CI 传入
; ============================================================================

#ifndef AppVer
  #define AppVer "1.0.0"
#endif
#ifndef ServiceArgs
  #define ServiceArgs "-instance interactive"
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
      “未安装 OpenVPNServiceInteractive”。 }
    ServExe := Bin + '\openvpnserv.exe';
    RunHidden('sc create {#SvcName} binPath= "\"' + ServExe + '\" {#ServiceArgs}" start= auto DisplayName= "荆楚理工学院VPN服务"');
    RunHidden('sc start {#SvcName}');
  end;
end;

function InitializeUninstall(): Boolean;
var RC: Integer;
begin
  Exec('taskkill.exe', '/F /IM {#GuiExe}', '', SW_HIDE, ewWaitUntilTerminated, RC);
  Exec(ExpandConstant('{cmd}'), '/C sc stop {#SvcName}',   '', SW_HIDE, ewWaitUntilTerminated, RC);
  Exec(ExpandConstant('{cmd}'), '/C sc delete {#SvcName}', '', SW_HIDE, ewWaitUntilTerminated, RC);
  { 两个视图都清,忽略错误(前提:目标机器未同时安装官方 OpenVPN) }
  Exec(ExpandConstant('{cmd}'), '/C reg delete "HKLM\Software\OpenVPN" /f /reg:64',     '', SW_HIDE, ewWaitUntilTerminated, RC);
  Exec(ExpandConstant('{cmd}'), '/C reg delete "HKLM\Software\OpenVPN" /f /reg:32',     '', SW_HIDE, ewWaitUntilTerminated, RC);
  Exec(ExpandConstant('{cmd}'), '/C reg delete "HKLM\Software\OpenVPN-GUI" /f /reg:64', '', SW_HIDE, ewWaitUntilTerminated, RC);
  Exec(ExpandConstant('{cmd}'), '/C reg delete "HKLM\Software\OpenVPN-GUI" /f /reg:32', '', SW_HIDE, ewWaitUntilTerminated, RC);
  Result := True;
end;
