packer {
  required_plugins {
    linode = {
      version = ">= 0.0.1"
      source  = "github.com/hashicorp/linode"
    }
    sshkey = {
      version = ">= 0.1.0"
      source  = "github.com/ivoronin/sshkey"
    }
  }
}

locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }


variable "linode_token" {
  type      = string
  sensitive = true
}

variable "nixos_version" {
  type    = string
  default = "21.05"
}

source "linode" "example" {
  image             = "linode/debian9"
  image_description = "NixOS ${var.nixos_version}"
  image_label       = "nixos-${var.nixos_version}-${local.timestamp}"
  instance_label    = "packer-build-${local.timestamp}"
  instance_type     = "g6-standard-2"
  linode_token      = var.linode_token
  region            = "us-east"
  ssh_username      = "root"
}

data "sshkey" "install" {}

build {
  sources = ["source.linode.example"]

  provisioner "file" {
    sources     = ["nixos/configuration.nix", "flake.nix", "flake.lock"]
    destination = "/root/"
  }

  provisioner "shell" {
    script = "scripts/setup-nix.sh"
  }

  provisioner "shell" {
    expect_disconnect = true
    inline = [
      "echo 'Installing dependencies for installation via Nix'",
      ". /root/.nix-profile/etc/profile.d/nix.sh",
      "nix --log-format raw profile install '/root#installProfile'",

      "echo 'Copying Configuration'",
      "mkdir -p /etc/nixos/",
      "cp /root/configuration.nix /etc/nixos/",
      "cp /root/flake.nix /etc/nixos",
      "cp /root/flake.lock /etc/nixos",

      "echo 'Patching ssh key into configuration.nix'",
      "sed -i -e \"s#packer_key#$(cat /root/.ssh/authorized_keys)#g\" /etc/nixos/configuration.nix",

      "echo 'Installing NixOS based on the following configuration.nix'",
      "cat /etc/nixos/configuration.nix",
      "nix --log-format raw profile install --profile /nix/var/nix/profiles/system /etc/nixos#nixosConfigurations.peertube-image.config.system.build.toplevel",
      "chown -R 0.0 /nix",
      "touch /etc/NIXOS /etc/NIXOS_LUSTRATE",
      "echo etc/nixos > /etc/NIXOS_LUSTRATE",
      "PATH=\"$PATH\" NIX_PATH=\"$NIX_PATH\" /nix/var/nix/profiles/system/bin/switch-to-configuration boot",
      "reboot"
    ]
  }

  provisioner "file" {
    sources     = ["nixos/configuration.nix", "flake.nix", "flake.lock"]
    destination = "/etc/nixos/"
  }

  provisioner "shell" {
    inline = [
      "rm -rf /old-root",
      "export SSH_KEY=\"$(curl -s -H 'Authorization: Bearer ${var.linode_token}' https://api.linode.com/v4/profile/sshkeys | jq '.data | map(.ssh_key) | .[]' | tr '\n' ' ')\"",
      "sed -i -e \"s#''ssh_key''#$${SSH_KEY}#\" /etc/nixos/configuration.nix",
      "sed -i -e \"s#''packer_key''##\" /etc/nixos/configuration.nix",
      "nixos-rebuild boot --flake /etc/nixos#peertube",
      "nix-collect-garbage -d"
    ]
  }
}

