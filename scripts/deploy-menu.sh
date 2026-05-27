#!/usr/bin/env bash
set -euo pipefail

SNAPSHOT_HEIGHT="${SNAPSHOT_HEIGHT:-1753260}"
SNAPSHOT_BASE_URL="${SNAPSHOT_BASE_URL:-https://snapshot.fractalbitcoin.io/fractal-indexer/${SNAPSHOT_HEIGHT}}"
WAIT_TIMEOUT_DEFAULT="${WAIT_TIMEOUT:-600}"
DEFAULT_RPC_PORT="${DEFAULT_RPC_PORT:-8332}"
SNAPSHOT_MIN_FREE_GB="${SNAPSHOT_MIN_FREE_GB:-400}"
INTERNAL_PORT_BIND_MODE="${INTERNAL_PORT_BIND_MODE:-localhost}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OFFICIAL_DEPLOY_REPO="${OFFICIAL_DEPLOY_REPO:-https://github.com/fractal-bitcoin/fractal-indexer-deploy.git}"
OFFICIAL_DEPLOY_REF="${OFFICIAL_DEPLOY_REF:-}"
OFFICIAL_DEPLOY_UPDATE="${OFFICIAL_DEPLOY_UPDATE:-auto}"
DEPLOY_BUNDLE_DIR="${DEPLOY_BUNDLE_DIR:-${ROOT_DIR}/.official/fractal-indexer-deploy}"
FRACTAL_INDEXER_DIR="${DEPLOY_BUNDLE_DIR}/fractal-indexer"
STAKE_INDEXER_DIR="${DEPLOY_BUNDLE_DIR}/stake-indexer"
STAKE_CONFIG_FILE="${STAKE_INDEXER_DIR}/conf/indexer/config.yaml"
PROOF_PUBLISHER_DIR="${DEPLOY_BUNDLE_DIR}/proof-publisher"
PROOF_CONFIG_EXAMPLE="${PROOF_PUBLISHER_DIR}/config.example.json"
FRACTAL_MENU_COMPOSE="${FRACTAL_INDEXER_DIR}/docker-compose.menu.yaml"
STAKE_MENU_COMPOSE="${STAKE_INDEXER_DIR}/docker-compose.menu.yaml"

COLOR_RESET=""
COLOR_GREEN=""
COLOR_YELLOW=""
COLOR_RED=""
if [[ -t 1 ]]; then
  COLOR_RESET=$'\033[0m'
  COLOR_GREEN=$'\033[32m'
  COLOR_YELLOW=$'\033[33m'
  COLOR_RED=$'\033[31m'
fi

DOCKER_COMPOSE=()
UI_LANG=""

CFG_RPC_URL=""
CFG_ZMQ_BLOCK=""
CFG_ZMQ_TX=""
CFG_RPC_USER=""
CFG_RPC_PASSWORD=""
CFG_FRACTALD_CONF=""
CFG_FRACTALD_DETECTED="false"
CFG_FRACTALD_LOOPBACK_WARN="false"
CFG_RESTORE_SNAPSHOT="true"
CFG_BACKUP_EXISTING_DATA="false"
CFG_STOP_RUNNING="true"
CFG_WAIT_TIMEOUT="${WAIT_TIMEOUT_DEFAULT}"
CFG_PREPARE_PROOF="false"
CFG_START_PROOF="false"
CFG_ALLOW_STAKE_WITHOUT_STATEHASH="false"
CFG_PROOF_RPC_URL=""
CFG_PROOF_RPC_USER=""
CFG_PROOF_RPC_PASSWORD=""
CFG_PROOF_PRIVATE_KEY=""
CFG_PROOF_CHANGE_ADDRESS=""
CFG_PROOF_REWARD_ADDRESS=""
CFG_PROOF_INDEXER_NAME=""
CFG_PROOF_INDEXER_ID=""
CFG_PROOF_UNISAT_KEY=""
CFG_INSTALL_DEPS="true"
CFG_CLONE_SOURCE_REPOS="false"
CFG_RESOURCE_MODE="auto"
CFG_RESOURCE_PERCENT="70"
CFG_MANUAL_FRACTAL_INDEXER_GB=""
CFG_MANUAL_FRACTAL_API_GB=""
CFG_MANUAL_CLICKHOUSE_GB=""
CFG_MANUAL_PIKA_GB=""
CFG_MANUAL_PIKA_BRC20_GB=""
CFG_MANUAL_STAKE_INDEXER_GB=""
CFG_MANUAL_POSTGRES_GB=""
CFG_MANUAL_REDIS_GB=""

main() {
  set_language_from_env

  case "${1:-}" in
    --help|-h)
      print_help
      return 0
      ;;
    --self-test)
      self_test
      return 0
      ;;
    --sync-official)
      ensure_official_deploy_bundle "force"
      return 0
      ;;
    --official-status)
      official_deploy_bundle_status
      return 0
      ;;
    --proof-registration-checklist)
      proof_publisher_registration_checklist
      return 0
      ;;
    --register-operator)
      operator_registration_not_available
      return 2
      ;;
    "")
      select_language
      ensure_official_deploy_bundle "auto" || return 1
      detect_compose || true
      menu_loop
      return 0
      ;;
  esac

  ensure_official_deploy_bundle "auto" || return 1
  detect_compose || true

  case "${1:-}" in
    --check)
      preflight
      return 0
      ;;
    --validate-rpc)
      validate_fractald_rpc_standalone
      return 0
      ;;
    --validate-statehash)
      validate_statehash_standalone
      return 0
      ;;
    --doctor)
      readiness_check
      return 0
      ;;
    --health)
      health_check
      return 0
      ;;
    --validate-proof)
      validate_proof_publisher_config_file
      return 0
      ;;
    *)
      error_i "Unknown argument: ${1}" "未知参数：${1}"
      print_help
      return 1
      ;;
  esac
}

set_language_from_env() {
  case "${DEPLOY_LANG:-}" in
    zh|ZH|cn|CN|chinese|Chinese|中文)
      UI_LANG="zh"
      ;;
    en|EN|english|English)
      UI_LANG="en"
      ;;
    *)
      UI_LANG=""
      ;;
  esac
}

select_language() {
  if [[ -n "${UI_LANG}" ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    UI_LANG="en"
    return 0
  fi

  clear_if_interactive
  cat <<'EOF'
Select language / 选择语言
1) English
2) 中文
EOF
  local choice
  read -r -p "Language [1]: " choice
  case "${choice}" in
    2|zh|ZH|cn|CN|中文)
      UI_LANG="zh"
      ;;
    *)
      UI_LANG="en"
      ;;
  esac
}

choose_text() {
  local en="$1"
  local zh="$2"
  if [[ "${UI_LANG}" == "zh" ]]; then
    printf "%s" "${zh}"
  else
    printf "%s" "${en}"
  fi
}

line_i() {
  choose_text "$1" "$2"
  printf "\n"
}

info_i() {
  printf "%s\n" "${COLOR_GREEN}>>>${COLOR_RESET} $(choose_text "$1" "$2")"
}

warn_i() {
  printf "%s\n" "${COLOR_YELLOW}WARN:${COLOR_RESET} $(choose_text "$1" "$2")" >&2
}

error_i() {
  printf "%s\n" "${COLOR_RED}ERROR:${COLOR_RESET} $(choose_text "$1" "$2")" >&2
}

print_help() {
  if [[ "${UI_LANG}" == "zh" ]]; then
    cat <<EOF
Fractal Indexer 交互式部署菜单

用法：
  bash scripts/deploy-menu.sh
  bash scripts/deploy-menu.sh --check
  bash scripts/deploy-menu.sh --validate-rpc
  bash scripts/deploy-menu.sh --validate-statehash
  bash scripts/deploy-menu.sh --doctor
  bash scripts/deploy-menu.sh --self-test
  bash scripts/deploy-menu.sh --sync-official
  bash scripts/deploy-menu.sh --official-status
  bash scripts/deploy-menu.sh --health
  bash scripts/deploy-menu.sh --validate-proof
  bash scripts/deploy-menu.sh --proof-registration-checklist
  bash scripts/deploy-menu.sh --register-operator

环境变量：
  DEPLOY_LANG=zh|en
  SNAPSHOT_HEIGHT=1753260
  SNAPSHOT_BASE_URL=https://snapshot.fractalbitcoin.io/fractal-indexer/1753260
  WAIT_TIMEOUT=600
  DEFAULT_RPC_PORT=8332
  SNAPSHOT_MIN_FREE_GB=400
  INTERNAL_PORT_BIND_MODE=localhost|official
  OFFICIAL_DEPLOY_REPO=https://github.com/fractal-bitcoin/fractal-indexer-deploy.git
  OFFICIAL_DEPLOY_REF=<branch|tag|commit>
  OFFICIAL_DEPLOY_UPDATE=auto|never
  DEPLOY_BUNDLE_DIR=.official/fractal-indexer-deploy

菜单能力：
  - 中英语言选择
  - 识别 Linux 环境和机器资源
  - 自动识别本机 Fractald 节点配置
  - 可选自动安装缺失运行依赖
  - 生成默认一条路部署可用性诊断
  - 自动拉取/更新官方 fractal-indexer-deploy 部署包
  - 运行脚本内部自测，便于开源维护
  - 一次性收集 RPC/ZMQ/proof-publisher 配置
  - 校验官方镜像、stake-indexer 版本和奖励起点高度
  - 生成本地 Docker Compose 资源 override
  - 恢复官方 fractal-indexer 快照
  - 初始化并启动 fractal-indexer
  - 初始化并启动 stake-indexer
  - 一键配置/校验 proof-publisher dry-run
  - 提供未来运营商注册 checklist，不自动真实广播
  - 预留一键注册运营商入口；官方开放前安全拒绝执行
  - 查看健康检查、状态和日志
EOF
  else
    cat <<EOF
Fractal Indexer Deploy Menu

Usage:
  bash scripts/deploy-menu.sh
  bash scripts/deploy-menu.sh --check
  bash scripts/deploy-menu.sh --validate-rpc
  bash scripts/deploy-menu.sh --validate-statehash
  bash scripts/deploy-menu.sh --doctor
  bash scripts/deploy-menu.sh --self-test
  bash scripts/deploy-menu.sh --sync-official
  bash scripts/deploy-menu.sh --official-status
  bash scripts/deploy-menu.sh --health
  bash scripts/deploy-menu.sh --validate-proof
  bash scripts/deploy-menu.sh --proof-registration-checklist
  bash scripts/deploy-menu.sh --register-operator

Environment:
  DEPLOY_LANG=zh|en
  SNAPSHOT_HEIGHT=1753260
  SNAPSHOT_BASE_URL=https://snapshot.fractalbitcoin.io/fractal-indexer/1753260
  WAIT_TIMEOUT=600
  DEFAULT_RPC_PORT=8332
  SNAPSHOT_MIN_FREE_GB=400
  INTERNAL_PORT_BIND_MODE=localhost|official
  OFFICIAL_DEPLOY_REPO=https://github.com/fractal-bitcoin/fractal-indexer-deploy.git
  OFFICIAL_DEPLOY_REF=<branch|tag|commit>
  OFFICIAL_DEPLOY_UPDATE=auto|never
  DEPLOY_BUNDLE_DIR=.official/fractal-indexer-deploy

The interactive menu can:
  - select English or Chinese
  - detect Linux environment and machine resources
  - auto-detect local Fractald node configuration
  - optionally install missing runtime dependencies
  - generate a default one-pass deployment readiness report
  - fetch/update the official fractal-indexer-deploy bundle automatically
  - run internal script self-tests for maintainers
  - collect RPC/ZMQ/proof-publisher settings once
  - validate official images, stake-indexer version, and reward start height
  - generate local Docker Compose resource overrides
  - restore the official fractal-indexer snapshot
  - initialize and start fractal-indexer
  - initialize and start stake-indexer
  - configure and validate proof-publisher dry-run in one pass
  - show the future operator registration checklist without real broadcasting
  - reserve one-click operator registration; safely refuse before official launch
  - show health checks, status, and logs
EOF
  fi
}

menu_loop() {
  while true; do
    banner
    if [[ "${UI_LANG}" == "zh" ]]; then
      cat <<EOF
1) 一条路自动部署：一次填完配置，然后自动部署
2) 环境识别/补依赖/资源配置
3) 预检依赖
4) 配置 Fractald RPC/ZMQ
5) 验证 Fractald RPC 和快照兼容性
6) 恢复 fractal-indexer 快照（${SNAPSHOT_HEIGHT}）
7) 初始化并启动 fractal-indexer
8) 初始化并启动 stake-indexer
9) proof-publisher dry-run 配置/校验/注册准备
10) 健康检查
11) 查看 Docker Compose 状态
12) 跟随日志
13) 停止服务
14) 切换语言
15) 默认一条路部署诊断
0) 退出
EOF
    else
      cat <<EOF
1) One-pass deployment: collect config once, then deploy automatically
2) Detect environment / install dependencies / configure resources
3) Preflight checks
4) Configure Fractald RPC/ZMQ
5) Validate Fractald RPC and snapshot compatibility
6) Restore fractal-indexer snapshot (${SNAPSHOT_HEIGHT})
7) Initialize and start fractal-indexer
8) Initialize and start stake-indexer
9) proof-publisher dry-run setup / validation / registration prep
10) Health checks
11) Show Docker Compose status
12) Follow logs
13) Stop services
14) Switch language
15) Default one-pass deployment readiness report
0) Exit
EOF
    fi
    printf "\n"
    local choice
    if ! read -r -p "$(choose_text "Select an option" "请选择"): " choice; then
      printf "\n"
      return 0
    fi
    local option_status=0
    case "${choice}" in
      1) guided_deployment || option_status=$? ;;
      2) environment_setup_menu || option_status=$? ;;
      3) preflight || option_status=$? ;;
      4) configure_chain || option_status=$? ;;
      5) validate_fractald_rpc_menu || option_status=$? ;;
      6) restore_snapshot_interactive || option_status=$? ;;
      7) start_fractal_indexer || option_status=$? ;;
      8) start_stake_indexer || option_status=$? ;;
      9) proof_publisher_menu || option_status=$? ;;
      10) health_check || option_status=$? ;;
      11) compose_status || option_status=$? ;;
      12) follow_logs_menu || option_status=$? ;;
      13) stop_services_menu || option_status=$? ;;
      14) UI_LANG=""; select_language || option_status=$? ;;
      15) readiness_check || option_status=$? ;;
      0) exit 0 ;;
      *) warn_i "Unknown option: ${choice}" "未知选项：${choice}" ;;
    esac
    if [[ "${option_status}" -ne 0 ]]; then
      warn_i "Option failed with exit code ${option_status}. Fix the issue above, then choose the next step." "当前选项失败，退出码 ${option_status}。请先处理上面的错误，再选择下一步。"
    fi
    pause
  done
}

banner() {
  clear_if_interactive
  cat <<EOF
${COLOR_GREEN}Fractal Indexer Deploy Menu${COLOR_RESET}
$(choose_text "Language" "语言"):   $(choose_text "English" "中文")
$(choose_text "Repository" "仓库"): ${ROOT_DIR}
$(choose_text "Official deploy bundle" "官方部署包"): ${DEPLOY_BUNDLE_DIR}
$(choose_text "Snapshot" "快照"):   ${SNAPSHOT_HEIGHT}

EOF
}

clear_if_interactive() {
  if [[ -t 1 ]] && command -v clear >/dev/null 2>&1; then
    clear
  fi
}

pause() {
  if [[ -t 0 ]]; then
    printf "\n"
    read -r -p "$(choose_text "Press Enter to continue..." "按 Enter 继续...")" _
  fi
}

ensure_official_deploy_bundle() {
  local mode="${1:-auto}"
  local parent head
  require_command git || return 1
  parent="$(dirname "${DEPLOY_BUNDLE_DIR}")"
  if [[ -d "${DEPLOY_BUNDLE_DIR}/.git" ]]; then
    if ! is_official_repo "${DEPLOY_BUNDLE_DIR}" "${OFFICIAL_DEPLOY_REPO}"; then
      error_i "Existing deploy bundle is not the configured official repository: ${DEPLOY_BUNDLE_DIR}" "现有部署包不是配置的官方仓库：${DEPLOY_BUNDLE_DIR}"
      return 1
    fi
    install_official_deploy_excludes || return 1
    if [[ "${mode}" == "force" || "${OFFICIAL_DEPLOY_UPDATE}" == "auto" ]]; then
      info_i "Updating official fractal-indexer-deploy bundle" "更新官方 fractal-indexer-deploy 部署包"
      sync_official_deploy_bundle || return 1
    fi
  else
    if [[ -e "${DEPLOY_BUNDLE_DIR}" ]]; then
      error_i "Deploy bundle path exists but is not a git repository: ${DEPLOY_BUNDLE_DIR}" "部署包路径已存在但不是 git 仓库：${DEPLOY_BUNDLE_DIR}"
      return 1
    fi
    mkdir -p "${parent}" || return 1
    info_i "Cloning official fractal-indexer-deploy bundle" "克隆官方 fractal-indexer-deploy 部署包"
    git clone "${OFFICIAL_DEPLOY_REPO}" "${DEPLOY_BUNDLE_DIR}" || return 1
    install_official_deploy_excludes || return 1
    if [[ -n "${OFFICIAL_DEPLOY_REF}" ]]; then
      sync_official_deploy_bundle || return 1
    fi
  fi
  require_official_deploy_files || return 1
  head="$(git -C "${DEPLOY_BUNDLE_DIR}" rev-parse --short HEAD 2>/dev/null || printf "unknown")"
  line_i "OK   official deploy bundle ready: ${DEPLOY_BUNDLE_DIR} (${head})" "OK   官方部署包已就绪：${DEPLOY_BUNDLE_DIR}（${head}）"
}

sync_official_deploy_bundle() {
  local branch current
  git -C "${DEPLOY_BUNDLE_DIR}" fetch --tags origin || return 1
  if [[ -n "${OFFICIAL_DEPLOY_REF}" ]]; then
    git -C "${DEPLOY_BUNDLE_DIR}" checkout --detach "${OFFICIAL_DEPLOY_REF}" || return 1
    return 0
  fi

  branch="$(official_deploy_default_branch)" || return 1
  current="$(git -C "${DEPLOY_BUNDLE_DIR}" branch --show-current 2>/dev/null || true)"
  if [[ -z "${current}" ]]; then
    if git -C "${DEPLOY_BUNDLE_DIR}" show-ref --verify --quiet "refs/heads/${branch}"; then
      git -C "${DEPLOY_BUNDLE_DIR}" checkout "${branch}" || return 1
    else
      git -C "${DEPLOY_BUNDLE_DIR}" checkout -b "${branch}" --track "origin/${branch}" || return 1
    fi
  fi

  git -C "${DEPLOY_BUNDLE_DIR}" pull --ff-only || return 1
}

