# vaultkit

Gerenciador unificado de snippets e notas via Rofi. Navegue, busque, copie e organize trechos de codigo e notas — tudo num unico menu.

Combina as funcionalidades do **snippet-holder** (gerenciamento de snippets em workspaces) e do **note_search** (busca de notas e blocos no vault) numa interface Rofi integrada.

## Dependencias

### Obrigatorio

| Pacote | Funcao |
|---|---|
| `rofi` (ou `rofi-wayland`) | Menu interativo |
| `xclip` (X11) ou `wl-clipboard` (Wayland) | Area de transferencia |
| `libnotify` | Notificacoes |

### Recomendado

| Pacote | Funcao |
|---|---|
| `fzf` | Busca de notas/blocos no terminal (opcao "Buscar no terminal") |
| `ripgrep` (`rg`) | Busca de conteudo nas notas |
| `xdotool` | Digitar snippets diretamente no cursor |
| `glow` | Preview formatado de notas no terminal (opcional) |
| `mousepad` (ou outro editor) | Editar snippets/notas |

### Instalacao das dependencias

**Debian / Ubuntu**
```bash
sudo apt install rofi xclip libnotify-bin ripgrep xdotool
```

**Arch / Manjaro / EndeavourOS**
```bash
sudo pacman -S rofi xclip libnotify ripgrep xdotool
```

**Fedora**
```bash
sudo dnf install rofi xclip libnotify ripgrep xdotool
```

## Instalar

```bash
git clone git@github.com:NonakaVal/rofi-snippet-holder.git
cd rofi-snippet-holder
./install.sh
```

O instalador detecta Wayland/X11 e verifica as dependencias.

### Variaveis de configuracao (opcionais, primeira instalacao)

```bash
VAULT_DIR="$HOME/Documentos/Notes" SNIPPETS_DIR="$HOME/Documentos/Notes/01 Snippets" ./install.sh
```

## Configuracao

Arquivo: `~/.config/vaultkit/config`

```bash
# Pastas de busca / exemplos
VAULT_DIR="$HOME/Documentos/Notes"
SNIPPETS_DIR="$HOME/Documentos/Notes/01 Snippets"
# Aplicativos
EDITOR_APP="mousepad"
TERMINAL_APP="konsole"      # terminal aberto por "Buscar no terminal" (auto-detectado)
# Uso padrao
DEFAULT_SORT="recent"      # "recent" ou "az"
HISTORY_LIMIT="40"          # max snippets no historico
PREVIEW_LINES="5"           # linhas mostradas no preview
CACHE_TTL="30"              # TTL do cache (em segundos)
```

Um unico arquivo (`~/.config/vaultkit/config`) define tanto as **pastas de busca**
(`VAULT_DIR`, `SNIPPETS_DIR`) quanto o **terminal** e o **uso padrao**. O terminal e
auto-detectado na instalacao (`konsole`, `kitty`, `alacritty`, `wezterm`, `foot`,
`ghostty`, `gnome-terminal`, `xterm`) e pode ser trocado editando `TERMINAL_APP`.

## Uso

```bash
vaultkit
```

### Menu principal

| Opcao | Descricao |
|---|---|
| Navegar snippets | Navegar pelas pastas de workspaces |
| Historico | Ultimos snippets copiados |
| Favoritos | Snippets marcados como favoritos |
| Buscar por tag | Filtrar snippets por tag (frontmatter) |
| Buscar no terminal | Fecha o Rofi e abre o terminal (`TERMINAL_APP`) com a busca fzf de notas/blocos |
| Configuracoes | Configurar vault, snippets, editor, terminal, etc. |
| Exportar | Exportar snippets como tar.gz |
| Importar | Importar snippets de tar.gz |

> A busca de notas (por nome, conteudo ou blocos de codigo) **nao** acontece dentro do Rofi.
> A opcao **Buscar no terminal** fecha o Rofi e abre o terminal configurado com a busca
> fzf ja em execucao, para filtrar, pre-visualizar e adicionar trechos diretamente no terminal.

