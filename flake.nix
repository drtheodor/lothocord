{
  description = "Empty Template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};

        mkSconsFlagsFromAttrSet = pkgs.lib.mapAttrsToList (
          k: v: if builtins.isString v then "${k}=${v}" else "${k}=${builtins.toJSON v}"
        );

        commonFlags = {
          #lto = "yes";
          deprecated = "no";
          minizip = "no";
          brottli = "no";
          xaudio2 = "no";
          vulkan = "no";
          use_volk = "no";
          sdl = "no";
          disable_xr = "yes";
          #module_astcenc_enabled = "no";
          module_basis_universal_enabled = "no";
          module_bcdec_enabled = "no";
          module_betsy_enabled = "no";
          module_csg_enabled = "no";
          module_cvtt_enabled = "no";
          module_dds_enabled = "no";
          module_etcpak_enabled = "no";
          module_fbx_enabled = "no";
          module_gltf_enabled = "no";
          module_gridmap_enabled = "no";
          module_hdr_enabled = "no";
          module_interactive_music_enabled = "no";
          module_jolt_physics_enabled = "no";
          module_ktx_enabled = "no";
          module_lightmapper_rd_enabled = "no";
          module_meshoptimizer_enabled = "no";
          module_mobile_vr_enabled = "no";
          module_multiplayer_enabled = "no";
          module_openxr_enabled = "no";
          module_raycast_enabled = "no";
          graphite = "no";
          module_tga_enabled = "no";
          module_tinyexr_enabled = "no";
          module_upnp_enabled = "no";
          module_vhacd_enabled = "no";
          module_webrtc_enabled = "no";
          module_webxr_enabled = "no";
          module_xatlas_unwrap_enabled = "no";
          module_zip_enabled = "no";
        };

        editorFlags = {
          steamapi = "no";
        } // commonFlags;

        exportFlags = {
          disable_3d = "yes";
          disable_physics_2d = "yes";
          disable_physics_3d = "yes";
          disable_navigation_3d = "yes";
          module_godot_physics_2d_enabled = "no";
          module_godot_physics_3d_enabled = "no";
          module_navigation_2d_enabled = "no";
          module_navigation_3d_enabled = "no";
          module_objectdb_profiler_enabled = "no";
        } // commonFlags;

        nativeBuildInputs = with pkgs; [
          git
        ];

        buildInputs = with pkgs; [
          #wayland
          (godot.overrideAttrs (attrs: {
            patches = attrs.patches 
              ++ lib.optional (!stdenv.hostPlatform.sse4_2Support) ./godot-no-sse4.patch
              ++ lib.optional (!stdenv.hostPlatform.sse4_2Support) ./no-sse4-check.patch;
            sconsFlags = attrs.sconsFlags ++ mkSconsFlagsFromAttrSet editorFlags;
          }))
          (godotPackages_4_6.export-template.overrideAttrs (attrs: {
            patches = attrs.patches 
              ++ lib.optional (!stdenv.hostPlatform.sse4_2Support) ./godot-no-sse4.patch
              ++ lib.optional (!stdenv.hostPlatform.sse4_2Support) ./no-sse4-check.patch;
            sconsFlags = attrs.sconsFlags ++ mkSconsFlagsFromAttrSet exportFlags;
          }))

          # zlibext
          pkg-config
          scons
          mold
          zlib
        ];
      in {
        devShells.default = pkgs.mkShell {
          inherit nativeBuildInputs buildInputs;
        };
      }
    );
}
