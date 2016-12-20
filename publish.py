
# see https://github.com/ArekSredzki/electron-release-server/blob/master/docs/urls.md
# see https://github.com/ArekSredzki/electron-release-server/blob/master/docs/api.md
# see https://github.com/ArekSredzki/electron-release-server/issues/79#issuecomment-263068900

import argparse
import textwrap
import requests
import os

def login(base_url, ca_file, username, password):
    response = requests.get(
        base_url+"/api/auth/login",
        verify=ca_file,
        params={
            "username": username,
            "password": password})
    response.raise_for_status()
    return response.json()["token"]

def create_version_if_needed(base_url, ca_file, token, channel, version, notes=""):
    response = requests.get(
        base_url+"/api/version/%s"%version,
        verify=ca_file,
        headers={
            "Authorization": "Bearer %s" % token
        })
    if response.status_code == 200:
        return
    response = requests.post(
        base_url+"/api/version",
        verify=ca_file,
        headers={
            "Authorization": "Bearer %s" % token
        },
        json={
            "name": version,
            "notes": notes,
            "channel": {
                "name": channel
            }})
    response.raise_for_status()

def create_asset(base_url, ca_file, token, version, platform, path):
    response = requests.post(
        base_url+"/api/asset",
        verify=ca_file,
        headers={
            "Authorization": "Bearer %s" % token
        },
        data={
            "version": version,
            "platform": platform,
        },
        files={
            "file": open(path, "rb")})
    response.raise_for_status()

parser = argparse.ArgumentParser(
    formatter_class=argparse.RawDescriptionHelpFormatter,
    description="Publishes an asset to the electron-release-server.",
    epilog=textwrap.dedent('''
        example:
          export ERS_USERNAME=vagrant
          export ERS_PASSWORD=vagrant
          %(prog)s stable 1.0.0 windows_64 hello-world-electron/dist/*1.0.0.exe
        '''))
parser.add_argument("channel", choices=["stable", "rc", "beta", "alpha"])
parser.add_argument("version")
parser.add_argument("platform", choices=["windows_64", "windows_32", "osx_64", "linux_64", "linux_32"])
parser.add_argument("path")
parser.add_argument("--notes")
parser.add_argument("--base-url", default="https://ers.example.com")
parser.add_argument("--username", default=os.environ.get("ERS_USERNAME"))
parser.add_argument("--password", default=os.environ.get("ERS_PASSWORD"))
parser.add_argument("--ca-file", default="/vagrant/tmp/ers.example.com-crt.pem")
args = parser.parse_args()

token = login(args.base_url, args.ca_file, args.username, args.password)
create_version_if_needed(args.base_url, args.ca_file, token, args.channel, args.version, notes=args.notes)
create_asset(args.base_url, args.ca_file, token, args.version, args.platform, args.path)
