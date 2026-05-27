#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSION_NAME="${FRACTAL_ONECLICK_SESSION:-fractal-indexer-oneclick}"
LOG_DIR="${FRACTAL_ONECLICK_LOG_DIR:-${ROOT_DIR}/logs}"
mkdir -p "${LOG_DIR}"

timestamp="$(date +%Y%m%d-%H%M%S)"
log_file="${LOG_DIR}/deploy-menu-${timestamp}.log"
latest_log="${LOG_DIR}/deploy-menu-latest.log"
ln -sfn "$(basename "${log_file}")" "${latest_log}"

menu_command="cd \"${ROOT_DIR}\" && bash scripts/deploy-menu.sh 2>&1 | tee -a \"${log_file}\""

print_attach_help() {
  cat <<EOF
Persistent session: ${SESSION_NAME}
Log file: ${log_file}

If SSH disconnects, reconnect and run:
  tmux attach -t ${SESSION_NAME}

Or follow the log:
  tail -f ${latest_log}
EOF
}

if command -v tmux >/dev/null 2>&1; then
  if [[ -n "${TMUX:-}" ]]; then
    print_attach_help
    bash -lc "${menu_command}"
    exit $?
  fi
  if tmux has-session -t "${SESSION_NAME}" 2>/dev/null; then
    echo "Attaching existing tmux session: ${SESSION_NAME}"
    tmux attach -t "${SESSION_NAME}"
  else
    print_attach_help
    tmux new-session -s "${SESSION_NAME}" "bash -lc '${menu_command}'"
  fi
  exit $?
fi

if command -v screen >/dev/null 2>&1; then
  cat <<EOF
tmux was not found; using screen.
If SSH disconnects, reconnect and run:
  screen -r ${SESSION_NAME}

Log file:
  ${log_file}
EOF
  screen -S "${SESSION_NAME}" bash -lc "${menu_command}"
  exit $?
fi

cat <<EOF
Neither tmux nor screen was found. Falling back to nohup.
The menu is interactive, so install tmux for the best experience:
  sudo apt-get update && sudo apt-get install -y tmux

Starting a non-interactive background log tail is not enough for first-time
configuration. Re-run this script after installing tmux, or run:
  bash scripts/deploy-menu.sh
EOF

nohup bash -lc "${menu_command}" >"${LOG_DIR}/nohup.out" 2>&1 &
echo "Started background process: $!"
echo "Log file: ${LOG_DIR}/nohup.out"
