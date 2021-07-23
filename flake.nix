{
  description = "A very basic flake";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.agent.url = "github:pingiun/docker-agent-test";

  outputs = { self, nixpkgs, flake-utils, agent }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in
        with pkgs; rec {
          defaultPackage =
            let script = pkgs.writeShellScriptBin "nixos-linode-packer" ''
              set -euo pipefail

              out=$1
              shift

              pushd $out
              source scripts/init.sh
              ${packer}/bin/packer init $out
            
              ${packer}/bin/packer build main.pkr.hcl "$@"
            '';
            in
            stdenv.mkDerivation {
              name = "nixos-linode-packer";

              nativeBuildInputs = [ makeWrapper packer ];

              src = ./src;

              installPhase = ''
                mkdir -p $out/bin
                cp -R ./* $out/
                cp ${./flake.nix} $out/flake.nix
                cp ${./flake.lock} $out/flake.lock
                makeWrapper ${script}/bin/nixos-linode-packer $out/bin/nixos-linode-packer \
                    --prefix PATH : ${pkgs.lib.makeBinPath [ coreutils ]} \
                    --add-flags "$out"
              '';
            };

          packages = flake-utils.lib.flattenTree
            (nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
              installProfile = symlinkJoin { name = "installProfile"; paths = [ jq nixos-install-tools ]; };
            }) // { };

          defaultApp = {
            type = "app";
            program = "${defaultPackage}/bin/nixos-linode-packer";
          };
        }) // {

      nixosConfigurations.local-peertube = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ (import ./src/nixos/configuration.nix { inherit nixpkgs; }) agent.nixosModule ];
      };
      
      nixosConfigurations.peertube-image = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ (import ./configuration.nix { inherit nixpkgs; enableAgent = false; }) agent.nixosModule ];
      };

      nixosConfigurations.peertube = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ (import ./configuration.nix { inherit nixpkgs; enableAgent = true; }) agent.nixosModule ];
      };

    };
}
