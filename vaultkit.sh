#!/usr/bin/env bash

# =============================================================================
# vaultkit — Gerenciador unificado de snippets + notas + blocos via Rofi
# Repositório isolado. Sem dependência de scripts externos.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

# Carrega módulos internos (ordem importa)
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/ui-rofi.sh"

# -----------------------------------------------------------------------------
# Inicialização
# -----------------------------------------------------------------------------
load_config
ensure_dirs
write_default_config
create_default_templates

# =============================================================================
# Navegador de snippets (loop de pastas)
# =============================================================================
browser() {
    local current_dir="$SNIPPETS_DIR"
    local sort_mode="$DEFAULT_SORT"

    while true; do
        local label msg entries selection ret dir_summary
        label="$(short_path "$current_dir")"

        dir_summary=""
        local dir_count
        dir_count=$(find "$current_dir" -mindepth 1 -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l)
        local sub_count
        sub_count=$(find "$current_dir" -mindepth 1 -maxdepth 1 -type d ! -name '.*' 2>/dev/null | wc -l)
        dir_summary="${dir_count}"
        (( sub_count > 0 )) && dir_summary="${dir_summary} · ${sub_count} pastas"

        [ "$sort_mode" = "recent" ] \
            && msg="+n novo · +g grupo · +o ordem · +q voltar · +w ir para · ${dir_summary}" \
            || msg="+n novo · +g grupo · +o ordem · +q voltar · +w ir para · A-Z · ${dir_summary}"

        entries="$(list_entries "$current_dir" "$sort_mode")"

        ret=0
        selection=$(echo "$entries" | rofi_menu \
            -p "$label" \
            -display-columns 1 \
            -mesg "$msg" \
            -kb-custom-1 "Alt+n" \
            -kb-custom-2 "Alt+g" \
            -kb-custom-3 "Alt+o" \
            -kb-custom-4 "Alt+q" \
            -kb-custom-5 "Alt+w") || ret=$?

        case "$ret" in
            10) new_snippet "$current_dir" ;;
            11)
                local new_dir
                new_dir="$(create_group "$current_dir")" || continue
                [ -n "$new_dir" ] && current_dir="$new_dir"
                ;;
            12)
                [ "$sort_mode" = "recent" ] && sort_mode="az" || sort_mode="recent"
                ;;
            13)
                [ "$current_dir" != "$SNIPPETS_DIR" ] && current_dir="$(dirname "$current_dir")"
                ;;
            14)
                _switch_folder "$current_dir"
                current_dir="$_switch_result"
                unset _switch_result
                ;;
            0)
                [ -z "$selection" ] && continue

                local entry_type entry_path
                entry_type="$(echo "$selection" | cut -f2)"
                entry_path="$(echo "$selection" | cut -f3)"

                case "$entry_type" in
                    "UP")  current_dir="$entry_path" ;;
                    "DIR") current_dir="$entry_path" ;;
                    "SEP") continue ;;
                    "FILE")
                        show_actions "$entry_path"
                        [ $? -eq 99 ] && exit 0
                        ;;
                esac
                ;;
            *) exit 0 ;;
        esac
    done
}

# =============================================================================
# Buscar no terminal — fecha o rofi e abre o terminal configurável com a busca
# fzf (note-search.sh) já rodando, para filtrar/selecionar/adicionar direto lá.
# Terminal definido em TERMINAL_APP (config), com detect_terminal() de fallback.
# =============================================================================
open_search() {
    local term="${TERMINAL_APP:-$(detect_terminal)}"
    local term_bin="${term%% *}"

    if ! command -v "$term_bin" >/dev/null 2>&1; then
        notify-send "vaultkit" "Terminal '$term_bin' não encontrado. Ajuste TERMINAL_APP no config."
        return 1
    fi

    # Roda a busca; ao sair do fzf mantém o shell aberto para uso direto.
    local cmd="source \"$SCRIPT_DIR/lib/note-search.sh\"; nf; exec bash"

    case "$term_bin" in
        konsole)         konsole -e bash -c "$cmd" & ;;
        gnome-terminal)  gnome-terminal -- bash -c "$cmd" & ;;
        kitty)           kitty bash -c "$cmd" & ;;
        *)               "$term_bin" -e bash -c "$cmd" & ;;
    esac

    disown
}

# =============================================================================
# Menu principal — tudo num único Rofi
# =============================================================================
main_menu() {
    local options choice
    options="$(printf "Navegar snippets\nHistorico\nFavoritos\nBuscar por tag\nBuscar no terminal\nConfiguracoes\nExportar\nImportar")"

    choice=$(echo "$options" | rofi_menu -p "") || return 0

    case "$choice" in
        "Navegar snippets")
            browser
            ;;
        "Historico")
            local entries chosen path
            entries="$(list_history)"
            [ -z "$entries" ] && notify-send "VaultKit" "Historico vazio." && return 0
            chosen=$(echo -e "$entries" | rofi_menu -p "historico") || return 0
            [ -z "$chosen" ] && return 0
            path="$(echo "$chosen" | cut -f3)"
            show_actions "$path"
            ;;
        "Favoritos")
            local entries chosen path
            entries="$(list_favorites)"
            [ -z "$entries" ] && notify-send "VaultKit" "Nenhum favorito." && return 0
            chosen=$(echo -e "$entries" | rofi_menu -p "favoritos") || return 0
            [ -z "$chosen" ] && return 0
            path="$(echo "$chosen" | cut -f3)"
            show_actions "$path"
            ;;
        "Buscar por tag")
            browse_by_tag
            ;;
        "Buscar no terminal")
            open_search
            ;;
        "Configuracoes")
            open_settings
            ;;
        "Exportar")
            export_snippets
            ;;
        "Importar")
            local archive
            archive=$(rofi_menu -p "Caminho do .tar.gz") || return 0
            [ -z "$archive" ] && return 0
            if [ ! -f "$archive" ]; then
                notify-send "VaultKit" "Arquivo nao encontrado."
                return 0
            fi
            import_snippets "$archive"
            ;;
    esac
}

# =============================================================================
# Busca por tag
# =============================================================================
browse_by_tag() {
    local tag
    local all_tags
    all_tags="$(collect_all_tags)"

    if [ -z "$all_tags" ]; then
        notify-send "VaultKit" "Nenhuma tag encontrada."
        return 0
    fi

    tag=$(echo "$all_tags" | rofi_menu -p "tag") || return 0
    [ -z "$tag" ] && return 0

    local results=""
    while IFS= read -r -d '' file; do
        if get_snippet_tags "$file" | grep -qiEx "$tag"; then
            local name
            name="$(basename "$file" .md)"
            results="${results}${name}\tFILE\t${file}\n"
        fi
    done < <(find "$SNIPPETS_DIR" -type f -name "*.md" -print0 2>/dev/null | sort -z)

    if [ -z "$results" ]; then
        notify-send "VaultKit" "Nenhum snippet com tag: $tag"
        return 0
    fi

    local chosen
    chosen=$(echo -ne "$results" | rofi_menu -p "$tag") || return 0
    [ -z "$chosen" ] && return 0

    local entry_path
    entry_path="$(echo "$chosen" | cut -f3)"
    show_actions "$entry_path"
}

# =============================================================================
# Entry point
# =============================================================================
main_menu
