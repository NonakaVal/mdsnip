# vaultkit

Gerenciador de snippets, notas e blocos de código via **Rofi** (GUI) e **fzf** (terminal). Snippets em Markdown com frontmatter YAML, compatível com tags do Obsidian.

## Funcionalidades

- **Navegação** por pastas e snippets no Rofi
- **Copiar** para clipboard ou **digitar** automaticamente (`xdotool`)
- **Histórico** e **Favoritos**
- **Busca** por tag (Rofi) ou por conteúdo/blocos (fzf no terminal)
- **Exportar / Importar** snippets em `.tar.gz`
- Suporte a **Wayland** e **X11**
- Templates com placeholders (`{{TITLE}}`, `{{DATE}}`, `{{CLIPBOARD}}`)

## Instalação

Requer EndeavourOS / Arch Linux (`pacman`).

```bash
./install.sh                                  # instala em /usr/local/bin
INSTALL_PREFIX="$HOME/.local" ./install.sh    # instala em ~/.local/bin (sem sudo)
```

O instalador cuida de todas as dependências.

## Uso

```bash
vaultkit    # abre o menu principal no Rofi
```

Menu principal:

| Opção | Descrição |
|---|---|
| Navegar snippets | Explora pastas e abre ações por snippet |
| Histórico | Últimos snippets usados |
| Favoritos | Snippets marcados como favorito |
| Buscar por tag | Filtra por tags (Obsidian-compatible) |
| Buscar no terminal | Abre `fzf` no terminal para busca avançada |
| Configurações | Editor, terminal, ordenação, etc. |
| Exportar / Importar | Backup e restore em `.tar.gz` |

## Dependências

`rofi`, `ripgrep`, `fzf`, `gawk`, `libnotify`, `tar`, `mousepad`, `glow`, `xclip`, `xdotool`, `wl-clipboard` + um terminal emulador.

## Configuração

Criada automaticamente no primeiro uso:

| Caminho | Conteúdo |
|---|---|
| `~/.config/vaultkit/config` | Arquivo de configuração |
| `~/Documentos/Notes/01 Snippets/` | Pasta padrão de snippets |
| `~/.local/share/vaultkit/` | Histórico, favoritos e índices |

Edite `EDITOR_APP`, `TERMINAL_APP`, `VAULT_DIR` e outras variáveis no arquivo de configuração ou pelo menu **Configurações** do Rofi.
