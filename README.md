# reSnap

reMarkable screenshots over ssh.

[![rm1](https://img.shields.io/badge/rM1-supported-green)](https://remarkable.com/store/remarkable)
[![rm2](https://img.shields.io/badge/rM2-supported-green)](https://remarkable.com/store/remarkable-2)

![a demo of reSnap](misc/demo.gif)

## Prequisites

- SSH-access to your reMarkable tablet.
  [Tutorial](https://remarkablewiki.com/tech/ssh) <br>
  (recommended: SSH-key so you don't have to type in your root password every time)

- The following programs are required on your reMarkable:
  - `lz4`
  - `head` (only reMarkable 2.0)

- The following programs are required on your computer:
  - `lz4`
  - `ffmpeg`
  - `feh`

### Installing Programs on your reMarkable

Please use [toltec](https://github.com/toltec-dev/toltec) to install `lz4` and `head` on your reMarkable.

Packages:
- `lz4`
- `coreutils-head`

Note: before installing the packages, run
```
opkg update
opkg upgrade
```
once and the install the packages via
```
opkg install <pkg>
```

## Usage

1. Connect your reMarkable via USB
1. Run
```
./reSnap.sh
```

### Options

- `-s --source` You can specify a custom IP. If you want to use reSnap over the Wifi, specify the IP of your reMarkable here.
- `-o --output` You can specify a custom output file for reSnap.
- `-l --landscape` Snapshot has now the landscape orientation.
- `-v --version` Displays version.
- `-h --help` Displays help information.

### Disclaimer

The majority of the code is copied from [reStream](https://github.com/rien/reStream). Be sure to check them out!
