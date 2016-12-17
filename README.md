This is a Vagrant Environment for a [Electron Release Server (ERS)](https://github.com/ArekSredzki/electron-release-server) service.

This will install ERS on the `ers` machine.


# Usage

Build and install the [Ubuntu Base Box](https://github.com/rgl/ubuntu-vagrant).

Add the following entry to your `/etc/hosts` file:

```
10.10.10.100 ers.example.com
```

Run `vagrant up ers` to launch the server.
