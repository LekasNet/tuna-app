[Setup]
AppName=Tuna Desktop
AppVersion=1.0.0
DefaultDirName={commonpf}\TunaDesktop
OutputDir=output
OutputBaseFilename=TunaDesktopInstaller
SetupIconFile=assets\icon\Tuna_install.ico
Compression=lzma
SolidCompression=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs
Source: "assets\icon\Tuna_icon.ico"; DestDir: "{app}"


[Icons]
Name: "{group}\Tuna Desktop"; Filename: "{app}\Tuna.exe"; IconFilename: "{app}\Tuna_icon.ico"
Name: "{commondesktop}\Tuna Desktop"; Filename: "{app}\Tuna.exe"; IconFilename: "{app}\Tuna_icon.ico"