official_deploy_default_branch() {
  local branch
  branch="$(git -C "${DEPLOY_BUNDLE_DIR}" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  branch="${branch#origin/}"
  if [[ -n "${branch}" ]]; then
    printf "%s" "${branch}"
    return 0
  fi

  git -C "${DEPLOY_BUNDLE_DIR}" remote set-head origin -a >/dev/null 2>&1 || true
  branch="$(git -C "${DEPLOY_BUNDLE_DIR}" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  branch="${branch#origin/}"
  if [[ -n "${branch}" ]]; then
    printf "%s" "${branch}"
    return 0
  fi

  if git -C "${DEPLOY_BUNDLE_DIR}" show-ref --verify --quiet refs/remotes/origin/main; then
    printf "main"
    return 0
  fi
  if git -C "${DEPLOY_BUNDLE_DIR}" show-ref --verify --quiet refs/remotes/origin/master; then
    printf "master"
    return 0
  fi

  error_i "Could not determine the official deploy repository default branch." "无法识别官方部署仓库的默认分支。"
  return 1
}

install_official_deploy_excludes() {
  local exclude_file entry
  exclude_file="${DEPLOY_BUNDLE_DIR}/.git/info/exclude"
  mkdir -p "$(dirname "${exclude_file}")" || return 1
  touch "${exclude_file}" || return 1
  for entry in \
    "/fractal-indexer/conf/indexer/chain.yaml" \
    "/stake-indexer/conf/indexer/chain.yaml" \
    "/proof-publisher/config.json" \
    "/fractal-indexer/docker-compose.override.yaml" \
    "/stake-indexer/docker-compose.override.yaml" \
    "/fractal-indexer/docker-compose.menu.yaml" \
    "/stake-indexer/docker-compose.menu.yaml" \
    "/fractal-indexer/data/" \
    "/stake-indexer/data/" \
    "/proof-publisher/logs/" \
    "/logs/" \
    "*.bak.*" \
    "data.backup.*/" \
    "data.restore.*/"; do
    grep -Fxq "${entry}" "${exclude_file}" 2>/dev/null || printf "%s\n" "${entry}" >>"${exclude_file}"
  done
}

official_deploy_bundle_status() {
  require_command git || return 1
  if [[ ! -d "${DEPLOY_BUNDLE_DIR}/.git" ]]; then
    warn_i "Official deploy bundle is not cloned yet: ${DEPLOY_BUNDLE_DIR}" "官方部署包尚未克隆：${DEPLOY_BUNDLE_DIR}"
    return 1
  fi
  install_official_deploy_excludes || return 1
  git -C "${DEPLOY_BUNDLE_DIR}" remote -v
  git -C "${DEPLOY_BUNDLE_DIR}" status --short --branch
  git -C "${DEPLOY_BUNDLE_DIR}" log --oneline -3
}

require_official_deploy_files() {
  local failed=0
  [[ -d "${FRACTAL_INDEXER_DIR}" ]] || { error_i "Missing official fractal-indexer directory in deploy bundle." "官方部署包缺少 fractal-indexer 目录。"; failed=1; }
  [[ -d "${STAKE_INDEXER_DIR}" ]] || { error_i "Missing official stake-indexer directory in deploy bundle." "官方部署包缺少 stake-indexer 目录。"; failed=1; }
  [[ -d "${PROOF_PUBLISHER_DIR}" ]] || { error_i "Missing official proof-publisher directory in deploy bundle." "官方部署包缺少 proof-publisher 目录。"; failed=1; }
  [[ -f "${FRACTAL_INDEXER_DIR}/docker-compose.yaml" ]] || failed=1
  [[ -f "${STAKE_INDEXER_DIR}/docker-compose.yaml" ]] || failed=1
  [[ -f "${PROOF_PUBLISHER_DIR}/docker-compose.yaml" ]] || failed=1
  [[ -f "${STAKE_CONFIG_FILE}" ]] || failed=1
  return "${failed}"
}

detect_compose() {
  if command_exists docker; then
    if docker compose version >/dev/null 2>&1 || { command_exists sudo && sudo -n docker compose version >/dev/null 2>&1; }; then
      DOCKER_COMPOSE=(docker compose)
      return 0
    fi
  fi
  if command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE=(docker-compose)
    return 0
  fi
  return 1
}

compose() {
  local dir="$1"
  shift
  local compose_files=()
  if [[ ${#DOCKER_COMPOSE[@]} -eq 0 ]]; then
    detect_compose || {
      error_i "Docker Compose was not found. Install Docker Compose before continuing." "没有找到 Docker Compose，请先安装后再继续。"
      return 1
    }
  fi
  if [[ -f "${dir}/docker-compose.menu.yaml" ]]; then
    compose_files=(-f docker-compose.menu.yaml)
    if [[ -f "${dir}/docker-compose.override.yaml" ]]; then
      compose_files+=(-f docker-compose.override.yaml)
    fi
  fi
  if docker_daemon_accessible; then
    (cd "${dir}" && "${DOCKER_COMPOSE[@]}" "${compose_files[@]}" "$@")
    return $?
  fi
  if docker_daemon_accessible_with_sudo; then
    (cd "${dir}" && sudo -n "${DOCKER_COMPOSE[@]}" "${compose_files[@]}" "$@")
    return $?
  fi
  if docker_sudo_prompt_possible; then
    warn_i "Docker needs sudo for this user. You may be prompted for the sudo password." "当前用户访问 Docker 需要 sudo，可能会提示输入 sudo 密码。"
    (cd "${dir}" && sudo "${DOCKER_COMPOSE[@]}" "${compose_files[@]}" "$@")
    return $?
  fi
  error_i "Docker daemon is not accessible. Run this script as a Docker-enabled user or with sudo." "Docker daemon 不可访问。请使用有 Docker 权限的用户运行，或用 sudo 运行。"
  return 1
}

docker_cmd() {
  if docker_daemon_accessible; then
    docker "$@"
    return $?
  fi
  if docker_daemon_accessible_with_sudo; then
    sudo -n docker "$@"
    return $?
  fi
  if docker_sudo_prompt_possible; then
    warn_i "Docker needs sudo for this user. You may be prompted for the sudo password." "当前用户访问 Docker 需要 sudo，可能会提示输入 sudo 密码。"
    sudo docker "$@"
    return $?
  fi
  error_i "Docker daemon is not accessible. Run this script as a Docker-enabled user or with sudo." "Docker daemon 不可访问。请使用有 Docker 权限的用户运行，或用 sudo 运行。"
  return 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

file_exists() {
  local path="$1"
  [[ -f "${path}" ]] || { command_exists sudo && sudo -n test -f "${path}" 2>/dev/null; }
}

file_readable() {
  local path="$1"
  [[ -r "${path}" ]] || { command_exists sudo && sudo -n test -r "${path}" 2>/dev/null; }
}

docker_daemon_accessible() {
  command_exists docker || return 1
  docker ps >/dev/null 2>&1
}

docker_daemon_accessible_with_sudo() {
  command_exists docker || return 1
  command_exists sudo || return 1
  sudo -n docker ps >/dev/null 2>&1
}

docker_sudo_prompt_possible() {
  command_exists docker || return 1
  command_exists sudo || return 1
  [[ -t 0 ]]
}

os_pretty_name() {
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    printf "%s" "${PRETTY_NAME:-${ID:-unknown}}"
  else
    uname -s
  fi
}

os_id() {
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    printf "%s" "${ID:-unknown}"
  else
    printf "unknown"
  fi
}

package_manager() {
  if command_exists apt-get; then
    printf "apt"
  elif command_exists dnf; then
    printf "dnf"
  elif command_exists yum; then
    printf "yum"
  elif command_exists apk; then
    printf "apk"
  else
    printf "unknown"
  fi
}

apt_package_available() {
  local package="$1"
  command_exists apt-cache || return 1
  apt-cache show "${package}" >/dev/null 2>&1
}

sudo_prefix() {
  if [[ "$(id -u)" -eq 0 ]]; then
    printf ""
  elif command_exists sudo; then
    printf "sudo "
  else
    printf "NO_SUDO"
  fi
}

cpu_count() {
  nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || printf "unknown"
}

mem_total_gb() {
  awk '/MemTotal/ {printf "%.0f", ($2/1024/1024)}' /proc/meminfo 2>/dev/null || printf "0"
}

mem_available_gb() {
  awk '/MemAvailable/ {printf "%.0f", ($2/1024/1024)}' /proc/meminfo 2>/dev/null || printf "0"
}

disk_available_gb() {
  df -BG "${ROOT_DIR}" 2>/dev/null | awk 'NR==2 {gsub("G","",$4); print $4}' || printf "0"
}

missing_dependencies() {
  local missing=()
  command_exists sudo || missing+=("sudo")
  command_exists curl || missing+=("curl")
  command_exists tar || missing+=("tar")
  command_exists zstd || missing+=("zstd")
  command_exists git || missing+=("git")
  command_exists docker || missing+=("docker")
  detect_compose || missing+=("docker-compose")
  if [[ "${#missing[@]}" -gt 0 ]]; then
    printf "%s\n" "${missing[@]}"
  fi
}

print_environment_summary() {
  info_i "Environment summary" "环境摘要"
  printf "  OS: %s\n" "$(os_pretty_name)"
  printf "  Package manager: %s\n" "$(package_manager)"
  printf "  CPU cores: %s\n" "$(cpu_count)"
  printf "  Memory: %s GB\n" "$(mem_total_gb)"
  printf "  Available memory: %s GB\n" "$(mem_available_gb)"
  printf "  Free disk near repo: %s GB\n" "$(disk_available_gb)"
  if command_exists docker; then
    printf "  Docker: %s\n" "$(docker --version 2>/dev/null || printf "installed")"
  else
    printf "  Docker: missing\n"
  fi
  if detect_compose; then
    printf "  Compose: %s\n" "${DOCKER_COMPOSE[*]}"
  else
    printf "  Compose: missing\n"
  fi
  printf "\n"
  info_i "Related repositories" "相关源码库"
  check_related_repo "fractal-indexer" "${ROOT_DIR}/../fractal-indexer" "https://github.com/fractal-bitcoin/fractal-indexer"
  check_related_repo "stake-indexer" "${ROOT_DIR}/../stake-indexer" "https://github.com/fractal-bitcoin/stake-indexer"
  check_related_repo "fractal-proof-publisher" "${ROOT_DIR}/../fractal-proof-publisher" "https://github.com/fractal-bitcoin/fractal-proof-publisher"
  line_i "  Note: source repositories are optional for research only; deployment uses official Docker images and the runtime official deploy bundle." "  说明：源码库仅用于研究；部署只使用官方 Docker 镜像和运行时官方部署包。"
  printf "\n"
  detect_fractald_config false
  print_fractald_detection_summary
}

check_related_repo() {
  local name="$1"
  local path="$2"
  local url="$3"
  if [[ -d "${path}/.git" ]]; then
    local head
    head="$(git -C "${path}" rev-parse --short HEAD 2>/dev/null || printf "unknown")"
    printf "  OK   %s: %s (%s)\n" "${name}" "${path}" "${head}"
  elif [[ -d "${path}" ]]; then
    printf "  OK   %s: %s\n" "${name}" "${path}"
  else
    printf "  SKIP %s: %s\n" "${name}" "$(choose_text "not cloned, optional for deployment" "未克隆，部署时可选")"
    printf "       %s\n" "${url}"
  fi
}

detect_fractald_config() {
  local verbose="${1:-true}"
  local conf
  CFG_FRACTALD_CONF=""
  CFG_FRACTALD_DETECTED="false"
  CFG_FRACTALD_LOOPBACK_WARN="false"
  conf="$(find_fractald_conf || true)"
  if [[ -n "${conf}" && -f "${conf}" ]] && file_readable "${conf}"; then
    CFG_FRACTALD_CONF="${conf}"
    apply_fractald_conf "${conf}"
    CFG_FRACTALD_DETECTED="true"
  else
    apply_fractald_process_args
  fi

  if [[ "${CFG_FRACTALD_DETECTED}" != "true" ]]; then
    CFG_RPC_URL="${CFG_RPC_URL:-http://fractald:${DEFAULT_RPC_PORT}}"
    CFG_ZMQ_BLOCK="${CFG_ZMQ_BLOCK:-tcp://fractald:10330}"
    CFG_ZMQ_TX="${CFG_ZMQ_TX:-tcp://fractald:10331}"
    CFG_RPC_USER="${CFG_RPC_USER:-bitcoinrpc}"
  fi

  if [[ "${verbose}" == "true" ]]; then
    print_fractald_detection_summary
  fi
}

find_fractald_conf() {
  local proc_conf candidate
  for candidate in \
    "${FRACTALD_CONF:-}" \
    "${BITCOIN_CONF:-}"; do
    if [[ -n "${candidate}" ]] && file_exists "${candidate}"; then
      printf "%s" "${candidate}"
      return 0
    fi
  done

  proc_conf="$(process_arg_value "-conf" || true)"
  if [[ -n "${proc_conf}" ]] && file_exists "${proc_conf}"; then
    printf "%s" "${proc_conf}"
    return 0
  fi

  local proc_datadir
  proc_datadir="$(process_arg_value "-datadir" || true)"
  if [[ -n "${proc_datadir}" ]] && file_exists "${proc_datadir}/bitcoin.conf"; then
    printf "%s" "${proc_datadir}/bitcoin.conf"
    return 0
  fi

  for candidate in \
    "/data/fractald-full/bitcoin.conf" \
    "/data/fractald/bitcoin.conf" \
    "/data/fractalbitcoin/bitcoin.conf" \
    "/data/fractal/bitcoin.conf" \
    "${HOME:-}/.fractalbitcoin/bitcoin.conf" \
    "${HOME:-}/.bitcoin/bitcoin.conf" \
    "/root/.fractalbitcoin/bitcoin.conf" \
    "/root/.bitcoin/bitcoin.conf" \
    "/var/lib/fractald-light/bitcoin.conf" \
    "/var/lib/fractald/bitcoin.conf" \
    "/var/lib/fractalbitcoin/bitcoin.conf" \
    "/var/lib/bitcoin/bitcoin.conf"; do
    if [[ -n "${candidate}" ]] && file_exists "${candidate}"; then
      printf "%s" "${candidate}"
      return 0
    fi
  done

  find /data /home /var/lib -maxdepth 4 -type f -name bitcoin.conf \( -path "*/.fractalbitcoin/bitcoin.conf" -o -path "*/fractald*/bitcoin.conf" -o -path "*/fractalbitcoin*/bitcoin.conf" -o -path "*/bitcoin/bitcoin.conf" \) 2>/dev/null | head -n 1
}

process_arg_value() {
  local key="$1"
  local line token previous
  line="$(ps -eo args 2>/dev/null | grep -E '(^|/)(fractald|bitcoind)( |$)' | grep -v grep | head -n 1 || true)"
  [[ -n "${line}" ]] || return 1
  previous=""
  for token in ${line}; do
    if [[ "${previous}" == "${key}" ]]; then
      printf "%s" "${token}"
      return 0
    fi
    case "${token}" in
      "${key}="*)
        printf "%s" "${token#*=}"
        return 0
        ;;
      "${key}")
        previous="${key}"
        ;;
      *)
        previous=""
        ;;
    esac
  done
  return 1
}

process_flag_value() {
  local key="$1"
  process_arg_value "${key}" || true
}

conf_value() {
  local key="$1"
  local file="$2"
  local awk_program='
    /^[[:space:]]*#/ {next}
    /^[[:space:]]*$/ {next}
    {
      k=$1
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
      if (k == key) {
        v=$0
        sub(/^[^=]*=/, "", v)
        sub(/[[:space:]]+#.*$/, "", v)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
        gsub(/^"|"$/, "", v)
        print v
      }
    }
  '
  if [[ -r "${file}" ]]; then
    awk -F= -v key="${key}" "${awk_program}" "${file}" | tail -n 1
    return 0
  fi
  if command_exists sudo && sudo -n test -r "${file}" 2>/dev/null; then
    sudo -n awk -F= -v key="${key}" "${awk_program}" "${file}" | tail -n 1
    return 0
  fi
  return 0
}

apply_fractald_conf() {
  local conf="$1"
  local rpc_user rpc_password rpc_port rpc_bind rpc_connect rpc_host zmq_block zmq_tx datadir cookie_auth
  rpc_user="$(conf_value "rpcuser" "${conf}")"
  rpc_password="$(conf_value "rpcpassword" "${conf}")"
  rpc_port="$(conf_value "rpcport" "${conf}")"
  rpc_bind="$(conf_value "rpcbind" "${conf}")"
  rpc_connect="$(conf_value "rpcconnect" "${conf}")"
  datadir="$(conf_value "datadir" "${conf}")"
  zmq_block="$(conf_value "zmqpubhashblock" "${conf}")"
  [[ -n "${zmq_block}" ]] || zmq_block="$(conf_value "zmqpubrawblock" "${conf}")"
  zmq_tx="$(conf_value "zmqpubrawtx" "${conf}")"
  [[ -n "${zmq_tx}" ]] || zmq_tx="$(conf_value "zmqpubhashtx" "${conf}")"

  if [[ -z "${rpc_user}${rpc_password}" ]]; then
    cookie_auth="$(read_cookie_auth "${datadir:-$(dirname "${conf}")}")"
    if [[ "${cookie_auth}" == *:* ]]; then
      rpc_user="${cookie_auth%%:*}"
      rpc_password="${cookie_auth#*:}"
    fi
  fi

  rpc_host="${rpc_connect:-${rpc_bind:-fractald}}"
  if is_loopback_host "${rpc_host}"; then
    CFG_FRACTALD_LOOPBACK_WARN="true"
  fi
  if is_loopback_zmq "${zmq_block}" || is_loopback_zmq "${zmq_tx}"; then
    CFG_FRACTALD_LOOPBACK_WARN="true"
  fi
  if [[ -z "${rpc_port}" && "${rpc_host}" =~ :[0-9]+$ ]]; then
    rpc_port="${rpc_host##*:}"
  fi
  rpc_port="${rpc_port:-${DEFAULT_RPC_PORT}}"
  rpc_host="$(normalize_rpc_host_for_container "${rpc_host}")"

  CFG_RPC_URL="${CFG_RPC_URL:-http://${rpc_host}:${rpc_port}}"
  CFG_ZMQ_BLOCK="${CFG_ZMQ_BLOCK:-$(normalize_zmq_for_container "${zmq_block:-tcp://fractald:10330}")}"
  CFG_ZMQ_TX="${CFG_ZMQ_TX:-$(normalize_zmq_for_container "${zmq_tx:-tcp://fractald:10331}")}"
  CFG_RPC_USER="${CFG_RPC_USER:-${rpc_user:-bitcoinrpc}}"
  CFG_RPC_PASSWORD="${CFG_RPC_PASSWORD:-${rpc_password:-}}"
}

read_cookie_auth() {
  local datadir="$1"
  local cookie="${datadir}/.cookie"
  if [[ -r "${cookie}" ]]; then
    head -n 1 "${cookie}"
  elif command_exists sudo && sudo -n test -r "${cookie}" 2>/dev/null; then
    sudo -n head -n 1 "${cookie}"
  fi
  return 0
}

apply_fractald_process_args() {
  local rpc_user rpc_password rpc_port zmq_block zmq_tx proc_conf proc_datadir
  proc_conf="$(process_flag_value "-conf")"
  if [[ -n "${proc_conf}" ]] && file_exists "${proc_conf}" && file_readable "${proc_conf}"; then
    CFG_FRACTALD_CONF="${proc_conf}"
    apply_fractald_conf "${proc_conf}"
    CFG_FRACTALD_DETECTED="true"
    return 0
  fi
  proc_datadir="$(process_flag_value "-datadir")"
  if [[ -n "${proc_datadir}" ]] && file_exists "${proc_datadir}/bitcoin.conf" && file_readable "${proc_datadir}/bitcoin.conf"; then
    CFG_FRACTALD_CONF="${proc_datadir}/bitcoin.conf"
    apply_fractald_conf "${proc_datadir}/bitcoin.conf"
    CFG_FRACTALD_DETECTED="true"
    return 0
  fi
  rpc_user="$(process_flag_value "-rpcuser")"
  rpc_password="$(process_flag_value "-rpcpassword")"
  rpc_port="$(process_flag_value "-rpcport")"
  zmq_block="$(process_flag_value "-zmqpubhashblock")"
  [[ -n "${zmq_block}" ]] || zmq_block="$(process_flag_value "-zmqpubrawblock")"
  zmq_tx="$(process_flag_value "-zmqpubrawtx")"
  [[ -n "${zmq_tx}" ]] || zmq_tx="$(process_flag_value "-zmqpubhashtx")"

  if [[ -n "${rpc_user}${rpc_password}${rpc_port}${zmq_block}${zmq_tx}" ]]; then
    CFG_FRACTALD_DETECTED="true"
    CFG_RPC_URL="${CFG_RPC_URL:-http://fractald:${rpc_port:-${DEFAULT_RPC_PORT}}}"
    CFG_ZMQ_BLOCK="${CFG_ZMQ_BLOCK:-$(normalize_zmq_for_container "${zmq_block:-tcp://fractald:10330}")}"
    CFG_ZMQ_TX="${CFG_ZMQ_TX:-$(normalize_zmq_for_container "${zmq_tx:-tcp://fractald:10331}")}"
    CFG_RPC_USER="${CFG_RPC_USER:-${rpc_user:-bitcoinrpc}}"
    CFG_RPC_PASSWORD="${CFG_RPC_PASSWORD:-${rpc_password:-}}"
  fi
}

normalize_rpc_host_for_container() {
  local host="$1"
  host="${host%%,*}"
  host="${host#http://}"
  host="${host#https://}"
  host="${host%%:*}"
  case "${host}" in
    ""|"0.0.0.0"|"127.0.0.1"|"localhost"|"::"|"[::]")
      printf "fractald"
      ;;
    *)
      printf "%s" "${host}"
      ;;
  esac
}

is_loopback_host() {
  local host="$1"
  host="${host%%,*}"
  host="${host#http://}"
  host="${host#https://}"
  host="${host%%:*}"
  case "${host}" in
    "127.0.0.1"|"localhost"|"::1"|"[::1]")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_loopback_zmq() {
  local url="$1"
  case "${url}" in
    tcp://127.0.0.1:*|tcp://localhost:*|tcp://[::1]:*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

normalize_zmq_for_container() {
  local url="$1"
  case "${url}" in
    tcp://127.0.0.1:*|tcp://localhost:*|tcp://0.0.0.0:*)
      printf "tcp://fractald:%s" "${url##*:}"
      ;;
    "")
      printf ""
      ;;
    *)
      printf "%s" "${url}"
      ;;
  esac
}

print_fractald_detection_summary() {
  info_i "Fractald detection" "Fractald 节点识别"
  if [[ "${CFG_FRACTALD_DETECTED}" == "true" ]]; then
    printf "  %s: %s\n" "$(choose_text "Detected" "已识别")" "$(bool_text true)"
    if [[ -n "${CFG_FRACTALD_CONF}" ]]; then
      printf "  config: %s\n" "${CFG_FRACTALD_CONF}"
    fi
    printf "  RPC URL: %s\n" "${CFG_RPC_URL:-<unknown>}"
    printf "  ZMQ block: %s\n" "${CFG_ZMQ_BLOCK:-<unknown>}"
    printf "  ZMQ tx: %s\n" "${CFG_ZMQ_TX:-<unknown>}"
    printf "  RPC user: %s\n" "${CFG_RPC_USER:-<unknown>}"
    printf "  RPC password: %s\n" "$(mask_secret "${CFG_RPC_PASSWORD:-}")"
    if [[ "${CFG_FRACTALD_LOOPBACK_WARN}" == "true" ]]; then
      warn_i "Detected RPC/ZMQ loopback bind. Containers may not reach Fractald through host-gateway unless Fractald also listens on the Docker bridge or 0.0.0.0." "检测到 RPC/ZMQ 绑定在本机回环地址。除非 Fractald 同时监听 Docker bridge 或 0.0.0.0，否则容器可能无法通过 host-gateway 访问 Fractald。"
    fi
  else
    line_i "  Not detected. The wizard will use standard defaults and ask you to confirm them." "  未识别到。向导会使用标准默认值，并让你确认。"
  fi
}

environment_setup_menu() {
  print_environment_summary
  printf "\n"
  if confirm_i "Install or repair missing dependencies now? This may use sudo and system package manager." "现在安装或修复缺失依赖？这可能会使用 sudo 和系统包管理器。" "y"; then
    install_missing_dependencies || return 1
  fi
  printf "\n"
  if confirm_i "Clone optional official source repositories for research?" "是否克隆可选官方源码库用于研究？" "n"; then
    clone_optional_source_repos || return 1
  fi
  printf "\n"
  if confirm_i "Generate Docker Compose resource overrides now?" "现在生成 Docker Compose 资源配置 override？" "y"; then
    collect_resource_config || return 1
    write_resource_overrides || return 1
  fi
}

clone_optional_source_repos() {
  require_command git
  clone_repo_if_missing "fractal-indexer" "${ROOT_DIR}/../fractal-indexer" "https://github.com/fractal-bitcoin/fractal-indexer.git"
  clone_repo_if_missing "stake-indexer" "${ROOT_DIR}/../stake-indexer" "https://github.com/fractal-bitcoin/stake-indexer.git"
  clone_repo_if_missing "fractal-proof-publisher" "${ROOT_DIR}/../fractal-proof-publisher" "https://github.com/fractal-bitcoin/fractal-proof-publisher.git"
}

clone_repo_if_missing() {
  local name="$1"
  local path="$2"
  local url="$3"
  if [[ -d "${path}/.git" ]]; then
    if ! is_official_repo "${path}" "${url}"; then
      warn_i "${name} exists but does not point to the official repository; skipping it." "${name} 已存在但不是官方仓库地址，跳过。"
      return 0
    fi
    info_i "${name} already exists; pulling latest official changes." "${name} 已存在，尝试拉取官方最新代码。"
    git -C "${path}" pull --ff-only || warn_i "Could not fast-forward ${name}; leaving it unchanged." "${name} 无法快进更新，保持现状。"
    return 0
  fi
  if [[ -e "${path}" ]]; then
    warn_i "${path} exists but is not a git repository; skipping." "${path} 已存在但不是 git 仓库，跳过。"
    return 0
  fi
  info_i "Cloning ${name}" "正在克隆 ${name}"
  git clone "${url}" "${path}"
}

is_official_repo() {
  local path="$1"
  local expected="$2"
  local actual expected_no_git repo_name
  actual="$(git -C "${path}" config --get remote.origin.url 2>/dev/null || true)"
  expected_no_git="${expected%.git}"
  repo_name="${expected_no_git##*/}"
  case "${actual}" in
    "${expected}"|"${expected_no_git}"|"git@github.com:fractal-bitcoin/${repo_name}.git"|"git@github.com:fractal-bitcoin/${repo_name}")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

install_missing_dependencies() {
  local pm sudo_cmd missing
  mapfile -t missing < <(missing_dependencies)
  if [[ "${#missing[@]}" -eq 0 ]]; then
    info_i "All required runtime dependencies are already available." "必要运行依赖都已经可用。"
    return 0
  fi

  pm="$(package_manager)"
  sudo_cmd="$(sudo_prefix)"
  if [[ "${sudo_cmd}" == "NO_SUDO" ]]; then
    error_i "Missing sudo. Run as root or install sudo first." "缺少 sudo。请用 root 运行或先安装 sudo。"
    return 1
  fi

  info_i "Missing dependencies:" "缺失依赖："
  printf "  %s\n" "${missing[@]}"
  case "${pm}" in
    apt)
      ${sudo_cmd}apt-get update || return 1
      ${sudo_cmd}apt-get install -y sudo ca-certificates curl gnupg lsb-release tar zstd git || return 1
      if ! command_exists docker; then
        ${sudo_cmd}apt-get install -y docker.io || return 1
      fi
      if ! detect_compose; then
        if apt_package_available docker-compose-plugin; then
          ${sudo_cmd}apt-get install -y docker-compose-plugin || return 1
        else
          ${sudo_cmd}apt-get install -y docker-compose || return 1
        fi
      fi
      ;;
    dnf)
      ${sudo_cmd}dnf install -y sudo ca-certificates curl tar zstd git docker docker-compose-plugin || return 1
      ;;
    yum)
      ${sudo_cmd}yum install -y sudo ca-certificates curl tar zstd git docker docker-compose-plugin || ${sudo_cmd}yum install -y sudo ca-certificates curl tar zstd git docker docker-compose || return 1
      ;;
    apk)
      ${sudo_cmd}apk add --no-cache sudo ca-certificates curl tar zstd git docker docker-cli-compose || return 1
      ;;
    *)
      error_i "Unsupported package manager. Install Docker, Docker Compose, curl, tar, and zstd manually." "暂不支持这个包管理器。请手动安装 Docker、Docker Compose、curl、tar、zstd。"
      return 1
      ;;
  esac

  if command_exists systemctl && command_exists docker; then
    ${sudo_cmd}systemctl enable --now docker || true
  fi
  if command_exists getent && getent group docker >/dev/null 2>&1; then
    local target_user="${SUDO_USER:-${USER:-}}"
    if [[ -n "${target_user}" && "${target_user}" != "root" ]]; then
      ${sudo_cmd}usermod -aG docker "${target_user}" || true
      warn_i "If ${target_user} was just added to the docker group, log out and back in, or run this script with sudo for the current session." "如果刚把 ${target_user} 加入 docker 组，需要重新登录，或当前会话先用 sudo 运行脚本。"
    fi
  fi
  detect_compose || true
  info_i "Dependency installation step completed." "依赖安装步骤完成。"
}

