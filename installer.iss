[Setup]
AppId={{D2D2E4A5-7C8F-4D3A-9A2D-1234567890AB}
AppName=tuna_unofficial_client
AppVersion=1.4.0
DefaultDirName={autopf}\tuna_unofficial_client
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
OutputDir=output
OutputBaseFilename=tuna_unofficial_client_installer
SetupIconFile=assets\icon\Tuna_install.ico
Compression=lzma
SolidCompression=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
Source: "assets\icon\Tuna_icon.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\tuna_unofficial_client"; Filename: "{app}\tuna_unofficial_client.exe"; IconFilename: "{app}\Tuna_icon.ico"
Name: "{commondesktop}\tuna_unofficial_client"; Filename: "{app}\tuna_unofficial_client.exe"; IconFilename: "{app}\Tuna_icon.ico"
