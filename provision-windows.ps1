param(
    [Parameter(Mandatory=$true)]
    [string]$config_ers_fqdn = 'ers.example.com',

    [Parameter(Mandatory=$true)]
    [string]$config_fqdn = 'windows.ers.example.com'
)

Set-StrictMode -Version Latest

$ErrorActionPreference = 'Stop'

trap {
    Write-Output "`nERROR: $_`n$($_.ScriptStackTrace)"
    Exit 1
}

# wrap the choco command (to make sure this script aborts when it fails).
function Start-Choco([string[]]$Arguments, [int[]]$SuccessExitCodes=@(0)) {
    &C:\ProgramData\chocolatey\bin\choco.exe @Arguments `
        | Where-Object { $_ -NotMatch '^Progress: ' }
    if ($SuccessExitCodes -NotContains $LASTEXITCODE) {
        throw "$(@('choco')+$Arguments | ConvertTo-Json -Compress) failed with exit code $LASTEXITCODE"
    }
}
function choco {
    Start-Choco $Args
}

# set keyboard layout.
# NB you can get the name from the list:
#      [Globalization.CultureInfo]::GetCultures('InstalledWin32Cultures') | Out-GridView
Set-WinUserLanguageList pt-PT -Force

# set the date format, number format, etc.
Set-Culture pt-PT

# set the timezone.
# tzutil /l lists all available timezone ids
& $env:windir\system32\tzutil /s "GMT Standard Time"

# show window content while dragging.
Set-ItemProperty -Path 'HKCU:Control Panel\Desktop' -Name DragFullWindows -Value 1

# show hidden files.
Set-ItemProperty -Path HKCU:Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name Hidden -Value 1

# show protected operating system files.
Set-ItemProperty -Path HKCU:Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name ShowSuperHidden -Value 1

# show file extensions.
Set-ItemProperty -Path HKCU:Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name HideFileExt -Value 0

# never combine the taskbar buttons.
#
# possibe values:
#   0: always combine and hide labels (default)
#   1: combine when taskbar is full
#   2: never combine
Set-ItemProperty -Path HKCU:Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name TaskbarGlomLevel -Value 2

# display full path in the title bar.
New-Item -Path HKCU:Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState -Force `
    | New-ItemProperty -Name FullPath -Value 1 -PropertyType DWORD `
    | Out-Null

# install classic shell.
New-Item -Path HKCU:Software\IvoSoft\ClassicStartMenu -Force `
    | New-ItemProperty -Name ShowedStyle2      -Value 1 -PropertyType DWORD `
    | Out-Null
New-Item -Path HKCU:Software\IvoSoft\ClassicStartMenu\Settings -Force `
    | New-ItemProperty -Name EnableStartButton -Value 1 -PropertyType DWORD `
    | New-ItemProperty -Name SkipMetro         -Value 1 -PropertyType DWORD `
    | Out-Null
choco install -y classic-shell --allow-empty-checksums -installArgs ADDLOCAL=ClassicStartMenu

# install Google Chrome and some useful extensions.
# see https://developer.chrome.com/extensions/external_extensions
choco install -y googlechrome
@(
    # JSON Formatter (https://chrome.google.com/webstore/detail/json-formatter/bcjindcccaagfpapjjmafapmmgkkhgoa).
    'bcjindcccaagfpapjjmafapmmgkkhgoa'
    # uBlock Origin (https://chrome.google.com/webstore/detail/ublock-origin/cjpalhdlnbpafiamejdnhcphjbkeiagm).
    'cjpalhdlnbpafiamejdnhcphjbkeiagm'
) | ForEach-Object {
    New-Item -Force -Path "HKLM:Software\Wow6432Node\Google\Chrome\Extensions\$_" `
        | Set-ItemProperty -Name update_url -Value 'https://clients2.google.com/service/update2/crx'
}

# install applications.
choco install -y notepad2
choco install -y git --params '/GitOnlyOnPath /NoAutoCrlf'
choco install -y gitextensions
choco install -y meld
choco install -y fiddler4
choco install -y 7zip
choco install -y visualstudiocode

# update $env:PATH with the recently installed Chocolatey packages.
Import-Module C:\ProgramData\chocolatey\helpers\chocolateyInstaller.psm1
Update-SessionEnvironment

# configure git.
# see http://stackoverflow.com/a/12492094/477532
git config --global user.name 'Rui Lopes'
git config --global user.email 'rgl@ruilopes.com'
git config --global push.default simple
git config --global core.autocrlf false
git config --global diff.guitool meld
git config --global difftool.meld.path 'C:/Program Files (x86)/Meld/Meld.exe'
git config --global difftool.meld.cmd '\"C:/Program Files (x86)/Meld/Meld.exe\" \"$LOCAL\" \"$REMOTE\"'
git config --global merge.tool meld
git config --global mergetool.meld.path 'C:/Program Files (x86)/Meld/Meld.exe'
git config --global mergetool.meld.cmd '\"C:/Program Files (x86)/Meld/Meld.exe\" --diff \"$LOCAL\" \"$BASE\" \"$REMOTE\" --output \"$MERGED\"'
#git config --list --show-origin

# install msys2.
# NB we have to manually build the msys2 package from source because the
#    current chocolatey package is somewhat brittle to install.
Push-Location $env:TEMP
$p = Start-Process git clone,https://github.com/rgl/choco-packages -PassThru -Wait
if ($p.ExitCode) {
    throw "git failed with exit code $($p.ExitCode)"
}
cd choco-packages/msys2
choco pack
choco install -y msys2 -Source $PWD
Pop-Location

# configure the msys2 launcher to let the shell inherith the PATH.
$msys2BasePath = 'C:\tools\msys64'
$msys2ConfigPath = "$msys2BasePath\msys2.ini"
[IO.File]::WriteAllText(
    $msys2ConfigPath,
    ([IO.File]::ReadAllText($msys2ConfigPath) `
        -replace '#?(MSYS2_PATH_TYPE=).+','$1inherit')
)