preflight() {
  print_environment_summary
  printf "\n"
  info_i "Checking local dependencies" "检查本机依赖"
  local failed=0
  check_command bash || failed=1
  check_init_privilege || failed=1
  check_command docker || failed=1
  if command_exists docker; then
    if docker_daemon_accessible; then
      line_i "OK   Docker daemon access" "OK   Docker daemon 可访问"
    elif docker_daemon_accessible_with_sudo; then
      warn_i "Docker daemon needs sudo for this user. Compose actions in this menu will use sudo for the current session." "当前用户访问 Docker daemon 需要 sudo。本菜单的 Compose 操作会在当前会话中使用 sudo。"
    elif docker_sudo_prompt_possible; then
      warn_i "Docker daemon needs sudo for this user and no cached sudo credential is available. Interactive Compose actions will ask for the sudo password; for unattended runs, start the menu with sudo or re-login after joining the docker group." "当前用户访问 Docker daemon 需要 sudo，且当前没有缓存的 sudo 凭据。交互式 Compose 操作会提示输入 sudo 密码；无人值守运行请用 sudo 启动菜单，或加入 docker 组后重新登录。"
    else
      error_i "Docker daemon is not accessible. Start Docker and make sure this user can run docker commands." "Docker daemon 不可访问。请启动 Docker，并确认当前用户能执行 docker 命令。"
      failed=1
    fi
  fi
  if detect_compose; then
    printf "OK   Docker Compose: %s\n" "${DOCKER_COMPOSE[*]}"
  else
    printf "MISS Docker Compose\n"
    failed=1
  fi
  check_command curl || failed=1
  check_command tar || failed=1
  check_command zstd || failed=1
  check_command git || true

  if tar --help 2>/dev/null | grep -q -- '--zstd'; then
    line_i "OK   tar supports --zstd" "OK   tar 支持 --zstd"
  else
    warn_i "tar may not support --zstd. Install zstd or GNU tar with zstd support before restoring snapshots." "tar 可能不支持 --zstd。恢复快照前请安装 zstd 或支持 zstd 的 GNU tar。"
  fi

  printf "\n"
  info_i "Checking repository files" "检查仓库文件"
  check_file "${FRACTAL_INDEXER_DIR}/docker-compose.yaml" || failed=1
  check_file "${STAKE_INDEXER_DIR}/docker-compose.yaml" || failed=1
  check_file "${STAKE_CONFIG_FILE}" || failed=1
  check_file "${PROOF_PUBLISHER_DIR}/docker-compose.yaml" || failed=1
  check_bundled_helper_scripts || failed=1
  validate_official_bundle || failed=1
  print_snapshot_disk_advisory
  report_internal_port_binding_policy || failed=1

  printf "\n"
  info_i "Checking API ports on localhost" "检查本机 API 端口"
  check_port_listener_advisory
  probe_url "fractal-indexer bestheight" "http://127.0.0.1:8000/brc20/bestheight" || true
  probe_url "stake-indexer status" "http://127.0.0.1:9637/indexer/status" || true
  probe_url "proof-publisher health" "http://127.0.0.1:8080/healthz" || true

  if [[ "${failed}" -ne 0 ]]; then
    error_i "Preflight checks found missing required dependencies." "预检发现缺少必要依赖。"
    return 1
  fi
  info_i "Preflight checks completed" "预检完成"
}

readiness_check() {
  local failed=0
  info_i "Default one-pass deployment readiness report" "默认一条路部署诊断"
  line_i "This check is non-destructive. It does not restore snapshots, write configs, or start services." "这个检查不会改动部署状态，不会恢复快照、写配置或启动服务。"
  printf "\n"

  preflight || failed=1

  printf "\n"
  info_i "Checking Fractald RPC gate" "检查 Fractald RPC 关卡"
  validate_fractald_rpc_standalone || failed=1

  printf "\n"
  info_i "Checking default snapshot restore disk guard" "检查默认快照恢复磁盘保护线"
  if snapshot_disk_has_min_free; then
    printf "OK   default snapshot disk guard satisfied: %sG available, %sG required\n" "$(snapshot_disk_available_gb)" "$(snapshot_disk_min_required_gb)"
  else
    warn_i "Default one-pass snapshot restore is not ready with current free disk. Use a larger filesystem for this deploy directory, skip snapshot restore, or explicitly lower SNAPSHOT_MIN_FREE_GB only after verifying the final data size." "按当前可用磁盘，默认一条路快照恢复还没准备好。请把部署目录放到更大的文件系统，或跳过快照恢复；只有确认最终数据大小后才显式调低 SNAPSHOT_MIN_FREE_GB。"
    failed=1
  fi

  printf "\n"
  info_i "Checking default startup port availability" "检查默认启动端口可用性"
  default_startup_ports_available || failed=1

  if [[ "${failed}" -ne 0 ]]; then
    error_i "Readiness report found blockers for the default one-pass deployment path." "默认一条路部署诊断发现阻塞项。"
    return 1
  fi
  info_i "Readiness report passed for the default one-pass deployment path." "默认一条路部署诊断通过。"
}

self_test() {
  local failed=0 tmp actual fixture_dir helper_status helper_has_cr helper_ran old_fractal_dir old_proof_dir old_stake_config_file old_proof_config_example
  info_i "Running internal script self-tests" "运行脚本内部自测"
  line_i "This check is non-destructive. It does not use Docker, write configs, or contact Fractald." "这个检查不会改动部署状态，不使用 Docker、不写配置、不连接 Fractald。"

  self_test_assert_success "version 0.1.1 >= 0.1.1" version_at_least "0.1.1" "0.1.1" || failed=1
  self_test_assert_success "version 0.1.2 >= 0.1.1" version_at_least "0.1.2" "0.1.1" || failed=1
  self_test_assert_failure "version 0.1.0 < 0.1.1" version_at_least "0.1.0" "0.1.1" || failed=1
  self_test_assert_failure "non-numeric version is rejected" version_at_least "latest" "0.1.1" || failed=1

  self_test_assert_equal "clamp invalid percent" "30" "$(clamp_int "abc" 30 90)" || failed=1
  self_test_assert_equal "clamp high percent" "90" "$(clamp_int "100" 30 90)" || failed=1
  self_test_assert_equal "normalize RPC loopback" "fractald" "$(normalize_rpc_host_for_container "http://127.0.0.1:8332")" || failed=1
  self_test_assert_equal "normalize RPC explicit host" "10.0.0.2" "$(normalize_rpc_host_for_container "http://10.0.0.2:8332")" || failed=1
  self_test_assert_equal "normalize ZMQ loopback" "tcp://fractald:10330" "$(normalize_zmq_for_container "tcp://127.0.0.1:10330")" || failed=1
  self_test_assert_equal "keep ZMQ explicit host" "tcp://10.0.0.2:10330" "$(normalize_zmq_for_container "tcp://10.0.0.2:10330")" || failed=1
  self_test_assert_success "official repo digest parser accepts official digest" repo_digest_has_official_repo "fractalbitcoin/fractal-indexer@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" "fractalbitcoin/fractal-indexer" || failed=1
  self_test_assert_failure "official repo digest parser rejects foreign digest" repo_digest_has_official_repo "local/fractal-indexer@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" "fractalbitcoin/fractal-indexer" || failed=1
  self_test_assert_equal "image reference repository parses tag" "fractalbitcoin/fractal-indexer" "$(image_reference_repository "fractalbitcoin/fractal-indexer:latest")" || failed=1
  self_test_assert_equal "image reference repository parses digest" "fractalbitcoin/fractal-indexer" "$(image_reference_repository "fractalbitcoin/fractal-indexer@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")" || failed=1
  self_test_assert_equal "image reference repository parses registry port" "registry.example.com:5000/fractal/fractal-indexer" "$(image_reference_repository "registry.example.com:5000/fractal/fractal-indexer:latest")" || failed=1
  self_test_assert_success "fractal-indexer startup enforces pull failure" grep -Fq 'pull_compose_service "${FRACTAL_INDEXER_DIR}" "indexer" "fractal-indexer indexer" || return 1' "${BASH_SOURCE[0]}" || failed=1
  self_test_assert_success "stake-indexer startup enforces pull failure" grep -Fq 'pull_compose_service "${STAKE_INDEXER_DIR}" "indexer" "stake-indexer" || return 1' "${BASH_SOURCE[0]}" || failed=1
  self_test_assert_success "proof-publisher start waits for health" grep -Fq 'wait_for_url "http://127.0.0.1:8080/healthz" "${CFG_WAIT_TIMEOUT}" || return 1' "${BASH_SOURCE[0]}" || failed=1
  self_test_assert_success "proof-publisher health is conditional" grep -Fq 'if [[ "${proof_required}" == "true" ]]; then' "${BASH_SOURCE[0]}" || failed=1
  self_test_assert_success "operator registration command safely refuses before official launch" grep -Fq 'operator registration is not enabled yet' "${BASH_SOURCE[0]}" || failed=1
  local old_docker_cmd
  old_docker_cmd="$(declare -f docker_cmd)"
  fixture_dir="$(mktemp -d)" || return 1
  mkdir -p "${fixture_dir}/proof-publisher" || {
    rm -rf "${fixture_dir}"
    return 1
  }
  printf 'services:\n  proof-publisher:\n    image: fractalbitcoin/fractal-proof-publisher:latest\n' >"${fixture_dir}/proof-publisher/docker-compose.yaml" || {
    rm -rf "${fixture_dir}"
    return 1
  }
  old_proof_dir="${PROOF_PUBLISHER_DIR}"
  PROOF_PUBLISHER_DIR="${fixture_dir}/proof-publisher"
  docker_cmd() {
    local last="${!#}"
    case "${last}" in
      fractalbitcoin/fractal-indexer:latest|fractalbitcoin/fractal-proof-publisher:latest)
        printf "%s\n" "fractalbitcoin/fractal-indexer@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        return 0
        ;;
      local/fractal-indexer:test)
        printf "%s\n" "local/fractal-indexer@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        return 0
        ;;
    esac
    return 1
  }
  self_test_assert_success "official image digest lookup accepts registry digest" image_has_official_repo_digest "fractalbitcoin/fractal-indexer:latest" "fractalbitcoin/fractal-indexer" || failed=1
  self_test_assert_failure "official image digest lookup rejects local digest" image_has_official_repo_digest "local/fractal-indexer:test" "fractalbitcoin/fractal-indexer" || failed=1
  self_test_assert_success "proof-publisher image prerequisite accepts registry manifest" check_proof_publisher_image_prerequisite || failed=1
  self_test_assert_success "proof-publisher image is checked before long deployment work" grep -Fq 'check_proof_publisher_image_prerequisite || return 1' "${BASH_SOURCE[0]}" || failed=1
  eval "${old_docker_cmd}"
  PROOF_PUBLISHER_DIR="${old_proof_dir}"
  rm -rf "${fixture_dir}"

  fixture_dir="$(mktemp -d)" || return 1
  printf 'services:\n  indexer:\n    image: fractalbitcoin/fractal-indexer:latest\n  api:\n    image: "fractalbitcoin/fractal-indexer:v0.2.0"\n  local:\n    image: local/fractal-indexer:test\n' >"${fixture_dir}/compose.yaml" || {
    rm -rf "${fixture_dir}"
    return 1
  }
  self_test_assert_equal "compose service image parser" "fractalbitcoin/fractal-indexer:latest" "$(compose_service_image "${fixture_dir}/compose.yaml" "indexer")" || failed=1
  self_test_assert_equal "compose service image parser strips quotes" "fractalbitcoin/fractal-indexer:v0.2.0" "$(compose_service_image "${fixture_dir}/compose.yaml" "api")" || failed=1
  rm -rf "${fixture_dir}"

  fixture_dir="$(mktemp -d)" || return 1
  mkdir -p "${fixture_dir}/fractal-indexer" || {
    rm -rf "${fixture_dir}"
    return 1
  }
  printf 'services:\n  indexer:\n    image: local/old\n' >"${fixture_dir}/fractal-indexer/docker-compose.yaml" || {
    rm -rf "${fixture_dir}"
    return 1
  }
  printf 'services:\n  indexer:\n    image: fractalbitcoin/fractal-indexer:latest\n' >"${fixture_dir}/fractal-indexer/docker-compose.menu.yaml" || {
    rm -rf "${fixture_dir}"
    return 1
  }
  self_test_assert_equal "active compose file prefers runtime menu copy" "${fixture_dir}/fractal-indexer/docker-compose.menu.yaml" "$(active_compose_file "${fixture_dir}/fractal-indexer")" || failed=1
  rm -rf "${fixture_dir}"

  tmp="$(mktemp)" || return 1
  printf '{"result":"000000000000000057410de57ea7a82ee3aba342d9b7d800d7de3ebb19a591d7","error":null}\n' >"${tmp}" || {
    rm -f "${tmp}"
    return 1
  }
  self_test_assert_equal "json_string result" "000000000000000057410de57ea7a82ee3aba342d9b7d800d7de3ebb19a591d7" "$(json_string "${tmp}" "result")" || failed=1
  printf '{"result":{"blocks":179,"headers":180,"pruned":true,"pruneheight":159},"error":null}\n' >"${tmp}" || {
    rm -f "${tmp}"
    return 1
  }
  self_test_assert_equal "json_number blocks" "179" "$(json_number "${tmp}" "blocks")" || failed=1
  self_test_assert_equal "json_number pruneheight" "159" "$(json_number "${tmp}" "pruneheight")" || failed=1
  rm -f "${tmp}"

  fixture_dir="$(mktemp -d)" || return 1
  mkdir -p "${fixture_dir}/stake-indexer/conf/indexer" "${fixture_dir}/proof-publisher" || {
    rm -rf "${fixture_dir}"
    return 1
  }
  printf 'start_reward_height: 1760000\n' >"${fixture_dir}/stake-indexer/conf/indexer/config.yaml" || {
    rm -rf "${fixture_dir}"
    return 1
  }
  printf '{"scan":{"start_height":1764000}}\n' >"${fixture_dir}/proof-publisher/config.example.json" || {
    rm -rf "${fixture_dir}"
    return 1
  }
  old_stake_config_file="${STAKE_CONFIG_FILE}"
  old_proof_config_example="${PROOF_CONFIG_EXAMPLE}"
  STAKE_CONFIG_FILE="${fixture_dir}/stake-indexer/conf/indexer/config.yaml"
  PROOF_CONFIG_EXAMPLE="${fixture_dir}/proof-publisher/config.example.json"

  actual="$(stake_statehash_height)" || failed=1
  if [[ "${actual:-}" =~ ^[0-9]+$ ]]; then
    printf "OK   stake start_reward_height is numeric: %s\n" "${actual}"
  else
    error_i "stake start_reward_height is not numeric: ${actual:-missing}" "stake start_reward_height 不是数字：${actual:-缺失}"
    failed=1
  fi
  actual="$(proof_config_number "start_height" "0")"
  if [[ "${actual:-}" =~ ^[0-9]+$ && "${actual}" -gt 0 ]]; then
    printf "OK   proof-publisher scan start_height is numeric: %s\n" "${actual}"
  else
    error_i "proof-publisher scan start_height is not numeric: ${actual:-missing}" "proof-publisher scan start_height 不是数字：${actual:-缺失}"
    failed=1
  fi
  STAKE_CONFIG_FILE="${old_stake_config_file}"
  PROOF_CONFIG_EXAMPLE="${old_proof_config_example}"
  rm -rf "${fixture_dir}"

  fixture_dir="$(mktemp -d)" || return 1
  mkdir -p "${fixture_dir}/proof-publisher" || {
    rm -rf "${fixture_dir}"
    return 1
  }
  cat >"${fixture_dir}/proof-publisher/config.json" <<'EOF'
{
  "bitcoin_rpc": {"url": "http://fractald:8332", "user": "bitcoinrpc", "password": "secret"},
  "signing": {"private_key_wif": "Kx11111111111111111111111111111111111111111111111111", "change_address": "bc1pchange"},
  "register": {"reward_addr": "bc1preward", "name": "test-indexer", "indexer_id": ""},
  "runtime": {"unisat_open_api_key": "test-key", "dry_run": true, "disable_broadcast": true}
}
EOF
  old_proof_dir="${PROOF_PUBLISHER_DIR}"
  PROOF_PUBLISHER_DIR="${fixture_dir}/proof-publisher"
  self_test_assert_success "proof-publisher config validator accepts dry-run safe config" validate_proof_publisher_config_file || failed=1
  sed -i 's/"disable_broadcast": true/"disable_broadcast": false/' "${PROOF_PUBLISHER_DIR}/config.json" || failed=1
  self_test_assert_failure "proof-publisher config validator rejects broadcast-enabled config" validate_proof_publisher_config_file || failed=1
  PROOF_PUBLISHER_DIR="${old_proof_dir}"
  rm -rf "${fixture_dir}"

  printf '{"code":0,"data":{"detail":[{"height":1760000,"blockHash":"000000000000000057410de57ea7a82ee3aba342d9b7d800d7de3ebb19a591d7","stateHash":"98a2b6ab8033323c031fcbda19a845c80f98c14551733b5b6a7e97c09edbbe0a"}]}}\n' >"${tmp}" || {
    rm -f "${tmp}"
    return 1
  }
  self_test_assert_success "statehash response with block hash is ready" statehash_response_ready "${tmp}" "1760000" || failed=1
  printf '{"code":0,"data":{"detail":[{"height":1760000,"blockHash":"","stateHash":"98a2b6ab8033323c031fcbda19a845c80f98c14551733b5b6a7e97c09edbbe0a"}]}}\n' >"${tmp}" || {
    rm -f "${tmp}"
    return 1
  }
  self_test_assert_failure "statehash response without block hash is not ready" statehash_response_ready "${tmp}" "1760000" || failed=1
  rm -f "${tmp}"

  fixture_dir="$(mktemp -d)" || return 1
  printf 'services:\n  pika-brc20:\n    ports:\n      - 9222:9221\n  postgres:\n    ports:\n      - "9432:5432"\n' >"${fixture_dir}/source.yaml" || {
    rm -rf "${fixture_dir}"
    return 1
  }
  if write_menu_compose_copy "${fixture_dir}/source.yaml" "${fixture_dir}/menu.yaml" \
    '9222:9221' '127.0.0.1:9222:9221' \
    '9432:5432' '127.0.0.1:9432:5432'; then
    actual="$(grep -F '127.0.0.1:9222:9221' "${fixture_dir}/menu.yaml" || true)"
    if [[ -n "${actual}" ]] && grep -Fq '127.0.0.1:9432:5432' "${fixture_dir}/menu.yaml"; then
      printf "OK   runtime Compose internal-port localization accepts quoted and unquoted mappings\n"
    else
      error_i "runtime Compose internal-port localization was not applied" "运行时 Compose 内部端口限制未生效"
      failed=1
    fi
  else
    failed=1
  fi
  rm -rf "${fixture_dir}"

  fixture_dir="$(mktemp -d)" || return 1
  mkdir -p "${fixture_dir}/scripts" || {
    rm -rf "${fixture_dir}"
    return 1
  }
  printf '#!/usr/bin/env bash\r\nprintf ok > helper-ran\r\n' >"${fixture_dir}/scripts/init.sh" || {
    rm -rf "${fixture_dir}"
    return 1
  }
  helper_has_cr="false"
  grep -q $'\r' "${fixture_dir}/scripts/init.sh" && helper_has_cr="true"
  if [[ "${helper_has_cr}" != "true" ]]; then
    printf "SKIP CRLF helper source-preservation test: this filesystem normalized the CRLF fixture on write\n"
  else
    helper_status=0
    run_init_script "${fixture_dir}" >/dev/null 2>&1 || helper_status=$?
    helper_ran="false"
    [[ -f "${fixture_dir}/helper-ran" ]] && helper_ran="true"
    if [[ "${helper_status}" -eq 0 && "${helper_ran}" == "true" ]] &&
      grep -q $'\r' "${fixture_dir}/scripts/init.sh"; then
      printf "OK   CRLF helper executes through a temporary LF copy without modifying source\n"
    else
      error_i "CRLF helper temporary execution test failed: status=${helper_status}, marker=${helper_ran}" "CRLF 辅助脚本临时执行测试失败：status=${helper_status}、marker=${helper_ran}"
      failed=1
    fi
  fi
  rm -rf "${fixture_dir}"

  fixture_dir="$(mktemp -d)" || return 1
  mkdir -p "${fixture_dir}/scripts" "${fixture_dir}/data/brc20" || {
    rm -rf "${fixture_dir}"
    return 1
  }
  printf '#!/usr/bin/env bash\nset -e\nmkdir -p data/brc20\ntest "$1" == "db" && printf db > data/db-marker\n' >"${fixture_dir}/scripts/init.sh" || {
    rm -rf "${fixture_dir}"
    return 1
  }
  old_fractal_dir="${FRACTAL_INDEXER_DIR}"
  FRACTAL_INDEXER_DIR="${fixture_dir}"
  if run_init_script "${FRACTAL_INDEXER_DIR}" >/dev/null 2>&1; then
    printf "OK   official directory-only init false-tail is normalized to success\n"
  else
    error_i "official directory-only init false-tail handling failed" "官方仅目录初始化的结尾 false 状态处理失败"
    failed=1
  fi
  self_test_assert_failure "empty data directory is not existing index state" fractal_indexer_has_data_files || failed=1
  printf data >"${FRACTAL_INDEXER_DIR}/data/brc20/state.db" || failed=1
  self_test_assert_success "database file is detected as existing index state" fractal_indexer_has_data_files || failed=1
  FRACTAL_INDEXER_DIR="${old_fractal_dir}"
  rm -rf "${fixture_dir}"

  self_test_resource_values || failed=1

  if [[ "${failed}" -ne 0 ]]; then
    error_i "Internal script self-tests failed." "脚本内部自测失败。"
    return 1
  fi
  info_i "Internal script self-tests passed." "脚本内部自测通过。"
}

