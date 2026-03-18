#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="install-skills.log"
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
}

MANIFEST="skills-manifest.yaml"
if [ ! -f "$MANIFEST" ]; then
    error "Manifest file $MANIFEST not found."
    exit 1
fi

log "Installing ClawHub CLI..."
sudo npm install -g clawhub

log "Parsing and installing skills from $MANIFEST..."

# Function to check required binaries
check_binaries() {
    local skill_name=$1
    local binaries=$2
    if [ "$binaries" == "null" ] || [ -z "$binaries" ]; then
        return 0
    fi
    
    # Remove brackets and quotes, split by comma
    local clean_bins=$(echo "$binaries" | sed 's/\[//g; s/\]//g; s/"//g; s/ //g')
    IFS=',' read -ra BINS <<< "$clean_bins"
    
    for bin in "${BINS[@]}"; do
        if ! command -v "$bin" &> /dev/null; then
            error "Skill '$skill_name' requires binary '$bin' which is not found in PATH."
            return 1
        fi
    done
    return 0
}

# Process community skills
echo "Processing community skills..."
jq -r '.community_skills[] | select(.enabled==true) | "\(.name)|\(.repo_or_registry)|\(.install_path)|\(.required_binaries)"' <(yq '.' "$MANIFEST") | while IFS='|' read -r name registry path bins; do
    log "Installing skill: $name"
    
    if ! check_binaries "$name" "$bins"; then
        log "Skipping $name due to missing dependencies."
        continue
    fi
    
    # Expand tilde in path
    eval expanded_path="$path"
    mkdir -p "$expanded_path"
    
    # Install via clawhub
    log "Running: clawhub install $registry --workdir $(dirname "$expanded_path")"
    CLAWHUB_WORKDIR=$(dirname "$expanded_path") clawhub install "$registry" --force || {
        error "Failed to install $name via ClawHub."
        continue
    }
    
    # Verify SKILL.md
    if [ -f "$expanded_path/$registry/SKILL.md" ]; then
        log "Successfully installed $name. SKILL.md verified."
    else
        error "SKILL.md not found for $name at $expanded_path/$registry"
    fi
done

log "Checking eligibility of all skills..."
openclaw skills list --eligible || log "Please start the gateway first to see eligible skills."

log "Skill installation complete."
