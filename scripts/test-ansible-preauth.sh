#!/bin/bash
#
# test-ansible-preauth.sh — does the warm-up open the connection Ansible reuses?
#
#   scripts/test-ansible-preauth.sh [path/to/.ansible_preauth]
#
# A stub `ssh` on PATH logs every call and runs the remote command locally, so
# Ansible completes with no network. Each call is resolved to the socket it
# would use with `ssh -G` (the call's own -o options, plus a test ssh config
# shaped like ~/.ssh/config). For every host, the warm-up (`ssh -fN`) must use
# the socket all of Ansible's connections use: if they differ, every touch
# happens twice. Runs the wrapper sourced into bash and into zsh.
#
# Needs ansible (ansible-core) and ssh. validate.sh skips it without them.

set -uo pipefail
# The run must see only what the test sets (this machine exports a vault
# password file, for one).
while IFS= read -r v; do unset "$v"; done < <(compgen -e | grep '^ANSIBLE_')

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
WRAPPER="${1:-$ROOT/thefiles/.ansible_preauth}"
REAL_SSH=$(command -v ssh) || { echo "needs ssh" >&2; exit 2; }
command -v ansible >/dev/null || { echo "needs ansible" >&2; exit 2; }

# pwd -P: Ansible resolves symlinks in its control dir (macOS /var -> /private/var).
T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/home"
pass=0 failed=0
ok()  { echo "  ✓ $1"; pass=$((pass + 1)); }
bad() { echo "  ✗ $1"; failed=$((failed + 1)); }

cat >"$T/ssh_config" <<'EOF'
Host *
  ControlMaster auto
  ControlPath ~/.ssh/control:%h:%p:%r
  ControlPersist 10m
EOF

# The stub logs "<host> <kind> <socket>" and pretends: -O check finds nothing,
# -fN succeeds, anything else runs the remote command here.
cat >"$T/bin/ssh" <<'EOF'
#!/bin/bash
args=("$@") opts=() kind=run i=0
while (( i < ${#args[@]} )); do
  case "${args[i]}" in
    -o) opts+=(-o "${args[i+1]}"); i=$((i + 2)) ;;
    -O) kind="${args[i+1]}"; i=$((i + 2)) ;;
    -fN) kind=warm; i=$((i + 1)) ;;
    -i|-l|-p|-F|-J) i=$((i + 2)) ;;
    -*) i=$((i + 1)) ;;
    *) break ;;
  esac
done
host="${args[i]}"
sock=$("$REAL_SSH" -G -F "$SSH_CONFIG" "${opts[@]}" "$host" 2>/dev/null |
       awk '$1 == "controlpath" { print $2 }')