self_test_assert_equal() {
  local name="$1"
  local expected="$2"
  local actual="$3"
  if [[ "${actual}" == "${expected}" ]]; then
    printf "OK   %s\n" "${name}"
    return 0
  fi
  error_i "${name}: expected '${expected}', got '${actual}'" "${name}：期望 '${expected}'，实际 '${actual}'"
  return 1
}

self_test_assert_success() {
  local name="$1"
  shift
  if "$@"; then
    printf "OK   %s\n" "${name}"
    return 0
  fi
  error_i "${name}: expected success" "${name}：期望成功"
  return 1
}

self_test_assert_failure() {
  local name="$1"
  shift
  if "$@"; then
    error_i "${name}: expected failure" "${name}：期望失败"
    return 1
  fi
  printf "OK   %s\n" "${name}"
}

self_test_resource_values() {
  local old_mode old_fi old_api old_clickhouse old_pika old_pika_brc20 old_stake old_postgres old_redis actual
  old_mode="${CFG_RESOURCE_MODE}"
  old_fi="${CFG_MANUAL_FRACTAL_INDEXER_GB}"
  old_api="${CFG_MANUAL_FRACTAL_API_GB}"
  old_clickhouse="${CFG_MANUAL_CLICKHOUSE_GB}"
  old_pika="${CFG_MANUAL_PIKA_GB}"
  old_pika_brc20="${CFG_MANUAL_PIKA_BRC20_GB}"
  old_stake="${CFG_MANUAL_STAKE_INDEXER_GB}"
  old_postgres="${CFG_MANUAL_POSTGRES_GB}"
  old_redis="${CFG_MANUAL_REDIS_GB}"

  CFG_RESOURCE_MODE="manual"
  CFG_MANUAL_FRACTAL_INDEXER_GB="8"
  CFG_MANUAL_FRACTAL_API_GB="9"
  CFG_MANUAL_CLICKHOUSE_GB="10"
  CFG_MANUAL_PIKA_GB="11"
  CFG_MANUAL_PIKA_BRC20_GB="12"
  CFG_MANUAL_STAKE_INDEXER_GB="2"
  CFG_MANUAL_POSTGRES_GB="3"
  CFG_MANUAL_REDIS_GB="1"
  actual="$(resource_values)"

  CFG_RESOURCE_MODE="${old_mode}"
  CFG_MANUAL_FRACTAL_INDEXER_GB="${old_fi}"
  CFG_MANUAL_FRACTAL_API_GB="${old_api}"
  CFG_MANUAL_CLICKHOUSE_GB="${old_clickhouse}"
  CFG_MANUAL_PIKA_GB="${old_pika}"
  CFG_MANUAL_PIKA_BRC20_GB="${old_pika_brc20}"
  CFG_MANUAL_STAKE_INDEXER_GB="${old_stake}"
  CFG_MANUAL_POSTGRES_GB="${old_postgres}"
  CFG_MANUAL_REDIS_GB="${old_redis}"

  self_test_assert_equal "manual resource values" "8 9 10 11 12 2 3 1" "${actual}"
}

check_bundled_helper_scripts() {
  info_i "Checking bundled helper scripts" "检查内置辅助脚本"
  check_script_file "${FRACTAL_INDEXER_DIR}/scripts/init.sh" || return 1
  check_script_file "${STAKE_INDEXER_DIR}/scripts/init.sh" || return 1
  check_script_file "${PROOF_PUBLISHER_DIR}/scripts/init.sh" || return 1
}

check_command() {
  if command_exists "$1"; then
    printf "OK   %s\n" "$1"
    return 0
  fi
  printf "MISS %s\n" "$1"
  return 1
}

check_init_privilege() {
  if ! command_exists sudo; then
    error_i "The official init.sh scripts invoke sudo for data-directory ownership, but sudo is not installed. Install sudo before deployment." "官方 init.sh 会调用 sudo 设置数据目录权限，但当前未安装 sudo。部署前请安装 sudo。"
    return 1
  fi
  if [[ "$(id -u)" -eq 0 ]]; then
    line_i "OK   init.sh ownership setup: sudo is installed and the script runs as root" "OK   init.sh 权限设置：已安装 sudo，且当前以 root 运行"
    return 0
  fi
  if sudo -n true >/dev/null 2>&1; then
    line_i "OK   init.sh ownership setup: passwordless/cached sudo is available" "OK   init.sh 权限设置：已有免密或已缓存 sudo"
    return 0
  fi
  if [[ -t 0 ]]; then
    warn_i "The official init.sh scripts require sudo for data-directory ownership and may ask for your sudo password during deployment." "官方 init.sh 需要 sudo 设置数据目录权限，部署时可能提示输入 sudo 密码。"
    return 0
  fi
  error_i "The official init.sh scripts require sudo, but this non-interactive run cannot authenticate with sudo. Run interactively, pre-authorize sudo, or run as root." "官方 init.sh 需要 sudo，但当前非交互运行无法完成 sudo 认证。请交互式运行、预先授权 sudo，或以 root 运行。"
  return 1
}

check_file() {
  if [[ -f "$1" ]]; then
    printf "OK   %s\n" "${1#${ROOT_DIR}/}"
    return 0
  fi
  printf "MISS %s\n" "${1#${ROOT_DIR}/}"
  return 1
}

stake_config_scalar() {
  local key="$1"
  if [[ ! -f "${STAKE_CONFIG_FILE}" ]]; then
    error_i "Missing ${STAKE_CONFIG_FILE#${ROOT_DIR}/}." "缺少 ${STAKE_CONFIG_FILE#${ROOT_DIR}/}。"
    return 1
  fi
  awk -F: -v key="${key}" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      value=$2
      sub(/[[:space:]]*#.*/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/\r/, "", value)
      print value
      exit
    }
  ' "${STAKE_CONFIG_FILE}"
}

stake_statehash_height() {
  local height
  height="$(stake_config_scalar "start_reward_height")" || return 1
  if [[ ! "${height}" =~ ^[0-9]+$ ]]; then
    error_i "Cannot read a numeric start_reward_height from ${STAKE_CONFIG_FILE#${ROOT_DIR}/}." "无法从 ${STAKE_CONFIG_FILE#${ROOT_DIR}/} 读取数字类型的 start_reward_height。"
    return 1
  fi
  printf "%s" "${height}"
}

proof_config_number() {
  local key="$1"
  local fallback="$2"
  local value=""
  if [[ -f "${PROOF_CONFIG_EXAMPLE}" ]]; then
    value="$(json_number "${PROOF_CONFIG_EXAMPLE}" "${key}")"
  fi
  if [[ "${value}" =~ ^[0-9]+$ ]]; then
    printf "%s" "${value}"
  else
    printf "%s" "${fallback}"
  fi
}

statehash_url_for_height() {
  local height="$1"
  printf "http://127.0.0.1:8000/brc20/statehash?start=%s&end=%s" "${height}" "${height}"
}

statehash_response_ready() {
  local file="$1"
  local height="$2"
  grep -Eq "\"height\"[[:space:]]*:[[:space:]]*${height}([^0-9]|$)" "${file}" &&
    grep -Eq '"blockHash"[[:space:]]*:[[:space:]]*"[0-9a-fA-F]{64}"' "${file}" &&
    grep -Eq '"stateHash"[[:space:]]*:[[:space:]]*"[0-9a-fA-F]{64}"' "${file}"
}

probe_statehash_ready() {
  local height="$1"
  local tmp="${2:-/tmp/fractal-deploy-menu-statehash.$$}"
  local url
  url="$(statehash_url_for_height "${height}")"
  if curl -fsS --max-time 5 "${url}" >"${tmp}" 2>/dev/null && statehash_response_ready "${tmp}" "${height}"; then
    printf "OK   fractal-indexer statehash %s: %s\n" "${height}" "$(head -c 160 "${tmp}")"
    rm -f "${tmp}"
    return 0
  fi
  rm -f "${tmp}"
  printf "WAIT fractal-indexer statehash %s: %s\n" "${height}" "$(choose_text "not indexed with a confirmed block hash yet" "尚未索引出带有效区块哈希的结果")"
  return 1
}

validate_statehash_standalone() {
  local height
  height="$(stake_statehash_height)" || return 1
  info_i "Validating FIP-101 statehash prerequisite for stake-indexer" "验证 stake-indexer 的 FIP-101 statehash 前置条件"
  probe_statehash_ready "${height}" || {
    error_i "Statehash at configured reward start height ${height} is not ready for stake-indexer." "配置的奖励起点高度 ${height} 的 statehash 尚不足以启动 stake-indexer。"
    return 1
  }
}

validate_official_bundle() {
  local failed=0 stake_image stake_version statehash_height
  local fractal_compose stake_compose proof_compose
  fractal_compose="$(active_compose_file "${FRACTAL_INDEXER_DIR}")"
  stake_compose="$(active_compose_file "${STAKE_INDEXER_DIR}")"
  proof_compose="$(active_compose_file "${PROOF_PUBLISHER_DIR}")"
  validate_official_image_repo "${fractal_compose}" "indexer" "fractalbitcoin/fractal-indexer" "fractal-indexer indexer" || failed=1
  validate_official_image_repo "${fractal_compose}" "api" "fractalbitcoin/fractal-indexer" "fractal-indexer api" || failed=1
  validate_official_image_repo "${proof_compose}" "proof-publisher" "fractalbitcoin/fractal-proof-publisher" "proof-publisher" || failed=1

  stake_image="$(compose_service_image "${stake_compose}" "indexer")"
  stake_image="${stake_image//$'\r'/}"
  case "${stake_image}" in
    "")
      error_i "stake-indexer image is missing from stake-indexer/docker-compose.yaml." "stake-indexer/docker-compose.yaml 缺少 stake-indexer 镜像。"
      failed=1
      ;;
    fractalbitcoin/stake-indexer:latest)
      error_i "This deploy bundle still selects stake-indexer:latest. Update to an official deployment release that pins stake-indexer v0.1.1 or newer before continuing." "当前部署包仍选择 stake-indexer:latest。继续前请更新到固定使用 stake-indexer v0.1.1 或更高版本的官方部署版本。"
      failed=1
      ;;
    fractalbitcoin/stake-indexer:v*)
      stake_version="${stake_image#fractalbitcoin/stake-indexer:v}"
      if version_at_least "${stake_version}" "0.1.1"; then
        printf "OK   official pinned stake-indexer image: %s\n" "${stake_image}"
      else
        error_i "stake-indexer image ${stake_image} is older than official v0.1.1, which is required for the current deployment config." "stake-indexer 镜像 ${stake_image} 低于当前部署配置要求的官方 v0.1.1。"
        failed=1
      fi
      ;;
    fractalbitcoin/stake-indexer:*)
      error_i "stake-indexer image must use an official pinned v0.1.1-or-newer tag, not ${stake_image}." "stake-indexer 镜像必须使用官方固定的 v0.1.1 或更高版本标签，不能使用 ${stake_image}。"
      failed=1
      ;;
    *)
      error_i "stake-indexer image must be an official fractalbitcoin/stake-indexer pinned tag: ${stake_image:-missing}." "stake-indexer 镜像必须是官方 fractalbitcoin/stake-indexer 固定标签：${stake_image:-缺失}。"
      failed=1
      ;;
  esac

  if statehash_height="$(stake_statehash_height)"; then
    printf "OK   statehash readiness height from official stake config: %s\n" "${statehash_height}"
    if [[ "${SNAPSHOT_HEIGHT}" =~ ^[0-9]+$ ]] && (( statehash_height < SNAPSHOT_HEIGHT )); then
      error_i "start_reward_height ${statehash_height} is below snapshot height ${SNAPSHOT_HEIGHT}; the restored snapshot cannot satisfy the readiness gate." "start_reward_height ${statehash_height} 低于快照高度 ${SNAPSHOT_HEIGHT}；恢复该快照后无法满足就绪检查。"
      failed=1
    fi
  else
    failed=1
  fi
  return "${failed}"
}

repo_digest_has_official_repo() {
  local digest="$1"
  local repository="$2"
  local prefix suffix
  prefix="${repository}@sha256:"
  [[ "${digest}" == "${prefix}"* ]] || return 1
  suffix="${digest:${#prefix}}"
  [[ "${suffix}" =~ ^[0-9a-fA-F]{64}$ ]]
}

image_reference_repository() {
  local reference="$1"
  local path last_part
  reference="${reference%%@*}"
  if [[ "${reference}" != *:* ]]; then
    printf "%s" "${reference}"
    return 0
  fi
  path="${reference%/*}"
  last_part="${reference##*/}"
  if [[ "${path}" == "${reference}" ]]; then
    printf "%s" "${reference%%:*}"
  else
    printf "%s/%s" "${path}" "${last_part%%:*}"
  fi
}

active_compose_file() {
  local dir="$1"
  if [[ -f "${dir}/docker-compose.menu.yaml" ]]; then
    printf "%s" "${dir}/docker-compose.menu.yaml"
  else
    printf "%s" "${dir}/docker-compose.yaml"
  fi
}

compose_service_image() {
  local file="$1"
  local service="$2"
  awk -v service="${service}" '
    {
      sub(/\r$/, "")
      line=$0
      stripped=line
      sub(/^[[:space:]]*/, "", stripped)
      if (stripped ~ "^" service ":[[:space:]]*$") {
        in_service=1
        service_indent=length(line)-length(stripped)
        next
      }
      if (!in_service) {
        next
      }
      if (stripped == "" || stripped ~ /^#/) {
        next
      }
      indent=length(line)-length(stripped)
      if (indent <= service_indent) {
        exit
      }
      if (stripped ~ /^image:[[:space:]]*/) {
        value=stripped
        sub(/^image:[[:space:]]*/, "", value)
        sub(/[[:space:]]+#.*$/, "", value)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        gsub(/^"|"$/, "", value)
        print value
        exit
      }
    }
  ' "${file}" 2>/dev/null || true
}

validate_official_image_repo() {
  local compose_file="$1"
  local service="$2"
  local repository="$3"
  local label="$4"
  local image
  image="$(compose_service_image "${compose_file}" "${service}")"
  image="${image//$'\r'/}"
  case "${image}" in
    "${repository}:"*|"${repository}@sha256:"*)
      printf "OK   official %s image: %s\n" "${label}" "${image}"
      ;;
    "")
      error_i "${label} image is missing from ${compose_file#${ROOT_DIR}/}." "${compose_file#${ROOT_DIR}/} 缺少 ${label} 镜像。"
      return 1
      ;;
    *)
      error_i "${label} image must use official repository ${repository}, not ${image}." "${label} 镜像必须使用官方仓库 ${repository}，不能使用 ${image}。"
      return 1
      ;;
  esac
}

image_has_official_repo_digest() {
  local image="$1"
  local repository="$2"
  local digests
  digests="$(docker_cmd image inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "${image}" 2>/dev/null || true)"
  [[ -n "${digests}" ]] || return 1
  while IFS= read -r digest; do
    [[ -z "${digest}" ]] && continue
    if repo_digest_has_official_repo "${digest}" "${repository}"; then
      return 0
    fi
  done <<<"${digests}"
  return 1
}

version_at_least() {
  local version="$1"
  local minimum="$2"
  local major minor patch min_major min_minor min_patch
  IFS=. read -r major minor patch <<<"${version}"
  IFS=. read -r min_major min_minor min_patch <<<"${minimum}"
  major="${major:-0}"
  minor="${minor:-0}"
  patch="${patch:-0}"
  min_major="${min_major:-0}"
  min_minor="${min_minor:-0}"
  min_patch="${min_patch:-0}"
  [[ "${major}${minor}${patch}${min_major}${min_minor}${min_patch}" =~ ^[0-9]+$ ]] || return 1
  if (( major != min_major )); then
    (( major > min_major ))
    return $?
  fi
  if (( minor != min_minor )); then
    (( minor > min_minor ))
    return $?
  fi
  (( patch >= min_patch ))
}

probe_url() {
  local name="$1"
  local url="$2"
  local tmp="/tmp/fractal-deploy-menu-probe.$$"
  if curl -fsS --max-time 5 "${url}" >"${tmp}" 2>/dev/null; then
    printf "OK   %s: %s\n" "${name}" "$(head -c 160 "${tmp}")"
    rm -f "${tmp}"
    return 0
  fi
  rm -f "${tmp}"
  printf "WAIT %s: %s %s\n" "${name}" "$(choose_text "not reachable at" "暂不可访问：")" "${url}"
  return 1
}

check_port_listener_advisory() {
  local ports=("8000:fractal-indexer API" "9222:pika-brc20" "9637:stake-indexer API" "9432:stake-indexer postgres" "9379:stake-indexer redis" "8080:proof-publisher")
  local item port label line
  if command_exists ss; then
    for item in "${ports[@]}"; do
      port="${item%%:*}"
      label="${item#*:}"
      line="$(ss -lntp "sport = :${port}" 2>/dev/null | awk 'NR==2 {print; exit}' || true)"
      print_port_listener_line "${port}" "${label}" "${line}"
    done
    return 0
  fi
  if command_exists netstat; then
    for item in "${ports[@]}"; do
      port="${item%%:*}"
      label="${item#*:}"
      line="$(netstat -lntp 2>/dev/null | awk -v port=":${port}" '$4 ~ port "$" {print; exit}' || true)"
      print_port_listener_line "${port}" "${label}" "${line}"
    done
    return 0
  fi
  warn_i "Neither ss nor netstat was found; skipping local port listener advisory." "未找到 ss 或 netstat，跳过本机端口监听提示。"
}

print_port_listener_line() {
  local port="$1"
  local label="$2"
  local line="$3"
  if [[ -n "${line}" ]]; then
    warn_i "Port ${port} (${label}) already has a listener: ${line}" "端口 ${port}（${label}）已有监听：${line}"
  else
    printf "OK   port %s (%s): no listener detected\n" "${port}" "${label}"
  fi
}

default_startup_ports_available() {
  local ports=("8000:fractal-indexer API" "9222:pika-brc20" "9637:stake-indexer API" "9432:stake-indexer postgres" "9379:stake-indexer redis" "8080:proof-publisher")
  local item port label failed=0
  if ! command_exists ss && ! command_exists netstat; then
    warn_i "Neither ss nor netstat was found; cannot prove default startup ports are free." "未找到 ss 或 netstat，无法证明默认启动端口空闲。"
    return 0
  fi
  for item in "${ports[@]}"; do
    port="${item%%:*}"
    label="${item#*:}"
    if port_has_listener "${port}"; then
      warn_i "Default startup port ${port} (${label}) is already in use." "默认启动端口 ${port}（${label}）已被占用。"
      failed=1
    else
      printf "OK   default startup port %s (%s) is free\n" "${port}" "${label}"
    fi
  done
  return "${failed}"
}

port_has_listener() {
  local port="$1"
  if command_exists ss; then
    ss -lnt "sport = :${port}" 2>/dev/null | awk 'NR==2 {found=1} END {exit found ? 0 : 1}'
    return $?
  fi
  if command_exists netstat; then
    netstat -lnt 2>/dev/null | awk -v port=":${port}" '$4 ~ port "$" {found=1} END {exit found ? 0 : 1}'
    return $?
  fi
  return 1
}

