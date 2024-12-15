#!/usr/bin/env zsh


################################################################################
# Environment Variables                                                        #
################################################################################

# location of installed zap modules (plugins and snippets)
# order: $ZAP_HOME/zap > $XDG_DATA_HOME/zap > $HOME/zap
ZAP_DIR="${ZAP_HOME:-${XDG_DATA_HOME:-$HOME}/zap}"

# explicit exit/return status codes
SUCCESS_CODE=0
FAILURE_CODE=1


################################################################################
# Helper Functions                                                             #
################################################################################

function __zap-usage() {
    local cmd="$1"

    if [[ "$cmd" == "install" ]]; then
        printf "Usage: zap install <NAME> <URL> [flags]\n\n"
        printf "Arguments:\n"
        printf "  %-15s custom name for the module.\n" "<NAME>"
        printf "  %-15s source URL for the module.\n" "<URL>"
        printf "\nFlags:\n"
        printf "  %-15s specific branch to reference from.\n" "-b, --branch"
        printf "  %-15s Supress output logs and messages.\n" "-q, --quiet"
    elif [[ "$cmd" == "load" ]]; then
        printf "Usage: zap load <MODULE> <FILE> [flags]\n\n"
        printf "Arguments:\n"
        printf "  %-15s name of the module.\n" "<MODULE>"
        printf "  %-15s name of the file to load.\n" "<FILE>"
    else
        printf "Usage: zap <command> [arguments]\n\n"
        printf "Commands:\n"
        printf "  %-15s create a new module from a given URL.\n" "install"
        printf "  %-15s source a specific file within a module.\n" "load"
        printf "  %-15s list all currently installed modules.\n" "list"
        printf "  %-15s TBD\n" "update"
        printf "  %-15s TBD\n\n" "remove"
        printf "Use \"zap <command> --help\" for more information on a specific command.\n"
    fi
}

function __zap-clone() {
    if [[ -n "$2" ]]; then
        git clone --recurse-submodules --depth 1 \
            "$1" --branch "$2" "$3" || {
                printf "Error failed to clone repository: '%s'\n" "$3"
                return FAILURE_CODE
            }
    else
        git clone --recurse-submodules --depth 1 \
            "$1" "$3" || {
                printf "Error: failed to clone repository: '%s'\n" "$3"
                return FAILURE_CODE
            }
    fi
}

function __zap-verify-params() {
    if [[ -z "$2" ]]; then
        printf "Error: missing argument '%s'\n" "$1"
        return FAILURE_CODE
    fi
    return SUCCESS_CODE
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
                return FAILURE_CODE
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

    __zap-verify-params "<NAME>" "$module_name" || return FAILURE_CODE
    __zap-verify-params "<URL>" "$remote_url" || return FAILURE_CODE

    local module_dir="$ZAP_DIR/$module_name"
    if [[ ! -d "$module_dir" ]]; then
        printf "Installing: '%s'\n" "$module_name"
        __zap-clone "$remote_url" "$remote_ref" "$module_dir" || return FAILURE_CODE
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
                return FAILURE_CODE
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

    __zap-verify-params "<MODULE>" "$module_name" || return FAILURE_CODE
    __zap-verify-params "<FILE>" "$source_file" || return FAILURE_CODE

    local source_path="$ZAP_DIR/$module_name/$source_file"
    if [[ ! -f "$source_path" ]]; then
        printf "Error: file '%s' does not exist.\n" "$source_path"
        return FAILURE_CODE
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

function zap() {
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        __zap-usage
        return SUCCESS_CODE
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
        "")
            __zap-usage
            ;;
        *)
            printf "Error: unknown command '$1'\n\n"
            __zap-usage
            ;;
    esac

    return SUCCESS_CODE
}
