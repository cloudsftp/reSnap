{
  pkgs ? import <nixpkgs> {},
  writeShellApplication,
  ...
}:
writeShellApplication {
  name = "reSnap";
  runtimeInputs = with pkgs; [
    ffmpeg
    feh
    imagemagick_light
    lz4
  ];
  text = builtins.readFile ./reSnap.sh;
}