guided_deployment() {
  info_i "One-pass deployment wizard starts" "一条路自动部署向导开始"
  collect_deployment_config
  print_deployment_plan
  confirm_i "Start automatic deployment now?" "确认开始自动部署？" "n" || {
    warn_i "Deployment cancelled before execution." "已在执行前取消部署。"
    return 0
  }
  run_deployment_plan
}

collect_deployment_config() {
  printf "\n"
  info_i "Step 1/5: Environment and resources" "第 1/5 步：环境和资源配置"
  print_environment_summary
  if confirm_i "Automatically install missing dependencies if needed? It covers Docker, Compose, curl, tar, zstd, and git." "如果缺依赖，是否自动安装？包含 Docker、Compose、curl、tar、zstd、git。" "y"; then
    CFG_INSTALL_DEPS="true"
  else
    CFG_INSTALL_DEPS="false"
  fi
  if confirm_i "Clone optional official source repositories for research? Docker deployment does not require them." "是否克隆可选官方源码库用于研究？Docker 部署不强制需要。" "n"; then
    CFG_CLONE_SOURCE_REPOS="true"
  else
    CFG_CLONE_SOURCE_REPOS="false"
  fi
  collect_resource_config

  printf "\n"
  info_i "Step 2/5: Fractald connection" "第 2/5 步：Fractald 连接配置"
  detect_fractald_config true
  collect_chain_config

  printf "\n"
  info_i "Step 3/5: Snapshot and startup behavior" "第 3/5 步：快照和启动行为"
  if confirm_i "Restore official fractal-indexer snapshot before startup?" "启动前恢复官方 fractal-indexer 快照？" "y"; then
    CFG_RESTORE_SNAPSHOT="true"
    if confirm_i "If fractal-indexer/data already exists, move it to a timestamped backup automatically?" "如果 fractal-indexer/data 已存在，是否自动移动到带时间戳的备份目录？" "n"; then
      CFG_BACKUP_EXISTING_DATA="true"
    else
      CFG_BACKUP_EXISTING_DATA="false"
    fi
  else
    CFG_RESTORE_SNAPSHOT="false"
    CFG_BACKUP_EXISTING_DATA="false"
  fi

  if confirm_i "Stop already-running Compose services when needed?" "如果相关 Compose 服务正在运行，是否按需自动停止？" "y"; then
    CFG_STOP_RUNNING="true"
  else
    CFG_STOP_RUNNING="false"
  fi
  CFG_WAIT_TIMEOUT="$(prompt_default_i "API wait timeout in seconds" "API 等待超时时间（秒）" "${WAIT_TIMEOUT_DEFAULT}")"
  if confirm_i "Allow stake-indexer to start before FIP-101 statehash is ready? Observation/debug only." "如果 FIP-101 statehash 尚未就绪，是否仍允许启动 stake-indexer？仅适合观察/调试。" "n"; then
    CFG_ALLOW_STAKE_WITHOUT_STATEHASH="true"
  else
    CFG_ALLOW_STAKE_WITHOUT_STATEHASH="false"
  fi

  printf "\n"
  info_i "Step 4/5: Optional proof-publisher" "第 4/5 步：可选 proof-publisher"
  if confirm_i "Prepare proof-publisher config in dry-run mode?" "是否准备 proof-publisher dry-run 配置？" "n"; then
    CFG_PREPARE_PROOF="true"
    collect_proof_config
    validate_proof_config_globals || return 1
    if confirm_i "Start proof-publisher in dry-run mode after stake-indexer is ready?" "stake-indexer 就绪后是否启动 proof-publisher dry-run？" "n"; then
      CFG_START_PROOF="true"
    else
      CFG_START_PROOF="false"
    fi
  else
    CFG_PREPARE_PROOF="false"
    CFG_START_PROOF="false"
  fi

  printf "\n"
  info_i "Step 5/5: Review before execution" "第 5/5 步：执行前确认"
}

collect_resource_config() {
  line_i "Resource configuration controls Docker container memory limits only. Auto mode uses currently available memory, so a co-located Fractald node keeps its memory headroom." "资源配置只控制 Docker 容器内存限制。自动模式按当前可用内存计算，因此同机 Fractald 会保留已有内存余量。"
  local mode
  mode="$(prompt_default_i "Resource mode: auto or manual" "资源模式：auto 自动 / manual 手动" "${CFG_RESOURCE_MODE}")"
  case "${mode}" in
    manual|m|Manual|MANUAL|手动)
      CFG_RESOURCE_MODE="manual"
      CFG_MANUAL_FRACTAL_INDEXER_GB="$(prompt_default_i "fractal-indexer indexer memory GB" "fractal-indexer indexer 内存 GB" "${CFG_MANUAL_FRACTAL_INDEXER_GB:-8}")"
      CFG_MANUAL_FRACTAL_API_GB="$(prompt_default_i "fractal-indexer api memory GB" "fractal-indexer api 内存 GB" "${CFG_MANUAL_FRACTAL_API_GB:-8}")"
      CFG_MANUAL_CLICKHOUSE_GB="$(prompt_default_i "ClickHouse memory GB" "ClickHouse 内存 GB" "${CFG_MANUAL_CLICKHOUSE_GB:-16}")"
      CFG_MANUAL_PIKA_GB="$(prompt_default_i "Pika memory GB" "Pika 内存 GB" "${CFG_MANUAL_PIKA_GB:-16}")"
      CFG_MANUAL_PIKA_BRC20_GB="$(prompt_default_i "Pika BRC20 memory GB" "Pika BRC20 内存 GB" "${CFG_MANUAL_PIKA_BRC20_GB:-16}")"
      CFG_MANUAL_STAKE_INDEXER_GB="$(prompt_default_i "stake-indexer service memory GB" "stake-indexer 服务内存 GB" "${CFG_MANUAL_STAKE_INDEXER_GB:-4}")"
      CFG_MANUAL_POSTGRES_GB="$(prompt_default_i "PostgreSQL memory GB" "PostgreSQL 内存 GB" "${CFG_MANUAL_POSTGRES_GB:-4}")"
      CFG_MANUAL_REDIS_GB="$(prompt_default_i "Redis memory GB" "Redis 内存 GB" "${CFG_MANUAL_REDIS_GB:-2}")"
      ;;
    *)
      CFG_RESOURCE_MODE="auto"
      CFG_RESOURCE_PERCENT="$(prompt_default_i "Percentage of currently available memory to allocate to indexer containers" "分配给索引器容器的当前可用内存百分比" "${CFG_RESOURCE_PERCENT}")"
      CFG_RESOURCE_PERCENT="$(clamp_int "${CFG_RESOURCE_PERCENT}" 30 90)"
      ;;
  esac
}

clamp_int() {
  local value="$1"
  local min="$2"
  local max="$3"
  if ! [[ "${value}" =~ ^[0-9]+$ ]]; then
    value="${min}"
  fi
  if (( value < min )); then
    value="${min}"
  fi
  if (( value > max )); then
    value="${max}"
  fi
  printf "%s" "${value}"
}

positive_gb() {
  local value="$1"
  local fallback="$2"
  if ! [[ "${value}" =~ ^[0-9]+$ ]]; then
    value="${fallback}"
  fi
  if (( value < 1 )); then
    value=1
  fi
  printf "%s" "${value}"
}

auto_mem_gb() {
  local budget="$1"
  local percent="$2"
  local min="$3"
  local value=$(( budget * percent / 100 ))
  if (( value < min )); then
    value="${min}"
  fi
  printf "%s" "${value}"
}

resource_values() {
  local mem available budget
  local min_indexer min_api min_clickhouse min_pika min_pika_brc20 min_stake min_postgres min_redis
  if [[ "${CFG_RESOURCE_MODE}" == "manual" ]]; then
    printf "%s %s %s %s %s %s %s %s\n" \
      "$(positive_gb "${CFG_MANUAL_FRACTAL_INDEXER_GB}" 8)" \
      "$(positive_gb "${CFG_MANUAL_FRACTAL_API_GB}" 8)" \
      "$(positive_gb "${CFG_MANUAL_CLICKHOUSE_GB}" 16)" \
      "$(positive_gb "${CFG_MANUAL_PIKA_GB}" 16)" \
      "$(positive_gb "${CFG_MANUAL_PIKA_BRC20_GB}" 16)" \
      "$(positive_gb "${CFG_MANUAL_STAKE_INDEXER_GB}" 4)" \
      "$(positive_gb "${CFG_MANUAL_POSTGRES_GB}" 4)" \
      "$(positive_gb "${CFG_MANUAL_REDIS_GB}" 2)"
    return 0
  fi

  mem="$(mem_total_gb)"
  available="$(mem_available_gb)"
  if [[ "${available}" =~ ^[0-9]+$ ]] && (( available >= 8 )); then
    mem="${available}"
  elif ! [[ "${mem}" =~ ^[0-9]+$ ]] || (( mem < 8 )); then
    mem=64
  fi
  if (( mem < 32 )); then
    warn_i "Available memory is low for a full indexer stack. Auto mode will still write conservative minimum limits; consider freeing memory or using manual mode." "当前可用内存偏低，不适合完整索引器栈。自动模式仍会写入保守最低限制；建议先释放内存或改用手动模式。"
  fi
  budget=$(( mem * CFG_RESOURCE_PERCENT / 100 ))
  if (( budget < 8 )); then
    budget=8
  fi
  if (( budget < 24 )); then
    min_indexer=1
    min_api=1
    min_clickhouse=1
    min_pika=1
    min_pika_brc20=1
    min_stake=1
    min_postgres=1
    min_redis=1
    warn_i "Auto resource budget is under 24 GB. Writing 1 GB minimum container caps; use manual mode on small machines." "自动资源预算低于 24GB。将写入 1GB 最小容器上限；小机器建议使用手动模式。"
  else
    min_indexer=4
    min_api=8
    min_clickhouse=4
    min_pika=4
    min_pika_brc20=4
    min_stake=1
    min_postgres=1
    min_redis=1
  fi
  printf "%s %s %s %s %s %s %s %s\n" \
    "$(auto_mem_gb "${budget}" 5 "${min_indexer}")" \
    "$(auto_mem_gb "${budget}" 60 "${min_api}")" \
    "$(auto_mem_gb "${budget}" 16 "${min_clickhouse}")" \
    "$(auto_mem_gb "${budget}" 6 "${min_pika}")" \
    "$(auto_mem_gb "${budget}" 6 "${min_pika_brc20}")" \
    "$(auto_mem_gb "${budget}" 4 "${min_stake}")" \
    "$(auto_mem_gb "${budget}" 2 "${min_postgres}")" \
    "$(auto_mem_gb "${budget}" 1 "${min_redis}")"
}

write_resource_overrides() {
  local fi_mem api_mem clickhouse_mem pika_mem pika_brc20_mem stake_mem postgres_mem redis_mem
  read -r fi_mem api_mem clickhouse_mem pika_mem pika_brc20_mem stake_mem postgres_mem redis_mem < <(resource_values)

  info_i "Writing Docker Compose resource overrides" "写入 Docker Compose 资源 override"
  cat >"${FRACTAL_INDEXER_DIR}/docker-compose.override.yaml" <<EOF
services:
  indexer:
    mem_limit: ${fi_mem}G
  api:
    mem_limit: ${api_mem}G
  clickhouse:
    mem_limit: ${clickhouse_mem}G
  pika:
    mem_limit: ${pika_mem}G
  pika-brc20:
    mem_limit: ${pika_brc20_mem}G
EOF

  cat >"${STAKE_INDEXER_DIR}/docker-compose.override.yaml" <<EOF
services:
  indexer:
    mem_limit: ${stake_mem}G
    extra_hosts:
      - fractal-indexer:host-gateway
      - fractald:host-gateway
  postgres:
    mem_limit: ${postgres_mem}G
  redis:
    mem_limit: ${redis_mem}G
EOF

  write_menu_compose_files || return 1
  printf " - fractal-indexer/docker-compose.override.yaml\n"
  printf " - stake-indexer/docker-compose.override.yaml\n"
}

write_menu_compose_files() {
  case "${INTERNAL_PORT_BIND_MODE}" in
    localhost)
      info_i "Writing local runtime Compose files with internal datastore ports bound to 127.0.0.1" "写入运行时 Compose 文件，将内部存储端口限制为 127.0.0.1"
      write_menu_compose_copy "${FRACTAL_INDEXER_DIR}/docker-compose.yaml" "${FRACTAL_MENU_COMPOSE}" \
        '9222:9221' '127.0.0.1:9222:9221' || return 1
      write_menu_compose_copy "${STAKE_INDEXER_DIR}/docker-compose.yaml" "${STAKE_MENU_COMPOSE}" \
        '9432:5432' '127.0.0.1:9432:5432' \
        '9379:6379' '127.0.0.1:9379:6379' || return 1
      printf " - fractal-indexer/docker-compose.menu.yaml (pika-brc20 localhost only)\n"
      printf " - stake-indexer/docker-compose.menu.yaml (postgres/redis localhost only)\n"
      warn_i "Use this menu for later start/stop/status actions, or pass -f docker-compose.menu.yaml -f docker-compose.override.yaml manually. Plain docker-compose up bypasses the localhost-only internal port policy." "后续启动/停止/查看状态请继续使用本菜单，或手动传入 -f docker-compose.menu.yaml -f docker-compose.override.yaml。直接运行 docker-compose up 会绕过内部端口仅限 localhost 的策略。"
      ;;
    official)
      warn_i "Using official host port exposure for internal datastore ports. Protect ports 9222, 9432, and 9379 with a firewall before startup." "使用官方内部存储端口暴露方式。启动前请用防火墙保护 9222、9432、9379 端口。"
      cp "${FRACTAL_INDEXER_DIR}/docker-compose.yaml" "${FRACTAL_MENU_COMPOSE}" || return 1
      cp "${STAKE_INDEXER_DIR}/docker-compose.yaml" "${STAKE_MENU_COMPOSE}" || return 1
      ;;
    *)
      error_i "Invalid INTERNAL_PORT_BIND_MODE=${INTERNAL_PORT_BIND_MODE}; use localhost or official." "无效的 INTERNAL_PORT_BIND_MODE=${INTERNAL_PORT_BIND_MODE}；请使用 localhost 或 official。"
      return 1
      ;;
  esac
}

write_menu_compose_copy() {
  local source="$1"
  local destination="$2"
  shift 2
  local tmp public secure
  tmp="$(mktemp "${destination}.tmp.XXXXXX")" || return 1
  cp "${source}" "${tmp}" || {
    rm -f "${tmp}"
    return 1
  }
  while [[ "$#" -ge 2 ]]; do
    public="$1"
    secure="$2"
    shift 2
    if grep -Eq "^[[:space:]]*-[[:space:]]*\"?${secure}\"?[[:space:]]*$" "${tmp}"; then
      continue
    fi
    if ! grep -Eq "^[[:space:]]*-[[:space:]]*\"?${public}\"?[[:space:]]*$" "${tmp}"; then
      rm -f "${tmp}"
      error_i "Cannot safely localize internal port mapping ${public} in ${source#${ROOT_DIR}/}; review the updated official Compose file before starting." "无法在 ${source#${ROOT_DIR}/} 中安全限制内部端口映射 ${public}；启动前请审查更新后的官方 Compose 文件。"
      return 1
    fi
    sed -E -i "s|^([[:space:]]*-[[:space:]]*)\"?${public}\"?([[:space:]]*)$|\\1\"${secure}\"\\2|" "${tmp}" || {
      rm -f "${tmp}"
      return 1
    }
  done
  mv "${tmp}" "${destination}" || return 1
}

report_internal_port_binding_policy() {
  info_i "Internal datastore host-port policy" "内部存储主机端口策略"
  case "${INTERNAL_PORT_BIND_MODE}" in
    localhost)
      line_i "OK   one-pass startup writes local runtime Compose files that bind pika-brc20 (9222), PostgreSQL (9432), and Redis (9379) to 127.0.0.1 only" "OK   一条路启动会写入本地运行时 Compose 文件，将 pika-brc20 (9222)、PostgreSQL (9432)、Redis (9379) 仅绑定到 127.0.0.1"
      ;;
    official)
      warn_i "Official Compose publishes internal datastore ports on host interfaces. Firewall ports 9222, 9432, and 9379 before startup." "官方 Compose 会在主机网卡发布内部存储端口。启动前请用防火墙保护 9222、9432、9379。"
      ;;
    *)
      error_i "Invalid INTERNAL_PORT_BIND_MODE=${INTERNAL_PORT_BIND_MODE}; use localhost or official." "无效的 INTERNAL_PORT_BIND_MODE=${INTERNAL_PORT_BIND_MODE}；请使用 localhost 或 official。"
      return 1
      ;;
  esac
  warn_i "Official API ports remain published according to the upstream Compose files (8000, 9637, and optional 8080). Restrict them with firewall or reverse-proxy access rules unless public access is intentional." "官方 API 端口仍按照上游 Compose 文件发布（8000、9637，以及可选的 8080）。除非明确需要公网访问，否则请用防火墙或反向代理访问规则限制它们。"
}

