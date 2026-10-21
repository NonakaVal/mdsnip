#!/usr/bin/env bash
#
# install.sh — Instalador do mdsnip para EndeavourOS / Arch Linux
#
# O que faz:
#   1. Instala todas as dependências de sistema via pacman
#   2. Garante um terminal compatível com "Buscar no terminal" (fzf)
#   3. Disponibiliza o comando `mdsnip` globalmente no PATH
#
# Em modo não interativo, os diretórios podem ser definidos com:
#   MDSNIP_VAULT_DIR="$HOME/Documentos/Notes"
#   MDSNIP_SNIPPETS_DIR="$HOME/Documentos/Notes/Snippets"
#
# Uso:
#   ./install.sh                                  # symlink em /usr/local/bin
#   INSTALL_PREFIX="$HOME/.local" ./install.sh    # symlink em ~/.local/bin (sem sudo)
#
# Requisito: EndeavourOS / Arch Linux (pacman).

set -euo pipefail

# =============================================================================
# Configuração
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
APP_NAME="mdsnip"
LEGACY_APP_NAME="vaultkit" # Nome anterior removido do PATH durante a atualização.
LEGACY_SCRIPT_NAME="${LEGACY_APP_NAME}.sh"
MDSNIP_SCRIPT="$SCRIPT_DIR/mdsnip.sh"
ROFI_THEME_SOURCE="$SCRIPT_DIR/simple-tokyonight.rasi"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
GLOBAL_BIN_DIR="${INSTALL_PREFIX}/bin"
USER_BIN_DIR="${HOME}/.local/bin"
LEGACY_SYSTEM_BIN_DIR="/usr/local/bin"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/${APP_NAME}"
CONFIG_FILE="$CONFIG_DIR/config"
ROFI_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rofi"
ROFI_THEME_TARGET="$ROFI_CONFIG_DIR/simple-tokyonight.rasi"

# Dependências essenciais para snippets + notas + blocos
REQUIRED_PKGS=(
    rofi            # menus dmenu
    ripgrep         # rg — listagem e busca
    fzf             # busca no terminal
    gawk            # awk GNU — frontmatter e blocos
    libnotify       # notify-send
    tar             # export/import
    mousepad        # editor padrão
    glow            # preview markdown no fzf
)

# Clipboard e digitação (instala ambos para X11 e Wayland)
CLIPBOARD_PKGS=(
    xclip           # clipboard X11
    xdotool         # digitar no X11 / XWayland
    wl-clipboard    # wl-copy / wl-paste no Wayland
)

# Terminais reconhecidos pelo detect_terminal() do mdsnip
SUPPORTED_TERMINALS=(konsole kitty alacritty wezterm foot ghostty gnome-terminal xterm)
FALLBACK_TERMINAL="kitty"

# Comandos obrigatórios após a instalação
REQUIRED_CMDS=(rofi rg fzf awk notify-send tar mousepad)

# =============================================================================
# Helpers de log (sempre em stderr para não poluir capturas de stdout)
# =============================================================================
if [[ -t 2 ]]; then
    C_RESET=$'\033[0m';  C_BOLD=$'\033[1m'
    C_RED=$'\033[31m';   C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
else
    C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""
fi