echo "$host $kind $sock" >>"$PREAUTH_LOG"
case "$kind" in
  check) exit 1 ;;
  run) cmd=("${args[@]:i+1}"); [[ ${#cmd[@]} -eq 0 ]] || exec /bin/sh -c "${cmd[*]}" ;;
esac
exit 0
EOF
chmod +x "$T/bin/ssh"

# <case> <shell> <ansible.cfg contents, or ""> <command...>: runs the command
# with the wrapper sourced; leaves the log in $T/<case>.<shell>.log.
run() {
  local sh="$2" cfg="$3" dir="$T/$1.$2"
  shift 3
  mkdir -p "$dir"
  printf 'all:\n  hosts:\n    alpha:\n    beta:\n' >"$dir/inv.yml"
  printf -- '- hosts: all\n  gather_facts: false\n  tasks:\n    - ping:\n' >"$dir/play.yml"
  [[ -z "$cfg" ]] || printf '%s\n' "$cfg" >"$dir/ansible.cfg"
  : >"$dir.log"
  # shellcheck disable=SC2016 # expanded by the inner shell
  (cd "$dir" && env HOME="$T/home" PATH="$T/bin:$PATH" REAL_SSH="$REAL_SSH" \
     SSH_CONFIG="$T/ssh_config" PREAUTH_LOG="$dir.log" ANSIBLE_PIPELINING=1 \
     ANSIBLE_HOST_KEY_CHECKING=0 W="$WRAPPER" CMD="$*" \
     "$sh" -c 'source "$W"; eval "$CMD"; echo "leak=${ANSIBLE_SSH_CONTROL_PATH-none}"' \
     >"$dir.out" 2>&1 </dev/null)
}

# <label> <log>: one warm-up per host, and its socket is the one every check
# and every Ansible connection to that host uses.
same_socket() {
  local label="$1" log="$2" h warm
  for h in alpha beta; do
    warm=$(awk -v h="$h" '$1 == h && $2 == "warm"' "$log")
    if [[ $(printf '%s\n' "$warm" | grep -c .) -ne 1 ]]; then
      bad "$label: $h warmed $(printf '%s\n' "$warm" | grep -c .) times, want 1"; continue
    fi
    if ! awk -v h="$h" '$1 == h && $2 == "run"' "$log" | grep -q .; then
      bad "$label: Ansible never connected to $h"; continue
    fi
    if awk -v h="$h" -v s="${warm##* }" '$1 == h && $3 != s { bad = 1 } END { exit !bad }' "$log"; then
      bad "$label: $h warmed ${warm##* }, Ansible used $(awk -v h="$h" '$1 == h && $2 == "run" { print $3; exit }' "$log")"
    else
      ok "$label: $h warmed once, and Ansible reused that socket"
    fi
  done
}

# <label> <out>: the run succeeded, and the shell kept no ANSIBLE_* variable.
ran_clean() {
  if [[ $(grep -c -E 'SUCCESS|ok=1' "$2") -ge 2 ]]; then ok "$1: Ansible ran on both hosts"
  else bad "$1: Ansible did not run on both hosts"; sed 's/^/      /' "$2"; fi
  if grep -q '^leak=none$' "$2"; then ok "$1: nothing left in the shell's environment"
  else bad "$1: $(grep '^leak=' "$2") left in the shell"; fi
}

for sh in bash zsh; do
  command -v "$sh" >/dev/null || { echo "skip: no $sh"; continue; }
  echo "$sh:"

  # Ansible's default: ssh_args has ControlPersist, no ControlPath, so Ansible
  # would hash a path of its own. The case the old wrapper got wrong.
  run default "$sh" "" ansible -i inv.yml all -m ping
  same_socket "default config" "$T/default.$sh.log"
  ran_clean "default config" "$T/default.$sh.out"

  run playbook "$sh" "" ansible-playbook -i inv.yml play.yml
  same_socket "ansible-playbook" "$T/playbook.$sh.log"
  ran_clean "ansible-playbook" "$T/playbook.$sh.out"

  # infrastructure-automation's shape: ssh_args names the path.
  run ssh_args "$sh" "$(printf '[ssh_connection]\nssh_args = -o ControlMaster=auto -o ControlPath=~/.ssh/control:%%h:%%p:%%r -o ControlPersist=10m')" \
    ansible -i inv.yml all -m ping
  same_socket "ssh_args ControlPath" "$T/ssh_args.$sh.log"
  ran_clean "ssh_args ControlPath" "$T/ssh_args.$sh.out"

  run control_path "$sh" "$(printf '[ssh_connection]\ncontrol_path = %%(directory)s/cfg-%%%%h-%%%%r')" \
    ansible -i inv.yml all -m ping
  same_socket "control_path" "$T/control_path.$sh.log"
  ran_clean "control_path" "$T/control_path.$sh.out"

  # No ControlPersist: Ansible adds no ControlPath, so both use the ssh config.
  run no_persist "$sh" "$(printf '[ssh_connection]\nssh_args = -C')" \
    ansible -i inv.yml all -m ping
  same_socket "ssh_args without ControlPersist" "$T/no_persist.$sh.log"
  ran_clean "ssh_args without ControlPersist" "$T/no_persist.$sh.out"

  # A query mode connects to nothing, so nothing is warmed.
  run query "$sh" "" ansible -i inv.yml all --list-hosts
  if grep -q . "$T/query.$sh.log"; then bad "--list-hosts: ssh was called"
  else ok "--list-hosts: ssh never called"; fi
done

echo "$pass passed, $failed failed"
[[ "$failed" -eq 0 && "$pass" -gt 0 ]]
