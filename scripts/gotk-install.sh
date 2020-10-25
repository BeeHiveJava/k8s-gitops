#!/usr/bin/env bash

# See https://github.com/ralish/bash-script-template/blob/main/script.sh

# Enable xtrace if the DEBUG environment variable is set
if [[ ${DEBUG-} =~ ^1|yes|true$ ]]; then
    set -o xtrace # Trace the execution of the script (debug)
fi

# A better class of script...
set -o errexit  # Exit on most errors (see the manual)
set -o errtrace # Make sure any error trap is inherited
set -o nounset  # Disallow expansion of unset variables
set -o pipefail # Use last non-zero exit code in a pipeline

# DESC: Usage help
# ARGS: None
# OUTS: None
function script_usage() {
    cat <<EOF
Usage:
    -gv|--gotk-version          The GitOps Toolkit version to install
     -h|--help                  Displays this help
     -v|--verbose               Displays verbose output
    -nc|--no-colour             Disables colour output
    -cr|--cron                  Run silently unless we encounter an error
EOF
}

# DESC: Parameter parser
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: Variables indicating command-line parameters and options
function parse_params() {
    local param
    while [[ $# -gt 0 ]]; do
        param="$1"
        shift
        case $param in
        -gv=* | --gotk-version=*)
            gotk_version="${param#*=}"
            ;;
        -h | --help)
            script_usage
            exit 0
            ;;
        -v | --verbose)
            export verbose=true
            ;;
        -nc | --no-colour)
            export no_colour=true
            ;;
        -cr | --cron)
            export cron=true
            ;;
        *)
            script_exit "Invalid parameter was provided: $param" 1
            ;;
        esac
    done
}

# DESC: Main control flow
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: None
function main() {
    # shellcheck source=templates/source.sh
    source "$(dirname "${BASH_SOURCE[0]}")/templates/source.sh"

    trap script_trap_err ERR
    trap script_trap_exit EXIT

    script_init "$@"
    parse_params "$@"
    cron_init
    colour_init
    #lock_init system

    gotk_install
}

function gotk_install() {
    gotk_check_install
    gotk_prepare_install

    gotk install \
        --version="$gotk_version" \
        --namespace="$gotk_namespace" \
        --components="$gotk_components" \
        --network-policy="$gotk_network_policy" \
        --export >"$gotk_export_path"
}

function gotk_check_install() {
    check_binary "git" 1
    check_binary "kubectl" 1
    check_binary "gotk" 1

    if ! gotk check --pre; then
        script_exit "gotk check failed: $0" 1
    fi
}

function gotk_prepare_install() {
    readonly gotk_version=${gotk_version-latest}
    readonly gotk_namespace=gotk-system
    readonly gotk_network_policy=false
    readonly gotk_components=source-controller,kustomize-controller,helm-controller,notification-controller

    local git_repository_root
    git_repository_root=$(git rev-parse --show-toplevel)

    readonly gotk_export_path="$git_repository_root/namespaces/gotk-system/toolkit-components.generated.yaml"
}

# Make it rain
main "$@"

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