### Navegacao de snippets

| Atalho | Acao |
|---|---|
| `Alt+n` | Novo snippet |
| `Alt+g` | Novo grupo/pasta |
| `Alt+o` | Alternar ordenacao (recentes / A-Z) |
| `Alt+q` | Voltar pasta |
| `Alt+w` | Ir para pasta (seletor) |
| `Enter` | Abrir snippet |
| `Esc` | Sair |

### Acoes de snippet

**Copiar** — copia o bloco de codigo para a clipboard  
**Digitar** — digita o bloco diretamente no cursor (xdotool)  
**Editar** — abre no editor configurado  
**Gerenciar tags** — adiciona/remove tags do frontmatter  
**Apagar** — remove o arquivo  
**Favoritar/Desfavoritar** — marca/desmarca como favorito

### Busca no terminal (fzf)

A opcao **Buscar no terminal** abre o terminal configurado com o seletor `nf`, que oferece
tres modos de busca no vault (`VAULT_DIR`):

| Modo | Descricao |
|---|---|
| Nome | Busca notas pelo nome do arquivo |
| Conteudo | Busca full-text no vault (ripgrep) |
| Blocos | Busca blocos de codigo indexados em todo o vault |

Atalhos dentro do fzf:

| Atalho | Acao |
|---|---|
| `Enter` | Imprime o caminho da nota/bloco selecionado |
| `ctrl-e` | Editar no `$EDITOR` |
| `ctrl-y` | Salvar o bloco como snippet numa pasta (workspace) |
| `ctrl-r` | Atualizar / reindexar |
| `ctrl-o` | Alternar ordenacao |

## Keybinding

Adicione ao seu gerenciador de janelas:

**GNOME** (via dconf):
```
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom26/']"
# Depois configure custom26 para: command='vaultkit', binding='<Super>s'
```

**i3**:
```
bindsym $mod+s exec --no-startup-id vaultkit
```

## Templates

Snippets sao criados a partir de templates em `~/.config/vaultkit/templates/`.

Tres templates padrao: `default.md`, `function.md`, `notes.md`.

### Criar template customizado

Crie um `.md` em `~/.config/vaultkit/templates/` com variaveis:

| Variavel | Descricao |
|---|---|
| `{{TITLE}}` | Nome do snippet |
| `{{DATE}}` | Data de criacao (YYYY-MM-DD) |
| `{{CLIPBOARD}}` | Conteudo da area de transferencia |

## Estrutura do projeto

```
vaultkit                # Script principal
lib/
  config.sh             # Configuracao e inicializacao (XDG), terminal
  core.sh               # Biblioteca central (clipboard, blocos, indice, tags, workspaces)
  note-search.sh        # Busca fzf no terminal (nome, conteudo, blocos) — self-contained
  ui-rofi.sh            # Interface Rofi, listagens, acoes, navegacao
install.sh              # Instalador (limpa predecessores snippet-holder/note_search)
uninstall.sh            # Desinstalador
```

## Dados

| Dado | Localizacao |
|---|---|
| Configuracao | `~/.config/vaultkit/config` |
| Templates | `~/.config/vaultkit/templates/` |
| Historico | `~/.local/share/vaultkit/history` |
| Favoritos | `~/.local/share/vaultkit/favorites` |
| Indice de blocos | `~/.local/share/vaultkit/code-index.tsv` |
| Cache de workspaces | `~/.local/share/vaultkit/workspace-cache.tsv` |

## Desinstalar

```bash
vaultkit-uninstall
# ou
bash ~/Projetos/rofi-snippet-holder/uninstall.sh
```

Remove binarios e modulos. Dados sao preservados. Para remover tudo:

```bash
rm -rf ~/.config/vaultkit ~/.local/share/vaultkit ~/.cache/vaultkit
```

## License

MIT
