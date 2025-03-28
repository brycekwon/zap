#!/usr/bin/env zsh


################################################################################
# ENVIRONMENT VARIABLES                                                        #
################################################################################

# current version of script
VERSION="1.0.0-dev"

# location of installed zap modules (plugins & snippets)
# order: $ZAP_HOME/zap -> $XDG_DATA_HOME/zap -> $HOME/zap
ZAP_DIR="${ZAP_HOME:-${XDG_DATA_HOME:-$HOME}/zap}"

# explicit status codes
SUCCESS=0
FAILURE=1


################################################################################
# HELPER FUNCTIONS                                                             #
################################################################################

function __zap-usage() {
    case "$1" in
        install)
            printf "Usage: zap install <NAME> <URL> [flags]\n\n"
            printf "Arguments:\n"
            printf "  %-15s custom name for the module.\n" "<NAME>"
            printf "  %-15s source URL for the module.\n" "<URL>"
            printf "\nFlags:\n"
            printf "  %-15s specific branch to reference from.\n" "-b, --branch"
            printf "  %-15s Supress output logs and messages.\n" "-q, --quiet"
            ;;
        load)
            printf "Usage: zap load <MODULE> <FILE> [flags]\n\n"
            printf "Arguments:\n"
            printf "  %-15s name of the module.\n" "<MODULE>"
            printf "  %-15s name of the file to load.\n" "<FILE>"
            ;;
        *)
            printf "Usage: zap <command> [arguments]\n\n"
            printf "Commands:\n"
            printf "  %-15s create a new module from a given URL.\n" "install"
            printf "  %-15s source a specific file within a module.\n" "load"
            printf "  %-15s list all currently installed modules.\n" "list"
            printf "  %-15s TBD\n" "update"
            printf "  %-15s TBD\n\n" "remove"
            printf "Use \"zap <command> --help\" for more information on a specific command.\n"
            ;;
    esac
}

function __zap-clone() {
    if [[ -n "$2" ]]; then
        git clone --recurse-submodules \
            "$1" --branch "$2" "$3" || {
                printf "Error failed to clone repository: '%s'\n" "$3"
                return "$FAILURE"
            }
    else
        git clone --recurse-submodules \
            "$1" "$3" || {
                printf "Error: failed to clone repository: '%s'\n" "$3"
                return "$FAILURE"
            }
    fi
}

function __zap-verify-params() {
    if [[ -z "$2" ]]; then
        printf "Error: missing argument '%s'\n" "$1"
        return "$FAILURE"
    fi
    return "$SUCCESS"
}


################################################################################
# Main Functions                                                               #
################################################################################

function zap-install() {
    local module_name=""
    local remote_url=""
    local remote_ref=""

    local verbose=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                __zap-usage "install"
                return "$FAILURE"
                ;;
            --branch|-b)
                remote_ref="$2"
                shift 2
                ;;
            --verbose|-v)
                verbose=true
                shift
                ;;
            *)
                if [[ -z "$module_name" ]]; then
                    module_name="$1"
                elif [[ -z "$remote_url" ]]; then
                    remote_url="$1"
                fi
                shift
                ;;
        esac
    done

    __zap-verify-params "<NAME>" "$module_name" || return "$FAILURE"
    __zap-verify-params "<URL>" "$remote_url" || return "$FAILURE"

    local module_dir="$ZAP_DIR/$module_name"
    if [[ ! -d "$module_dir" ]]; then
        printf "Installing: '%s'\n" "$module_name"
        __zap-clone "$remote_url" "$remote_ref" "$module_dir" || return "$FAILURE"
    elif [[ "$verbose" == true ]]; then
        printf "Error: module '%s' already exists.\n" "$module_name"
    fi
}

function zap-load() {
    local module_name=""
    local source_file=""

    local verbose=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                __zap-usage "install"
                return "$FAILURE"
                ;;
            --verbose|-v)
                verbose=true
                shift
                ;;
            *)
                if [[ -z "$module_name" ]]; then
                    module_name="$1"
                elif [[ -z "$source_file" ]]; then
                    source_file="$1"
                fi
                shift
                ;;
        esac
    done

    __zap-verify-params "<MODULE>" "$module_name" || return "$FAILURE"
    __zap-verify-params "<FILE>" "$source_file" || return "$FAILURE"

    local source_path="$ZAP_DIR/$module_name/$source_file"
    if [[ ! -f "$source_path" ]]; then
        printf "Error: file '%s' does not exist.\n" "$source_path"
        return "$FAILURE"
    fi

    source "$source_path"
}

function zap-update() {
    for i in $(command ls $ZAP_DIR); do
        pushd "$ZAP_DIR/${i}" > /dev/null || continue
        printf "Updating: '%s'\n" "${i}"

        git pull || {
            printf "Error: failed to pull repository: '%s'\n" ${i}
            continue
        }

        popd > /dev/null || continue
    done
}

function zap-list() {
    printf "Installed Packages:\n"
    local packages=("$ZAP_DIR/"*)
    for pkg in "${packages[@]}"; do
        if [[ -d "$pkg" ]]; then
            printf " - %s\n" "$(basename "$pkg")"
        fi
    done
}

function zap() {
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        __zap-usage
        return "$SUCCESS"
    fi

    case "$1" in
        install)
            shift
            zap-install "$@"
            ;;
        load)
            shift
            zap-load "$@"
            ;;
        update)
            shift
            zap-update "$@"
            ;;
        list)
            shift
            zap-list "$@"
            ;;
        "")
            __zap-usage
            ;;
        *)
            printf "Error: unknown command '$1'\n\n"
            __zap-usage
            ;;
    esac

    return "$SUCCESS"
}

