export PACKER_CACHE_DIR=$HOME/.cache/packer
if [[ ! -v PKR_VAR_linode_token ]]; then
    export PKR_VAR_linode_token=$(pass linode_token)
fi
