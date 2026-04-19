[Setup]
AppId={{D2D2E4A5-7C8F-4D3A-9A2D-1234567890AB}
AppName=Tuna Desktop
AppVersion=1.3.0
DefaultDirName={autopf}\TunaDesktop
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
OutputDir=output
OutputBaseFilename=TunaDesktopInstaller
SetupIconFile=assets\icon\Tuna_install.ico
Compression=lzma
SolidCompression=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
Source: "assets\icon\Tuna_icon.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Tuna Desktop"; Filename: "{app}\Tuna.exe"; IconFilename: "{app}\Tuna_icon.ico"
Name: "{commondesktop}\Tuna Desktop"; Filename: "{app}\Tuna.exe"; IconFilename: "{app}\Tuna_icon.ico"