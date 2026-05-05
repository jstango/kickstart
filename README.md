# Kickstart

A cross-platform, idempotent bootstrap repository for quickly setting up a development environment on a new Linux VM, with a focus on AI/ML workloads.

## Tools Included

- **Shell & Prompt**: [Starship](https://starship.rs/) (Catppuccin Powerline preset)
- **Environment Manager**: [Miniconda](https://docs.conda.io/en/latest/miniconda.html)
- **Editor**: [Neovim](https://neovim.io/)
- **CLI AI**: [Gemini CLI](https://www.npmjs.com/package/@google/gemini-cli)
- **Multiplexer**: [tmux](https://github.com/tmux/tmux)
- **Utilities**:
    - [nvtop](https://github.com/Syllo/nvtop) (GPU monitoring)
    - [eza](https://github.com/eza-community/eza) (Modern `ls`)

## Usage

You can now use this command to set up any new VM:
```bash
git clone https://github.com/jstango/kickstart.git ~/kickstart && cd ~/kickstart && ./bootstrap.sh
```

1.  **Log into your new VM.**
2.  **Clone this repository:**
    ```bash
    git clone https://github.com/jstango/kickstart.git ~/kickstart
    ```
3.  **Run the bootstrap script:**
    ```bash
    cd ~/kickstart
    ./bootstrap.sh
    ```
4.  **Restart your shell** or run `source ~/.bashrc`.

## Customization

- Edit `config/starship.toml` to change your prompt.
- Edit `config/.tmux.conf` for tmux preferences.
- Add new tools to `bootstrap.sh`.
