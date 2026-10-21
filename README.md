# mdsnip

Gerenciador de snippets, notas e blocos de código via **Rofi** (GUI) e **fzf** (terminal). O repositório `mdsnip` mantém snippets em Markdown com frontmatter YAML, compatível com tags do Obsidian.

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

O instalador cuida das dependências e solicita os caminhos, um por vez: primeiro a pasta de snippets (onde serão salvos e pesquisados) e depois a Vault (onde estão as notas e os code blocks). Os dois inputs exibem valores padrão entre colchetes; pressione Enter para aceitá-los. Os padrões são `~/Documentos/Notes/Snippets` para snippets e `~/Documentos/Notes` para a Vault.

Em modo não interativo, configure os diretórios com `MDSNIP_VAULT_DIR` e `MDSNIP_SNIPPETS_DIR`; sem essas variáveis, serão usados os mesmos padrões.

```bash
MDSNIP_VAULT_DIR="$HOME/Documentos/Notes" \
MDSNIP_SNIPPETS_DIR="$HOME/Documentos/Notes/Snippets" \
./install.sh
```

## Uso

```bash
mdsnip         # abre o menu principal no Rofi
mdsnip search  # abre diretamente a busca no terminal (fzf)
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
| `~/.config/mdsnip/config` | Arquivo de configuração |
| `~/Documentos/Notes/Snippets/` | Pasta padrão de snippets |
| `~/Documentos/Notes/` | Pasta padrão do vault |
| `~/.local/share/mdsnip/` | Histórico, favoritos e índices |
| `~/.cache/mdsnip/` | Cache |

Edite `EDITOR_APP`, `TERMINAL_APP`, `VAULT_DIR` e outras variáveis no arquivo de configuração ou pelo menu **Configurações** do Rofi.
