# TODO — open polish items

Items deferred from the 2026-05 overhaul because they're cosmetic, stylistic,
or low-impact. Not blocking, not insecure — captured here so they're not lost.

## Shell ergonomics

- **`setopt CORRECT` / `CORRECT_ALL`** — `thefiles/.zsh_options:47-48`. The "did
  you mean…" prompts on every typo. Subjective: many people find them
  obnoxious. Drop unless you actually use them.
- **`export TERM=xterm-256color`** lives in `thefiles/.zsh_keys:43`, a
  *keybindings* file. Wrong file (it's an env var) and forces TERM regardless
  of what your terminal advertises — can mis-render in iTerm/Warp/tmux/SSH.
  Move to `.exports` or just delete.

## Python / aliases

- **Custom `python()` function bypasses pyenv** — `thefiles/.aliases` macos
  block. With pyenv installed (which puts shims in `$PATH`), this function
  overrides the shim and routes plain `python` to `/usr/bin/python3` when no
  venv is active. If pyenv is authoritative, remove the function. If you want
  the system-Python fallback, keep it.
- **`lwp-request` HTTP-method aliases** — `thefiles/.aliases:103`. Defines
  `GET`, `HEAD`, `POST`, … as shell aliases. Requires `libwww-perl` (often
  missing). `httpie` (`http GET …`) is the modern equivalent. Replace or
  remove.

## Repo polish

- **Vim config not tracked** — `EDITOR='vim'` in `.profile` but no `.vimrc`
  in the repo. Either commit a vim config or switch to a different editor
  (`hx`, `nvim`).

## Ideas for next round (not committed)

- **`brew bundle cleanup --file=thefiles/Brewfile`** — periodically reconcile
  installed-but-not-listed formulas. Read-only with `--dry-run`.
- **Atuin** for shell history with optional sync — useful when you switch
  between machines a lot.
- **`docs/decisions.md`** — add to it as new architectural calls land. The
  log only stays useful if it gets updated.

---

*Updates: append at the relevant section, not at the bottom. Remove items
when they're done.*
