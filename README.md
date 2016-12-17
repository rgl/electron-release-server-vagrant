This is a Vagrant Environment for a [Electron Release Server (ERS)](https://github.com/ArekSredzki/electron-release-server) service.

This will install ERS on the `ers` machine.

This will build (and publish to `ers`) an example [hello-world electron application](https://github.com/rgl/hello-world-electron) on these different machines:

* `ubuntu`
* `windows`

# Usage

Build and install the [Ubuntu Base Box](https://github.com/rgl/ubuntu-vagrant).

Build and install the Windows Base Box with:

```bash
git clone https://github.com/joefitzgerald/packer-windows
cd packer-windows
# this will take ages to build, so leave it running over night...
packer build windows_2012_r2.json
vagrant box add windows_2012_r2 windows_2012_r2_virtualbox.box
rm *.box
cd ..
```

Add the following entry to your `/etc/hosts` file:

```
10.10.10.100 ers.example.com
```

Run `vagrant up ers` to launch the server.

Run `vagrant up ubuntu` to launch the Ubuntu client.

Run `vagrant up windows` to launch the Windows client.

To run the example application, login at each client, and install from http://ers.example.com.
