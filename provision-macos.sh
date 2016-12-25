#!/bin/bash
set -eux

config_fqdn=$(hostname)
config_ers_fqdn=$(hostname | sed -E 's,^[a-z]+\.,,')

# rename the hard disk.
diskutil rename disk0s2 macOS

# install homebrew.
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" </dev/null
brew analytics off

# configure vim.
cat >~/.vimrc <<'EOF'
syntax on
set background=dark
set esckeys
set ruler
set laststatus=2
set nobackup
EOF

# configure the shell.
cat >~/.bash_profile <<'EOF'
# If not running interactively, don't do anything
[[ "$-" != *i* ]] && return

export LANG=en_US.UTF-8
export EDITOR=vim
export PAGER=less

alias l='ls -lFG'
alias ll='l -a'
alias h='history 25'
alias j='jobs -l'
EOF
cat >~/.inputrc <<'EOF'
"\e[A": history-search-backward
"\e[B": history-search-forward
"\eOD": backward-word
"\eOC": forward-word
set show-all-if-ambiguous on
set completion-ignore-case on
EOF

# configure the Dock.
brew install dockutil
dockutil --list \
    | awk -F\t '{print $1}' \
    | grep -v -E 'Store|Safari|System|Downloads' \
    | xargs -L1 dockutil --remove
dockutil --position 1 --add /Applications/Utilities/Terminal.app

# configure the mouse scroll direction to non-Natural.
defaults write ~/Library/Preferences/.GlobalPreferences com.apple.swipescrolldirection -bool NO

# configure git.
# see http://stackoverflow.com/a/12492094/477532
git config --global user.name 'Rui Lopes'
git config --global user.email 'rgl@ruilopes.com'
git config --global push.default simple
git config --global core.autocrlf false
#git config --list --show-origin

# install Visual Studio Code.
brew cask install visual-studio-code

# install the ers certificate.
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /vagrant/tmp/$config_ers_fqdn-crt.pem

# install dependencies.
brew install python3
pip3 install requests
brew install node

# publish an application.
export ERS_USERNAME=vagrant
export ERS_PASSWORD=vagrant
releases=(
    'v1.0.0 hello world'
    'v1.1.0 show ip address'
    'v1.2.0 show ip location'
)
git clone https://github.com/rgl/hello-world-electron.git hello-world-electron
pushd hello-world-electron
for release in "${releases[@]}"; do
    tag=$(echo -n "$release" | sed -E 's,([^ ]+) (.+),\1,')
    notes=$(echo -n "$release" | sed -E 's,([^ ]+) (.+),\2,')
    git checkout -q $tag
    make dist
    app_version=$(perl -ne '/"version": "(.+)"/ && print $1' package.json)
    app_path=dist/mac/hello-world_${app_version}_amd64.dmg
    mv "dist/mac/hello-world-$app_version.dmg" $app_path
    python3 /vagrant/publish.py stable $app_version osx_64 $app_path --notes "$notes"
done
popd
