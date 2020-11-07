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
    # shellcheck source=SCRIPTDIR/templates/source.sh
    source "$(dirname "${BASH_SOURCE[0]}")/templates/source.sh"

    trap script_trap_err ERR
    trap script_trap_exit EXIT

    script_init "$@"
    parse_params "$@"
    cron_init
    colour_init
    #lock_init system

    export
}

function export() {
    check_export
    prepare_export

    kubectl get secret \
        --namespace "$sealed_secrets_namespace" \
        --output "$sealed_secrets_format" \
        -l "$sealed_secrets_label" \
        >"$sealed_secrets_export_path"
}

function check_export() {
    check_binary "kubectl" 1
    check_binary "kubeseal" 1
}

function prepare_export() {
    readonly sealed_secrets_namespace=kube-system
    readonly sealed_secrets_label=sealedsecrets.bitnami.com/sealed-secrets-key

    readonly sealed_secrets_format=yaml
    readonly sealed_secrets_export_path="keys.$sealed_secrets_format"
}

# Make it rain
main "$@"

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
