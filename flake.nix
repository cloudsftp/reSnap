{
  description = "Take screnshots of your reMarkable tablet over SSH";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: (
        let
          pkgs = import nixpkgs {inherit system;};
          reSnap = pkgs.callPackage ./. {};
        in {
          packages = rec {
            inherit reSnap;
            default = reSnap;
          };
          apps = {
            reSnap = flake-utils.lib.mkApp {
              name = "reSnap";
              drv = reSnap;
            };
          };
          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              ffmpeg
              feh
              imagemagick_light
              lz4
            ];
          };
        }
      )
    );
}
