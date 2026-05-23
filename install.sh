#!/bin/bash

set -e

SCRIPT_NAME="vaultkit"
INSTALL_DIR="$HOME/.local/bin"
LIB_DIR="$INSTALL_DIR/lib"
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"

VAULT_DIR="${VAULT_DIR:-$HOME/Documentos/Notes}"
SNIPPETS_DIR="${SNIPPETS_DIR:-$VAULT_DIR/01 Snippets}"
EDITOR_APP="${EDITOR_APP:-mousepad}"

# Terminal usado pela busca fzf (Buscar no terminal). Auto-detecta se nao definido.
detect_terminal() {
    local t
    for t in konsole kitty alacritty wezterm foot ghostty gnome-terminal xterm; do
        command -v "$t" >/dev/null 2>&1 && { echo "$t"; return 0; }
    done
    echo "xterm"
}
TERMINAL_APP="${TERMINAL_APP:-$(detect_terminal)}"

echo "=== vaultkit :: instalador ==="

# -----------------------------------------------------------------------------
# Verificar dependências
# -----------------------------------------------------------------------------
missing=0

# Rofi
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    echo "[i] sessao Wayland detectada"
    if command -v rofi >/dev/null 2>&1 && rofi -version 2>/dev/null | grep -qi wayland; then
        echo "[ok] rofi-wayland"
    elif command -v rofi >/dev/null 2>&1; then
        echo "[!] rofi instalado, mas pode nao ter suporte a Wayland."
    else
        echo "[x] rofi-wayland nao encontrado"
        missing=1
    fi

    if command -v wl-copy >/dev/null 2>&1; then
        echo "[ok] wl-clipboard"
    else
        echo "[x] wl-clipboard nao encontrado"
        missing=1
    fi
else
    echo "[i] sessao X11 detectada"
    if command -v rofi >/dev/null 2>&1; then
        echo "[ok] rofi"
    else
        echo "[x] rofi nao encontrado"
        missing=1
    fi

    if command -v xclip >/dev/null 2>&1; then
        echo "[ok] xclip"
    else
        echo "[x] xclip nao encontrado"
        missing=1
    fi
fi

# Clipboard
if command -v notify-send >/dev/null 2>&1; then
    echo "[ok] libnotify"
else
    echo "[x] libnotify nao encontrado (notify-send)"
    missing=1
fi

# Opcionais para busca de conteúdo
if command -v rg >/dev/null 2>&1; then
    echo "[ok] ripgrep (busca de conteudo)"
else
    echo "[!] ripgrep nao encontrado — busca de conteudo desabilitada"
fi

if command -v fzf >/dev/null 2>&1; then
    echo "[ok] fzf (busca de notas/blocos)"
else
    echo "[!] fzf nao encontrado — busca de notas requer fzf"
fi

if command -v xdotool >/dev/null 2>&1; then
    echo "[ok] xdotool (digitar snippets)"
else
    echo "[!] xdotool nao encontrado — funcao 'Digitar' usara clipboard"
fi

if [ "$missing" -eq 1 ]; then
    echo ""
    echo "Instale as dependencias obrigatorias e rode novamente."
    echo ""
    echo "  Debian/Ubuntu:"
    echo "    sudo apt install rofi xclip libnotify-bin ripgrep"
    echo ""
    echo "  Arch/Manjaro:"
    echo "    sudo pacman -S rofi xclip libnotify ripgrep"
    echo ""
    echo "  Fedora:"
    echo "    sudo dnf install rofi xclip libnotify ripgrep"
    exit 1
fi

# -----------------------------------------------------------------------------
# Instalar
# -----------------------------------------------------------------------------
echo ""
echo "[i] instalando..."

mkdir -p "$INSTALL_DIR" "$LIB_DIR" "$SNIPPETS_DIR"

# Script principal
cp "$SOURCE_DIR/$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# Libs internas
for lib in config.sh core.sh note-search.sh ui-rofi.sh; do
    if [ -f "$SOURCE_DIR/lib/$lib" ]; then
        cp "$SOURCE_DIR/lib/$lib" "$LIB_DIR/$lib"
        chmod +x "$LIB_DIR/$lib"
    fi
done

# Configuração
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/vaultkit"
CONFIG_FILE="$CONFIG_DIR/config"

if [ ! -f "$CONFIG_FILE" ]; then
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" <<EOF
# vaultkit — configuracao
# Pastas de busca / exemplos
VAULT_DIR="$VAULT_DIR"
SNIPPETS_DIR="$SNIPPETS_DIR"
# Aplicativos
EDITOR_APP="$EDITOR_APP"
TERMINAL_APP="$TERMINAL_APP"   # terminal aberto pela busca (Buscar no terminal)
# Uso padrao
DEFAULT_SORT="recent"
HISTORY_LIMIT="40"
PREVIEW_LINES="5"
CACHE_TTL="30"
EOF
    echo "[ok] configuracao criada em $CONFIG_FILE"
else
    echo "[i] configuracao existente em $CONFIG_FILE (nao modificada)"
fi

# -----------------------------------------------------------------------------
# Limpeza de versoes anteriores (predecessores do vaultkit)
# Remove apenas os arquivos que o vaultkit substitui. Nao toca em outras
# ferramentas (clipa, gca, transcribe, etc.).
# -----------------------------------------------------------------------------
echo ""
echo "[i] removendo predecessores (snippet-holder / note_search)..."

legacy_bin=(
    "$INSTALL_DIR/snippet-holder.sh"
    "$INSTALL_DIR/snippet-holder"
    "$INSTALL_DIR/note_search.sh"
    "$INSTALL_DIR/note_lib.sh"
)
legacy_libs=(
    "$LIB_DIR/clipboard.sh"
    "$LIB_DIR/filesystem.sh"
    "$LIB_DIR/rofi_ui.sh"
    "$LIB_DIR/snippets.sh"
    "$LIB_DIR/search.sh"
)
for f in "${legacy_bin[@]}" "${legacy_libs[@]}"; do
    if [ -e "$f" ]; then
        rm -f "$f"
        echo "    - removido $f"
    fi
done

echo ""
echo "[ok] instalado em $INSTALL_DIR/$SCRIPT_NAME"
echo "[ok] bibliotecas em $LIB_DIR/"
echo "[ok] vault: $VAULT_DIR"
echo "[ok] snippets: $SNIPPETS_DIR"
echo "[ok] editor: $EDITOR_APP"
echo "[ok] terminal: $TERMINAL_APP"
echo ""
echo "Execute: vaultkit"
