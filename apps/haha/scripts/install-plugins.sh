#!/bin/bash
# Enhanced WordPress Plugin Installer for haha
# Uses WP-CLI when possible, falls back to manual download when needed

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
TIMEOUT_DURATION=60
PLUGINS_DIR="./wp-content/plugins"
LOG_FILE="plugin_install_$(date +%Y%m%d_%H%M%S).log"

print_status() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
print_debug() { echo -e "${PURPLE}[DEBUG]${NC} $1" | tee -a "$LOG_FILE"; }

show_help() {
    echo "WordPress Plugin Installer for haha"
    echo ""
    echo "Usage: $0 [OPTIONS] <plugins-file>"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -d, --dry-run  Show what would be installed without actually installing"
    echo "  -v, --verbose  Enable verbose output"
    echo "  -f, --force    Force reinstall even if plugin exists"
    echo ""
    echo "Example: $0 plugins.txt"
    echo "         $0 --dry-run plugins.txt"
}

check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker is not installed or not in PATH"
        return 1
    fi
    
    if ! docker compose run --rm wpcli core is-installed >/dev/null 2>&1; then
        print_error "WordPress is not installed yet. Please run 'make setup' first."
        return 1
    fi
    
    if ! docker compose run --rm wpcli --version >/dev/null 2>&1; then
        print_error "WP-CLI is not accessible"
        return 1
    fi
    
    print_success "Prerequisites check passed."
    return 0
}

setup_permissions() {
    print_status "Setting up file permissions..."
    
    # Create necessary directories
    mkdir -p wp-content/{upgrade,uploads,plugins,themes} 2>/dev/null || true
    
    print_success "Permissions setup completed."
}

