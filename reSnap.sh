#!/bin/sh

version="v2.5.2"

# create temporary directory
tmp_dir="/tmp/reSnap"
if [ ! -d "$tmp_dir" ]; then
  mkdir "$tmp_dir"
fi

# default values
ip="${REMARKABLE_IP:-10.11.99.1}"
output_file="$tmp_dir"
delete_output_file="true"
display_output_file="${RESNAP_DISPLAY:-true}"
color_correction="${RESNAP_COLOR_CORRECTION:-true}"
byte_correction="${RESNAP_BYTE_CORRECTION:-true}"
invert_colors="${REMARKABLE_INVERT_COLORS:-false}"
filters="null"
copy_to_clipboard="false"
construct_sketch="false"

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
    delete_output_file="false"
    output_file="."
    shift
    # if next argument is not empty and not an option (TODO: own function?)
    if [ $# -gt 0 ] && [ "$(expr "$1" : "-")" -eq 0 ]; then
      output_file="$1"
      shift
    fi
    ;;
  -d | --display)
    display_output_file="true"
    shift
    ;;
  -n | --no-display)
    display_output_file="false"
    shift
    ;;
  -x | --clipboard)
    copy_to_clipboard="true"
    shift
    ;;
  -f | --sketch)
    construct_sketch="true"
    shift
    ;;
  -c | --og-color)
    color_correction="false"
    shift
    ;;
  -p | --og-pixel-format)
    byte_correction="false"
    shift
    ;;
  -i | --invert-colors)
    invert_colors="true"
    shift
    ;;
  -v | --version)
    echo "$0 version $version"
    exit 0
    ;;
  -h | --help | *)
    echo "Usage: $0 [-l] [-d] [-n] [-v] [-x] [-f] [--source <ssh-host>] [--output <output-file>] [-h]"
    echo "Examples:"
    echo "  $0                    # snapshot in portrait"
    echo "  $0 -l                 # snapshot in landscape"
    echo "  $0 -s 192.168.2.104   # snapshot over wifi"
    echo "  $0 -o snapshot.png    # saves the snapshot in the current directory"
    echo "  $0 -o                 # same as above, but named after the notebook"
    echo "  $0 -d                 # display the file"
    echo "  $0 -n                 # don't display the file"
    echo "  $0 -c                 # no color correction (reMarkable2)"
    echo "  $0 -x                 # Copy snapshot to clipboard also"
    echo "  $0 -f                 # Remove white background"
    echo "  $0 -p                 # no pixel format correction (reMarkable2 version < 3.6)"
    echo "  $0 -v                 # displays version"
    echo "  $0 --sketch           # Construct sketc"
    echo "  $0 -i                 # Invert colors"
    echo "  $0 -h                 # displays help information (this)"
    exit 2
    ;;
  esac
done

if [ "$display_output_file" != "true" ]; then
  delete_output_file="false"
fi

if [ "$delete_output_file" = "true" ]; then
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
  # pixel format
  if [ "$byte_correction" = "true" ]; then
    bytes_per_pixel=2
    pixel_format="gray16"
    filters="$filters,transpose=3" # 90° clockwise and vertical flip
  else
    bytes_per_pixel=1
    pixel_format="gray8"
    filters="$filters,transpose=2" # 90° counter-clockwise
  fi

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
  skip_bytes="$((0x$skip_bytes_hex + 7))"

  # remarkable's dd does not have iflag=skip_bytes, so cut the command in two:
  # one to seek the exact amount and the second to copy in a large chunk
  # bytes are located in, and then we trim the resulting data with what we need.
  head_fb0="{ dd bs=1 skip=$skip_bytes count=0 && dd bs=$window_bytes count=1; } < /proc/$pid/mem 2>/dev/null"

  # color correction
  if [ "$color_correction" = "true" ]; then
    filters="$filters,curves=all=0.045/0 0.06/1"
  fi

else

  echo "$rm_version not supported"
  exit 2

fi

if [ "$invert_colors" = "true" ]; then
  filters="$filters,negate"
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
  echo "            Please refer to the README."
  echo
  compress="tee"
  decompress="tee"
fi

# Get notebook metadata
notebooks_dir="/home/root/.local/share/remarkable/xochitl"
notebook_data_file="$(ssh_cmd "ls -u $notebooks_dir" | head -n 1)"
notebook_id="$(basename "$notebook_data_file" | cut -d '.' -f 1)"

notebook_metadata_file="$notebooks_dir/${notebook_id}.metadata"
metadata="$(ssh_cmd cat "$notebook_metadata_file")"

echo "$metadata" | jq "{ id: \"$notebook_id\", metadata: $metadata }"

if [ -d "$output_file" ]; then
  output_dir="$output_file"

  # TODO: if jq not installed, fallback
  output_file_name="$(echo "$metadata" | jq -r '.visibleName')"

  output_file="${output_dir}/${output_file_name} [$(date "+%F %H:%M:%S")].png"
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

if [ "$construct_sketch" = "true" ]; then
  echo "Constructing sketch"
  magick "${output_file}" -fill white -draw 'rectangle 0,0 100,100' \
    -fill white -draw "rectangle 0,1870 2,1872" \
    -transparent white -trim -resize 50% +repage "${output_file}"

  output_file=$(realpath "${output_file}")
fi

# Copy to clipboard
if [ "$copy_to_clipboard" = "true" ]; then
  echo "Copying to clipboard"
  xclip -selection clipboard -t image/png -i "${output_file}"
  # TODO: add support for wayland (wl-copy)
fi

# Show the snapshot
if [ "$display_output_file" = "true" ]; then
  feh --fullscreen "$output_file"
fi