collect_chain_config() {
  CFG_RPC_URL="$(prompt_default_i "Fractald RPC URL visible from containers" "容器内可访问的 Fractald RPC URL" "${CFG_RPC_URL:-http://fractald:${DEFAULT_RPC_PORT}}")"
  CFG_ZMQ_BLOCK="$(prompt_default_i "Fractald ZMQ block URL visible from containers" "容器内可访问的 Fractald ZMQ 区块 URL" "${CFG_ZMQ_BLOCK:-tcp://fractald:10330}")"
  CFG_ZMQ_TX="$(prompt_default_i "Fractald ZMQ tx URL visible from containers" "容器内可访问的 Fractald ZMQ 交易 URL" "${CFG_ZMQ_TX:-tcp://fractald:10331}")"
  CFG_RPC_USER="$(prompt_default_i "Fractald RPC user" "Fractald RPC 用户名" "${CFG_RPC_USER:-bitcoinrpc}")"
  CFG_RPC_PASSWORD="$(prompt_secret_i "Fractald RPC password" "Fractald RPC 密码" "${CFG_RPC_PASSWORD:-}")"
}

collect_proof_config() {
  CFG_PROOF_RPC_URL="$(prompt_default_i "Fractald RPC URL visible from proof-publisher" "proof-publisher 内可访问的 Fractald RPC URL" "${CFG_PROOF_RPC_URL:-${CFG_RPC_URL:-http://fractald:${DEFAULT_RPC_PORT}}}")"
  CFG_PROOF_RPC_USER="$(prompt_default_i "Fractald RPC user for proof-publisher" "proof-publisher 使用的 Fractald RPC 用户名" "${CFG_PROOF_RPC_USER:-${CFG_RPC_USER:-bitcoinrpc}}")"
  CFG_PROOF_RPC_PASSWORD="$(prompt_secret_i "Fractald RPC password for proof-publisher" "proof-publisher 使用的 Fractald RPC 密码" "${CFG_PROOF_RPC_PASSWORD:-${CFG_RPC_PASSWORD:-}}")"
  CFG_PROOF_PRIVATE_KEY="$(prompt_secret_i "Indexer private key WIF or placeholder" "索引器私钥 WIF 或占位符" "${CFG_PROOF_PRIVATE_KEY:-}")"
  CFG_PROOF_CHANGE_ADDRESS="$(prompt_default_i "Change address" "找零地址" "${CFG_PROOF_CHANGE_ADDRESS:-REPLACE_CHANGE_ADDRESS}")"
  CFG_PROOF_REWARD_ADDRESS="$(prompt_default_i "Reward address" "奖励地址" "${CFG_PROOF_REWARD_ADDRESS:-REPLACE_REWARD_ADDRESS}")"
  CFG_PROOF_INDEXER_NAME="$(prompt_default_i "Indexer name" "索引器名称" "${CFG_PROOF_INDEXER_NAME:-REPLACE_INDEXER_NAME}")"
  CFG_PROOF_INDEXER_ID="$(prompt_default_i "Existing indexer id, empty before register" "已有 indexer_id，注册前可留空" "${CFG_PROOF_INDEXER_ID:-}")"
  CFG_PROOF_UNISAT_KEY="$(prompt_secret_i "UniSat Open API key or placeholder" "UniSat Open API key 或占位符" "${CFG_PROOF_UNISAT_KEY:-}")"
}

validate_proof_config_globals() {
  local failed=0
  info_i "Validating proof-publisher dry-run inputs" "验证 proof-publisher dry-run 输入"
  require_proof_value "Fractald RPC URL" "Fractald RPC URL" "${CFG_PROOF_RPC_URL}" || failed=1
  require_proof_value "Fractald RPC user" "Fractald RPC 用户名" "${CFG_PROOF_RPC_USER}" || failed=1
  require_proof_value "Fractald RPC password" "Fractald RPC 密码" "${CFG_PROOF_RPC_PASSWORD}" || failed=1
  require_proof_value "Indexer private key WIF" "索引器私钥 WIF" "${CFG_PROOF_PRIVATE_KEY}" || failed=1
  require_proof_value "Change address" "找零地址" "${CFG_PROOF_CHANGE_ADDRESS}" || failed=1
  require_proof_value "Reward address" "奖励地址" "${CFG_PROOF_REWARD_ADDRESS}" || failed=1
  require_proof_value "Indexer name" "索引器名称" "${CFG_PROOF_INDEXER_NAME}" || failed=1
  require_proof_value "UniSat Open API key" "UniSat Open API key" "${CFG_PROOF_UNISAT_KEY}" || failed=1
  if [[ -n "${CFG_PROOF_INDEXER_ID}" ]] && value_is_placeholder "${CFG_PROOF_INDEXER_ID}"; then
    error_i "Existing indexer id is still a placeholder. Leave it empty before official registration or set the real id after registration." "已有 indexer_id 仍是占位符。官方注册前请留空；注册后再填真实 id。"
    failed=1
  fi
  if [[ "${failed}" -eq 0 ]]; then
    line_i "OK   proof-publisher inputs are complete; generated config will still force dry_run=true and disable_broadcast=true" "OK   proof-publisher 输入完整；生成配置仍会强制 dry_run=true 且 disable_broadcast=true"
  fi
  return "${failed}"
}

require_proof_value() {
  local en="$1"
  local zh="$2"
  local value="$3"
  if [[ -z "${value}" || "${value}" =~ ^[[:space:]]*$ ]]; then
    error_i "${en} is required." "${zh} 为必填项。"
    return 1
  fi
  if value_is_placeholder "${value}"; then
    error_i "${en} cannot be a placeholder." "${zh} 不能是占位符。"
    return 1
  fi
  if [[ "${value}" =~ [[:space:]] ]]; then
    error_i "${en} contains whitespace; check the value before continuing." "${zh} 包含空白字符，请确认后继续。"
    return 1
  fi
}

value_is_placeholder() {
  local value="$1"
  case "${value}" in
    REPLACE_*|"<"*">"|YOUR_*|CHANGE_ME|TODO|TBD)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

print_deployment_plan() {
  local statehash_height
  printf "\n"
  line_i "Deployment plan:" "部署计划："
  printf "  Install missing dependencies: %s\n" "$(bool_text "${CFG_INSTALL_DEPS}")"
  printf "  Clone optional official source repositories: %s\n" "$(bool_text "${CFG_CLONE_SOURCE_REPOS}")"
  printf "  Resource mode: %s\n" "${CFG_RESOURCE_MODE}"
  if [[ "${CFG_RESOURCE_MODE}" == "auto" ]]; then
    printf "  Resource memory percentage: %s%% of currently available memory\n" "${CFG_RESOURCE_PERCENT}"
  else
    printf "  Resource memory: indexer=%sG api=%sG clickhouse=%sG pika=%sG pika-brc20=%sG stake=%sG postgres=%sG redis=%sG\n" \
      "${CFG_MANUAL_FRACTAL_INDEXER_GB}" "${CFG_MANUAL_FRACTAL_API_GB}" "${CFG_MANUAL_CLICKHOUSE_GB}" \
      "${CFG_MANUAL_PIKA_GB}" "${CFG_MANUAL_PIKA_BRC20_GB}" "${CFG_MANUAL_STAKE_INDEXER_GB}" \
      "${CFG_MANUAL_POSTGRES_GB}" "${CFG_MANUAL_REDIS_GB}"
  fi
  printf "  RPC URL: %s\n" "${CFG_RPC_URL}"
  printf "  ZMQ block: %s\n" "${CFG_ZMQ_BLOCK}"
  printf "  ZMQ tx: %s\n" "${CFG_ZMQ_TX}"
  printf "  RPC user: %s\n" "${CFG_RPC_USER}"
  printf "  RPC password: %s\n" "$(mask_secret "${CFG_RPC_PASSWORD}")"
  printf "  Snapshot restore: %s\n" "$(bool_text "${CFG_RESTORE_SNAPSHOT}")"
  printf "  Auto backup existing data: %s\n" "$(bool_text "${CFG_BACKUP_EXISTING_DATA}")"
  printf "  Stop running services when needed: %s\n" "$(bool_text "${CFG_STOP_RUNNING}")"
  printf "  API wait timeout: %s seconds\n" "${CFG_WAIT_TIMEOUT}"
  if statehash_height="$(stake_statehash_height)"; then
    printf "  Statehash readiness height: %s\n" "${statehash_height}"
  fi
  printf "  Allow stake before statehash ready: %s\n" "$(bool_text "${CFG_ALLOW_STAKE_WITHOUT_STATEHASH}")"
  printf "  Prepare proof-publisher dry-run: %s\n" "$(bool_text "${CFG_PREPARE_PROOF}")"
  printf "  Start proof-publisher dry-run: %s\n" "$(bool_text "${CFG_START_PROOF}")"
  if [[ "${CFG_PREPARE_PROOF}" == "true" ]]; then
    printf "  Proof indexer name: %s\n" "${CFG_PROOF_INDEXER_NAME}"
  fi
}

run_deployment_plan() {
  local initialize_from_scratch="false"
  if [[ "${CFG_INSTALL_DEPS}" == "true" ]]; then
    install_missing_dependencies || return 1
  fi
  if [[ "${CFG_CLONE_SOURCE_REPOS}" == "true" ]]; then
    clone_optional_source_repos || return 1
  fi
  preflight || return 1
  if [[ "${CFG_START_PROOF}" == "true" ]]; then
    check_proof_publisher_image_prerequisite || return 1
    printf "\n"
  fi
  printf "\n"
  write_resource_overrides || return 1
  printf "\n"
  write_chain_config_from_globals || return 1
  if [[ "${CFG_RESTORE_SNAPSHOT}" != "true" ]] && ! fractal_indexer_has_data_files; then
    initialize_from_scratch="true"
    warn_i "Snapshot restore is disabled and no existing fractal-indexer database files were found. The official from-genesis initialization path will be used and requires Fractald block data from height 0." "已禁用快照恢复，且未找到已有 fractal-indexer 数据库文件。将使用官方从创世块初始化路径，并要求 Fractald 可提供高度 0 起的区块数据。"
    validate_fractald_rpc_for_deployment "0" || {
      error_i "An empty deployment without the snapshot requires an unpruned historical Fractald node. Enable the official snapshot restore or use a node that can serve block height 0." "空数据部署若不恢复快照，就需要可提供完整历史区块的 Fractald 节点。请启用官方快照恢复，或使用能提供高度 0 区块的节点。"
      return 1
    }
  else
    validate_fractald_rpc_for_deployment || return 1
  fi
  printf "\n"
  if [[ "${CFG_RESTORE_SNAPSHOT}" == "true" ]]; then
    restore_snapshot_plan "${CFG_BACKUP_EXISTING_DATA}" "${CFG_STOP_RUNNING}" || return 1
  else
    warn_i "Skipping snapshot restore. Starting from scratch can take a long time." "跳过快照恢复。从零同步会非常慢。"
  fi
  printf "\n"
  start_fractal_indexer "${initialize_from_scratch}" || return 1
  wait_for_fractal_indexer "${CFG_WAIT_TIMEOUT}" || return 1
  printf "\n"
  start_stake_indexer || return 1
  wait_for_stake_indexer "${CFG_WAIT_TIMEOUT}" || return 1
  printf "\n"
  if [[ "${CFG_PREPARE_PROOF}" == "true" ]]; then
    write_proof_publisher_config_from_globals || return 1
    if [[ "${CFG_START_PROOF}" == "true" ]]; then
      start_proof_publisher_dry_run || return 1
    fi
    printf "\n"
  fi
  health_check
}

configure_chain() {
  info_i "Creating chain.yaml files" "创建 chain.yaml 配置文件"
  detect_fractald_config true
  collect_chain_config
  write_chain_config_from_globals
}

write_chain_config_from_globals() {
  local rpc_auth="${CFG_RPC_USER}:${CFG_RPC_PASSWORD}"
  write_fractal_chain_yaml "${CFG_RPC_URL}" "${CFG_ZMQ_BLOCK}" "${CFG_ZMQ_TX}" "${rpc_auth}" || return 1
  write_stake_chain_yaml "${CFG_RPC_URL}" "${rpc_auth}" || return 1
  info_i "Wrote local chain configs" "已写入本地 chain 配置"
  printf " - %s\n" "fractal-indexer/conf/indexer/chain.yaml"
  printf " - %s\n" "stake-indexer/conf/indexer/chain.yaml"
}

validate_fractald_rpc_standalone() {
  detect_fractald_config true
  validate_fractald_rpc_for_deployment
}

validate_fractald_rpc_menu() {
  if [[ -z "${CFG_RPC_URL}" ]]; then
    detect_fractald_config true
  else
    print_fractald_detection_summary
  fi
  validate_fractald_rpc_for_deployment
}

validate_fractald_rpc_for_deployment() {
  info_i "Validating Fractald RPC from a Docker container" "从 Docker 容器内验证 Fractald RPC"
  local additional_height="${1:-}"
  local tmp_dir config_file output_file
  tmp_dir="$(mktemp -d)" || return 1
  config_file="${tmp_dir}/curl.conf"
  output_file="${tmp_dir}/rpc.json"
  chmod 700 "${tmp_dir}" 2>/dev/null || true
  {
    printf "fail\n"
    printf "silent\n"
    printf "show-error\n"
    printf "max-time = 15\n"
    if [[ -n "${CFG_RPC_USER}${CFG_RPC_PASSWORD}" ]]; then
      printf "user = \"%s:%s\"\n" "$(curl_config_escape "${CFG_RPC_USER}")" "$(curl_config_escape "${CFG_RPC_PASSWORD}")"
    fi
    printf "header = \"content-type: text/plain;\"\n"
  } >"${config_file}" || {
    rm -rf "${tmp_dir}"
    return 1
  }
  chmod 600 "${config_file}" 2>/dev/null || true

  if ! run_rpc_probe "${tmp_dir}" "${config_file}" "${output_file}" "getblockchaininfo" "[]"; then
    rm -rf "${tmp_dir}"
    if [[ "${CFG_FRACTALD_LOOPBACK_WARN}" == "true" ]]; then
      warn_i "Detected Fractald loopback-only RPC/ZMQ config. Add a Docker bridge rpcbind/rpcallowip and ZMQ bind, then restart Fractald. Example: rpcbind=172.17.0.1, rpcallowip=172.16.0.0/12, zmqpubrawblock=tcp://172.17.0.1:10330, zmqpubrawtx=tcp://172.17.0.1:10331." "检测到 Fractald RPC/ZMQ 仅绑定本机回环。请增加 Docker bridge 的 rpcbind/rpcallowip 和 ZMQ 绑定后重启 Fractald。例如：rpcbind=172.17.0.1、rpcallowip=172.16.0.0/12、zmqpubrawblock=tcp://172.17.0.1:10330、zmqpubrawtx=tcp://172.17.0.1:10331。"
    fi
    error_i "Container RPC test failed. Check the RPC URL, credentials, rpcbind/rpcallowip, Docker host-gateway, and whether the node uses port 8332 or 10332." "容器内 RPC 测试失败。请检查 RPC URL、账号密码、rpcbind/rpcallowip、Docker host-gateway，以及节点实际使用 8332 还是 10332。"
    return 1
  fi
  if ! rpc_response_ok "${output_file}"; then
    rm -rf "${tmp_dir}"
    error_i "Container RPC test returned an unexpected response." "容器内 RPC 测试返回了非预期响应。"
    return 1
  fi

  if ! validate_fractald_snapshot_compatibility "${output_file}"; then
    rm -rf "${tmp_dir}"
    return 1
  fi
  if ! validate_fractald_required_blocks "${tmp_dir}" "${config_file}" "${output_file}" "${additional_height}"; then
    rm -rf "${tmp_dir}"
    return 1
  fi
  rm -rf "${tmp_dir}"
}

run_rpc_probe() {
  local tmp_dir="$1"
  local config_file="$2"
  local output_file="$3"
  local method="$4"
  local params="$5"
  local payload_file status
  payload_file="${tmp_dir}/payload-${method}.json"
  printf '{"jsonrpc":"1.0","id":"deploy-menu","method":"%s","params":%s}\n' "${method}" "${params}" >"${payload_file}" || return 1
  status=0
  docker_cmd run --rm \
    --add-host fractald:host-gateway \
    --user "$(id -u):$(id -g)" \
    -v "${tmp_dir}:/tmp/fractal-rpc:ro" \
    curlimages/curl:8.11.1 \
    --config "/tmp/fractal-rpc/$(basename "${config_file}")" \
    --data-binary "@/tmp/fractal-rpc/$(basename "${payload_file}")" \
    "${CFG_RPC_URL}" >"${output_file}" || status=$?
  rm -f "${payload_file}"
  return "${status}"
}

rpc_response_ok() {
  local file="$1"
  grep -q '"result"' "${file}" && grep -Eq '"error"[[:space:]]*:[[:space:]]*null' "${file}"
}

curl_config_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf "%s" "${value}"
}

validate_fractald_snapshot_compatibility() {
  local rpc_output="$1"
  local blocks headers pruned pruneheight
  blocks="$(json_number "${rpc_output}" "blocks")"
  headers="$(json_number "${rpc_output}" "headers")"
  pruneheight="$(json_number "${rpc_output}" "pruneheight")"
  if grep -q '"pruned"[[:space:]]*:[[:space:]]*true' "${rpc_output}"; then
    pruned="true"
  else
    pruned="false"
  fi

  printf "OK   RPC reachable: blocks=%s headers=%s pruned=%s\n" "${blocks:-unknown}" "${headers:-unknown}" "${pruned}"
  if [[ "${pruned}" == "true" ]]; then
    if [[ -z "${pruneheight}" ]]; then
      error_i "Fractald is pruned but pruneheight could not be read from RPC." "Fractald 是剪枝节点，但无法从 RPC 读取 pruneheight。"
      return 1
    fi
    printf "OK   pruneheight=%s, snapshot=%s\n" "${pruneheight}" "${SNAPSHOT_HEIGHT}"
    if (( pruneheight > SNAPSHOT_HEIGHT )); then
      error_i "Fractald has already pruned below the snapshot height. Use a node with pruneheight <= snapshot height, a less-pruned node, or a full node." "Fractald 已经剪掉快照高度之前的数据。请使用 pruneheight <= 快照高度的节点、更少剪枝的节点或全节点。"
      return 1
    fi
  fi
  if [[ -n "${blocks}" && "${blocks}" =~ ^[0-9]+$ ]] && (( blocks < SNAPSHOT_HEIGHT )); then
    warn_i "Fractald block height is below the snapshot height. The indexer may wait until the node catches up." "Fractald 当前高度低于快照高度。索引器可能需要等待节点追上。"
  fi
}

validate_fractald_required_blocks() {
  local tmp_dir="$1"
  local config_file="$2"
  local rpc_output="$3"
  local additional_height="${4:-}"
  local blocks statehash_height height failed=0 seen=""
  blocks="$(json_number "${rpc_output}" "blocks")"
  statehash_height="$(stake_statehash_height 2>/dev/null || true)"

  for height in "${SNAPSHOT_HEIGHT}" "${statehash_height}" "${additional_height}"; do
    [[ "${height}" =~ ^[0-9]+$ ]] || continue
    if [[ "|${seen}|" == *"|${height}|"* ]]; then
      continue
    fi
    seen="${seen}|${height}"
    if [[ "${blocks}" =~ ^[0-9]+$ ]] && (( height > blocks )); then
      warn_i "Skipping required block availability check at height ${height}; Fractald has only synced to ${blocks}." "跳过高度 ${height} 的必要区块可用性检查；Fractald 当前只同步到 ${blocks}。"
      continue
    fi
    validate_fractald_block_available "${tmp_dir}" "${config_file}" "${height}" || failed=1
  done
  return "${failed}"
}

validate_fractald_block_available() {
  local tmp_dir="$1"
  local config_file="$2"
  local height="$3"
  local hash_output block_output hash
  hash_output="${tmp_dir}/getblockhash-${height}.json"
  block_output="${tmp_dir}/getblock-${height}.json"

  if ! run_rpc_probe "${tmp_dir}" "${config_file}" "${hash_output}" "getblockhash" "[${height}]"; then
    error_i "Fractald getblockhash failed at height ${height} from inside Docker." "容器内调用 Fractald getblockhash 失败，高度 ${height}。"
    return 1
  fi
  if ! rpc_response_ok "${hash_output}"; then
    print_rpc_error "getblockhash ${height}" "${hash_output}"
    return 1
  fi
  hash="$(json_string "${hash_output}" "result")"
  if [[ ! "${hash}" =~ ^[0-9a-fA-F]{64}$ ]]; then
    print_rpc_error "getblockhash ${height}" "${hash_output}"
    return 1
  fi

  if ! run_rpc_probe "${tmp_dir}" "${config_file}" "${block_output}" "getblock" "[\"${hash}\",0]"; then
    error_i "Fractald getblock failed at height ${height} from inside Docker." "容器内调用 Fractald getblock 失败，高度 ${height}。"
    return 1
  fi
  if ! rpc_response_ok "${block_output}"; then
    print_rpc_error "getblock ${height}" "${block_output}"
    return 1
  fi
  printf "OK   required block data available at height %s via getblockhash/getblock\n" "${height}"
}

print_rpc_error() {
  local label="$1"
  local file="$2"
  local snippet
  snippet="$(tr -d '\n' <"${file}" | head -c 240)"
  error_i "${label} returned an RPC error or unexpected response: ${snippet}" "${label} 返回 RPC 错误或非预期响应：${snippet}"
}

json_number() {
  local file="$1"
  local key="$2"
  awk -v key="\"${key}\"" '
    { line = line $0 }
    END {
      pos = index(line, key)
      if (!pos) {
        exit
      }
      value = substr(line, pos + length(key))
      sub(/^[[:space:]]*:[[:space:]]*/, "", value)
      if (match(value, /^[0-9]+/)) {
        print substr(value, RSTART, RLENGTH)
      }
    }
  ' "${file}"
}

json_string() {
  local file="$1"
  local key="$2"
  awk -v key="\"${key}\"" '
    { line = line $0 }
    END {
      pos = index(line, key)
      if (!pos) {
        exit
      }
      value = substr(line, pos + length(key))
      sub(/^[[:space:]]*:[[:space:]]*/, "", value)
      if (match(value, /^"[^"]*"/)) {
        print substr(value, RSTART + 1, RLENGTH - 2)
      }
    }
  ' "${file}"
}

prompt_default_i() {
  local en="$1"
  local zh="$2"
  local default="$3"
  local label value
  label="$(choose_text "${en}" "${zh}")"
  read -r -p "${label} [${default}]: " value
  printf "%s" "${value:-${default}}"
}

prompt_secret_i() {
  local en="$1"
  local zh="$2"
  local default="${3:-}"
  local label value suffix
  label="$(choose_text "${en}" "${zh}")"
  if [[ -n "${default}" ]]; then
    suffix="$(choose_text " [press Enter to keep existing value]" " [直接回车保留现有值]")"
  else
    suffix=""
  fi
  if [[ -t 0 ]]; then
    read -r -s -p "${label}${suffix}: " value
    printf "\n" >&2
  else
    read -r -p "${label}${suffix}: " value
  fi
  printf "%s" "${value:-${default}}"
}

confirm_i() {
  local en="$1"
  local zh="$2"
  local default="${3:-n}"
  local label suffix answer
  label="$(choose_text "${en}" "${zh}")"
  if [[ "${default}" == "y" ]]; then
    suffix="[Y/n]"
  else
    suffix="[y/N]"
  fi
  read -r -p "${label} ${suffix}: " answer
  if [[ -z "${answer}" ]]; then
    [[ "${default}" == "y" ]]
    return $?
  fi
  case "${answer}" in
    y|Y|yes|YES|Yes|是|对|好)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

bool_text() {
  if [[ "$1" == "true" ]]; then
    choose_text "yes" "是"
  else
    choose_text "no" "否"
  fi
}

mask_secret() {
  if [[ -z "$1" ]]; then
    printf "%s" "$(choose_text "<empty>" "<空>")"
  else
    printf "******"
  fi
}

backup_if_exists() {
  local path="$1"
  if [[ -f "${path}" ]]; then
    local backup="${path}.bak.$(date +%Y%m%d%H%M%S)"
    if ! cp "${path}" "${backup}" 2>/dev/null; then
      privileged_run cp "${path}" "${backup}" || {
        error_i "Could not back up protected config file ${path#${ROOT_DIR}/}." "无法备份受保护的配置文件 ${path#${ROOT_DIR}/}。"
        return 1
      }
    fi
    secure_backup_file "${backup}" || return 1
    warn_i "Existing config backed up to ${backup#${ROOT_DIR}/}" "已有配置已备份到 ${backup#${ROOT_DIR}/}"
  fi
}

privileged_run() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
    return $?
  fi
  command_exists sudo || return 1
  if sudo -n true >/dev/null 2>&1; then
    sudo -n "$@"
    return $?
  fi
  if [[ -t 0 ]]; then
    sudo "$@"
    return $?
  fi
  return 1
}

secure_backup_file() {
  local path="$1"
  if chmod 600 "${path}" 2>/dev/null; then
    return 0
  fi
  privileged_run chmod 600 "${path}" || {
    error_i "Could not restrict permissions on backup file ${path#${ROOT_DIR}/}." "无法限制备份文件 ${path#${ROOT_DIR}/} 的权限。"
    return 1
  }
}

secure_container_config_file() {
  local path="$1"
  local container_uid="$2"
  if [[ "$(id -u)" -eq "${container_uid}" ]]; then
    chmod 600 "${path}" || return 1
    return 0
  fi
  if privileged_run chown "${container_uid}:${container_uid}" "${path}" &&
    privileged_run chmod 600 "${path}"; then
    return 0
  fi
  error_i "Could not secure ${path#${ROOT_DIR}/} for container uid ${container_uid}. Run the configuration step as uid ${container_uid} or with working sudo/root access." "无法为容器 uid ${container_uid} 安全设置 ${path#${ROOT_DIR}/}。请以 uid ${container_uid} 或可用 sudo/root 权限运行配置步骤。"
  return 1
}

prepare_config_rewrite() {
  local path="$1"
  backup_if_exists "${path}" || return 1
  if [[ -e "${path}" ]] && ! rm -f "${path}" 2>/dev/null; then
    privileged_run rm -f "${path}" || {
      error_i "Could not replace protected config file ${path#${ROOT_DIR}/} after backup." "备份后无法替换受保护的配置文件 ${path#${ROOT_DIR}/}。"
      return 1
    }
  fi
}

write_fractal_chain_yaml() {
  local rpc_url="$1"
  local zmq_block="$2"
  local zmq_tx="$3"
  local rpc_auth="$4"
  local path="${FRACTAL_INDEXER_DIR}/conf/indexer/chain.yaml"
  prepare_config_rewrite "${path}" || return 1
  (umask 077; cat >"${path}" <<EOF
chain_type: Fractal
skip_missing_utxo: false

zmq_block: "$(yaml_escape "${zmq_block}")"
zmq_tx: "$(yaml_escape "${zmq_tx}")"
rpc: "$(yaml_escape "${rpc_url}")"
rpc_auth: "$(yaml_escape "${rpc_auth}")"

utxo_pika_batch: 1024

jubilee_activation_height: 21000
ordinals_activation_height: 21000
reinscription_activation_height: 21000
brc20_single_step_transfer_height: 930930
EOF
  ) || return 1
  secure_container_config_file "${path}" "1000"
}

write_stake_chain_yaml() {
  local rpc_url="$1"
  local rpc_auth="$2"
  local path="${STAKE_INDEXER_DIR}/conf/indexer/chain.yaml"
  prepare_config_rewrite "${path}" || return 1
  (umask 077; cat >"${path}" <<EOF
rpc: "$(yaml_escape "${rpc_url}")"
rpc_auth: "$(yaml_escape "${rpc_auth}")"
EOF
  ) || return 1
  secure_container_config_file "${path}" "1000"
}

restore_snapshot_interactive() {
  local backup_existing="false"
  local stop_running="false"
  if confirm_i "Stop fractal-indexer first if it is running?" "如果 fractal-indexer 正在运行，是否先停止？" "y"; then
    stop_running="true"
  fi
  if directory_has_contents "${FRACTAL_INDEXER_DIR}/data"; then
    warn_i "Snapshot restore requires an empty fractal-indexer/data directory." "快照恢复要求 fractal-indexer/data 目录为空。"
    local answer
    read -r -p "$(choose_text "Type RESTORE to move existing data to a timestamped backup and continue" "输入 RESTORE 将现有数据移动到带时间戳的备份目录并继续"): " answer
    if [[ "${answer}" != "RESTORE" ]]; then
      warn_i "Snapshot restore cancelled." "已取消快照恢复。"
      return 1
    fi
    backup_existing="true"
  fi
  restore_snapshot_plan "${backup_existing}" "${stop_running}"
}

restore_snapshot_plan() {
  local backup_existing="$1"
  local stop_running="$2"
  info_i "Preparing fractal-indexer snapshot restore" "准备恢复 fractal-indexer 快照"
  ensure_compose_project_owned "${FRACTAL_INDEXER_DIR}" "fractal-indexer" || return 1
  require_command curl || return 1
  require_command tar || return 1
  if ! tar --help 2>/dev/null | grep -q -- '--zstd'; then
    error_i "tar does not support --zstd. Install GNU tar with zstd support before restoring snapshots." "tar 不支持 --zstd。恢复快照前请安装支持 zstd 的 GNU tar。"
    return 1
  fi

  if compose "${FRACTAL_INDEXER_DIR}" ps --services --filter "status=running" 2>/dev/null | grep -q .; then
    if [[ "${stop_running}" != "true" ]]; then
      error_i "fractal-indexer is running and auto-stop is disabled." "fractal-indexer 正在运行，但未启用自动停止。"
      return 1
    fi
    warn_i "Stopping running fractal-indexer services." "正在停止运行中的 fractal-indexer 服务。"
    compose "${FRACTAL_INDEXER_DIR}" down || return 1
  fi

  local data_dir="${FRACTAL_INDEXER_DIR}/data"
  if directory_has_contents "${data_dir}"; then
    if [[ "${backup_existing}" != "true" ]]; then
      error_i "fractal-indexer/data is not empty. Re-run the wizard and allow automatic backup, or clean it manually." "fractal-indexer/data 不为空。请重新运行向导并允许自动备份，或手动清理。"
      return 1
    fi
  fi
  check_snapshot_free_space || return 1

  local staging
  staging="$(mktemp -d "${FRACTAL_INDEXER_DIR}/data.restore.XXXXXX")" || return 1
  info_i "Downloading snapshot from ${SNAPSHOT_BASE_URL}" "正在从 ${SNAPSHOT_BASE_URL} 下载快照"
  if ! (
    cd "${staging}" || exit 1
    download_snapshot_part "pika-brc20.tar.zst" || exit 1
    download_snapshot_part "brc20-base.tar.zst" || exit 1
    download_snapshot_part "pika.tar.zst" || exit 1
    download_snapshot_part "clickhouse.tar.zst" || exit 1
  ); then
    rm -rf "${staging}"
    error_i "Snapshot restore failed. Temporary partial data was removed; existing data was left unchanged." "快照恢复失败。临时半残数据已删除；原有数据保持不变。"
    return 1
  fi

  if directory_has_contents "${data_dir}"; then
    local backup="${FRACTAL_INDEXER_DIR}/data.backup.$(date +%Y%m%d%H%M%S)"
    mv "${data_dir}" "${backup}" || {
      rm -rf "${staging}"
      return 1
    }
    warn_i "Existing data moved to ${backup#${ROOT_DIR}/}" "现有数据已移动到 ${backup#${ROOT_DIR}/}"
  else
    rm -rf "${data_dir}" || {
      rm -rf "${staging}"
      return 1
    }
  fi
  mv "${staging}" "${data_dir}" || return 1
  printf "height=%s\nsource=%s\nrestored_at=%s\n" "${SNAPSHOT_HEIGHT}" "${SNAPSHOT_BASE_URL}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"${data_dir}/.snapshot-restore-complete" || return 1

  info_i "Fixing fractal-indexer data ownership" "修正 fractal-indexer 数据目录权限"
  run_init_script "${FRACTAL_INDEXER_DIR}" || return 1
}

check_snapshot_free_space() {
  local available min_required
  min_required="$(snapshot_disk_min_required_gb)"
  available="$(snapshot_disk_available_gb)"
  if ! [[ "${available}" =~ ^[0-9]+$ ]]; then
    warn_i "Could not read free disk space before snapshot restore." "恢复快照前无法读取可用磁盘空间。"
    return 0
  fi
  printf "OK   free disk near fractal-indexer=%sG, minimum required=%sG\n" "${available}" "${min_required}"
  if (( available < min_required )); then
    error_i "Not enough free disk for the official snapshot restore. Move the deploy directory to a larger disk or set SNAPSHOT_MIN_FREE_GB to an explicit lower value if you have verified the final data size." "可用磁盘不足，不适合恢复官方快照。请把部署目录放到更大的磁盘；如果你已确认最终数据大小，可显式调低 SNAPSHOT_MIN_FREE_GB。"
    return 1
  fi
}

print_snapshot_disk_advisory() {
  local available min_required
  min_required="$(snapshot_disk_min_required_gb)"
  available="$(snapshot_disk_available_gb)"
  if ! [[ "${available}" =~ ^[0-9]+$ ]]; then
    warn_i "Could not read free disk space for the snapshot advisory." "无法读取快照磁盘空间建议所需的可用空间。"
    return 0
  fi
  if (( available < min_required )); then
    warn_i "Free disk near fractal-indexer is ${available}G, below the default snapshot guard ${min_required}G. The default one-pass snapshot restore will stop unless you use a larger disk, skip snapshot restore, or explicitly lower SNAPSHOT_MIN_FREE_GB after checking the final size." "fractal-indexer 附近可用磁盘为 ${available}G，低于默认快照保护线 ${min_required}G。默认一条路快照恢复会停止；请使用更大磁盘、跳过快照恢复，或在确认最终大小后显式调低 SNAPSHOT_MIN_FREE_GB。"
  else
    printf "OK   free disk near fractal-indexer=%sG, snapshot guard=%sG\n" "${available}" "${min_required}"
  fi
}

snapshot_disk_min_required_gb() {
  clamp_int "${SNAPSHOT_MIN_FREE_GB}" 1 100000
}

snapshot_disk_available_gb() {
  df -BG "${FRACTAL_INDEXER_DIR}" 2>/dev/null | awk 'NR==2 {gsub("G","",$4); print $4}' || printf "unknown"
}

snapshot_disk_has_min_free() {
  local available min_required
  available="$(snapshot_disk_available_gb)"
  min_required="$(snapshot_disk_min_required_gb)"
  [[ "${available}" =~ ^[0-9]+$ ]] || return 1
  (( available >= min_required ))
}

directory_has_contents() {
  local dir="$1"
  [[ -d "${dir}" ]] || return 1
  find "${dir}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null | grep -q .
}

fractal_indexer_has_data_files() {
  local dir
  for dir in \
    "${FRACTAL_INDEXER_DIR}/data/clickhouse" \
    "${FRACTAL_INDEXER_DIR}/data/pika" \
    "${FRACTAL_INDEXER_DIR}/data/pika-brc20" \
    "${FRACTAL_INDEXER_DIR}/data/brc20"; do
    if [[ -d "${dir}" ]] && find "${dir}" -type f -print -quit 2>/dev/null | grep -q .; then
      return 0
    fi
  done
  return 1
}

download_snapshot_part() {
  local file="$1"
  info_i "Restoring ${file}" "正在恢复 ${file}"
  curl -fL --retry 5 --retry-delay 10 --retry-connrefused "${SNAPSHOT_BASE_URL}/${file}" | tar --zstd -xf -
}

check_script_file() {
  local path="$1"
  if [[ ! -f "${path}" ]]; then
    error_i "Missing helper script: ${path#${ROOT_DIR}/}" "缺少辅助脚本：${path#${ROOT_DIR}/}"
    return 1
  fi
  if grep -q $'\r' "${path}"; then
    warn_i "${path#${ROOT_DIR}/} has CRLF line endings. It will be executed through a temporary LF-normalized copy only when initialization is requested." "${path#${ROOT_DIR}/} 使用 CRLF 行尾。只有在执行初始化时，才会通过临时 LF 规范化副本运行。"
  else
    printf "OK   %s line endings: LF\n" "${path#${ROOT_DIR}/}"
  fi
}

run_init_script() {
  local dir="$1"
  shift
  local source tmp status
  source="${dir}/scripts/init.sh"
  check_script_file "${source}" || return 1
  tmp="$(mktemp)" || return 1
  sed 's/\r$//' "${source}" >"${tmp}" || {
    rm -f "${tmp}"
    return 1
  }
  if [[ "${dir}" == "${FRACTAL_INDEXER_DIR}" && "$#" -eq 0 ]]; then
    # Official init.sh ends with a false `test ... &&` branch in directory-only mode.
    printf "\n:\n" >>"${tmp}" || {
      rm -f "${tmp}"
      return 1
    }
  fi
  chmod 700 "${tmp}" || {
    rm -f "${tmp}"
    return 1
  }
  status=0
  (cd "${dir}" && bash "${tmp}" "$@") || status=$?
  rm -f "${tmp}"
  return "${status}"
}

start_fractal_indexer() {
  local initialize_from_scratch="${1:-false}"
  validate_official_bundle || return 1
  require_chain_config "${FRACTAL_INDEXER_DIR}/conf/indexer/chain.yaml" || return 1
  if [[ "${initialize_from_scratch}" != "true" ]] && ! fractal_indexer_has_data_files; then
    error_i "No restored or existing fractal-indexer database files were found. Use the one-pass wizard with official snapshot restore, or disable snapshot restore there only when using a full historical Fractald node." "未找到已恢复或已有的 fractal-indexer 数据库文件。请使用一条路向导恢复官方快照；只有使用完整历史 Fractald 节点时，才在向导中禁用快照恢复。"
    return 1
  fi
  write_menu_compose_files || return 1
  ensure_compose_project_owned "${FRACTAL_INDEXER_DIR}" "fractal-indexer" || return 1
  info_i "Initializing fractal-indexer directories" "初始化 fractal-indexer 目录"
  run_init_script "${FRACTAL_INDEXER_DIR}" || return 1
  pull_compose_service "${FRACTAL_INDEXER_DIR}" "indexer" "fractal-indexer indexer" || return 1
  pull_compose_service "${FRACTAL_INDEXER_DIR}" "api" "fractal-indexer api" || return 1
  if [[ "${initialize_from_scratch}" == "true" ]]; then
    info_i "Initializing empty fractal-indexer database from genesis using the official indexer command" "使用官方索引器命令从创世块初始化空的 fractal-indexer 数据库"
    compose "${FRACTAL_INDEXER_DIR}" run --rm indexer -full -end 1 || return 1
  fi
  info_i "Starting fractal-indexer stack" "启动 fractal-indexer 栈"
  compose "${FRACTAL_INDEXER_DIR}" up -d || return 1
}

start_stake_indexer() {
  validate_official_bundle || return 1
  require_chain_config "${STAKE_INDEXER_DIR}/conf/indexer/chain.yaml" || return 1
  ensure_statehash_ready_for_stake_start || return 1
  write_menu_compose_files || return 1
  ensure_compose_project_owned "${STAKE_INDEXER_DIR}" "stake-indexer" || return 1
  info_i "Initializing stake-indexer directories" "初始化 stake-indexer 目录"
  run_init_script "${STAKE_INDEXER_DIR}" || return 1
  pull_compose_service "${STAKE_INDEXER_DIR}" "indexer" "stake-indexer" || return 1
  info_i "Starting stake-indexer stack" "启动 stake-indexer 栈"
  compose "${STAKE_INDEXER_DIR}" up -d || return 1
  check_stake_indexer_startup || return 1
}

ensure_statehash_ready_for_stake_start() {
  local height
  height="$(stake_statehash_height)" || return 1
  if probe_statehash_ready "${height}"; then
    return 0
  fi
  if [[ "${CFG_ALLOW_STAKE_WITHOUT_STATEHASH}" == "true" ]]; then
    warn_i "Statehash at configured reward start height ${height} is unavailable. Continuing only because observation/debug mode is enabled." "配置的奖励起点高度 ${height} 的 statehash 不可用。仅因已启用观察/调试模式而继续。"
    return 0
  fi
  error_i "Statehash at configured reward start height ${height} is unavailable. Start or catch up fractal-indexer first; stake-indexer was not started." "配置的奖励起点高度 ${height} 的 statehash 不可用。请先启动或追平 fractal-indexer；stake-indexer 未启动。"
  return 1
}

pull_compose_service() {
  local dir="$1"
  local service="$2"
  local label="$3"
  local image
  info_i "Pulling official image for ${label}" "拉取 ${label} 的官方镜像"
  if compose "${dir}" pull "${service}"; then
    return 0
  fi
  image="$(compose_service_image "$(active_compose_file "${dir}")" "${service}")"
  if [[ -n "${image}" ]] && image_has_official_repo_digest "${image}" "$(image_reference_repository "${image}")"; then
    warn_i "Could not pull ${label}, but a locally cached official registry image with digest is present; continuing." "无法拉取 ${label}，但本地已缓存带官方仓库 digest 的镜像；继续执行。"
    return 0
  fi
  error_i "Could not pull ${label}, and no official registry digest is present locally. This official-only menu will not build or run a local modified image." "无法拉取 ${label}，且本地没有可验证的官方仓库 digest。这个仅官方版本菜单不会构建或运行本地魔改镜像。"
  return 1
}

check_stake_indexer_startup() {
  local logs
  sleep 5
  logs="$(stake_indexer_logs 160)"
  diagnose_stake_indexer_logs "${logs}" || return 1
  if report_compose_container_issues "${STAKE_INDEXER_DIR}" "stake-indexer"; then
    return 0
  fi
  return 1
}

stake_indexer_logs() {
  local tail_count="${1:-160}"
  local logs
  if ! logs="$(compose "${STAKE_INDEXER_DIR}" logs --tail="${tail_count}" indexer 2>&1)"; then
    logs=""
  fi
  printf "%s" "${logs}"
}

diagnose_stake_indexer_logs() {
  local logs="$1"
  local failed=0
  if grep -q "threshold_fb invalid" <<<"${logs}"; then
    error_i "The running stake-indexer image predates the current official v0.1.1 deployment config. Pull the pinned official image and recreate this service; the menu will not alter reward rules." "正在运行的 stake-indexer 镜像早于当前官方 v0.1.1 部署配置。请拉取固定的官方镜像并重建该服务；菜单不会改动奖励规则。"
    failed=1
  fi
  if grep -q "release_percent invalid" <<<"${logs}" && grep -q "strconv.ParseUint" <<<"${logs}"; then
    error_i "The running stake-indexer image predates official support for fractional reward release tiers. Pull the pinned official v0.1.1 image and recreate this service." "正在运行的 stake-indexer 镜像早于官方对小数奖励释放比例的支持。请拉取固定的官方 v0.1.1 镜像并重建该服务。"
    failed=1
  fi
  if grep -q "Method not found" <<<"${logs}" && grep -q "syncBlockIndexer init latest block from rpc failed" <<<"${logs}"; then
    error_i "A stale stake-indexer process is still calling getblockindexrange. Official stake-indexer v0.1.1 uses standard getblockhash RPC; pull the pinned official image and recreate this service." "仍有旧版 stake-indexer 进程在调用 getblockindexrange。官方 stake-indexer v0.1.1 已改用标准 getblockhash RPC；请拉取固定的官方镜像并重建该服务。"
    failed=1
  fi
  if grep -q "read chain config failed: open conf/chain.yaml" <<<"${logs}"; then
    error_i "stake-indexer started without conf/chain.yaml. Run the Fractald configuration step before starting stake-indexer." "stake-indexer 启动时缺少 conf/chain.yaml。请先执行 Fractald 配置步骤再启动 stake-indexer。"
    failed=1
  fi
  if grep -q "status code: 401" <<<"${logs}"; then
    error_i "stake-indexer RPC authentication was rejected with HTTP 401. Check rpc_auth in stake-indexer/conf/indexer/chain.yaml." "stake-indexer 的 RPC 认证被 HTTP 401 拒绝。请检查 stake-indexer/conf/indexer/chain.yaml 里的 rpc_auth。"
    failed=1
  fi
  return "${failed}"
}

start_proof_publisher_dry_run() {
  if [[ ! -f "${PROOF_PUBLISHER_DIR}/config.json" ]]; then
    error_i "Missing proof-publisher/config.json." "缺少 proof-publisher/config.json。"
    return 1
  fi
  validate_proof_publisher_config_file || return 1
  validate_official_bundle || return 1
  ensure_compose_project_owned "${PROOF_PUBLISHER_DIR}" "proof-publisher" || return 1
  ensure_proof_publisher_image || return 1
  info_i "Initializing proof-publisher data directory" "初始化 proof-publisher 数据目录"
  run_init_script "${PROOF_PUBLISHER_DIR}" || return 1
  info_i "Starting proof-publisher in dry-run mode" "以 dry-run 模式启动 proof-publisher"
  compose "${PROOF_PUBLISHER_DIR}" up -d || return 1
  wait_for_url "http://127.0.0.1:8080/healthz" "${CFG_WAIT_TIMEOUT}" || return 1
  wait_for_url "http://127.0.0.1:8080/status" "${CFG_WAIT_TIMEOUT}" || return 1
}

ensure_proof_publisher_image() {
  local image="fractalbitcoin/fractal-proof-publisher:latest"
  if docker_cmd image inspect "${image}" >/dev/null 2>&1; then
    if image_has_official_repo_digest "${image}" "$(image_reference_repository "${image}")"; then
      return 0
    fi
  fi
  if compose "${PROOF_PUBLISHER_DIR}" pull proof-publisher; then
    return 0
  fi
  if image_has_official_repo_digest "${image}" "$(image_reference_repository "${image}")"; then
    warn_i "Could not pull ${image}, but a locally cached official registry image with digest is present; continuing." "无法拉取 ${image}，但本地已缓存带官方仓库 digest 的镜像；继续执行。"
    return 0
  fi
  error_i "Could not pull official image ${image}, and no official registry digest is present locally. This official-only menu will not build or run a local modified proof-publisher image." "无法拉取官方镜像 ${image}，且本地没有可验证的官方仓库 digest。这个仅官方版本菜单不会构建或运行本地魔改 proof-publisher 镜像。"
  return 1
}

check_proof_publisher_image_prerequisite() {
  local image repository
  image="$(compose_service_image "$(active_compose_file "${PROOF_PUBLISHER_DIR}")" "proof-publisher")"
  image="${image//$'\r'/}"
  if [[ -z "${image}" ]]; then
    error_i "proof-publisher image is missing from the active Compose file." "当前 Compose 文件缺少 proof-publisher 镜像。"
    return 1
  fi
  repository="$(image_reference_repository "${image}")"
  info_i "Checking official proof-publisher image before long-running deployment work" "在执行长耗时部署前检查官方 proof-publisher 镜像"
  if docker_cmd manifest inspect "${image}" >/dev/null 2>&1; then
    printf "OK   official proof-publisher image is reachable: %s\n" "${image}"
    return 0
  fi
  if image_has_official_repo_digest "${image}" "${repository}"; then
    warn_i "Could not inspect ${image} in the registry, but a locally cached official registry image with digest is present; continuing." "无法从镜像仓库检查 ${image}，但本地已缓存带官方仓库 digest 的镜像；继续执行。"
    return 0
  fi
  error_i "proof-publisher dry-run startup was selected, but ${image} is not reachable in the registry and no cached official digest is present. Disable proof-publisher startup or wait for the official image to be published." "已选择启动 proof-publisher dry-run，但 ${image} 在镜像仓库不可访问，且本地没有官方 digest 缓存。请关闭 proof-publisher 启动，或等待官方镜像发布。"
  return 1
}

require_chain_config() {
  if [[ ! -f "$1" ]]; then
    error_i "Missing ${1#${ROOT_DIR}/}. Run configuration first." "缺少 ${1#${ROOT_DIR}/}。请先运行配置。"
    return 1
  fi
}

wait_for_fractal_indexer() {
  local timeout="${1:-${WAIT_TIMEOUT_DEFAULT}}"
  local statehash_height
  statehash_height="$(stake_statehash_height)" || return 1
  info_i "Waiting for fractal-indexer API" "等待 fractal-indexer API"
  if ! wait_for_url "http://127.0.0.1:8000/brc20/bestheight" "${timeout}"; then
    report_compose_container_issues "${FRACTAL_INDEXER_DIR}" "fractal-indexer" || true
    return 1
  fi
  if wait_for_statehash "${statehash_height}" "${timeout}"; then
    return 0
  fi
  report_compose_container_issues "${FRACTAL_INDEXER_DIR}" "fractal-indexer" || true
  if [[ "${CFG_ALLOW_STAKE_WITHOUT_STATEHASH}" == "true" ]]; then
    warn_i "Statehash at configured reward start height ${statehash_height} is not ready yet. Continuing because observation/debug mode was enabled." "配置的奖励起点高度 ${statehash_height} 的 statehash 暂未就绪。已按观察/调试模式继续。"
    return 0
  fi
  error_i "Statehash at configured reward start height ${statehash_height} is not ready. Not starting stake-indexer by default; increase WAIT_TIMEOUT or rerun health checks after fractal-indexer catches up." "配置的奖励起点高度 ${statehash_height} 的 statehash 尚未就绪。默认不会启动 stake-indexer；请增加 WAIT_TIMEOUT，或等 fractal-indexer 追上后重新健康检查。"
  return 1
}

wait_for_statehash() {
  local height="$1"
  local timeout="$2"
  local start now
  start="$(date +%s)"
  while true; do
    if probe_statehash_ready "${height}"; then
      return 0
    fi
    now="$(date +%s)"
    if (( now - start >= timeout )); then
      warn_i "Timed out waiting for confirmed statehash at height ${height}" "等待高度 ${height} 的有效 statehash 超时"
      return 1
    fi
    sleep 5
  done
}

wait_for_stake_indexer() {
  local timeout="${1:-${WAIT_TIMEOUT_DEFAULT}}"
  info_i "Waiting for stake-indexer API" "等待 stake-indexer API"
  if ! wait_for_url "http://127.0.0.1:9637/indexer/status" "${timeout}"; then
    report_compose_container_issues "${STAKE_INDEXER_DIR}" "stake-indexer" || true
    return 1
  fi
  wait_for_url "http://127.0.0.1:9637/stake-reward/sync-status" "${timeout}" || true
}

wait_for_url() {
  local url="$1"
  local timeout="$2"
  local start now tmp
  tmp="/tmp/fractal-deploy-menu-wait.$$"
  start="$(date +%s)"
  while true; do
    if curl -fsS --max-time 5 "${url}" >"${tmp}" 2>/dev/null; then
      printf "OK   %s: %s\n" "${url}" "$(head -c 160 "${tmp}")"
      rm -f "${tmp}"
      return 0
    fi
    now="$(date +%s)"
    if (( now - start >= timeout )); then
      rm -f "${tmp}"
      warn_i "Timed out waiting for ${url}" "等待 ${url} 超时"
      return 1
    fi
    sleep 5
  done
}

proof_publisher_menu() {
  while true; do
    printf "\n"
    info_i "proof-publisher dry-run and registration preparation" "proof-publisher dry-run 和注册准备"
    if [[ "${UI_LANG}" == "zh" ]]; then
      cat <<EOF
1) 一键配置 proof-publisher dry-run（填写、校验、写入 config.json）
2) 校验现有 proof-publisher/config.json
3) 启动 proof-publisher dry-run 并检查 health/status
4) 查看未来运营商注册 checklist（不广播）
5) 一键注册运营商（官方开放后启用；当前安全拒绝）
0) 返回主菜单
EOF
    else
      cat <<EOF