validate_plugin_name() {
    local plugin="$1"
    # Basic validation: plugin names should only contain letters, numbers, hyphens, and underscores
    if [[ ! "$plugin" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 1
    fi
    return 0
}

check_plugin_exists_on_repo() {
    local plugin="$1"
    local url="https://wordpress.org/plugins/$plugin/"
    
    if [ "$VERBOSE" = true ]; then
        print_debug "Checking plugin existence at: $url"
    fi
    
    # Try multiple methods to check if plugin exists
    if command -v curl >/dev/null 2>&1; then
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" --max-time 10)
        if [ "$VERBOSE" = true ]; then
            print_debug "HTTP response code: $http_code"
        fi
        if [ "$http_code" = "200" ]; then
            return 0
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -q --spider --timeout=10 "$url" 2>/dev/null; then
            return 0
        fi
    fi
    
    # If HTTP check fails, still try to download - sometimes the plugin page
    # might be temporarily unavailable but the download still works
    if [ "$VERBOSE" = true ]; then
        print_debug "Plugin page check failed, but will still attempt download"
    fi
    return 1
}

install_plugin_manually() {
    local plugin="$1"
    
    print_status "Trying manual installation for: $plugin"
    
    # Validate plugin name
    if ! validate_plugin_name "$plugin"; then
        print_error "Invalid plugin name: $plugin"
        return 1
    fi
    
    # Check if plugin is already installed using WP-CLI (which sees the Docker volume)
    if docker compose run --rm wpcli plugin is-installed "$plugin" >/dev/null 2>&1; then
        if [ "$FORCE_INSTALL" = true ]; then
            print_status "Force flag set. Removing existing plugin..."
            docker compose run --rm wpcli plugin uninstall "$plugin" >/dev/null 2>&1 || true
        else
            print_warning "Plugin '$plugin' already exists. Activating..."
            if docker compose run --rm wpcli plugin activate "$plugin" >/dev/null 2>&1; then
                print_success "✅ Activated existing plugin: $plugin"
                return 0
            else
                print_error "❌ Failed to activate existing plugin: $plugin"
                return 1
            fi
        fi
    fi
    
    # Check if plugin exists on WordPress.org before downloading
    if ! check_plugin_exists_on_repo "$plugin"; then
        print_warning "Plugin page check failed for '$plugin', but attempting download anyway..."
    fi
    
    # Create temporary directory for download
    local temp_dir=$(mktemp -d)
    local download_url="https://downloads.wordpress.org/plugin/$plugin.zip"
    
    print_debug "Downloading from: $download_url to temp directory"
    if wget -q --timeout=30 "$download_url" -O "$temp_dir/$plugin.zip"; then
        print_status "Downloaded. Extracting: $plugin"
        if command -v unzip >/dev/null 2>&1; then
            if unzip -q "$temp_dir/$plugin.zip" -d "$temp_dir" 2>/dev/null; then
                # Copy extracted plugin directly to the Docker volume via container
                print_status "Copying plugin to WordPress container..."
                if docker compose run --rm -v "$temp_dir:/tmp/plugin_install" wordpress bash -c "cp -r /tmp/plugin_install/$plugin /var/www/html/wp-content/plugins/ && chown -R www-data:www-data /var/www/html/wp-content/plugins/$plugin" >/dev/null 2>&1; then
                    rm -rf "$temp_dir"
                    print_status "Copied. Activating: $plugin"
                    if docker compose run --rm wpcli plugin activate "$plugin" >/dev/null 2>&1; then
                        print_success "✅ Manually installed and activated: $plugin"
                        return 0
                    else
                        print_error "❌ Manual install succeeded but activation failed: $plugin"
                        return 1
                    fi
                else
                    print_error "❌ Failed to copy plugin to container: $plugin"
                    rm -rf "$temp_dir"
                    return 1
                fi
            else
                print_error "❌ Failed to extract: $plugin"
                rm -rf "$temp_dir"
                return 1
            fi
        else
            print_error "❌ No unzip utility available"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        print_error "❌ Failed to download: $plugin"
        rm -rf "$temp_dir"
        return 1
    fi
}

install_single_plugin() {
    local plugin="$1"
    
    # Validate plugin name
    if ! validate_plugin_name "$plugin"; then
        print_error "Invalid plugin name: $plugin"
        return 1
    fi
    
    # Check if plugin is already installed and active
    if docker compose run --rm wpcli plugin is-installed "$plugin" >/dev/null 2>&1; then
        if [ "$FORCE_INSTALL" = true ]; then
            print_status "Force flag set. Reinstalling plugin: $plugin"
            docker compose run --rm wpcli plugin deactivate "$plugin" >/dev/null 2>&1
            docker compose run --rm wpcli plugin uninstall "$plugin" >/dev/null 2>&1
        elif docker compose run --rm wpcli plugin is-active "$plugin" >/dev/null 2>&1; then
            print_status "Plugin '$plugin' is already active. Skipping."
            return 0
        else
            print_status "Plugin '$plugin' exists but not active. Activating..."
            if docker compose run --rm wpcli plugin activate "$plugin" >/dev/null 2>&1; then
                print_success "✅ Activated existing plugin: $plugin"
                return 0
            else
                print_error "❌ Failed to activate existing plugin: $plugin"
                return 1
            fi
        fi
    fi
    
    if [ "$DRY_RUN" = true ]; then
        print_status "DRY RUN: Would install plugin: $plugin"
        return 0
    fi
    
    print_status "Installing new plugin: $plugin"
    
    # Method 1: Try WP-CLI direct installation
    if [ "$VERBOSE" = true ]; then
        print_debug "Attempting WP-CLI installation with ${TIMEOUT_DURATION}s timeout"
    fi
    
    if timeout "$TIMEOUT_DURATION" docker compose run --rm wpcli plugin install "$plugin" --activate >/dev/null 2>&1; then
        print_success "✅ Installed via WP-CLI: $plugin"
        return 0
    fi
    
    print_warning "WP-CLI install failed. Trying manual method..."
    
    # Method 2: Manual download and installation
    if install_plugin_manually "$plugin"; then
        return 0
    fi
    
    print_error "❌ All installation methods failed for: $plugin"
    return 1
}

parse_plugins_file() {
    local plugins_file="$1"
    local -a plugins=()
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        if [[ ! "$line" =~ ^[[:space:]]*# ]] && [[ -n "${line// }" ]]; then
            plugin=$(echo "$line" | xargs)
            if [ -n "$plugin" ]; then
                plugins+=("$plugin")
            fi
        fi
    done < "$plugins_file"
    
    printf '%s\n' "${plugins[@]}"
}

install_plugins() {
    local plugins_file="$1"
    
    if [ ! -f "$plugins_file" ]; then
        print_error "Plugins file not found: $plugins_file"
        return 1
    fi
    
    print_status "Processing plugins from $plugins_file for haha..."
    
    # Check prerequisites
    if ! check_prerequisites; then
        return 1
    fi
    
    # Setup permissions (only if not dry run)
    if [ "$DRY_RUN" != true ]; then
        setup_permissions
    fi
    
    # Parse plugins file
    readarray -t plugins < <(parse_plugins_file "$plugins_file")
    
    if [ ${#plugins[@]} -eq 0 ]; then
        print_warning "No plugins found in $plugins_file"
        return 0
    fi
    
    print_status "Found ${#plugins[@]} plugins to process"
    
    if [ "$DRY_RUN" = true ]; then
        print_status "DRY RUN MODE - No actual installations will be performed"
        echo ""
    fi
    
    # Install plugins
    local installed_count=0
    local failed_count=0
    local skipped_count=0
    
    for plugin in "${plugins[@]}"; do
        if [ "$VERBOSE" = true ]; then
            print_debug "Processing plugin: $plugin"
        fi
        
        if install_single_plugin "$plugin"; then
            if [ "$DRY_RUN" = true ]; then
                ((skipped_count++))
            else
                ((installed_count++))
            fi
        else
            ((failed_count++))
        fi
        echo "" # Add spacing between plugins
    done
    
    # Summary
    echo ""
    print_status "Installation Summary for haha:"
    if [ "$DRY_RUN" = true ]; then
        print_success "✅ Would process: $skipped_count plugins"
    else
        print_success "✅ Successfully processed: $installed_count plugins"
    fi
    
    if [ $failed_count -gt 0 ]; then
        print_warning "⚠️ Failed to process: $failed_count plugins"
    fi
    
    echo ""
    if [ "$DRY_RUN" != true ]; then
        print_status "Currently active plugins:"
        docker compose run --rm wpcli plugin list --status=active --format=table 2>/dev/null || print_warning "Could not list active plugins"
        
        echo ""
        print_status "Installation log saved to: $LOG_FILE"
    fi
}

# Parse command line arguments
DRY_RUN=false
VERBOSE=false
FORCE_INSTALL=false
PLUGINS_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -f|--force)
            FORCE_INSTALL=true
            shift
            ;;
        -*)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            if [ -z "$PLUGINS_FILE" ]; then
                PLUGINS_FILE="$1"
            else
                print_error "Multiple plugin files specified"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if plugins file was provided
if [ -z "$PLUGINS_FILE" ]; then
    PLUGINS_FILE="plugins.txt"
fi

# Main execution
print_status "WordPress Plugin Installer Started for haha"
print_status "Plugins file: $PLUGINS_FILE"
if [ "$DRY_RUN" = true ]; then
    print_status "Mode: DRY RUN"
fi
if [ "$VERBOSE" = true ]; then
    print_status "Verbose mode: ON"
fi
if [ "$FORCE_INSTALL" = true ]; then
    print_status "Force reinstall: ON"
fi
echo ""

install_plugins "$PLUGINS_FILE"