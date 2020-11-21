# reSnap

![a demo of reSnap](misc/demo.gif)

## Prequisites

- SSH-access to your reMarkable tablet. (recommended: SSH-key so you don't have to type in your root password every time)

- lz4 on your reMarkable
  ```
  scp lz4.arm.static root@10.11.99.1:~/lz4
  ssh root@10.11.99.1 'chmod +x /home/root/lz4'
  ```

- The following apt-packages are required:
  - ffmpeg
  - lz4
  - feh

## Usage

1. Connect your reMarkable via USB
1. Run ./reSnap.sh

### Options

- `-s --source` You can specify a custom ssh-host. If you want to use reSnap over the Wifi, specify the IP of your reMarkable here.
- `-o --output` You can specify a custom output file for reSnap.
- `-l --landscape` Snapshot has now the landscape orientation.

### Disclaimer

The mojarity of the code is copied from [reStream](https://github.com/rien/reStream). Be sure to check them out!