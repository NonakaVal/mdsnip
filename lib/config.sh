#!/bin/bash

# =============================================================================
# config.sh — Configuração centralizada do mdsnip
# XDG-compliant: ~/.config/mdsnip/config
# =============================================================================

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mdsnip"
CONFIG_FILE="$CONFIG_DIR/config"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/mdsnip"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/mdsnip"
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
    SNIPPETS_DIR="${SNIPPETS_DIR:-$VAULT_DIR/Snippets}"
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

_config_quote() {
    local value="$1" quoted="" char i
    for ((i = 0; i < ${#value}; i++)); do
        char="${value:i:1}"
        if [[ "$char" == $'\\' || "$char" == '"' || "$char" == '$' || "$char" == '`' ]]; then
            quoted+="\\$char"
        else
            quoted+="$char"
        fi
    done
    printf '"%s"' "$quoted"
}

write_default_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        mkdir -p "$CONFIG_DIR"
        {
            printf '# mdsnip — configuração\n'
            printf '# Pastas de busca / exemplos\n'
            printf 'VAULT_DIR=%s\n' "$(_config_quote "$HOME/Documentos/Notes")"
            printf 'SNIPPETS_DIR=%s\n' "$(_config_quote "$HOME/Documentos/Notes/Snippets")"
            printf '# Aplicativos\n'
            printf 'EDITOR_APP=%s\n' "$(_config_quote "mousepad")"
            printf 'TERMINAL_APP=%s   # terminal aberto pela busca (Buscar no terminal)\n' "$(_config_quote "$(detect_terminal)")"
            printf '# Uso padrão\n'
            printf 'DEFAULT_SORT=%s\n' "$(_config_quote "recent")"
            printf 'HISTORY_LIMIT=%s\n' "$(_config_quote "40")"
            printf 'PREVIEW_LINES=%s\n' "$(_config_quote "5")"
            printf 'CACHE_TTL=%s\n' "$(_config_quote "30")"
        } > "$CONFIG_FILE"
    fi
}

save_config() {
    mkdir -p "$CONFIG_DIR"
    {
        printf '# mdsnip — configuração\n'
        printf '# Pastas de busca / exemplos\n'
        printf 'VAULT_DIR=%s\n' "$(_config_quote "$VAULT_DIR")"
        printf 'SNIPPETS_DIR=%s\n' "$(_config_quote "$SNIPPETS_DIR")"
        printf '# Aplicativos\n'
        printf 'EDITOR_APP=%s\n' "$(_config_quote "$EDITOR_APP")"
        printf 'TERMINAL_APP=%s   # terminal aberto pela busca (Buscar no terminal)\n' "$(_config_quote "$TERMINAL_APP")"
        printf '# Uso padrão\n'
        printf 'DEFAULT_SORT=%s\n' "$(_config_quote "$DEFAULT_SORT")"
        printf 'HISTORY_LIMIT=%s\n' "$(_config_quote "$HISTORY_LIMIT")"
        printf 'PREVIEW_LINES=%s\n' "$(_config_quote "$PREVIEW_LINES")"
        printf 'CACHE_TTL=%s\n' "$(_config_quote "$CACHE_TTL")"
    } > "$CONFIG_FILE"
}