1) One-click proof-publisher dry-run setup (collect, validate, write config.json)
2) Validate existing proof-publisher/config.json
3) Start proof-publisher dry-run and check health/status
4) Show future operator registration checklist (no broadcast)
5) One-click operator registration (enabled after official launch; safely refuses now)
0) Back to main menu
EOF
    fi
    local choice
    read -r -p "$(choose_text "Select an option" "请选择"): " choice
    case "${choice}" in
      1) proof_publisher_one_click_setup ;;
      2) validate_proof_publisher_config_file ;;
      3) start_proof_publisher_dry_run ;;
      4) proof_publisher_registration_checklist ;;
      5) operator_registration_not_available || true ;;
      0) return 0 ;;
      *) warn_i "Unknown option: ${choice}" "未知选项：${choice}" ;;
    esac
    pause
  done
}

proof_publisher_one_click_setup() {
  info_i "Preparing proof-publisher dry-run config" "准备 proof-publisher dry-run 配置"
  warn_i "This flow never enables real broadcasting. It writes dry_run=true and disable_broadcast=true." "这个流程不会启用真实广播。它会写入 dry_run=true 和 disable_broadcast=true。"
  collect_proof_config
  validate_proof_config_globals || return 1
  write_proof_publisher_config_from_globals || return 1
  validate_proof_publisher_config_file || return 1
  proof_publisher_registration_checklist
  if confirm_i "Start proof-publisher dry-run now and check health/status?" "现在启动 proof-publisher dry-run 并检查 health/status？" "n"; then
    start_proof_publisher_dry_run
  fi
}

