#!/bin/sh

ssh_host="root@10.11.99.1"
output_file="snapshot.png"
filters="null"

while [ $# -gt 0 ]; do
  case "$1" in
  -l | --landscape)
    filters="$filters,transpose=1"
    shift
    ;;
  -s | --source)
    ssh_host="$2"
    shift
    shift
    ;;
  -o | --output)
    output_file="$2"
    shift
    shift
    ;;
  esac
done

# technical parameters
width=1408
height=1872
bytes_per_pixel=2

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

ssh_cmd "$read_command" |
  $decompress |
  ffmpeg -y \
    -f rawvideo \
    -pixel_format rgb565le \
    -video_size "$width,$height" \
    -i - \
    -vf "$filters" \
    -frames:v 1 "$output_file"

feh --fullscreen "$output_file"
