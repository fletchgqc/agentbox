#!/usr/bin/env bash
# Module System Functions for AgentBox

#############################################
# Module System Functions
#############################################

# Parse module spec into name and version
# Usage: read name version < <(parse_module_spec "nodejs:20")
parse_module_spec() {
    local spec="$1"
    if [[ "$spec" =~ : ]]; then
        echo "${spec%%:*}" "${spec#*:}"
    else
        echo "$spec" ""
    fi
}

# Module directory search paths
get_module_search_paths() {
    local paths=(
        "${HOME}/.agentbox/modules"
        "${SCRIPT_DIR}/modules"
    )
    echo "${paths[@]}"
}

# Validate module name format
validate_module_name() {
    local name="$1"
    
    # Must be lowercase alphanumeric with underscores/hyphens
    if [[ ! "$name" =~ ^[a-z0-9_-]+$ ]]; then
        return 1
    fi
    
    # Reject path traversal
    if [[ "$name" =~ \.\. ]] || [[ "$name" =~ / ]]; then
        return 1
    fi
    
    return 0
}

# Validate module directory isn't a symlink to dangerous location
validate_module_directory() {
    local module_dir="$1"
    
    # Check if it's a symlink
    if [[ -L "$module_dir" ]]; then
        local target
        target=$(readlink -f "$module_dir" 2>/dev/null) || return 1
        
        # Symlink target must be within ~/.agentbox or agentbox repo
        if [[ ! "$target" =~ ^${HOME}/.agentbox ]] && [[ ! "$target" =~ ^${SCRIPT_DIR} ]]; then
            log_error "Module directory symlink points outside allowed locations: $target"
            return 1
        fi
    fi
    
    return 0
}

# Validate mount path for security
validate_mount_path() {
    local mount_spec="$1"
    local host_path container_path

    # Parse host:container
    IFS=: read -r host_path container_path <<< "$mount_spec"

    # Validate mount spec format
    if [[ -z "$host_path" ]] || [[ -z "$container_path" ]]; then
        log_error "Invalid mount specification (must be host:container): $mount_spec"
        return 1
    fi

    # Expand tilde in host path
    host_path="${host_path/#\~/$HOME}"

    # Check for path traversal in both paths
    if [[ "$host_path" =~ \.\. ]]; then
        log_error "Path traversal not allowed in host mount path: $host_path"
        return 1
    fi

    if [[ "$container_path" =~ \.\. ]]; then
        log_error "Path traversal not allowed in container mount path: $container_path"
        return 1
    fi

    # Container path must be absolute
    if [[ ! "$container_path" =~ ^/ ]]; then
        log_error "Container mount path must be absolute: $container_path"
        return 1
    fi

    # Must start with whitelisted prefixes
    local allowed_prefixes=(
        "${HOME}/.cache"
        "${HOME}/.config"
        "${HOME}/.npm"
        "${HOME}/.m2"
        "${HOME}/.gradle"
        "${HOME}/.cargo"
        "${HOME}/.rustup"
        "${HOME}/.sdkman"
        "${HOME}/.nvm"
    )

    local allowed=false
    for prefix in "${allowed_prefixes[@]}"; do
        if [[ "$host_path" == "$prefix"* ]]; then
            allowed=true
            break
        fi
    done

    if [[ "$allowed" == "false" ]]; then
        log_error "Host mount path not in whitelist: $host_path"
        log_error "Allowed prefixes: ~/.cache, ~/.config, ~/.npm, ~/.m2, ~/.gradle, ~/.cargo, ~/.rustup, ~/.sdkman, ~/.nvm"
        return 1
    fi

    # Check blacklist for both host and container paths
    local blacklist=(
        "/var/run/docker.sock"
        "/var/run"
        "/etc"
        "/sys"
        "/proc"
        "/dev"
        "/bin"
        "/sbin"
        "/usr/bin"
        "/usr/sbin"
        "/lib"
        "/lib64"
        "/boot"
        "/root"
    )

    for blocked in "${blacklist[@]}"; do
        if [[ "$host_path" == "$blocked"* ]]; then
            log_error "Blocked host mount path: $host_path"
            log_error "Cannot mount system directories"
            return 1
        fi
        if [[ "$container_path" == "$blocked"* ]]; then
            log_error "Blocked container mount path: $container_path"
            log_error "Cannot mount to system directories in container"
            return 1
        fi
    done

    # Container path must be in /home/agent/ for safety
    if [[ ! "$container_path" =~ ^/home/agent/ ]]; then
        log_error "Container mount path must be in /home/agent/: $container_path"
        log_error "Mounting outside user home is not allowed"
        return 1
    fi

    return 0
}

