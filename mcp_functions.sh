#!/bin/bash

# MCP server configuration functions
# Provides automatic MCP server configuration from .mcp.json files

get_server_name() {
    echo "$1" | jq -r '.key'
}

get_server_command() {
    echo "$1" | jq -r '.value.command'
}

get_server_args() {
    echo "$1" | jq -r '.value.args[]?' | tr '\n' ' '
}

get_server_env_flags() {
    echo "$1" | jq -r '.value.env | to_entries[] | "--env \(.key)=\(.value)"' | tr '\n' ' '
}

get_all_configured_servers() {
    claude mcp list 2>&1 | grep -E "^[a-zA-Z0-9_-]+:" | cut -d: -f1
}

is_server_already_configured() {
    local server_name="$1"
    local configured_list="$2"
    echo "$configured_list" | grep -q "^${server_name}$"
}

get_env_vars_array() {
    local server_json="$1"
    local -n result=$2
    while IFS= read -r line; do
        [[ -n "$line" ]] && result+=(--env "$line")
    done < <(echo "$server_json" | jq -r '.value.env // empty | to_entries[] | "\(.key)=\(.value)"')
}

get_args_array() {
    local server_json="$1"
    local -n result=$2
    while IFS= read -r arg; do
        [[ -n "$arg" ]] && result+=("$arg")
    done < <(echo "$server_json" | jq -r '.value.args[]?')
}

build_mcp_add_command() {
    local name="$1"
    local cmd="$2"
    local -n env_vars_ref=$3
    local -n args_ref=$4
    local -n result=$5

    result=(claude mcp add --scope user)
    result+=("${env_vars_ref[@]}")
    result+=(--) # Separator between options and positional args
    result+=("$name" "$cmd")
    result+=("${args_ref[@]}")
}

execute_mcp_add_command() {
    local -n cmd_array=$1
    "${cmd_array[@]}" 2>&1 | sed 's/^/     /'
}

add_mcp_server() {
    local server_json="$1"
    local name=$(get_server_name "$server_json")
    local cmd=$(get_server_command "$server_json")

    echo "   + Adding $name..."

    local env_vars=()
    get_env_vars_array "$server_json" env_vars

    local args=()
    get_args_array "$server_json" args

    local mcp_cmd=()
    build_mcp_add_command "$name" "$cmd" env_vars args mcp_cmd
    execute_mcp_add_command mcp_cmd
}

check_jq_installed() {
    if ! command -v jq &>/dev/null; then
        echo "   ⚠ jq not found - skipping MCP auto-configuration"
        return 1
    fi
}

# Enable project MCP servers by updating Claude settings.
# Workaround for bug #9189 where the approval prompt doesn't appear.
enable_project_mcp_servers() {
    local settings_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
    local settings_file="$settings_dir/settings.local.json"

    mkdir -p "$settings_dir"

    # Create or update settings file
    if [[ ! -f "$settings_file" ]] || ! jq -e . "$settings_file" >/dev/null 2>&1; then
        echo '{"enableAllProjectMcpServers": true}' > "$settings_file"
    else
        local tmp=$(mktemp)
        jq '.enableAllProjectMcpServers = true' "$settings_file" > "$tmp" && mv "$tmp" "$settings_file"
    fi

    echo "   ✓ Enabled project MCP servers (workaround for bug #9189)"
}

process_each_server_from_config() {
    local configured_list="$1"
    local config_file="${2:-/workspace/.mcp.json}"

    local added_any=false
    jq -r '.mcpServers | to_entries[] | @json' "$config_file" 2>/dev/null | while read -r server; do
        local name=$(get_server_name "$server")
        if ! is_server_already_configured "$name" "$configured_list"; then
            add_mcp_server "$server"
            added_any=true
        fi
    done

    if ! $added_any; then
        echo "   ✓ All MCP servers already configured"
    fi
}

configure_mcp_servers() {
    local config_file="${1:-/workspace/.mcp.json}"

    # Enable project MCP servers in settings (workaround for bug #9189)
    # Do this regardless of whether .mcp.json exists in this project
    enable_project_mcp_servers

    [ ! -f "$config_file" ] && return 0

    echo "🔧 Configuring MCP servers from $config_file..."
    check_jq_installed || return 1

    local configured=$(get_all_configured_servers)
    process_each_server_from_config "$configured" "$config_file"
    echo ""
}
