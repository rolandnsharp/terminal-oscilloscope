{
  description = "Terminal oscilloscope with CRT phosphor rendering";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = lib.genAttrs systems;

      mkPkgs = system:
        import nixpkgs { inherit system; };
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = mkPkgs system;
          ffmpegForOsc = pkgs.ffmpeg-full;
          runtimeLibraryPath = lib.makeLibraryPath [ ffmpegForOsc ];
        in
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "terminal-oscilloscope";
            version = "0.1.0";

            src = ./.;

            nativeBuildInputs = [
              pkgs.nim
              pkgs.makeWrapper
            ];

            buildInputs = [
              ffmpegForOsc
            ];

            buildPhase = ''
              runHook preBuild

              nim c -d:release --threads:on --nimcache:$TMPDIR/nimcache-osc_braille -o:osc_braille src/osc_braille.nim
              nim c -d:release --threads:on --nimcache:$TMPDIR/nimcache-osc_braille -o:osc src/osc.nim

              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall

              install -Dm755 osc $out/bin/osc-unwrapped
              install -Dm755 osc_braille $out/bin/osc_braille-unwrapped

              makeWrapper $out/bin/osc-unwrapped $out/bin/osc \
                --prefix LD_LIBRARY_PATH : ${runtimeLibraryPath}

              makeWrapper $out/bin/osc_braille-unwrapped $out/bin/osc_braille \
                --prefix LD_LIBRARY_PATH : ${runtimeLibraryPath}

              runHook postInstall
            '';

            meta = {
              description = "Terminal oscilloscope with CRT phosphor rendering";
              mainProgram = "osc";
              platforms = lib.platforms.linux;
            };
          };
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/osc";
        };

        osc = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/osc";
        };

        osc_braille = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/osc_braille";
        };
      });

      devShells = forAllSystems (system:
        let
          pkgs = mkPkgs system;
          ffmpegForOsc = pkgs.ffmpeg-full;
          runtimeLibraryPath = lib.makeLibraryPath [ ffmpegForOsc ];
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.nim
              pkgs.nimble
              pkgs.pkg-config
              ffmpegForOsc
            ];

            shellHook = ''
              export LD_LIBRARY_PATH=${runtimeLibraryPath}:''${LD_LIBRARY_PATH:-}
            '';
          };
        });
    };
}