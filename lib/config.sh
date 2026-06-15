#!/bin/bash

# =============================================================================
# config.sh — Configuração centralizada do vaultkit
# XDG-compliant: ~/.config/vaultkit/config
# =============================================================================

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/vaultkit"
CONFIG_FILE="$CONFIG_DIR/config"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/vaultkit"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/vaultkit"
TEMPLATE_DIR="$CONFIG_DIR/templates"

HISTORY_FILE="$DATA_DIR/history"
FAVORITES_FILE="$DATA_DIR/favorites"

DATE_FORMAT="$(date +%Y-%m-%d)"

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    fi

    VAULT_DIR="${VAULT_DIR:-$HOME/Documentos/Notes}"
    SNIPPETS_DIR="${SNIPPETS_DIR:-$VAULT_DIR/01 Snippets}"
    EDITOR_APP="${EDITOR_APP:-mousepad}"
    TERMINAL_APP="${TERMINAL_APP:-$(detect_terminal)}"
    DEFAULT_SORT="${DEFAULT_SORT:-recent}"
    HISTORY_LIMIT="${HISTORY_LIMIT:-40}"
    PREVIEW_LINES="${PREVIEW_LINES:-5}"
    CACHE_TTL="${CACHE_TTL:-30}"

    # Propagate para core.sh / note-search.sh
    export VAULT_DIR SNIPPETS_DIR EDITOR_APP TERMINAL_APP
}

# Detecta um terminal disponível (fallback quando TERMINAL_APP não está no config)
detect_terminal() {
    local t
    for t in konsole kitty alacritty wezterm foot ghostty gnome-terminal xterm; do
        if command -v "$t" >/dev/null 2>&1; then
            echo "$t"
            return 0
        fi
    done
    echo "xterm"
}

ensure_dirs() {
    mkdir -p "$VAULT_DIR" "$SNIPPETS_DIR" "$DATA_DIR" "$CACHE_DIR" "$CONFIG_DIR" "$TEMPLATE_DIR"
    touch "$HISTORY_FILE" "$FAVORITES_FILE" 2>/dev/null || true
}

write_default_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        mkdir -p "$CONFIG_DIR"
        cat > "$CONFIG_FILE" <<EOF
# vaultkit — configuração
# Pastas de busca / exemplos
VAULT_DIR="$HOME/Documentos/Notes"
SNIPPETS_DIR="$HOME/Documentos/Notes/01 Snippets"
# Aplicativos
EDITOR_APP="mousepad"
TERMINAL_APP="$(detect_terminal)"   # terminal aberto pela busca (Buscar no terminal)
# Uso padrão
DEFAULT_SORT="recent"
HISTORY_LIMIT="40"
PREVIEW_LINES="5"
CACHE_TTL="30"
EOF
    fi
}

save_config() {
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" <<EOF
# vaultkit — configuração
# Pastas de busca / exemplos
VAULT_DIR="$VAULT_DIR"
SNIPPETS_DIR="$SNIPPETS_DIR"
# Aplicativos
EDITOR_APP="$EDITOR_APP"
TERMINAL_APP="$TERMINAL_APP"   # terminal aberto pela busca (Buscar no terminal)
# Uso padrão
DEFAULT_SORT="$DEFAULT_SORT"
HISTORY_LIMIT="$HISTORY_LIMIT"
PREVIEW_LINES="$PREVIEW_LINES"
CACHE_TTL="$CACHE_TTL"
EOF
}