# Validate environment variable
validate_env_var() {
    local env_spec="$1"
    local var_name var_value
    
    # Parse VAR=value
    IFS== read -r var_name var_value <<< "$env_spec"
    
    # Check blacklist
    local blacklist=(
        "LD_PRELOAD"
        "LD_LIBRARY_PATH"
        "DOCKER_HOST"
        "DOCKER_TLS_VERIFY"
        "DOCKER_CERT_PATH"
    )
    
    for blocked in "${blacklist[@]}"; do
        if [[ "$var_name" == "$blocked" ]]; then
            log_error "Blocked environment variable: $var_name"
            log_error "Blocked variables: LD_PRELOAD, LD_LIBRARY_PATH, DOCKER_HOST, DOCKER_TLS_VERIFY, DOCKER_CERT_PATH"
            return 1
        fi
    done
    
    # Validate PATH entries
    if [[ "$var_name" == "PATH" ]]; then
        # Check for relative path components
        if [[ "$var_value" =~ (^|:)\.\.?(/|:|$) ]]; then
            log_error "PATH contains relative paths (. or ..) which is not allowed: $var_value"
            return 1
        fi
    fi
    
    return 0
}

# Find module by name and optional version
find_module() {
    local module_spec="$1"
    local module_name module_version
    
    read module_name module_version < <(parse_module_spec "$module_spec")
    module_name="${module_name,,}"
    
    # Validate module name
    if ! validate_module_name "$module_name"; then
        log_error "Invalid module name: $module_name"
        return 1
    fi
    
    # Search for module in search paths
    local search_paths
    read -ra search_paths <<< "$(get_module_search_paths)"
    
    for base_path in "${search_paths[@]}"; do
        local module_dir="${base_path}/${module_name}"
        
        if [[ ! -d "$module_dir" ]]; then
            continue
        fi
        
        # Validate module directory
        if ! validate_module_directory "$module_dir"; then
            continue
        fi
        
        # Determine dockerfile name
        local dockerfile_name
        if [[ -n "$module_version" ]]; then
            dockerfile_name="${module_version}.dockerfile"
        else
            dockerfile_name="dockerfile"
        fi
        
        local dockerfile_path="${module_dir}/${dockerfile_name}"
        
        if [[ -f "$dockerfile_path" ]] && [[ -r "$dockerfile_path" ]]; then
            echo "$module_dir"
            return 0
        fi
    done
    
    return 1
}

