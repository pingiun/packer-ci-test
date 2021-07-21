{
  description = "A very basic flake";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in
      with pkgs; rec {
        defaultPackage =
          let script = pkgs.writeShellScriptBin "nixos-linode-packer" ''
            out=$1
            shift
            logfile=$(mktemp)

            pushd $out
            source scripts/init.sh
            ${packer}/bin/packer init $out
            
            ${packer}/bin/packer build main.pkr.hcl "$@" | tee $logfile
            popd
            
            echo -n "linode_image = \"" > terraform.tfvars
            grep 'private/' $logfile | cut -d '(' -f 2 | tr -d ')' >> terraform.tfvars
            echo "\"" >> terraform.tfvars
          '';
          in
          stdenv.mkDerivation {
            name = "nixos-linode-packer";

            nativeBuildInputs = [ makeWrapper packer ];

            src = ./src;

            installPhase = ''
              mkdir -p $out/bin
              cp -R ./* $out/
              makeWrapper ${script}/bin/nixos-linode-packer $out/bin/nixos-linode-packer \
                  --prefix PATH : ${pkgs.lib.makeBinPath [ coreutils ]} \
                  --add-flags "$out"
            '';
          };

        defaultApp = {
          type = "app";
          program = "${defaultPackage}/bin/nixos-linode-packer";
        };
      });
}