log_step()  { printf '\n%s==> %s%s\n' "$C_BOLD$C_BLUE" "$*" "$C_RESET" >&2; }
log_ok()    { printf '%s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*" >&2; }
log_warn()  { printf '%s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
log_error() { printf '%s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die()       { log_error "$*"; exit 1; }

# =============================================================================
# Pré-validações
# =============================================================================
check_bash_version() {
    if (( BASH_VERSINFO[0] < 4 )); then
        die "bash 4+ necessário (atual: ${BASH_VERSION})."
    fi
    log_ok "bash ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]} OK"
}

check_os() {
    log_step "Verificando sistema operacional"
    if ! command -v pacman >/dev/null 2>&1; then
        die "pacman não encontrado. Este instalador é focado em EndeavourOS / Arch Linux."
    fi
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        log_ok "Sistema: ${NAME:-Arch Linux} (${ID:-arch})"
    elif [[ -f /etc/arch-release ]]; then
        log_ok "Arch / EndeavourOS detectado"
    else
        log_warn "Não foi possível confirmar o distro — pacman presente, prosseguindo"
    fi
}

check_mdsnip_script() {
    [[ -f "$MDSNIP_SCRIPT" ]] || die "mdsnip.sh não encontrado em: $MDSNIP_SCRIPT"
    [[ -f "$ROFI_THEME_SOURCE" ]] || die "Tema Rofi não encontrado em: $ROFI_THEME_SOURCE"
    [[ -d "$SCRIPT_DIR/lib" ]] || die "Diretório lib/ não encontrado em: $SCRIPT_DIR/lib"
    log_ok "mdsnip.sh, tema Rofi e lib/ encontrados"
}

# Copia apenas diretórios antigos sem equivalente novo; a origem é preservada.
migrate_legacy_dir() {
    local label="$1" source_dir="$2" target_dir="$3" answer
    if [[ ! -d "$source_dir" || -e "$target_dir" || -L "$target_dir" ]]; then
        return 0
    fi

    if [[ ! -t 0 || ! -t 1 ]]; then
        log_warn "Migração de $label ignorada em modo não interativo: $source_dir"
        return 0
    fi

    printf 'Migrar %s de %s para %s? [s/N] ' "$label" "$source_dir" "$target_dir" >&2
    IFS= read -r answer
    if [[ "$answer" =~ ^[sS]([iI][mM])?$ ]]; then
        mkdir -p "$(dirname "$target_dir")"
        cp -a "$source_dir" "$target_dir" || die "Falha ao migrar $label para $target_dir"
        log_ok "$label migrado; o original foi preservado"
    else
        log_warn "Migração de $label ignorada; o original foi preservado"
    fi
}

migrate_legacy_data() {
    local config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
    local data_root="${XDG_DATA_HOME:-$HOME/.local/share}"
    local cache_root="${XDG_CACHE_HOME:-$HOME/.cache}"

    migrate_legacy_dir "configuração" "$config_root/$LEGACY_APP_NAME" "$config_root/$APP_NAME"
    migrate_legacy_dir "dados" "$data_root/$LEGACY_APP_NAME" "$data_root/$APP_NAME"
    migrate_legacy_dir "cache" "$cache_root/$LEGACY_APP_NAME" "$cache_root/$APP_NAME"
}

# Garante sudo para pacman e /usr/local/bin
ensure_sudo() {
    log_step "Verificando privilégios de administrador"
    if [[ $EUID -eq 0 ]]; then
        log_warn "Rodando como root — em desktops prefira um usuário com sudo"
        SUDO=""
        return
    fi

    # Prefixo em home: pacman ainda precisa de sudo, symlink não
    command -v sudo >/dev/null 2>&1 || die "sudo não disponível. Instale 'sudo' ou rode como root."
    sudo -v || die "Não foi possível obter privilégios sudo."
    SUDO="sudo"
    log_ok "sudo disponível"
}

# =============================================================================
# Pacotes
# =============================================================================
# Retorna apenas nomes de pacotes (uma por linha) — sem logs no stdout
package_list() {
    printf '%s\n' "${REQUIRED_PKGS[@]}"
    printf '%s\n' "${CLIPBOARD_PKGS[@]}"
}

detect_aur_helper() {
    if command -v yay >/dev/null 2>&1; then
        echo "yay"
    elif command -v paru >/dev/null 2>&1; then
        echo "paru"
    else
        echo ""
    fi
}

install_packages() {
    log_step "Instalando pacotes via pacman"

    local -a pkgs=()
    mapfile -t pkgs < <(package_list)

    log_ok "Pacotes: ${pkgs[*]}"

    # --needed evita reinstalar o que já está ok
    # shellcheck disable=SC2086
    if ! $SUDO pacman -S --needed --noconfirm "${pkgs[@]}"; then
        die "Falha ao instalar pacotes com pacman. Rode: sudo pacman -Syu e tente de novo."
    fi
    log_ok "Pacotes instalados"

    # glow: se sumiu do repo oficial, tenta AUR (opcional)
    if ! command -v glow >/dev/null 2>&1; then
        local aur
        aur="$(detect_aur_helper)"
        if [[ -n "$aur" ]]; then
            log_warn "glow não veio pelo pacman — tentando AUR ($aur)"
            $aur -S --needed --noconfirm glow \
                || log_warn "glow (opcional) não instalado — preview markdown usará cat"
        else
            log_warn "glow ausente e sem yay/paru. Preview markdown usará cat."
        fi
    else
        log_ok "glow disponível"
    fi
}

# Garante ao menos um terminal da lista suportada
ensure_terminal() {
    log_step "Verificando terminal compatível"
    local t
    for t in "${SUPPORTED_TERMINALS[@]}"; do
        if command -v "$t" >/dev/null 2>&1; then
            log_ok "Terminal encontrado: $t"
            return
        fi
    done

    log_warn "Nenhum terminal compatível — instalando $FALLBACK_TERMINAL"
    $SUDO pacman -S --needed --noconfirm "$FALLBACK_TERMINAL" \
        || die "Falha ao instalar o terminal $FALLBACK_TERMINAL."
    log_ok "$FALLBACK_TERMINAL instalado"
}

# =============================================================================
# Verificação pós-instalação
# =============================================================================
verify_dependencies() {
    log_step "Verificando dependências instaladas"
    local -a missing=()
    local cmd

    for cmd in "${REQUIRED_CMDS[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log_ok "$cmd"
        else
            missing+=("$cmd")
            log_error "$cmd ausente"
        fi
    done

    if command -v xclip >/dev/null 2>&1 || command -v wl-copy >/dev/null 2>&1; then
        log_ok "clipboard (xclip e/ou wl-copy)"
    else
        missing+=("xclip|wl-copy")
        log_error "Nenhum clipboard disponível (xclip ou wl-copy)"
    fi

    if command -v glow >/dev/null 2>&1; then
        log_ok "glow (preview markdown)"
    else
        log_warn "glow opcional ausente"
    fi

    if (( ${#missing[@]} > 0 )); then
        die "Dependências faltando: ${missing[*]}"
    fi
    log_ok "Todas as dependências obrigatórias estão presentes"
}

# =============================================================================
# Comando global
# =============================================================================
# mdsnip.sh resolve o diretório via readlink -f "$0", então symlink funciona.
install_global_command() {
    log_step "Criando comando global '$APP_NAME'"
    chmod +x "$MDSNIP_SCRIPT"
    # garante executáveis nos módulos (source não exige, mas é bom)
    chmod +x "$SCRIPT_DIR/lib"/*.sh 2>/dev/null || true

    local target_bin=""

    remove_legacy_command_link "$GLOBAL_BIN_DIR/$LEGACY_APP_NAME"
    remove_legacy_command_link "$USER_BIN_DIR/$LEGACY_APP_NAME"
    remove_legacy_command_link "$LEGACY_SYSTEM_BIN_DIR/$LEGACY_APP_NAME"

    # 1) destino gravável pelo usuário (INSTALL_PREFIX em home)
    if [[ -w "$GLOBAL_BIN_DIR" ]] || mkdir -p "$GLOBAL_BIN_DIR" 2>/dev/null && [[ -w "$GLOBAL_BIN_DIR" ]]; then
        ln -sfn "$MDSNIP_SCRIPT" "$GLOBAL_BIN_DIR/$APP_NAME"
        target_bin="$GLOBAL_BIN_DIR/$APP_NAME"
        log_ok "Symlink: $target_bin -> $MDSNIP_SCRIPT"
    # 2) root
    elif [[ $EUID -eq 0 ]]; then
        mkdir -p "$GLOBAL_BIN_DIR"
        ln -sfn "$MDSNIP_SCRIPT" "$GLOBAL_BIN_DIR/$APP_NAME"
        target_bin="$GLOBAL_BIN_DIR/$APP_NAME"
        log_ok "Symlink: $target_bin -> $MDSNIP_SCRIPT"
    # 3) sudo em /usr/local/bin
    elif [[ -n "${SUDO:-}" ]]; then
        $SUDO mkdir -p "$GLOBAL_BIN_DIR"
        $SUDO ln -sfn "$MDSNIP_SCRIPT" "$GLOBAL_BIN_DIR/$APP_NAME"
        target_bin="$GLOBAL_BIN_DIR/$APP_NAME"
        log_ok "Symlink: $target_bin -> $MDSNIP_SCRIPT (via sudo)"
    # 4) fallback ~/.local/bin
    else
        log_warn "Sem permissão em $GLOBAL_BIN_DIR — usando $USER_BIN_DIR"
        mkdir -p "$USER_BIN_DIR"
        ln -sfn "$MDSNIP_SCRIPT" "$USER_BIN_DIR/$APP_NAME"
        target_bin="$USER_BIN_DIR/$APP_NAME"
        log_ok "Symlink: $target_bin -> $MDSNIP_SCRIPT"
    fi

    INSTALLED_BIN="$target_bin"

    # Aviso de PATH se necessário
    local bin_dir
    bin_dir="$(dirname "$target_bin")"
    if [[ ":${PATH}:" != *":${bin_dir}:"* ]]; then
        log_warn "$bin_dir não está no PATH. Adicione ao ~/.bashrc:"
        printf '    export PATH="%s:$PATH"\n' "$bin_dir" >&2
    fi
}

remove_legacy_command_link() {
    local link="$1" target
    [[ -L "$link" ]] || return 0
    target="$(readlink -f -- "$link" 2>/dev/null || true)"
    [[ "${target##*/}" == "$LEGACY_SCRIPT_NAME" ]] || return 0

    if [[ -w "$(dirname "$link")" ]]; then
        rm -- "$link"
    else
        $SUDO rm -- "$link" || die "Não foi possível remover o comando legado $link"
    fi
    log_ok "Comando legado removido: $link"
}

# Instala o tema sem exigir privilégios de administrador.
install_rofi_theme() {
    log_step "Instalando tema padrão do Rofi"
    mkdir -p "$ROFI_CONFIG_DIR"
    install -m 0644 "$ROFI_THEME_SOURCE" "$ROFI_THEME_TARGET"
    log_ok "Tema Rofi: $ROFI_THEME_TARGET"
}

# Lê apenas valores simples no formato VAR="valor", sem executar o arquivo.
read_config_value() {
    local key="$1" line raw value char escaped i
    [[ -f "$CONFIG_FILE" ]] || return 1

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" == "$key="* ]] || continue
        raw="${line#"$key="}"
        [[ "${raw:0:1}" == '"' ]] || continue
        raw="${raw:1}"
        value=""
        escaped=0

        for ((i = 0; i < ${#raw}; i++)); do
            char="${raw:i:1}"
            if (( escaped )); then
                if [[ "$char" == '"' || "$char" == '$' || "$char" == '`' ]]; then
                    value+="$char"
                elif [[ "$char" != $'\\' ]]; then
                    value+="\\$char"
                else
                    value+="$char"
                fi
                escaped=0
            elif [[ "$char" == $'\\' ]]; then
                escaped=1
            elif [[ "$char" == '"' ]]; then
                break
            else
                value+="$char"
            fi
        done

        printf '%s' "$value"
        return 0
    done < "$CONFIG_FILE"
    return 1
}

quote_config_value() {
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

update_config_paths() {
    local vault_value snippets_value temp_file line
    local has_vault=0 has_snippets=0
    vault_value="$(quote_config_value "$VAULT_DIR")"
    snippets_value="$(quote_config_value "$SNIPPETS_DIR")"
    mkdir -p "$CONFIG_DIR"
    temp_file="$(mktemp "$CONFIG_FILE.XXXXXX")" || die "Não foi possível criar arquivo temporário para $CONFIG_FILE"

    if [[ -f "$CONFIG_FILE" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            case "$line" in
                VAULT_DIR=*)
                    if (( ! has_vault )); then
                        printf 'VAULT_DIR=%s\n' "$vault_value" >> "$temp_file"
                        has_vault=1
                    fi
                    ;;
                SNIPPETS_DIR=*)
                    if (( ! has_snippets )); then
                        printf 'SNIPPETS_DIR=%s\n' "$snippets_value" >> "$temp_file"
                        has_snippets=1
                    fi
                    ;;
                *) printf '%s\n' "$line" >> "$temp_file" ;;
            esac
        done < "$CONFIG_FILE"
        chmod --reference="$CONFIG_FILE" "$temp_file"
    else
        printf '# mdsnip — configuração\n' > "$temp_file"
    fi

    (( has_vault )) || printf 'VAULT_DIR=%s\n' "$vault_value" >> "$temp_file"
    (( has_snippets )) || printf 'SNIPPETS_DIR=%s\n' "$snippets_value" >> "$temp_file"
    mv "$temp_file" "$CONFIG_FILE" || die "Não foi possível atualizar $CONFIG_FILE"
}

expand_user_path() {
    local path="$1" tilde_prefix=$'\x7e/'
    path="${path//\$\{HOME\}/$HOME}"
    path="${path//\$HOME\//$HOME/}"
    [[ "$path" == $'\044HOME' ]] && path="$HOME"

    case "$path" in
        "~") path="$HOME" ;;
        "$tilde_prefix"*) path="$HOME/${path#"$tilde_prefix"}" ;;
    esac

    while [[ "$path" != "/" && "$path" == */ ]]; do
        path="${path%/}"
    done
    [[ "$path" == /* ]] || path="$PWD/$path"
    printf '%s' "$path"
}

confirm_create_dir() {
    local answer
    printf 'Criar diretório %s? [S/n] ' "$1" >&2
    IFS= read -r answer
    [[ -z "$answer" || "$answer" =~ ^[sS]([iI][mM])?$ ]]
}

validate_path() {
    local path="$1" label="$2" interactive="$3" probe
    path="$(expand_user_path "$path")"

    if [[ ! -d "$path" ]]; then
        if [[ "$interactive" == "yes" ]] && ! confirm_create_dir "$path"; then
            log_warn "Escolha outro caminho para $label"
            return 1
        fi
        if ! mkdir -p "$path"; then
            log_error "Não foi possível criar o diretório de $label: $path"
            return 1
        fi
    fi

    if [[ ! -d "$path" ]] || ! probe="$(mktemp "$path/.mdsnip-write-test.XXXXXX" 2>/dev/null)"; then
        log_error "Diretório de $label não é gravável: $path"
        return 1
    fi
    rm -f "$probe" || die "Não foi possível remover o arquivo de teste $probe"

    VALIDATED_PATH="$(cd "$path" && pwd -P)" || {
        log_error "Não foi possível resolver o caminho de $label: $path"
        return 1
    }
}

ask_interactive_path() {
    local label="$1" default="$2" input
    while true; do
        IFS= read -r -e -p "$label [$default]: " input
        input="${input:-$default}"
        if validate_path "$input" "$label" yes; then
            return 0
        fi
    done
}

ask_paths() {
    local interactive="no"
    local default_vault="$HOME/Documentos/Notes"
    local default_snippets
    local configured_vault="" configured_snippets=""

    if [[ -t 0 && -t 1 ]]; then
        interactive="yes"
        configured_vault="$(read_config_value VAULT_DIR || true)"
        configured_snippets="$(read_config_value SNIPPETS_DIR || true)"
        [[ -n "$configured_vault" ]] && default_vault="$configured_vault"
        default_snippets="$default_vault/Snippets"
        [[ -n "$configured_snippets" ]] && default_snippets="$configured_snippets"
    fi

    if [[ "$interactive" == "yes" ]]; then
        ask_interactive_path "Pasta de snippets" "$default_snippets"
        SNIPPETS_DIR="$VALIDATED_PATH"

        ask_interactive_path "Pasta da Vault (code blocks)" "$default_vault"
        VAULT_DIR="$VALIDATED_PATH"
    else
        VAULT_DIR="${MDSNIP_VAULT_DIR:-$default_vault}"
        SNIPPETS_DIR="${MDSNIP_SNIPPETS_DIR:-$VAULT_DIR/Snippets}"
        validate_path "$VAULT_DIR" "vault" no || die "Caminho de vault inválido"
        VAULT_DIR="$VALIDATED_PATH"
        validate_path "$SNIPPETS_DIR" "snippets" no || die "Caminho de snippets inválido"
        SNIPPETS_DIR="$VALIDATED_PATH"
    fi

    update_config_paths
    log_ok "Snippets: $SNIPPETS_DIR"
    log_ok "Vault: $VAULT_DIR"
}

# =============================================================================
# Resumo final
# =============================================================================
print_summary() {
    local bin="${INSTALLED_BIN:-$GLOBAL_BIN_DIR/$APP_NAME}"

    cat <<EOF

${C_BOLD}${C_GREEN} Instalação do $APP_NAME concluída!${C_RESET}

${C_BOLD}Como usar:${C_RESET}
    $APP_NAME                # abre o menu principal (rofi)
    $APP_NAME search         # abre diretamente a busca no terminal (fzf)

${C_BOLD}Comando instalado em:${C_RESET}
    $bin

${C_BOLD}Configuração (criada no 1º uso):${C_RESET}
    $CONFIG_FILE
    Snippets: $SNIPPETS_DIR
    Vault: $VAULT_DIR

${C_BOLD}Pacotes instalados:${C_RESET}
    rofi, ripgrep, fzf, gawk, libnotify, tar, mousepad, glow
    xclip, xdotool, wl-clipboard (+ terminal se necessário)

${C_BOLD}Dica:${C_RESET} troque o editor no menu "Configurações" do $APP_NAME
ou em EDITOR_APP no arquivo de configuração.

EOF
}

# =============================================================================
# Main
# =============================================================================
main() {
    log_step "$APP_NAME — instalador (EndeavourOS / Arch)"
    check_bash_version
    check_os
    check_mdsnip_script
    migrate_legacy_data
    ensure_sudo
    install_packages
    ensure_terminal
    verify_dependencies
    install_global_command
    install_rofi_theme
    ask_paths
    print_summary
}

main "$@"
