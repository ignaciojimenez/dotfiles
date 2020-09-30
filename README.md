# Choco's dotfiles

## Structure
```
dotfiles/
├── thefiles/
│   ├── .scripts/
│   │    └── brew_maintain - homebrew update script to be added to cronjob
│   ├── .aliases
│   ├── .bash_profile
│   ├── .common_functions
│   ├── .exports
│   ├── .gitconfig
│   └── .zshrc
├── bootstrap.sh - creates symlinks and initializes the environment if passed as an argument
├── env_bootstrap.sh - environment initializer
├── profile_bootstrap.sh - NOT USED ATM (probably never to be used)
└── README.md
```

## Installation/usage
1. Clone git repo
`git clone https://github.com/ignaciojimenez/dotfiles.git`
2. Execute bootstrap.sh 
 `bootstrap.sh` can be run in two modes:
   - Plain: It will create symlinks in `$HOME` folder to all dotfiles contained in the repo
   - Kickstart: If `--kickstart or -k` are used, also the environment will be kickstarted: Useful for new installations
  `env_bootstrap.sh` is the _kickstart_ script. It can be used separately passing the environment type as an argument (currently only `macos|unix`)
      > Note that currently almost everything has been mainly tested in macos

## Future work
- [ ] Test in bash to see if Path needs to be created
- [ ] Develop more unix (currently almost empty)
- [ ] Think of a smarter way to populate changes into different shells
- [ ] Make it work for other shells - For now solutions are all tradeoffs of the dotfile usability
- [ ] env_bootstrap is a zsh script to include specific mac directives. Test if this will work in debian.