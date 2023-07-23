#!/bin/sh

version="2.4"

# create temporary directory
tmp_dir="/tmp/reSnap"
if [ ! -d "$tmp_dir" ]; then
  mkdir "$tmp_dir"
fi

# default values
ip="${REMARKABLE_IP:-10.11.99.1}"
output_file="$tmp_dir/snapshot_$(date +%F_%H-%M-%S).png"
delete_output_file="true"
display_output_file="${RESNAP_DISPLAY:-true}"
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
    delete_output_file="false"
    shift
    shift
    ;;
  -d | --display)
    display_output_file="true"
    shift
    ;;
  -n | --no-display)
    display_output_file="false"
    shift
    ;;
  -v | --version)
    echo "$0 version $version"
    exit 0
    ;;
  -h | --help | *)
    echo "Usage: $0 [-l] [-d] [-n] [-v] [--source <ssh-host>] [--output <output-file>] [-h]"
    echo "Examples:"
    echo "  $0                    # snapshot in portrait"
    echo "  $0 -l                 # snapshot in landscape"
    echo "  $0 -s 192.168.2.104   # snapshot over wifi"
    echo "  $0 -o snapshot.png    # saves the snapshot in the current directory"
    echo "  $0 -d                 # force display the file (requires feh)"
    echo "  $0 -n                 # force don't display the file"
    echo "  $0 -v                 # displays version"
    echo "  $0 -h                 # displays help information (this)"
    exit 2
    ;;
  esac
done

if [ "$delete_output_file" = "true" ] && [ "$display_output_file" = "true" ]; then
  # delete temporary file on exit
  trap 'rm -f $output_file' EXIT
fi

# ssh command
ssh_host="root@$ip"
ssh_cmd() {
  ssh -o ConnectTimeout=1 "$ssh_host" "$@"
}

# check if we are able to reach the reMarkable
if ! ssh_cmd true; then
  echo "$ssh_host unreachable"
  exit 1
fi

rm_version="$(ssh_cmd cat /sys/devices/soc0/machine)"

# technical parameters
if [ "$rm_version" = "reMarkable 1.0" ]; then

  # calculate how much bytes the window is
  width=1408
  height=1872
  bytes_per_pixel=2

  window_bytes="$((width * height * bytes_per_pixel))"

  # read the first $window_bytes of the framebuffer
  head_fb0="dd if=/dev/fb0 count=1 bs=$window_bytes 2>/dev/null"

  # pixel format
  pixel_format="rgb565le"

elif [ "$rm_version" = "reMarkable 2.0" ]; then

  # calculate how much bytes the window is
  width=1872
  height=1404
  bytes_per_pixel=1

  window_bytes="$((width * height * bytes_per_pixel))"

  # Find xochitl's process. In case of more than one pids, take the first one which contains /dev/fb0.
  for n in $(ssh_cmd pidof xochitl); do
    pid=$n
    has_fb=$(ssh_cmd "grep -C1 '/dev/fb0' /proc/$pid/maps")
    if [ "$has_fb" != "" ]; then
      break
    fi
  done

  # find framebuffer location in memory
  # it is actually the map allocated _after_ the fb0 mmap
  read_address="grep -C1 '/dev/fb0' /proc/$pid/maps | tail -n1 | sed 's/-.*$//'"
  skip_bytes_hex="$(ssh_cmd "$read_address")"
  skip_bytes="$((0x$skip_bytes_hex + 8))"

  # carve the framebuffer out of the process memory
  page_size=4096
  window_start_blocks="$((skip_bytes / page_size))"
  window_offset="$((skip_bytes % page_size))"
  window_length_blocks="$((window_bytes / page_size + 1))"

  # Using dd with bs=1 is too slow, so we first carve out the pages our desired
  # bytes are located in, and then we trim the resulting data with what we need.
  head_fb0="dd if=/proc/$pid/mem bs=$page_size skip=$window_start_blocks count=$window_length_blocks 2>/dev/null |
    tail -c+$window_offset |
    cut -b -$window_bytes"

  # pixel format
  pixel_format="gray8"

  # rotate by 90 degrees to the right
  filters="$filters,transpose=2"

else

  echo "$rm_version not supported"
  exit 2

fi

# don't remove, related to this pr
# https://github.com/cloudsftp/reSnap/pull/6
FFMPEG_ABS="$(command -v ffmpeg)"
LZ4_ABS="$(command -v lz4)"
decompress="${LZ4_ABS} -d"

# compression commands
if ssh_cmd "[ -f /opt/bin/lz4 ]"; then
  compress="/opt/bin/lz4"
elif ssh_cmd "[ -f ~/lz4 ]"; then # backwards compatibility
  compress="\$HOME/lz4"
else
  echo
  echo "WARNING:    lz4 not found on $rm_version."
  echo "            It is recommended to install it for vastly improved performance."
  echo "            But only for versions up to 2.15.1.1189 at the time of writing."
  echo "            Please refer to the README"
  echo
  compress="tee"
  decompress="tee"
fi

# read and compress the data on the reMarkable
# decompress and decode the data on this machine
ssh_cmd "$head_fb0 | $compress" |
  $decompress |
  "${FFMPEG_ABS}" -y \
    -f rawvideo \
    -pixel_format $pixel_format \
    -video_size "$width,$height" \
    -i - \
    -vf "$filters" \
    -frames:v 1 "$output_file"

if [ "$display_output_file" = "true" ]; then
  # show the snapshot
  feh --fullscreen "$output_file"
fi
