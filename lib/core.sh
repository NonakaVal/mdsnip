#!/bin/bash

# =============================================================================
# core.sh — Biblioteca interna do vaultkit
# Consolidada de note_lib.sh + filesystem.sh + clipboard.sh
# Sem dependências externas além de ferramentas do sistema.
# =============================================================================

# -----------------------------------------------------------------------------
# Paths (setados por config.sh, defaults aqui)
# -----------------------------------------------------------------------------
VAULT_DIR="${VAULT_DIR:-$HOME/Documentos/Notes}"
SNIPPETS_DIR="${SNIPPETS_DIR:-$VAULT_DIR/01 Snippets}"
INDEX_FILE="$HOME/.local/share/vaultkit/code-index.tsv"
INDEX_MAX_AGE=86400
WORKSPACE_CACHE="$HOME/.local/share/vaultkit/workspace-cache.tsv"

# =============================================================================
# Utility — filename sanitization, field reading
# =============================================================================

safe_filename() {
    local name="$1"
    name="${name//[\/:*?\"<>|]/-}"
    while [[ "$name" == *[[:space:]] ]]; do
        name="${name%?}"
    done
    printf '%s' "$name"
}

safe_dirname() {
    safe_filename "$1"
}

_read_field() {
    local file="$1" field="$2"
    [[ ! -f "$file" ]] && return 1
    awk -v field="$field" '
        BEGIN { in_front = 0 }
        /^---[[:space:]]*$/ {
            if (!in_front) { in_front = 1; next }
            else exit
        }
        in_front && index($0, field ":") == 1 {
            val = $0
            sub(/^[^:]*:[[:space:]]*/, "", val)
            gsub(/^"|"$/, "", val)
            print val
            exit
        }
    ' "$file"
}

ensure_dirs() {
    mkdir -p "$(dirname "$INDEX_FILE")" "$SNIPPETS_DIR"
}

# =============================================================================
# Clipboard & Typing
# =============================================================================

