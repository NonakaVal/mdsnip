#!/usr/bin/env bash
#
# install.sh — Instalador do vaultkit para EndeavourOS / Arch Linux
#
# O que faz:
#   1. Instala todas as dependências de sistema via pacman
#   2. Garante um terminal compatível com "Buscar no terminal" (fzf)
#   3. Disponibiliza o comando `vaultkit` globalmente no PATH
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
VAULTKIT_SCRIPT="$SCRIPT_DIR/vaultkit.sh"
ROFI_THEME_SOURCE="$SCRIPT_DIR/simple-tokyonight.rasi"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
GLOBAL_BIN_DIR="${INSTALL_PREFIX}/bin"
USER_BIN_DIR="${HOME}/.local/bin"
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

# Terminais reconhecidos pelo detect_terminal() do vaultkit
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

check_vaultkit_script() {
    [[ -f "$VAULTKIT_SCRIPT" ]] || die "vaultkit.sh não encontrado em: $VAULTKIT_SCRIPT"
    [[ -f "$ROFI_THEME_SOURCE" ]] || die "Tema Rofi não encontrado em: $ROFI_THEME_SOURCE"
    [[ -d "$SCRIPT_DIR/lib" ]] || die "Diretório lib/ não encontrado em: $SCRIPT_DIR/lib"
    log_ok "vaultkit.sh, tema Rofi e lib/ encontrados"
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
# vaultkit.sh resolve o diretório via readlink -f "$0", então symlink funciona.
install_global_command() {
    log_step "Criando comando global 'vaultkit'"
    chmod +x "$VAULTKIT_SCRIPT"
    # garante executáveis nos módulos (source não exige, mas é bom)
    chmod +x "$SCRIPT_DIR/lib"/*.sh 2>/dev/null || true

    local target_bin=""

    # 1) destino gravável pelo usuário (INSTALL_PREFIX em home)
    if [[ -w "$GLOBAL_BIN_DIR" ]] || mkdir -p "$GLOBAL_BIN_DIR" 2>/dev/null && [[ -w "$GLOBAL_BIN_DIR" ]]; then
        ln -sfn "$VAULTKIT_SCRIPT" "$GLOBAL_BIN_DIR/vaultkit"
        target_bin="$GLOBAL_BIN_DIR/vaultkit"
        log_ok "Symlink: $target_bin -> $VAULTKIT_SCRIPT"
    # 2) root
    elif [[ $EUID -eq 0 ]]; then
        mkdir -p "$GLOBAL_BIN_DIR"
        ln -sfn "$VAULTKIT_SCRIPT" "$GLOBAL_BIN_DIR/vaultkit"
        target_bin="$GLOBAL_BIN_DIR/vaultkit"
        log_ok "Symlink: $target_bin -> $VAULTKIT_SCRIPT"
    # 3) sudo em /usr/local/bin
    elif [[ -n "${SUDO:-}" ]]; then
        $SUDO mkdir -p "$GLOBAL_BIN_DIR"
        $SUDO ln -sfn "$VAULTKIT_SCRIPT" "$GLOBAL_BIN_DIR/vaultkit"
        target_bin="$GLOBAL_BIN_DIR/vaultkit"
        log_ok "Symlink: $target_bin -> $VAULTKIT_SCRIPT (via sudo)"
    # 4) fallback ~/.local/bin
    else
        log_warn "Sem permissão em $GLOBAL_BIN_DIR — usando $USER_BIN_DIR"
        mkdir -p "$USER_BIN_DIR"
        ln -sfn "$VAULTKIT_SCRIPT" "$USER_BIN_DIR/vaultkit"
        target_bin="$USER_BIN_DIR/vaultkit"
        log_ok "Symlink: $target_bin -> $VAULTKIT_SCRIPT"
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

# Instala o tema sem exigir privilégios de administrador.
install_rofi_theme() {
    log_step "Instalando tema padrão do Rofi"
    mkdir -p "$ROFI_CONFIG_DIR"
    install -m 0644 "$ROFI_THEME_SOURCE" "$ROFI_THEME_TARGET"
    log_ok "Tema Rofi: $ROFI_THEME_TARGET"
}

# =============================================================================
# Resumo final
# =============================================================================
print_summary() {
    local bin="${INSTALLED_BIN:-$GLOBAL_BIN_DIR/vaultkit}"

    cat <<EOF

${C_BOLD}${C_GREEN} Instalação do vaultkit concluída!${C_RESET}

${C_BOLD}Como usar:${C_RESET}
    vaultkit                # abre o menu principal (rofi)
    vaultkit search         # abre diretamente a busca no terminal (fzf)

${C_BOLD}Comando instalado em:${C_RESET}
    $bin

${C_BOLD}Configuração (criada no 1º uso):${C_RESET}
    ~/.config/vaultkit/config
    ~/Documentos/Notes/01 Snippets   # pasta padrão de snippets

${C_BOLD}Pacotes instalados:${C_RESET}
    rofi, ripgrep, fzf, gawk, libnotify, tar, mousepad, glow
    xclip, xdotool, wl-clipboard (+ terminal se necessário)

${C_BOLD}Dica:${C_RESET} troque o editor no menu "Configurações" do vaultkit
ou em EDITOR_APP no arquivo de configuração.

EOF
}

# =============================================================================
# Main
# =============================================================================
main() {
    log_step "vaultkit — instalador (EndeavourOS / Arch)"
    check_bash_version
    check_os
    check_vaultkit_script
    ensure_sudo
    install_packages
    ensure_terminal
    verify_dependencies
    install_global_command
    install_rofi_theme
    print_summary
}

main "$@"
