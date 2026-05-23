#!/bin/bash

set -e

SCRIPT_NAME="vaultkit"
INSTALL_DIR="$HOME/.local/bin"
LIB_DIR="$INSTALL_DIR/lib"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/vaultkit"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/vaultkit"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/vaultkit"

echo "=== vaultkit :: desinstalador ==="

removed=0

if [ -f "$INSTALL_DIR/$SCRIPT_NAME" ]; then
    rm "$INSTALL_DIR/$SCRIPT_NAME"
    echo "[ok] removido $INSTALL_DIR/$SCRIPT_NAME"
    removed=1
fi

if [ -d "$LIB_DIR" ]; then
    for lib in config.sh core.sh note-search.sh ui-rofi.sh; do
        if [ -f "$LIB_DIR/$lib" ]; then
            rm "$LIB_DIR/$lib"
            removed=1
        fi
    done
    [ "$removed" -eq 1 ] && echo "[ok] removidos modulos em $LIB_DIR/"
fi

echo ""
echo "[i] Os seguintes dados NAO foram removidos (preservados):"
echo "    - Configuracao: $CONFIG_DIR"
echo "    - Historico/favoritos: $DATA_DIR"
echo "    - Cache: $CACHE_DIR"
echo "    - Vault e snippets (definidos na config)"
echo ""
echo "Para remover tudo manualmente:"
echo "    rm -rf \"$CONFIG_DIR\" \"$DATA_DIR\" \"$CACHE_DIR\""

if [ "$removed" -eq 1 ]; then
    echo ""
    echo "[ok] vaultkit desinstalado."
else
    echo ""
    echo "[i] vaultkit nao encontrado em $INSTALL_DIR"
fi
