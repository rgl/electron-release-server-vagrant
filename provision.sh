#!/bin/bash
# here be dragons... see http://fvue.nl/wiki/Bash:_Error_handling
set -eux

config_fqdn=$(hostname --fqdn)

echo "127.0.0.1 $config_fqdn" >>/etc/hosts

echo 'Defaults env_keep += "DEBIAN_FRONTEND"' >/etc/sudoers.d/env_keep_apt
chmod 440 /etc/sudoers.d/env_keep_apt
export DEBIAN_FRONTEND=noninteractive

# update the package cache.
apt-get -y update

# vim.
apt-get install -y --no-install-recommends vim
cat >/etc/vim/vimrc.local <<'EOF'
syntax on
set background=dark
set esckeys
set ruler
set laststatus=2
set nobackup
autocmd BufNewFile,BufRead Vagrantfile set ft=ruby
EOF

# install postgres.
apt-get install -y --no-install-recommends postgresql

# create user and database.
postgres_ers_password=$(openssl rand -hex 32)
sudo -sHu postgres psql -c "create role ers login password '$postgres_ers_password'"
sudo -sHu postgres createdb -E UTF8 -O ers ers
sudo -sHu postgres createdb -E UTF8 -O ers ers_sessions

# install git.
apt-get install -y --no-install-recommends git
git config --global user.name 'Rui Lopes'
git config --global user.email 'rgl@ruilopes.com'
git config --global push.default simple
git config --global core.autocrlf false

# create a self-signed certificate.
pushd /etc/ssl/private
openssl genrsa \
    -out $config_fqdn-keypair.pem \
    2048 \
    2>/dev/null
chmod 400 $config_fqdn-keypair.pem
openssl req -new \
    -sha256 \
    -subj "/CN=$config_fqdn" \
    -key $config_fqdn-keypair.pem \
    -out $config_fqdn-csr.pem
