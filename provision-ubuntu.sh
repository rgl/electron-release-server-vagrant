#!/bin/bash
set -eux

config_fqdn=$(hostname --fqdn)
config_ers_fqdn=$(hostname --domain)

echo 'Defaults env_keep += "DEBIAN_FRONTEND"' >/etc/sudoers.d/env_keep_apt
chmod 440 /etc/sudoers.d/env_keep_apt
export DEBIAN_FRONTEND=noninteractive

# install the xfce desktop.
apt-get update
apt-get install -y xfce4 lightdm lightdm-gtk-greeter
apt-get install -y xfce4-terminal
apt-get install -y xfce4-whiskermenu-plugin
apt-get install -y xfce4-taskmanager
apt-get install -y menulibre
apt-get install -y firefox
apt-get install -y --no-install-recommends git meld
apt-get install -y --no-install-recommends httpie
apt-get install -y --no-install-recommends jq
apt-get install -y --no-install-recommends vim

# install Visual Studio Code.
wget -qO/tmp/vscode_amd64.deb 'https://go.microsoft.com/fwlink/?LinkID=760868'
dpkg -i /tmp/vscode_amd64.deb || apt-get install -y -f
apt-get install -y libgconf2-4
rm /tmp/vscode_amd64.deb

# set system configuration.
cp -v -r /vagrant/config-ubuntu/etc/* /etc

sudo -sHu vagrant <<'VAGRANT_EOF'
#!/bin/bash
# abort this script on errors.
set -eux

# set user configuration.
mkdir -p .config
cp -r /vagrant/config-ubuntu/dotconfig/* .config
find .config -type d -exec chmod 700 {} \;
find .config -type f -exec chmod 600 {} \;

# configure git.
# see http://stackoverflow.com/a/12492094/477532
git config --global user.name 'Rui Lopes'
git config --global user.email 'rgl@ruilopes.com'
git config --global push.default simple
git config --global core.autocrlf false
git config --global diff.guitool meld
git config --global difftool.meld.path meld
git config --global difftool.meld.cmd 'meld "$LOCAL" "$REMOTE"'
git config --global merge.tool meld
git config --global mergetool.meld.path meld
git config --global mergetool.meld.cmd 'meld --diff "$LOCAL" "$BASE" "$REMOTE" --output "$MERGED"'
#git config --list --show-origin
VAGRANT_EOF

apt-get remove -y --purge xscreensaver
apt-get autoremove -y --purge

# install node LTS.
# see https://github.com/nodesource/distributions#debinstall
wget -qO- https://deb.nodesource.com/setup_6.x | bash
apt-get install -y nodejs

# install the ers certificate.
cp /vagrant/tmp/$config_ers_fqdn-crt.pem /usr/local/share/ca-certificates/$config_ers_fqdn.crt
update-ca-certificates

# publish an application.
sudo -sHu vagrant <<'VAGRANT_EOF'
set -eux
tags=(v1.0.0 v1.1.0)
for tag in "${tags[@]}"; do
    git clone -b $tag https://github.com/rgl/hello-world-electron.git hello-world-electron-$tag
    pushd hello-world-electron-$tag
    make dist
    app_version=$(perl -ne '/"version": "(.+)"/ && print $1' package.json)
    app_path=dist/hello-world_${app_version}_amd64.AppImage
    mv "dist/hello-world-$app_version-x86_64.AppImage" $app_path
    python /vagrant/publish.py vagrant vagrant stable $app_version linux_64 $app_path
    popd
done
VAGRANT_EOF
