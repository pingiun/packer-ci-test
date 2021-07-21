export PACKER_CACHE_DIR=$HOME/.cache/packer
if which pass; then
    export PKR_VAR_linode_token=$(pass linode_token)
fi