# List available versions for a module
list_available_versions() {
    local module_name="$1"
    local versions=()
    
    local search_paths
    read -ra search_paths <<< "$(get_module_search_paths)"
    
    for base_path in "${search_paths[@]}"; do
        local module_dir="${base_path}/${module_name}"
        
        if [[ ! -d "$module_dir" ]]; then
            continue
        fi
        
        # Find all .dockerfile files
        while IFS= read -r -d '' dockerfile; do
            local basename
            basename=$(basename "$dockerfile")
            if [[ "$basename" == "dockerfile" ]]; then
                versions+=("(no version)")
            else
                # Extract version from filename
                local version="${basename%.dockerfile}"
                versions+=("$version")
            fi
        done < <(find "$module_dir" -maxdepth 1 -name "*.dockerfile" -print0 2>/dev/null)
    done
    
    if [[ ${#versions[@]} -eq 0 ]]; then
        return 1
    fi
    
    printf '%s\n' "${versions[@]}" | sort -u
    return 0
}

# Show module error with helpful information
show_module_error() {
    local module_spec="$1"
    local module_name module_version
    
    read module_name module_version < <(parse_module_spec "$module_spec")
    module_name="${module_name,,}"
    
    log_error "Module not found: $module_spec"
    echo ""
    echo "Searched in:"
    
    local search_paths
    read -ra search_paths <<< "$(get_module_search_paths)"
    
    for base_path in "${search_paths[@]}"; do
        if [[ -n "$module_version" ]]; then
            echo "  - ${base_path}/${module_name}/${module_version}.dockerfile"
        else
            echo "  - ${base_path}/${module_name}/dockerfile"
        fi
    done
    
    # Show available versions
    echo ""
    if available_versions=$(list_available_versions "$module_name" 2>/dev/null); then
        echo "Available ${module_name} versions:"
        while IFS= read -r version; do
            echo "  - $version"
        done <<< "$available_versions"
    else
        echo "Module '${module_name}' not found in any search path."
    fi
}

# Helper: Get module file path for a given type
_get_module_file_path() {
    local module_spec="$1"
    local file_type="$2"  # "dockerfile", "mounts", "env"
    local module_name module_version
    
    read module_name module_version < <(parse_module_spec "$module_spec")
    
    local module_dir
    module_dir=$(find_module "$module_spec") || return 1
    
    # Determine filename based on type and version
    local filename
    if [[ -n "$module_version" ]]; then
        filename="${module_version}.${file_type}"
    else
        filename="$file_type"
    fi
    
    echo "${module_dir}/${filename}"
}

# Load module dockerfile content
load_module_dockerfile() {
    local module_spec="$1"
    local dockerfile_path
    
    dockerfile_path=$(_get_module_file_path "$module_spec" "dockerfile") || {
        show_module_error "$module_spec"
        return 1
    }
    
    # Validate file
    if [[ ! -f "$dockerfile_path" ]]; then
        log_error "Dockerfile not found: $dockerfile_path"
        return 1
    fi
    
    if [[ ! -r "$dockerfile_path" ]]; then
        log_error "Dockerfile not readable: $dockerfile_path"
        return 1
    fi
    
    # Check file size (max 1MB)
    local file_size
    file_size=$(stat -c%s "$dockerfile_path" 2>/dev/null || stat -f%z "$dockerfile_path" 2>/dev/null)
    if [[ -z "$file_size" ]]; then
        log_error "Cannot determine file size: $dockerfile_path"
        return 1
    fi
    if [[ $file_size -eq 0 ]]; then
        log_error "Dockerfile is empty: $dockerfile_path"
        return 1
    fi
    if [[ $file_size -gt 1048576 ]]; then
        log_error "Dockerfile too large (>1MB): $dockerfile_path"
        return 1
    fi
    
    cat "$dockerfile_path"
}

# Load module mounts
load_module_mounts() {
    local module_spec="$1"
    local mounts_path
    
    mounts_path=$(_get_module_file_path "$module_spec" "mounts") || return 1
    
    # Mounts file is optional
    if [[ ! -f "$mounts_path" ]]; then
        return 0
    fi
    
    if [[ ! -r "$mounts_path" ]]; then
        log_error "Mounts file not readable: $mounts_path"
        return 1
    fi
    
    # Read and validate each mount
    while IFS= read -r mount_spec; do
        # Skip empty lines and comments
        [[ -z "$mount_spec" ]] && continue
        [[ "$mount_spec" =~ ^[[:space:]]*# ]] && continue
        
        # Validate mount
        if ! validate_mount_path "$mount_spec"; then
            log_error "Invalid mount in module $module_spec: $mount_spec"
            return 1
        fi
        
        echo "$mount_spec"
    done < "$mounts_path"
}

# Load module environment variables
load_module_env() {
    local module_spec="$1"
    local env_path
    
    env_path=$(_get_module_file_path "$module_spec" "env") || return 1
    
    # Env file is optional
    if [[ ! -f "$env_path" ]]; then
        return 0
    fi
    
    if [[ ! -r "$env_path" ]]; then
        log_error "Environment file not readable: $env_path"
        return 1
    fi
    
    # Read and validate each variable
    while IFS= read -r env_spec; do
        # Skip empty lines and comments
        [[ -z "$env_spec" ]] && continue
        [[ "$env_spec" =~ ^[[:space:]]*# ]] && continue
        
        # Validate env var
        if ! validate_env_var "$env_spec"; then
            log_error "Invalid environment variable in module $module_spec: $env_spec"
            return 1
        fi
        
        echo "$env_spec"
    done < "$env_path"
}

#############################################
# Configuration File Functions
#############################################

# Find .agentbox config file by searching upward
find_agentbox_config() {
    local search_dir="$PROJECT_DIR"
    
    while [[ "$search_dir" != "/" ]]; do
        if [[ -f "${search_dir}/.agentbox" ]]; then
            echo "${search_dir}/.agentbox"
            return 0
        fi
        search_dir=$(dirname "$search_dir")
    done
    
    # Not found
    return 1
}

# Parse .agentbox config file and extract modules
parse_agentbox_config() {
    local config_file="$1"
    
    # Check if file exists and is readable
    if [[ ! -f "$config_file" ]] || [[ ! -r "$config_file" ]]; then
        log_error "Config file not readable: $config_file"
        return 1
    fi
    
    # Use yq to parse YAML
    if ! command -v yq &>/dev/null; then
        log_error "yq not found. Required for parsing .agentbox config."
        return 1
    fi
    
    # Validate YAML syntax
    if ! yq eval . "$config_file" &>/dev/null; then
        log_error "Invalid YAML syntax in $config_file"
        return 1
    fi
    
    # Extract modules array
    local modules_json
    modules_json=$(yq eval '.modules // []' -o json "$config_file" 2>/dev/null)
    
    if [[ -z "$modules_json" ]] || [[ "$modules_json" == "null" ]] || [[ "$modules_json" == "[]" ]]; then
        # No modules specified, return empty
        return 0
    fi
    
    # Parse JSON array and validate each module
    local modules=()
    local seen_modules=()
    
    while IFS= read -r module_spec; do
        # Skip empty
        [[ -z "$module_spec" ]] && continue
        
        # Normalize to lowercase
        module_spec="${module_spec,,}"
        
        # Parse and validate module name
        local module_name
        read module_name _ < <(parse_module_spec "$module_spec")
        
        # Validate module name
        if ! validate_module_name "$module_name"; then
            log_error "Invalid module name in config: $module_spec"
            return 1
        fi
        
        # Check for duplicates
        if [[ " ${seen_modules[*]} " =~ " ${module_spec} " ]]; then
            log_error "Duplicate module in .agentbox: $module_spec"
            return 1
        fi
        
        seen_modules+=("$module_spec")
        modules+=("$module_spec")
    done < <(echo "$modules_json" | jq -r '.[]' 2>/dev/null)
    
    # Output modules one per line
    printf '%s\n' "${modules[@]}"
}

# Get modules list from config or empty for base-only
get_modules_list() {
    local config_file
    
    # Try to find config file
    if ! config_file=$(find_agentbox_config); then
        # No config found, use base image only
        return 0
    fi
    
    log_info "Found config: $config_file"
    
    # Parse config file
    local modules
    if ! modules=$(parse_agentbox_config "$config_file"); then
        return 1
    fi
    
    # Validate all modules exist before proceeding
    if [[ -n "$modules" ]]; then
        while IFS= read -r module_spec; do
            if ! find_module "$module_spec" &>/dev/null; then
                show_module_error "$module_spec"
                return 1
            fi
        done <<< "$modules"
    fi
    
    echo "$modules"
}

#############################################
# Dynamic Dockerfile Generation Functions
#############################################

# Generate Dockerfile from base + modules
generate_dockerfile() {
    local modules_list="$1"
    local output_file="$2"

    cat "$DOCKERFILE_BASE" > "$output_file"

    # If no modules, we're done
    if [[ -z "$modules_list" ]]; then
        return 0
    fi

    # Add each module's dockerfile content
    while IFS= read -r module_spec; do
        [[ -z "$module_spec" ]] && continue

        echo "" >> "$output_file"
        echo "# Module: $module_spec" >> "$output_file"

        if ! module_content=$(load_module_dockerfile "$module_spec"); then
            log_error "Failed to load module: $module_spec"
            return 1
        fi

        echo "$module_content" >> "$output_file"

        # Load module environment variables and emit as ENV instructions
        local module_env
        if module_env=$(load_module_env "$module_spec" 2>/dev/null); then
            while IFS= read -r env_spec; do
                [[ -z "$env_spec" ]] && continue

                # Parse VAR=value
                local var_name var_value
                IFS== read -r var_name var_value <<< "$env_spec"

                echo "ENV ${var_name}=${var_value}" >> "$output_file"
            done <<< "$module_env"
        fi
    done <<< "$modules_list"

    return 0
}

# Calculate hash of all build inputs
get_image_hash() {
    local modules_list="$1"
    local config_file
    
    # Find config file (if exists)
    config_file=$(find_agentbox_config 2>/dev/null) || config_file=""
    
    # Combine all inputs for hashing
    local hash_input=""
    
    # 1. Project directory path
    hash_input+="PROJECT_DIR:${PROJECT_DIR}"$'\n'
    
    # 2. Config file content (if exists)
    if [[ -n "$config_file" ]] && [[ -f "$config_file" ]]; then
        hash_input+="CONFIG:"$(cat "$config_file")$'\n'
    fi
    
    # 3. Dockerfile.base content
    hash_input+="DOCKERFILE_BASE:"$(cat "$DOCKERFILE_BASE")$'\n'
    
    # 4. Module files content
    if [[ -n "$modules_list" ]]; then
        while IFS= read -r module_spec; do
            [[ -z "$module_spec" ]] && continue
            
            # Dockerfile content
            local dockerfile_content
            dockerfile_content=$(load_module_dockerfile "$module_spec" 2>/dev/null) || continue
            hash_input+="MODULE_DOCKERFILE:${module_spec}:${dockerfile_content}"$'\n'
            
            # Mounts content
            local mounts_content
            mounts_content=$(load_module_mounts "$module_spec" 2>/dev/null) || mounts_content=""
            if [[ -n "$mounts_content" ]]; then
                hash_input+="MODULE_MOUNTS:${module_spec}:${mounts_content}"$'\n'
            fi
            
            # Env content
            local env_content
            env_content=$(load_module_env "$module_spec" 2>/dev/null) || env_content=""
            if [[ -n "$env_content" ]]; then
                hash_input+="MODULE_ENV:${module_spec}:${env_content}"$'\n'
            fi
        done <<< "$modules_list"
    fi
    
    # Calculate SHA-256 and take first 8 characters
    echo -n "$hash_input" | sha256sum | cut -c1-8
}

# Get image name based on config
get_image_name() {
    local modules_list="$1"
    
    if [[ -z "$modules_list" ]]; then
        echo "agentbox:base"
    else
        local hash
        hash=$(get_image_hash "$modules_list")
        echo "agentbox:${hash}"
    fi
}