copy_to_clipboard() {
    local text
    text="$(cat)"
    if command -v wl-copy >/dev/null 2>&1 && [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
        printf '%s' "$text" | wl-copy
    elif command -v xclip >/dev/null 2>&1; then
        printf '%s' "$text" | xclip -selection clipboard
    elif command -v wl-copy >/dev/null 2>&1; then
        printf '%s' "$text" | wl-copy
    else
        return 1
    fi
}

read_clipboard() {
    if command -v wl-paste >/dev/null 2>&1 && [ "$XDG_SESSION_TYPE" = "wayland" ]; then
        wl-paste 2>/dev/null
    elif command -v xclip >/dev/null 2>&1; then
        xclip -o -selection clipboard 2>/dev/null
    elif command -v wl-paste >/dev/null 2>&1; then
        wl-paste 2>/dev/null
    fi
}

type_text() {
    local text="$1" delay="${2:-50}"
    if ! command -v xdotool >/dev/null 2>&1; then
        printf '%s' "$text" | copy_to_clipboard
        return 1
    fi
    if (( ${#text} > 5000 )); then
        text="${text:0:5000}"
    fi
    xdotool type --delay "$delay" --clearmodifiers -- "$text"
}

# =============================================================================
# History & Favorites
# =============================================================================

add_to_history() {
    local file="$1"
    touch "$HISTORY_FILE"
    grep -vFx "$file" "$HISTORY_FILE" 2>/dev/null > "$HISTORY_FILE.tmp" || true
    echo "$file" | cat - "$HISTORY_FILE.tmp" > "$HISTORY_FILE"
    head -n "$HISTORY_LIMIT" "$HISTORY_FILE" > "$HISTORY_FILE.tmp"
    mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
}

toggle_favorite() {
    local file="$1"
    local name
    name="$(basename "$file" .md)"
    if grep -qFx "$file" "$FAVORITES_FILE" 2>/dev/null; then
        grep -vFx "$file" "$FAVORITES_FILE" > "$FAVORITES_FILE.tmp" || true
        mv "$FAVORITES_FILE.tmp" "$FAVORITES_FILE"
        notify-send "VaultKit" "\"$name\" removido dos favoritos."
    else
        echo "$file" >> "$FAVORITES_FILE"
        notify-send "VaultKit" "\"$name\" adicionado aos favoritos."
    fi
}

is_favorite() {
    grep -qFx "$1" "$FAVORITES_FILE" 2>/dev/null
}

# =============================================================================
# Code Block Extraction
# =============================================================================

# Output TSV: block_index \t language \t line_start \t line_end \t preview
extract_blocks() {
    local file="$1"
    [[ ! -f "$file" ]] && return 1
    awk '
        BEGIN { in_block = 0; block_idx = 0 }
        /^```/ {
            if (!in_block) {
                in_block = 1; block_idx++
                lang = $0; sub(/^```/, "", lang)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", lang)
                line_start = NR + 1; first_line = ""
                next
            } else {
                preview = (first_line != "") ? first_line : "(empty)"
                if (length(preview) > 80) preview = substr(preview, 1, 77) "..."
                printf "%d\t%s\t%d\t%d\t%s\n", block_idx, lang, line_start, NR - 1, preview
                in_block = 0; next
            }
        }
        in_block && NR >= line_start && first_line == "" { first_line = $0 }
    ' "$file"
}

block_content() {
    local file="$1" target="${2:-1}"
    [[ ! -f "$file" ]] && return 1
    awk -v target="$target" '
        /^```/ {
            if (!in_block) { in_block = 1; block_idx++; next }
            else { if (block_idx == target) exit; in_block = 0; next }
        }
        in_block && block_idx == target { print }
    ' "$file"
}

block_preview() {
    local file="$1" target="${2:-1}" max="${3:-15}"
    block_content "$file" "$target" | head -n "$max"
}

# =============================================================================
# Block Save — save a code block as .md snippet in a workspace folder
# =============================================================================

normalize_snippet_target() {
    local target_dir="$1"
    [[ -z "$target_dir" ]] && return 1

    # Relative path → save inside 01 Snippets
    if [[ "$target_dir" != /* ]]; then
        printf '%s/%s' "$SNIPPETS_DIR" "$target_dir"
        return 0
    fi

    printf '%s' "$target_dir"
}

save_block() {
    local source_file="$1"
    local block_index="${2:-1}"
    local target_dir="$3"
    [[ ! -f "$source_file" ]] && return 1
    [[ -z "$target_dir" ]] && return 1

    target_dir=$(normalize_snippet_target "$target_dir") || return 1
    mkdir -p "$target_dir"

    local language content block_info source_rel
    source_rel="${source_file#$VAULT_DIR/}"

    block_info=$(extract_blocks "$source_file" | awk -v idx="$block_index" '$1 == idx')
    if [[ -n "$block_info" ]]; then
        language=$(printf '%s' "$block_info" | cut -f2)
        content=$(block_content "$source_file" "$block_index")
    else
        language="text"
        content=$(cat "$source_file")
    fi

    local base="${source_file##*/}"
    local item_name
    item_name=$(safe_filename "${base%.md}")
    if (( block_index > 1 )); then
        item_name="${item_name}-bloco-${block_index}"
    fi

    local item_file="$target_dir/${item_name}.md" counter=1
    while [[ -f "$item_file" ]]; do
        item_file="$target_dir/${item_name}-${counter}.md"
        ((counter++))
    done

    {
        printf '%s\n' '---'
        printf 'source: "%s"\n' "$source_rel"
        printf 'block: %s\n' "$block_index"
        printf 'language: %s\n' "${language:-text}"
        printf 'added: %s\n' "$(date +%Y-%m-%d)"
        printf 'tags: []\n'
        printf '%s\n\n' '---'
        printf '%s%s\n' '```' "${language:-}"
        printf '%s\n' "$content"
        printf '%s\n' '```'
    } > "$item_file"

    printf '%s' "$item_file"
}

# =============================================================================
# Workspace (folder) listing & cache
# =============================================================================

list_snippet_folders() {
    local dir="${1:-$SNIPPETS_DIR}"
    [[ ! -d "$dir" ]] && return 0
    local d
    for d in "$dir"/*/; do
        [[ -d "$d" ]] || continue
        local name
        name="$(basename "$d")"
        [[ "$name" == .* ]] && continue
        local count
        count=$(find "$d" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l)
        printf '%s\t%s\n' "$name" "$count"
    done
}

build_workspace_cache() {
    local cache_file="$WORKSPACE_CACHE"
    mkdir -p "$(dirname "$cache_file")"
    local tmp="${cache_file}.tmp"

    {
        local ws_dir ws_name
        for ws_dir in "$SNIPPETS_DIR"/*/; do
            [[ -d "$ws_dir" ]] || continue
            ws_name="$(basename "$ws_dir")"
            [[ "$ws_name" == .* ]] && continue

            local md_file
            while IFS= read -r md_file; do
                [[ -z "$md_file" ]] && continue
                local source block
                source=$(_read_field "$md_file" "source")
                block=$(_read_field "$md_file" "block")
                [[ -z "$source" ]] && source="-"
                [[ -z "$block" ]] && block="0"
                printf '%s\t%s\t%s\t%s\n' "$ws_name" "$source" "$block" "${md_file##*/}"
            done < <(find "$ws_dir" -name "*.md" -type f 2>/dev/null)
        done
    } > "$tmp"

    mv "$tmp" "$cache_file"
}

