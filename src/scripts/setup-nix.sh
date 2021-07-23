#! /bin/sh -e

echo 'Setting up Nix'

apt-get -qq install sudo

mkdir /nix

addgroup --system --gid 30000 nixbld

for i in $(seq 1 32); do
    useradd --home-dir /var/empty --gid nixbld --groups nixbld --no-create-home --no-user-group --system --shell /usr/sbin/nologin --uid $((30000 + i)) nixbld$i
done

curl -Ls https://github.com/numtide/nix-flakes-installer/releases/download/nix-3.0pre20200804_ed52cf6/install | sh

mkdir -p ~/.config/nix/
echo "experimental-features = nix-command flakes ca-references" > ~/.config/nix/nix.conf