prepare_proof_publisher_config() {
  proof_publisher_one_click_setup
}

write_proof_publisher_config_from_globals() {
  local path="${PROOF_PUBLISHER_DIR}/config.json"
  local scan_start_height scan_poll_interval scan_target_block_version scan_confirmations scan_reorg_depth
  validate_proof_config_globals || return 1
  scan_start_height="$(proof_config_number "start_height" "1764000")"
  scan_poll_interval="$(proof_config_number "poll_interval" "30000000000")"
  scan_target_block_version="$(proof_config_number "target_block_version" "539361536")"
  scan_confirmations="$(proof_config_number "required_confirmations" "1")"
  scan_reorg_depth="$(proof_config_number "max_reorg_depth" "100")"
  prepare_config_rewrite "${path}" || return 1
  (umask 077; cat >"${path}" <<EOF
{
  "bitcoin_rpc": {
    "url": "$(json_escape "${CFG_PROOF_RPC_URL}")",
    "user": "$(json_escape "${CFG_PROOF_RPC_USER}")",
    "password": "$(json_escape "${CFG_PROOF_RPC_PASSWORD}")",
    "network": "mainnet"
  },
  "signing": {
    "private_key_wif": "$(json_escape "${CFG_PROOF_PRIVATE_KEY}")",
    "change_address": "$(json_escape "${CFG_PROOF_CHANGE_ADDRESS}")",
    "initial_utxos": []
  },
  "state_api": {
    "base_url": "http://fractal-indexer:8000",
    "timeout": 5000000000,
    "auth": "",
    "provider": "query-fip101"
  },
  "fee_api": {
    "timeout": 5000000000,
    "strategy": "minimum",
    "min_fee_rate_sat_vb": 1,
    "max_fee_rate_sat_vb": 1,
    "fixed_fee_rate_sat_vb": 1
  },
  "register": {
    "index_ratio_bp": 100,
    "reward_addr_type": "p2wpkh",
    "reward_addr": "$(json_escape "${CFG_PROOF_REWARD_ADDRESS}")",
    "name": "$(json_escape "${CFG_PROOF_INDEXER_NAME}")",
    "indexer_id": "$(json_escape "${CFG_PROOF_INDEXER_ID}")"
  },
  "scan": {
    "start_height": ${scan_start_height},
    "poll_interval": ${scan_poll_interval},
    "target_block_version": ${scan_target_block_version},
    "required_confirmations": ${scan_confirmations},
    "max_reorg_depth": ${scan_reorg_depth}
  },
  "tx": {
    "send_change_min_value": 546
  },
  "database": {
    "sqlite_path": "/app/data/publisher.db"
  },
  "runtime": {
    "mode": "unisat_open_api",
    "unisat_open_api_url": "https://open-api.unisat.io",
    "unisat_open_api_key": "$(json_escape "${CFG_PROOF_UNISAT_KEY}")",
    "dry_run": true,
    "disable_broadcast": true,
    "health_addr": ":8080"
  }
}
EOF
  ) || return 1
  secure_container_config_file "${path}" "10001" || return 1
  info_i "Wrote proof-publisher/config.json with dry_run=true and disable_broadcast=true" "已写入 proof-publisher/config.json，且 dry_run=true、disable_broadcast=true"
}

validate_proof_publisher_config_file() {
  local path="${PROOF_PUBLISHER_DIR}/config.json"
  local failed=0
  info_i "Validating proof-publisher/config.json" "校验 proof-publisher/config.json"
  if [[ ! -f "${path}" ]]; then
    error_i "Missing proof-publisher/config.json. Run proof-publisher setup first." "缺少 proof-publisher/config.json。请先运行 proof-publisher 配置。"
    return 1
  fi
  require_json_true "${path}" "dry_run" || failed=1
  require_json_true "${path}" "disable_broadcast" || failed=1
  require_json_nonempty_string "${path}" "url" || failed=1
  require_json_nonempty_string "${path}" "user" || failed=1
  require_json_nonempty_string "${path}" "password" || failed=1
  require_json_nonempty_string "${path}" "private_key_wif" || failed=1
  require_json_nonempty_string "${path}" "change_address" || failed=1
  require_json_nonempty_string "${path}" "reward_addr" || failed=1
  require_json_nonempty_string "${path}" "name" || failed=1
  require_json_nonempty_string "${path}" "unisat_open_api_key" || failed=1
  if grep -q 'REPLACE_' "${path}"; then
    error_i "proof-publisher/config.json still contains REPLACE_ placeholders." "proof-publisher/config.json 仍包含 REPLACE_ 占位符。"
    failed=1
  fi
  if [[ "${failed}" -eq 0 ]]; then
    line_i "OK   proof-publisher config is complete and broadcast-safe for dry-run" "OK   proof-publisher 配置完整，并保持 dry-run 广播安全"
  fi
  return "${failed}"
}

require_json_true() {
  local path="$1"
  local key="$2"
  if grep -Eq "\"${key}\"[[:space:]]*:[[:space:]]*true([,[:space:]}]|$)" "${path}"; then
    printf "OK   %s=true\n" "${key}"
    return 0
  fi
  error_i "proof-publisher/config.json must set ${key}=true." "proof-publisher/config.json 必须设置 ${key}=true。"
  return 1
}

require_json_nonempty_string() {
  local path="$1"
  local key="$2"
  if grep -Eq "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]+\"" "${path}"; then
    printf "OK   %s is set\n" "${key}"
    return 0
  fi
  error_i "proof-publisher/config.json must set a non-empty ${key} string." "proof-publisher/config.json 必须设置非空 ${key} 字符串。"
  return 1
}

proof_publisher_registration_checklist() {
  info_i "Future operator registration checklist" "未来运营商注册 checklist"
  if [[ "${UI_LANG}" == "zh" ]]; then
    cat <<EOF
当前版本只做 dry-run 准备，不自动真实注册或广播。

等官方开放第三方服务商注册后，正式注册流程应至少包含：
  1. 确认 portal 已开放第三方 indexer 注册。
  2. 校验 owner/change 地址余额和可用 UTXO。
  3. 校验 owner 地址、reward 地址、indexer name、indexer_id。
  4. dry-run 生成 register_indexer / submit_proof 任务。
  5. 展示将要广播的交易、手续费、铭文内容和风险提示。
  6. 用户二次确认后才允许真实广播。
  7. 记录 txid、indexer_id、广播状态和后续 proof 状态。

本菜单预留此入口，但不会在官方规则明确前实现真实广播。
EOF
  else
    cat <<EOF
This version prepares dry-run only. It does not perform real registration or
broadcast transactions.

When official third-party indexer registration opens, a production registration
flow should include at least:
  1. Confirm the portal allows third-party indexer registration.
  2. Check owner/change address balance and spendable UTXOs.
  3. Validate owner address, reward address, indexer name, and indexer_id.
  4. Dry-run register_indexer / submit_proof task generation.
  5. Show the transaction, fee, inscription payload, and risk notice.
  6. Require explicit second confirmation before real broadcast.
  7. Record txid, indexer_id, broadcast state, and future proof state.

This menu reserves the entry point but does not implement real broadcasting
before the official rules are clear.
EOF
  fi
}

operator_registration_not_available() {
  error_i "One-click operator registration is not enabled yet." "一键注册运营商尚未启用。"
  warn_i "This package intentionally refuses real registration and broadcasting until the official third-party operator rules are public and stable." "在官方第三方运营商规则公开并稳定前，本项目会拒绝真实注册和广播。"
  proof_publisher_registration_checklist
  return 2
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/}"
  printf "%s" "${value}"
}

yaml_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/}"
  printf "%s" "${value}"
}

health_check() {
  local failed=0
  local statehash_height
  local proof_required="false"
  if [[ "${CFG_START_PROOF}" == "true" ]]; then
    proof_required="true"
  fi
  info_i "Official deployment bundle" "官方部署包"
  validate_official_bundle || failed=1
  printf "\n"
  info_i "Docker Compose status" "Docker Compose 状态"
  compose_status || true
  printf "\n"
  info_i "Container diagnostics" "容器诊断"
  report_compose_container_issues "${FRACTAL_INDEXER_DIR}" "fractal-indexer" || failed=1
  report_compose_container_issues "${STAKE_INDEXER_DIR}" "stake-indexer" || failed=1
  diagnose_stake_indexer_logs "$(stake_indexer_logs 220)" || failed=1
  if [[ "${proof_required}" == "true" ]]; then
    report_compose_container_issues "${PROOF_PUBLISHER_DIR}" "proof-publisher" || failed=1
  else
    report_compose_container_issues "${PROOF_PUBLISHER_DIR}" "proof-publisher" || true
  fi
  if [[ -f "${PROOF_PUBLISHER_DIR}/config.json" ]]; then
    validate_proof_publisher_config_file || failed=1
  else
    line_i "proof-publisher config: not prepared" "proof-publisher 配置：尚未准备"
  fi
  check_internal_datastore_bindings || failed=1
  printf "\n"
  info_i "HTTP health checks" "HTTP 健康检查"
  probe_url "fractal-indexer bestheight" "http://127.0.0.1:8000/brc20/bestheight" || failed=1
  if statehash_height="$(stake_statehash_height)"; then
    probe_statehash_ready "${statehash_height}" || failed=1
  else
    failed=1
  fi
  probe_url "stake-indexer status" "http://127.0.0.1:9637/indexer/status" || failed=1
  probe_url "stake-indexer reward sync" "http://127.0.0.1:9637/stake-reward/sync-status" || failed=1
  if [[ "${proof_required}" == "true" ]]; then
    probe_url "proof-publisher health" "http://127.0.0.1:8080/healthz" || failed=1
    probe_url "proof-publisher status" "http://127.0.0.1:8080/status" || failed=1
  else
    probe_url "proof-publisher health" "http://127.0.0.1:8080/healthz" || true
    probe_url "proof-publisher status" "http://127.0.0.1:8080/status" || true
  fi
  return "${failed}"
}

check_internal_datastore_bindings() {
  local ports=("9222:pika-brc20" "9432:stake-indexer postgres" "9379:stake-indexer redis")
  local item port label addresses address exposed failed=0
  info_i "Internal datastore listener security" "内部存储监听安全性"
  if ! command_exists ss && ! command_exists netstat; then
    warn_i "Neither ss nor netstat was found; cannot verify internal datastore listener exposure." "未找到 ss 或 netstat，无法验证内部存储监听暴露范围。"
    return 0
  fi
  for item in "${ports[@]}"; do
    port="${item%%:*}"
    label="${item#*:}"
    if command_exists ss; then
      addresses="$(ss -lnt "sport = :${port}" 2>/dev/null | awk 'NR > 1 {print $4}' || true)"
    else
      addresses="$(netstat -lnt 2>/dev/null | awk -v port=":${port}" '$4 ~ port "$" {print $4}' || true)"
    fi
    if [[ -z "${addresses}" ]]; then
      printf "SKIP port %s (%s): no listener detected\n" "${port}" "${label}"
      continue
    fi
    exposed="false"
    while IFS= read -r address; do
      [[ -n "${address}" ]] || continue
      case "${address}" in
        127.0.0.1:*|\[::1\]:*)
          ;;
        *)
          exposed="true"
          ;;
      esac
    done <<<"${addresses}"
    if [[ "${exposed}" == "false" ]]; then
      printf "OK   port %s (%s) is localhost-only: %s\n" "${port}" "${label}" "$(tr '\n' ' ' <<<"${addresses}")"
    elif [[ "${INTERNAL_PORT_BIND_MODE}" == "official" ]]; then
      warn_i "Port ${port} (${label}) follows official public host binding: $(tr '\n' ' ' <<<"${addresses}"). Protect it with a firewall." "端口 ${port}（${label}）使用官方公网主机绑定：$(tr '\n' ' ' <<<"${addresses}")。请用防火墙保护。"
    else
      error_i "Port ${port} (${label}) is exposed beyond localhost: $(tr '\n' ' ' <<<"${addresses}"). Recreate the stack through this menu or use INTERNAL_PORT_BIND_MODE=official only with a firewall." "端口 ${port}（${label}）暴露范围超过 localhost：$(tr '\n' ' ' <<<"${addresses}")。请通过本菜单重建服务；只有配置了防火墙时才使用 INTERNAL_PORT_BIND_MODE=official。"
      failed=1
    fi
  done
  return "${failed}"
}

compose_status() {
  info_i "fractal-indexer" "fractal-indexer"
  compose "${FRACTAL_INDEXER_DIR}" ps || true
  printf "\n"
  info_i "stake-indexer" "stake-indexer"
  compose "${STAKE_INDEXER_DIR}" ps || true
  printf "\n"
  info_i "proof-publisher" "proof-publisher"
  compose "${PROOF_PUBLISHER_DIR}" ps || true
}

report_compose_container_issues() {
  local dir="$1"
  local label="$2"
  local ids=()
  local output line failed=0 restarted=0 expected_dir workdir seen_workdirs
  mapfile -t ids < <(compose "${dir}" ps -q 2>/dev/null || true)
  if [[ "${#ids[@]}" -eq 0 ]]; then
    line_i "${label}: no containers found" "${label}: 未发现容器"
    return 0
  fi
  expected_dir="$(cd "${dir}" && pwd -P)"
  output="$(docker_cmd inspect --format '{{.Name}} status={{.State.Status}} oom={{.State.OOMKilled}} restarts={{.RestartCount}} exit={{.State.ExitCode}} workdir={{ index .Config.Labels "com.docker.compose.project.working_dir" }}' "${ids[@]}" 2>/dev/null || true)"
  seen_workdirs=""
  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    if [[ "${line}" =~ oom=true || "${line}" =~ status=exited || "${line}" =~ status=dead ]]; then
      warn_i "${label}: ${line}" "${label}: ${line}"
      failed=1
    elif [[ "${line}" =~ restarts=[1-9][0-9]* ]]; then
      warn_i "${label}: historical container restart observed, but the container is currently running: ${line}" "${label}: 检测到历史容器重启，但当前容器仍在运行：${line}"
      restarted=1
    fi
    workdir="${line##* workdir=}"
    if [[ "${workdir}" != "${line}" && -n "${workdir}" && "${workdir}" != "<no value>" && "${workdir}" != "${expected_dir}" ]]; then
      if [[ "|${seen_workdirs}|" != *"|${workdir}|"* ]]; then
        warn_i "${label}: container belongs to another deploy directory: ${workdir}" "${label}: 容器属于另一个部署目录：${workdir}"
        seen_workdirs="${seen_workdirs}|${workdir}"
      fi
      failed=1
    fi
  done <<<"${output}"
  if [[ "${failed}" -eq 0 && "${restarted}" -eq 0 ]]; then
    line_i "${label}: no OOM/restart/exited containers detected" "${label}: 未发现 OOM、重启或退出容器"
  elif [[ "${failed}" -eq 0 ]]; then
    line_i "${label}: no OOM or exited containers detected; historical restarts are warnings only" "${label}: 未发现 OOM 或退出容器；历史重启仅作为警告"
  fi
  return "${failed}"
}

ensure_compose_project_owned() {
  local dir="$1"
  local label="$2"
  local ids=()
  local output line expected_dir workdir seen_workdirs found=0
  mapfile -t ids < <(compose "${dir}" ps -q 2>/dev/null || true)
  if [[ "${#ids[@]}" -eq 0 ]]; then
    return 0
  fi
  expected_dir="$(cd "${dir}" && pwd -P)"
  output="$(docker_cmd inspect --format '{{.Name}} workdir={{ index .Config.Labels "com.docker.compose.project.working_dir" }}' "${ids[@]}" 2>/dev/null || true)"
  seen_workdirs=""
  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    workdir="${line##* workdir=}"
    if [[ "${workdir}" != "${line}" && -n "${workdir}" && "${workdir}" != "<no value>" && "${workdir}" != "${expected_dir}" ]]; then
      if [[ "|${seen_workdirs}|" != *"|${workdir}|"* ]]; then
        error_i "${label}: refusing to change containers from another deploy directory: ${workdir}. Run the menu from that directory, stop those containers there, or set a different Compose project name before continuing." "${label}: 拒绝改动来自另一个部署目录的容器：${workdir}。请从那个目录运行菜单、在那里停止容器，或继续前设置不同的 Compose project name。"
        seen_workdirs="${seen_workdirs}|${workdir}"
      fi
      found=1
    fi
  done <<<"${output}"
  if [[ "${found}" -ne 0 ]]; then
    return 1
  fi
}

follow_logs_menu() {
  cat <<'EOF'
1) fractal-indexer
2) stake-indexer
3) proof-publisher
EOF
  local choice
  read -r -p "$(choose_text "Select logs to follow" "请选择要跟随的日志"): " choice
  case "${choice}" in
    1) compose "${FRACTAL_INDEXER_DIR}" logs --tail=100 -f ;;
    2) compose "${STAKE_INDEXER_DIR}" logs --tail=100 -f ;;
    3) compose "${PROOF_PUBLISHER_DIR}" logs --tail=100 -f ;;
    *) warn_i "Unknown option: ${choice}" "未知选项：${choice}" ;;
  esac
}

stop_services_menu() {
  cat <<'EOF'
1) fractal-indexer
2) stake-indexer
3) proof-publisher
4) all
EOF
  local choice
  read -r -p "$(choose_text "Select services to stop" "请选择要停止的服务"): " choice
  case "${choice}" in
    1) confirm_i "Stop fractal-indexer?" "停止 fractal-indexer？" "n" && ensure_compose_project_owned "${FRACTAL_INDEXER_DIR}" "fractal-indexer" && compose "${FRACTAL_INDEXER_DIR}" down ;;
    2) confirm_i "Stop stake-indexer?" "停止 stake-indexer？" "n" && ensure_compose_project_owned "${STAKE_INDEXER_DIR}" "stake-indexer" && compose "${STAKE_INDEXER_DIR}" down ;;
    3) confirm_i "Stop proof-publisher?" "停止 proof-publisher？" "n" && ensure_compose_project_owned "${PROOF_PUBLISHER_DIR}" "proof-publisher" && compose "${PROOF_PUBLISHER_DIR}" down ;;
    4)
      confirm_i "Stop all services?" "停止全部服务？" "n" || return 0
      ensure_compose_project_owned "${PROOF_PUBLISHER_DIR}" "proof-publisher" || return 1
      ensure_compose_project_owned "${STAKE_INDEXER_DIR}" "stake-indexer" || return 1
      ensure_compose_project_owned "${FRACTAL_INDEXER_DIR}" "fractal-indexer" || return 1
      compose "${PROOF_PUBLISHER_DIR}" down || true
      compose "${STAKE_INDEXER_DIR}" down || true
      compose "${FRACTAL_INDEXER_DIR}" down || true
      ;;
    *) warn_i "Unknown option: ${choice}" "未知选项：${choice}" ;;
  esac
}

require_command() {
  if ! command_exists "$1"; then
    error_i "Missing required command: $1" "缺少必要命令：$1"
    return 1
  fi
}

main "$@"