block_in_workspace() {
    local source_file="$1" block_idx="$2"
    local cache_file="$WORKSPACE_CACHE"
    [[ ! -f "$cache_file" ]] && return 0
    [[ -z "$source_file" || -z "$block_idx" ]] && return 0
    awk -F'\t' -v src="$source_file" -v blk="$block_idx" '
        $2 == src && $3 == blk { print $1 }
    ' "$cache_file"
}

ensure_workspace_cache() {
    local cache_file="$WORKSPACE_CACHE"

    if [[ ! -f "$cache_file" ]]; then
        build_workspace_cache
        return
    fi

    local cache_ts
    cache_ts=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)

    local ws_dir ws_ts
    for ws_dir in "$SNIPPETS_DIR"/*/; do
        [[ -d "$ws_dir" ]] || continue
        ws_ts=$(stat -c %Y "$ws_dir" 2>/dev/null || echo 0)
        if (( ws_ts > cache_ts )); then
            build_workspace_cache
            return
        fi
    done
}

# =============================================================================
# Tags — parser compatível com Obsidian (inline, bloco e escalar)
# =============================================================================

get_snippet_tags() {
    local file="$1"
    awk '
        BEGIN { in_front=0; in_tags_block=0 }

        /^---[[:space:]]*$/ {
            if (!in_front) { in_front=1; next }
            else { exit }
        }
        !in_front { next }

        /^tags:[[:space:]]*/ {
            in_tags_block=0
            sub(/^tags:[[:space:]]*/, "")

            if (/^\[/) {
                gsub(/^\[|\]$/, "")
                gsub(/,[[:space:]]*/, "\n")
                gsub(/[[:space:]]+$/, "")
                if (length > 0) print
                next
            }
            if (length > 0) {
                gsub(/[[:space:]]+$/, "")
                print
                next
            }
            in_tags_block=1
            next
        }

        in_tags_block && /^[[:space:]]+-[[:space:]]/ {
            sub(/^[[:space:]]+-[[:space:]]+/, "")
            gsub(/[[:space:]]+$/, "")
            if (length > 0) print
            next
        }

        in_tags_block && /^[^[:space:]]/ { exit }
    ' "$file"
}

collect_all_tags() {
    find "$SNIPPETS_DIR" \( -name '.config' -o -name '.data' -o -name '.cache' \) -prune \
        -o -type f -name "*.md" -print0 2>/dev/null \
        | while IFS= read -r -d '' f; do get_snippet_tags "$f"; done \
        | sort -u | grep -v '^$'
}

# Tag rewrite (adds/removes tags in frontmatter, uses Obsidian block format)
_tag_add() {
    local file="$1" tag="$2"
    local tags_list
    tags_list="$(get_snippet_tags "$file")"
    tags_list="$(printf "%s\n%s" "$tags_list" "$tag" | grep -v '^$' | sort -u)"
    _rewrite_tags "$file" "$tags_list"
}

_tag_remove() {
    local file="$1" tag="$2"
    local tags_list
    tags_list="$(get_snippet_tags "$file" | grep -ivEx "$tag" || true)"
    _rewrite_tags "$file" "$tags_list"
}

