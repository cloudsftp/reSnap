#!/bin/sh

version="1.4"

# create temporary directory
tmp_dir="/tmp/reSnap"
if [ ! -d "$tmp_dir" ]; then
  mkdir "$tmp_dir"
fi

# default values
ip="10.11.99.1"
output_file="$tmp_dir/snapshot_$(date +%F_%H-%M-%S).png"
filters="null"

# parsing arguments
while [ $# -gt 0 ]; do
  case "$1" in
  -l | --landscape)
    filters="$filters,transpose=1"
    shift
    ;;
  -s | --source)
    ip="$2"
    shift
    shift
    ;;
  -o | --output)
    output_file="$2"
    shift
    shift
    ;;
  -v | --version)
    echo "$0 version $version"
    exit 0
    ;;
  -h | --help | *)
    echo "Usage: $0 [-l] [-v] [--source <ssh-host>] [--output <output-file>] [-h]"
    echo "Examples:"
    echo "  $0                    # snapshot in portrait"
    echo "  $0 -l                 # snapshot in landscape"
    echo "  $0 -s 192.168.2.104   # snapshot over wifi"
    echo "  $0 -o snapshot.png    # saves the snapshot in the current directory"
    echo "  $0 -v                 # displays version"
    echo "  $0 -h                 # displays help information (this)"
    exit 2
    ;;
  esac
done

# technical parameters
width=1408
height=1872
bytes_per_pixel=2

# ssh command
ssh_host="root@$ip"
ssh_cmd() {
  ssh -o ConnectTimeout=1 "$ssh_host" "$@"
}

# check if we are able to reach the remarkable
if ! ssh_cmd true; then
  echo "$ssh_host unreachable"
  exit 1
fi

# compression commands
compress="\$HOME/lz4"
decompress="lz4 -d"

# calculate how much bytes the window is
window_bytes="$((width * height * bytes_per_pixel))"

# read the first $window_bytes of the framebuffer
head_fb0="dd if=/dev/fb0 count=1 bs=$window_bytes 2>/dev/null"

read_command="$head_fb0 | $compress"

# execute read_command on the reMarkable and encode received data
ssh_cmd "$read_command" |
  $decompress |
  ffmpeg -y \
    -f rawvideo \
    -pixel_format rgb565le \
    -video_size "$width,$height" \
    -i - \
    -vf "$filters" \
    -frames:v 1 "$output_file"

# show the snapshot
feh --fullscreen "$output_file"
