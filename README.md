# Choco's dotfiles

## Structure
```
dotfiles/
├── thefiles/
│   ├── .scripts/
│   │    └── brew_maintain - homebrew update script to be added to cronjob
│   ├── .aliases         - Shell aliases (OS-specific included)
│   ├── .bash_profile   - Bash-specific profile
│   ├── .common_functions - Shared shell functions
│   ├── .exports        - Environment variables
│   ├── .gitconfig      - Git configuration
│   ├── .profile        - Core shell-agnostic settings
│   ├── .security       - Security settings and SSH config
│   ├── .zprofile       - Zsh login settings
│   ├── .zsh_keys       - Zsh key bindings
│   ├── .zsh_options    - Zsh shell options
│   └── .zshrc          - Zsh interactive settings
├── bootstrap.sh       - Creates symlinks in $HOME
├── env_bootstrap.sh   - Environment initializer (macos|unix)
└── README.md
```

## Installation
1. Clone git repo
`git clone https://github.com/ignaciojimenez/dotfiles.git`
2. Execute bootstrap.sh 
 `bootstrap.sh` can be run in two modes:
   - Plain: Creates symlinks in `$HOME` to all dotfiles
   - Kickstart: Use `--kickstart or -k` to also initialize environment

> Note: Currently tested mainly on macOS. Provides fallbacks for missing apps (Sublime, Secretive).

## Features
- Organized shell configuration (login vs interactive)
- Enhanced zsh experience (key bindings, history, navigation)
- Security-focused settings with fallbacks
- OS-specific customizations (macos|unix)