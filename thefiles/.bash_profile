# TODO: explore $PATH problems
# exporting some env variables
source .exports

# common bash functions used in scripts
source .common_functions

# importing aliases
source .aliases $(detect_os)
