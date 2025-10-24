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

add_mcp_server() {
    local server_json="$1"
    local name=$(get_server_name "$server_json")
    local cmd=$(get_server_command "$server_json")
    local args=$(get_server_args "$server_json")
    local env_flags=$(get_server_env_flags "$server_json")

    echo "   + Adding $name..."
    eval "claude mcp add --scope local $env_flags $name $cmd $args" 2>&1 | sed 's/^/     /'
}

check_jq_installed() {
    if ! command -v jq &>/dev/null; then
        echo "   ⚠ jq not found - skipping MCP auto-configuration"
        return 1
    fi
}

process_each_server_from_config() {
    local configured_list="$1"
    local config_file="${2:-/workspace/.mcp.json}"

    jq -r '.mcpServers | to_entries[] | @json' "$config_file" 2>/dev/null | while read -r server; do
        local name=$(get_server_name "$server")
        if is_server_already_configured "$name" "$configured_list"; then
            echo "   ✓ $name (already configured)"
        else
            add_mcp_server "$server"
        fi
    done
}

configure_mcp_servers() {
    local config_file="${1:-/workspace/.mcp.json}"

    [ ! -f "$config_file" ] && return 0

    echo "🔧 Configuring MCP servers from $config_file..."
    check_jq_installed || return 1

    local configured=$(get_all_configured_servers)
    process_each_server_from_config "$configured" "$config_file"
    echo ""
}