openssl x509 -req -sha256 \
    -signkey $config_fqdn-keypair.pem \
    -extensions a \
    -extfile <(echo "[a]
        subjectAltName=DNS:$config_fqdn
        extendedKeyUsage=serverAuth
        ") \
    -days 365 \
    -in  $config_fqdn-csr.pem \
    -out $config_fqdn-crt.pem
popd
# share it with the other nodes.
mkdir -p /vagrant/tmp
pushd /vagrant/tmp
cp /etc/ssl/private/$config_fqdn-crt.pem .
openssl x509 -outform der -in $config_fqdn-crt.pem -out $config_fqdn-crt.der
popd

# install and configure nginx to proxy requests to ers.
apt-get install -y --no-install-recommends nginx
rm -f /etc/nginx/sites-enabled/default
cat >/etc/nginx/sites-available/$config_fqdn.conf <<EOF
ssl_session_cache shared:SSL:4m;
ssl_session_timeout 6h;
#ssl_stapling on;
#ssl_stapling_verify on;

server {
  listen 80;
  server_name _;
  return 301 https://$config_fqdn\$request_uri;
}

server {
  listen 443 ssl http2;
  server_name $config_fqdn;
  access_log /var/log/nginx/$config_fqdn.access.log;

  ssl_certificate /etc/ssl/private/$config_fqdn-crt.pem;
  ssl_certificate_key /etc/ssl/private/$config_fqdn-keypair.pem;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  # see https://github.com/cloudflare/sslconfig/blob/master/conf
  # see https://blog.cloudflare.com/it-takes-two-to-chacha-poly/
  # see https://blog.cloudflare.com/do-the-chacha-better-mobile-performance-with-cryptography/
  # NB even though we have CHACHA20 here, the OpenSSL library that ships with Ubuntu 16.04 does not have it. so this is a nop. no problema.
  ssl_ciphers EECDH+CHACHA20:EECDH+AES128:RSA+AES128:EECDH+AES256:RSA+AES256:EECDH+3DES:RSA+3DES:!aNULL:!MD5;

  tcp_nodelay on;
  client_max_body_size 1G;
  proxy_send_timeout 120;
  proxy_read_timeout 300;
  proxy_buffering off;
  proxy_http_version 1.1;
  proxy_set_header Host \$http_host;
  proxy_set_header X-Real-IP \$remote_addr;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-NginX-Proxy true;
  proxy_set_header Upgrade \$http_upgrade;
  proxy_set_header Connection "upgrade";

  location / {
    root /opt/ers/assets;
    try_files \$uri @server;
  }

  location @server {
    proxy_pass http://127.0.0.1:5014;
  }
}
EOF
ln -s ../sites-available/$config_fqdn.conf /etc/nginx/sites-enabled/
systemctl restart nginx

# add the ers user.
groupadd --system ers
adduser \
    --system \
    --disabled-login \
    --no-create-home \
    --gecos '' \
    --ingroup ers \
    --home /opt/ers \
    ers
install -d -o ers -g ers -m 755 /opt/ers

# install node LTS.
# see https://github.com/nodesource/distributions#debinstall
wget -qO- https://deb.nodesource.com/setup_6.x | bash
apt-get install -y nodejs
node --version
npm --version

# download and install ers.
# see https://github.com/ArekSredzki/electron-release-server/blob/master/docs/deploy.md
sudo -sHu ers <<EOF
set -eux
cd /opt/ers
ers_tarball=v1.4.3.tar.gz
ers_download_url=https://github.com/ArekSredzki/electron-release-server/archive/\$ers_tarball
ers_download_sha1=2d0eab4a3df866a6e6b0ed314041badd49c65a29
wget -q \$ers_download_url
if [ "\$(sha1sum \$ers_tarball | awk '{print \$1}')" != "\$ers_download_sha1" ]; then
    echo "downloaded \$ers_download_url failed the checksum verification"
    exit 1
fi
tar xf \$ers_tarball --strip-components 1
rm \$ers_tarball
export NODE_ENV=production
npm install
./node_modules/.bin/bower install
npm cache clean
chmod 700 config
# see http://sailsjs.com/documentation/concepts/configuration/the-local-js-file
# see config/docker.js
# see config/env/production.js
# see config/connections.js
# see config/models.js
cat >config/local.js <<EOC
module.exports = {
    appUrl: 'https://$config_fqdn',
    host: '127.0.0.1',
    port: 5014,
    auth: {
        static: {
            username: 'vagrant',
            password: 'vagrant'
        },
    },
    jwt: {
        token_secret: '\$(openssl rand -hex 32)',
    },
    models: {
        migrate: 'alter', // NB this will be changed to 'safe' after initialization.
    },
    connections: {
        postgresql: {
            adapter: 'sails-postgresql',
            host: '/var/run/postgresql/',
            user: 'ers',
            database: 'ers',
        }
    },
    session: {
        adapter: 'sails-pg-session',
        secret: '\$(openssl rand -hex 32)',
        host: '/var/run/postgresql/',
        user: 'ers',
        database: 'ers_sessions',
    },
    files: {
        dirname: '/opt/ers/assets-files',
    }
};
EOC
EOF

# create and enable the ers systemd service unit.
cat >/etc/systemd/system/ers.service <<'EOF'
[Unit]
Description=ers
After=network.target

[Service]
Type=simple
User=ers
Group=ers
#Environment=NODE_ENV=production # NB this will be uncommented after initialization.
ExecStart=/usr/bin/npm start
WorkingDirectory=/opt/ers
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl enable ers

# initialize the sessions database.
sudo -sHu ers psql -d ers_sessions </opt/ers/node_modules/sails-pg-session/sql/sails-pg-session-support.sql

# initialize the main database.
# see http://sailsjs.com/documentation/concepts/deployment
function wait_for_ready {
    bash -c 'while [[ "$(wget -qO- http://localhost:5014/api/version)" != "[]" ]]; do sleep 5; done'
}
systemctl start ers
wait_for_ready
systemctl stop ers
sudo -sHu postgres psql -d ers -c '\d' # dump tables
sed -i -E "s/^(\s+migrate:).*alter.*/\1 'safe',/" /opt/ers/config/local.js
sed -i -E 's/^#(Environment=NODE_ENV=).+/\1production/' /etc/systemd/system/ers.service
systemctl daemon-reload
systemctl start ers
wait_for_ready
systemctl status ers

# clean packages.
apt-get -y autoremove
apt-get -y clean
