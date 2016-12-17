This is a Vagrant Environment for a [Electron Release Server (ERS)](https://github.com/ArekSredzki/electron-release-server) service.

This will install ERS on the `ers` machine.

This will build (and publish to `ers`) an example [hello-world electron application](https://github.com/rgl/hello-world-electron) on these different machines:

* `ubuntu`

# Usage

Build and install the [Ubuntu Base Box](https://github.com/rgl/ubuntu-vagrant).

Add the following entry to your `/etc/hosts` file:

```
10.10.10.100 ers.example.com
```

Run `vagrant up ers` to launch the server.

Run `vagrant up ubuntu` to launch the Ubuntu client.

To run the example application, login at each client, and install from http://ers.example.com.