# define a function for easying the execution of bash scripts.
$bashPath = "$msys2BasePath\usr\bin\bash.exe"
function Bash($script) {
    $eap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        # we also redirect the stderr to stdout because PowerShell
        # oddly interleaves them.
        # see https://www.gnu.org/software/bash/manual/bash.html#The-Set-Builtin
        echo "exec 2>&1;set -eu;export PATH=`"/usr/bin:`$PATH`";$script" | &$bashPath
        if ($LASTEXITCODE) {
            throw "bash execution failed with exit code $LASTEXITCODE"
        }
    } finally {
        $ErrorActionPreference = $eap
    }
}

# export HOME to point to the user Windows directory.
$env:HOME = $env:USERPROFILE

# configure the shell.
Bash @'
pacman --noconfirm -Sy vim make unzip tar dos2unix netcat perl

cat>~/.bash_history<<"EOF"
EOF

cat>~/.bashrc<<"EOF"
# If not running interactively, don't do anything
[[ "$-" != *i* ]] && return

export EDITOR=vim
export PAGER=less

alias l='ls -lF --color'
alias ll='l -a'
alias h='history 25'
alias j='jobs -l'
EOF

cat>~/.inputrc<<"EOF"
"\e[A": history-search-backward
"\e[B": history-search-forward
"\eOD": backward-word
"\eOC": forward-word
set show-all-if-ambiguous on
set completion-ignore-case on
EOF

cat>~/.vimrc<<"EOF"
syntax on
set background=dark
set esckeys
set ruler
set laststatus=2
set nobackup
EOF
'@

# install ConEmu.
choco install -y conemu
cp c:/vagrant/config-windows/ConEmu.xml $env:APPDATA\ConEmu.xml
reg import c:/vagrant/config-windows/ConEmu.reg

# remove the default desktop shortcuts.
del C:\Users\Public\Desktop\*.lnk

# add MSYS2 shortcut to the Desktop and Start Menu.
Install-ChocolateyShortcut `
  -ShortcutFilePath "$env:USERPROFILE\Desktop\MSYS2 Bash.lnk" `
  -TargetPath 'C:\Program Files\ConEmu\ConEmu64.exe' `
  -Arguments '-run {MSYS2} -icon C:\tools\msys64\msys2.ico' `
  -IconLocation C:\tools\msys64\msys2.ico `
  -WorkingDirectory '%USERPROFILE%'
Install-ChocolateyShortcut `
  -ShortcutFilePath "C:\Users\All Users\Microsoft\Windows\Start Menu\Programs\MSYS2 Bash.lnk" `
  -TargetPath 'C:\Program Files\ConEmu\ConEmu64.exe' `
  -Arguments '-run {MSYS2} -icon C:\tools\msys64\msys2.ico' `
  -IconLocation C:\tools\msys64\msys2.ico `
  -WorkingDirectory '%USERPROFILE%'

# import the ers site https certificate into the local machine trust store.
Import-Certificate `
    -FilePath C:/vagrant/tmp/$config_ers_fqdn-crt.der `
    -CertStoreLocation Cert:/LocalMachine/Root `
    | Out-Null

# install the tools needed to build and publish the example application.
choco install -y nodejs
choco install -y python

# update $env:PATH with the recently installed Chocolatey packages.
Update-SessionEnvironment

# install dependency.
pip install requests

# build and publish the hello-world app.
Bash @"
export ERS_USERNAME=vagrant
export ERS_PASSWORD=vagrant
set -eux
cd ~
tags=(v1.0.0 v1.1.0)
for tag in "`${tags[@]}"; do
    git clone -b `$tag https://github.com/rgl/hello-world-electron.git hello-world-electron-`$tag
    pushd hello-world-electron-`$tag
    make dist
    app_version=`$(perl -ne '/"version": "(.+)"/ && print `$1' package.json)
    app_path=dist/hello-world-setup_`${app_version}_amd64.exe
    mv "dist/hello-world Setup `$app_version.exe" `$app_path
    python /c/vagrant/publish.py stable `$app_version windows_64 `$app_path --ca-file /c/vagrant/tmp/$config_ers_fqdn-crt.pem
    popd
done
"@
