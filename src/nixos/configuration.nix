{ pkgs, options, lib, utils, ... }:
with lib;
with utils;
{
  imports = [ <nixpkgs/nixos/modules/profiles/qemu-guest.nix> ];

  boot.loader.timeout = 10;
  boot.loader.grub.forceInstall = true;
  boot.loader.grub.device = "nodev";
  boot.cleanTmpDir = true;

  fileSystems."/" = { device = "/dev/sda"; fsType = "ext4"; };
  swapDevices = [{ device = "/dev/sdb"; }];
  boot.initrd.postMountCommands = ''
    if [[ -e /dev/sdb ]]; then
      swapon /dev/sdb
    fi
  '';

  services.openssh.enable = true;

  # These get replaced within the packer build
  users.users.root.openssh.authorizedKeys.keys = [
    ''ssh_key''
    ''packer_key''
  ];
}
