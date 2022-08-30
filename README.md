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

- The following programs are required on your computer:
  - `lz4`
  - `ffmpeg`
  - `feh`

### Installing Programs on your reMarkable

Please use [toltec](https://github.com/toltec-dev/toltec) to install `lz4` on your reMarkable.

Packages:
- `lz4`

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
- `-d --display` Force program to display the snapshot. (overwrites environment variable)
- `-n --no-display` Force program to not display the snapshot.
- `-v --version` Displays version.
- `-h --help` Displays help information.

## Environment Variables

- `REMARKABLE_IP` Default IP of your reMarkable.
- `RESNAP_DISPLAY` Default behavior of reSnap. See option `-d and -n`.

### Disclaimer

The majority of the code is copied from [reStream](https://github.com/rien/reStream). Be sure to check them out!