_rewrite_tags() {
    local file="$1" tags_list="$2"
    local new_tags_block="tags:"
    if [ -z "$tags_list" ]; then
        new_tags_block="tags: []"
    else
        while IFS= read -r t; do
            [ -z "$t" ] && continue
            new_tags_block="${new_tags_block}"$'\n'"  - ${t}"
        done <<< "$tags_list"
    fi

    awk -v new_block="$new_tags_block" '
        BEGIN { in_front=0; in_tags=0; done=0 }

        /^---[[:space:]]*$/ {
            if (!in_front) { in_front=1; print; next }
            else {
                if (in_tags && !done) { print new_block; done=1 }
                in_front=0; in_tags=0; print; next
            }
        }

        in_front && /^tags:[[:space:]]*/ {
            in_tags=1
            if ($0 !~ /^tags:[[:space:]]*$/) {
                print new_block
                done=1
                in_tags=0
            }
            next
        }

        in_front && in_tags && /^[[:space:]]+-[[:space:]]/ { next }

        in_front && in_tags && /^[^[:space:]]/ {
            if (!done) { print new_block; done=1 }
            in_tags=0
            print; next
        }

        { print }

        END {
            if (in_tags && !done) { print new_block }
        }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

# =============================================================================
# Code Index (vault-wide)
# =============================================================================

# Format: file_path \t block_index \t language \t preview \t line_start \t line_end
build_code_index() {
    local vault="${1:-$VAULT_DIR}"
    local index_file="$INDEX_FILE"
    mkdir -p "$(dirname "$index_file")"

    local files=()
    while IFS= read -r f; do
        [[ "$f" =~ /(\.obsidian|\.config|\.data|\.cache|01\ Snippets)/ ]] && continue
        files+=("$f")
    done < <(rg --files -g "*.md" "$vault" 2>/dev/null)

    if (( ${#files[@]} == 0 )); then
        : > "$index_file"
        return 0
    fi

    local tmp="${index_file}.tmp"
    awk -v prefix="$vault/" '
        FNR == 1 {
            in_block = 0; block_idx = 0
            rel = FILENAME
            n = index(rel, prefix)
            if (n == 1) rel = substr(rel, length(prefix) + 1)
        }
        /^```/ {
            if (!in_block) {
                in_block = 1; block_idx++
                lang = $0; sub(/^```/, "", lang)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", lang)
                line_start = FNR + 1; first_line = ""
                next
            } else {
                preview = (first_line != "") ? first_line : "(empty)"
                if (length(preview) > 80) preview = substr(preview, 1, 77) "..."
                printf "%s\t%d\t%s\t%s\t%d\t%d\n", rel, block_idx, lang, preview, line_start, FNR - 1
                in_block = 0; next
            }
        }
        in_block && FNR >= line_start && first_line == "" { first_line = $0 }
    ' "${files[@]}" > "$tmp"

    mv "$tmp" "$index_file"
}

index_age() {
    if [[ ! -f "$INDEX_FILE" ]]; then echo "999999999"; return; fi
    local now file_ts
    now=$(date +%s)
    file_ts=$(stat -c %Y "$INDEX_FILE" 2>/dev/null || echo 0)
    echo $(( now - file_ts ))
}

index_stale() {
    local age; age=$(index_age)
    (( age > INDEX_MAX_AGE ))
}

search_index() {
    local query="$1"
    [[ ! -f "$INDEX_FILE" ]] && return 1
    [[ -z "$query" ]] && return 1
    rg --no-line-number --color=never --smart-case -- "$query" "$INDEX_FILE" 2>/dev/null
}

# =============================================================================
# Relative time helper
# =============================================================================

rel_time() {
    local ts="$1"
    local now delta
    now=$(date +%s)
    delta=$(( now - ts ))

    if   [ "$delta" -lt 3600 ];   then echo "há $(( delta / 60 ))min"
    elif [ "$delta" -lt 86400 ];  then echo "há $(( delta / 3600 ))h"
    elif [ "$delta" -lt 604800 ]; then echo "há $(( delta / 86400 ))d"
    elif [ "$delta" -lt 2592000 ];then echo "há $(( delta / 604800 ))sem"
    else                               echo "há $(( delta / 2592000 ))m"
    fi
}

# =============================================================================
# Export / Import
# =============================================================================

export_snippets() {
    local timestamp archive
    timestamp=$(date +%Y%m%d_%H%M%S)
    archive="$SNIPPETS_DIR/vaultkit-export-${timestamp}.tar.gz"
    tar -czf "$archive" -C "$(dirname "$SNIPPETS_DIR")" "$(basename "$SNIPPETS_DIR")" 2>/dev/null
    notify-send "VaultKit" "Exportado: $archive"
    echo "$archive"
}

import_snippets() {
    local archive="$1"
    local count_before count_after
    count_before=$(find "$SNIPPETS_DIR" -type f -name "*.md" | wc -l)
    tar -xzf "$archive" -C "$(dirname "$SNIPPETS_DIR")" 2>/dev/null
    count_after=$(find "$SNIPPETS_DIR" -type f -name "*.md" | wc -l)
    local added=$((count_after - count_before))
    notify-send "VaultKit" "Importados $added snippets."
}
