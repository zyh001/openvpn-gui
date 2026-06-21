; ============================================================================
;  荆楚理工学院 VPN 客户端  —  Inno Setup 安装脚本
;  打包:OpenVPN 运行时 + Wintun 驱动 + 交互服务 + 定制版 GUI + 配置
;  目标:用户双击安装 -> 桌面图标 -> 打开 GUI 即可连接(只需输入统一身份账号密码)
;
;  本脚本由 .github/workflows/build-installer.yml 自动调用,可接收以下 /D 定义:
;    /DAppVer=1.0.0                          版本号(取自 git tag)
;    /DServiceArgs="-instance interactive ovpn"   交互服务参数(CI 自动探测)
;  本地手动编译时不传也行,会用下面的默认值。
; ============================================================================

#ifndef AppVer
  #define AppVer "1.0.0"
#endif
; 交互服务启动参数(CI 会自动探测并覆盖;这是兜底默认值)
#ifndef ServiceArgs
  #define ServiceArgs "-instance interactive ovpn"
#endif
; 检测是否提供了图标,没有就不引用,避免编译报错
#if FileExists("app.ico")
  #define HaveIcon
#endif

#define MyAppName       "荆楚理工学院VPN"
#define MyAppPublisher  "湖北摇光科技有限公司"
#define MyAppURL        "https://www.jcut.edu.cn"
#define GuiExe          "openvpn-gui.exe"
; ↓ 配置文件名 —— 这个名字就是 GUI 托盘菜单里显示的连接名
#define OvpnConfig      "JCUT-教育网.ovpn"
#define PayloadDir      "payload"
; 我们自己的交互服务名(故意区别于官方 OpenVPNServiceInteractive,卸载时只删自己的)
#define SvcName         "JCUTVPNService"

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
ArchitecturesAllowed=x64compatible
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
; OpenVPN 运行时 + Wintun 驱动 + 交互服务 + 定制 GUI(全部已在 payload\bin 里)
Source: "{#PayloadDir}\bin\*"; DestDir: "{app}\bin"; Flags: recursesubdirs ignoreversion
; 配置文件
Source: "{#PayloadDir}\config\{#OvpnConfig}"; DestDir: "{app}\config"; Flags: ignoreversion
#ifdef HaveIcon
Source: "app.ico"; DestDir: "{app}"; Flags: ignoreversion
#endif

[Registry]
; OpenVPN GUI 通过这些键找到 openvpn.exe / 配置目录 / 日志目录
Root: HKLM; Subkey: "Software\OpenVPN"; ValueType: string; ValueName: "exe_path";          ValueData: "{app}\bin\openvpn.exe"; Flags: uninsdeletevalue
Root: HKLM; Subkey: "Software\OpenVPN"; ValueType: string; ValueName: "config_dir";        ValueData: "{app}\config";          Flags: uninsdeletevalue
Root: HKLM; Subkey: "Software\OpenVPN"; ValueType: string; ValueName: "log_dir";           ValueData: "{app}\log";             Flags: uninsdeletevalue
Root: HKLM; Subkey: "Software\OpenVPN"; ValueType: string; ValueName: "priority";          ValueData: "NORMAL_PRIORITY_CLASS"; Flags: uninsdeletevalue
Root: HKLM; Subkey: "Software\OpenVPN"; ValueType: string; ValueName: "ovpn_admin_group";  ValueData: "OpenVPN Administrators"; Flags: uninsdeletevalue
Root: HKLM; Subkey: "Software\OpenVPN-GUI"; ValueType: string; ValueName: "config_dir"; ValueData: "{app}\config";          Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\OpenVPN-GUI"; ValueType: string; ValueName: "exe_path";   ValueData: "{app}\bin\openvpn.exe"; Flags: uninsdeletekey

[Icons]
#ifdef HaveIcon
Name: "{group}\{#MyAppName}";       Filename: "{app}\bin\{#GuiExe}"; IconFilename: "{app}\app.ico"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\bin\{#GuiExe}"; IconFilename: "{app}\app.ico"; Tasks: desktopicon
#else
Name: "{group}\{#MyAppName}";       Filename: "{app}\bin\{#GuiExe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\bin\{#GuiExe}"; Tasks: desktopicon
#endif
Name: "{group}\卸载 {#MyAppName}";   Filename: "{uninstallexe}"
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\bin\{#GuiExe}"; Tasks: autostart

[Run]
; 安装完成后直接拉起 GUI(静默安装时跳过)
Filename: "{app}\bin\{#GuiExe}"; Description: "立即启动 {#MyAppName}"; Flags: nowait postinstall skipifsilent

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
  KillGui;          { 关闭可能在运行的旧 GUI }
  Result := True;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var ExePath: String;
begin
  if CurStep = ssPostInstall then
  begin
    ExePath := ExpandConstant('{app}\bin\openvpnserv.exe');
    { 注册并启动交互服务。ServiceArgs 由 CI 自动探测,本地编译用默认值。 }
    RunHidden('sc create {#SvcName} binPath= "\"' + ExePath +
              '\" {#ServiceArgs}" start= auto DisplayName= "荆楚理工学院VPN服务"');
    RunHidden('sc start {#SvcName}');
  end;
end;

function InitializeUninstall(): Boolean;
var RC: Integer;
begin
  Exec('taskkill.exe', '/F /IM {#GuiExe}', '', SW_HIDE, ewWaitUntilTerminated, RC);
  Exec(ExpandConstant('{cmd}'), '/C sc stop {#SvcName}',   '', SW_HIDE, ewWaitUntilTerminated, RC);
  Exec(ExpandConstant('{cmd}'), '/C sc delete {#SvcName}', '', SW_HIDE, ewWaitUntilTerminated, RC);
  Result := True;
end;
