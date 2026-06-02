#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY_MENU="${ROOT_DIR}/scripts/deploy-menu.sh"
DEPLOY_BUNDLE_DIR="${DEPLOY_BUNDLE_DIR:-${ROOT_DIR}/.official/fractal-indexer-deploy}"
PROOF_CONFIG="${DEPLOY_BUNDLE_DIR}/proof-publisher/config.json"
SNAPSHOT_HEIGHT="${SNAPSHOT_HEIGHT:-1753260}"
SNAPSHOT_MIN_FREE_GB="${SNAPSHOT_MIN_FREE_GB:-400}"
QA_DOCKER_CIDR="${QA_DOCKER_CIDR:-}"
QA_OUTPUT_DIR="${QA_OUTPUT_DIR:-${ROOT_DIR}/logs}"
UI_LANG=""
APPLY="false"

main() {
  set_language_from_env
  case "${1:-}" in
    ""|--menu)
      select_language
      menu_loop
      ;;
    --help|-h)
      print_help
      ;;
    --list)
      list_topics
      ;;
    --check-all)
      check_all "${2:-}"
      ;;
    --check)
      require_topic "${2:-}"
      check_topic "$2"
      ;;
    --fix)
      require_topic "${2:-}"
      [[ "${3:-}" == "--apply" ]] && APPLY="true"
      fix_topic "$2"
      ;;
    --self-test)
      self_test
      ;;
    *)
      error_i "Unknown argument: $1" "未知参数：$1"
      print_help
      return 1
      ;;
  esac
}

set_language_from_env() {
  case "${DEPLOY_LANG:-}" in
    zh|ZH|cn|CN|chinese|Chinese|中文) UI_LANG="zh" ;;
    *) UI_LANG="en" ;;
  esac
}

select_language() {
  [[ -t 0 ]] || return 0
  printf "Select language / 选择语言\n1) English\n2) 中文\n"
  local choice
  read -r -p "Language [1]: " choice
  [[ "${choice}" == "2" ]] && UI_LANG="zh" || UI_LANG="en"
}

choose_text() {
  if [[ "${UI_LANG}" == "zh" ]]; then
    printf "%s" "$2"
  else
    printf "%s" "$1"
  fi
}

info_i() {
  printf ">>> %s\n" "$(choose_text "$1" "$2")"
}

ok_i() {
  printf "OK   %s\n" "$(choose_text "$1" "$2")"
}

warn_i() {
  printf "WARN: %s\n" "$(choose_text "$1" "$2")" >&2
}

error_i() {
  printf "ERROR: %s\n" "$(choose_text "$1" "$2")" >&2
}

print_help() {
  if [[ "${UI_LANG}" == "zh" ]]; then
    cat <<'EOF'
Fractal Indexer Q&A 助手

用法：
  bash scripts/qa-helper.sh
  bash scripts/qa-helper.sh --list
  bash scripts/qa-helper.sh --check-all
  bash scripts/qa-helper.sh --check <topic>
  bash scripts/qa-helper.sh --fix <topic>
  bash scripts/qa-helper.sh --fix <topic> --apply
  bash scripts/qa-helper.sh --self-test

`--check` 只诊断。`--fix` 先给出处理路径；只有明确带 `--apply` 的支持项才会执行改动。
EOF
  else
    cat <<'EOF'
Fractal Indexer Q&A Helper

Usage:
  bash scripts/qa-helper.sh
  bash scripts/qa-helper.sh --list
  bash scripts/qa-helper.sh --check-all
  bash scripts/qa-helper.sh --check <topic>
  bash scripts/qa-helper.sh --fix <topic>
  bash scripts/qa-helper.sh --fix <topic> --apply
  bash scripts/qa-helper.sh --self-test

`--check` diagnoses only. `--fix` shows a remediation path; only supported
actions explicitly called with `--apply` make changes.
EOF
  fi
  printf "\n"
  list_topics
}

list_topics() {
  if [[ "${UI_LANG}" == "zh" ]]; then
    cat <<'EOF'
Topics:
  prerequisites   运行依赖和部署前置条件
  official        官方部署包版本、v0.2.0 镜像与配置校验
  fractald        是否存在可用 Fractald 节点
  rpc             RPC 端口、容器连通和剪枝兼容
  rpc-exposure    Fractald RPC/ZMQ 公网暴露风险
  api-exposure    indexer API / 内部存储端口暴露风险
  snapshot        官方快照、剪枝高度和所需区块
  resources       磁盘、内存和容器资源建议
  interrupted     SSH 断线或中途停止后的恢复路径
  statehash       fractal-indexer 就绪与 stake 启动门槛
  health          运行中服务健康检查、旧镜像/旧 RPC 方法日志
  proof           proof-publisher dry-run / 广播安全
  registration    未来运营商注册边界
  secrets         敏感配置和误提交检查
  scope           官方版本范围和魔改排除说明
  issue-report    生成不含密钥的初步排查报告
EOF
  else
    cat <<'EOF'
Topics:
  prerequisites   Runtime dependencies and deployment prerequisites
  official        Official deploy bundle version, v0.2.0 image, and config checks
  fractald        Presence of a usable Fractald node
  rpc             RPC port, container connectivity, pruning compatibility
  rpc-exposure    Fractald RPC/ZMQ public exposure risk
  api-exposure    Indexer API / datastore public exposure risk
  snapshot        Official snapshot, prune height, required blocks
  resources       Disk, memory, and container-resource advice
  interrupted     Recovery after SSH disconnect or interrupted deployment
  statehash       fractal-indexer readiness gate for stake startup
  health          Running service health and stale image/RPC-method logs
  proof           proof-publisher dry-run / broadcast safety
  registration    Future operator-registration boundary
  secrets         Secret files and accidental-commit checks
  scope           Official-only scope and excluded customizations
  issue-report    Generate a first-line report without secrets
EOF
  fi
}

require_topic() {
  if [[ -z "$1" ]]; then
    error_i "Missing topic. Run --list." "缺少 topic。请运行 --list 查看。"
    return 1
  fi
}

menu_loop() {
  while true; do
    printf "\n"
    info_i "Q&A helper: select an operator problem" "Q&A 助手：选择你遇到的问题"
    if [[ "${UI_LANG}" == "zh" ]]; then
      cat <<'EOF'
1) 一次运行常见安全/部署检查
2) 节点与 RPC 检查
3) RPC/ZMQ 公网暴露检查与处理建议
4) API/数据库端口暴露检查与处理建议
5) 快照/剪枝/资源检查
6) 断线恢复与服务健康
7) statehash / stake 启动门槛
8) proof-publisher / 注册安全
9) 官方包版本与更新
10) 敏感文件检查与 issue 报告
11) 查看全部 topic
0) 返回
EOF
    else
      cat <<'EOF'
1) Run common security/readiness checks
2) Node and RPC checks
3) RPC/ZMQ public exposure check and remediation
4) API/datastore exposure check and remediation
5) Snapshot/pruning/resource checks
6) Disconnect recovery and service health
7) statehash / stake startup gate
8) proof-publisher / registration safety
9) Official bundle version and update
10) Secret-file check and issue report
11) List every topic
0) Back
EOF
    fi
    local choice
    read -r -p "$(choose_text "Select an option" "请选择"): " choice || return 0
    case "${choice}" in
      1) check_all || true ;;
      2) check_topic fractald || true; check_topic rpc || true ;;
      3) check_topic rpc-exposure || true; fix_topic rpc-exposure ;;
      4) check_topic api-exposure || true; fix_topic api-exposure ;;
      5) check_topic snapshot || true; check_topic resources || true ;;
      6) check_topic interrupted || true; check_topic health || true ;;
      7) check_topic statehash || true ;;
      8) check_topic proof || true; check_topic registration || true ;;
      9) check_topic official || true; fix_topic official ;;
      10) check_topic secrets || true; fix_topic issue-report ;;
      11) list_topics ;;
      0) return 0 ;;
      *) warn_i "Unknown option: ${choice}" "未知选项：${choice}" ;;
    esac
  done
}

check_topic() {
  case "$1" in
    prerequisites) check_prerequisites ;;
    official) check_official ;;
    fractald) check_fractald ;;
    rpc) check_rpc ;;
    rpc-exposure) check_rpc_exposure ;;
    api-exposure) check_api_exposure ;;
    snapshot) check_snapshot ;;
    resources) check_resources ;;
    interrupted) check_interrupted ;;
    statehash) check_statehash ;;
    health) check_health ;;
    proof) check_proof ;;
    registration) check_registration ;;
    secrets) check_secrets ;;
    scope) check_scope ;;
    issue-report) preview_issue_report ;;
    *)
      error_i "Unknown topic: $1" "未知 topic：$1"
      return 1
      ;;
  esac
}

fix_topic() {
  case "$1" in
    prerequisites) fix_prerequisites ;;
    official) fix_official ;;
    fractald) fix_fractald ;;
    rpc) fix_rpc ;;
    rpc-exposure) fix_rpc_exposure ;;
    api-exposure) fix_api_exposure ;;
    snapshot) fix_snapshot ;;
    resources) fix_resources ;;
    interrupted) fix_interrupted ;;
    statehash) fix_statehash ;;
    health) fix_health ;;
    proof) fix_proof ;;
    registration) fix_registration ;;
    secrets) fix_secrets ;;
    scope) fix_scope ;;
    issue-report) fix_issue_report ;;
    *)
      error_i "Unknown topic: $1" "未知 topic：$1"
      return 1
      ;;
  esac
}

check_all() {
  local deep="${1:-}" failed=0
  info_i "Running common Q&A checks (read-only)" "运行常见 Q&A 检查（只读）"
  check_prerequisites || failed=1
  check_fractald || failed=1
  check_rpc_exposure || failed=1
  check_api_exposure || failed=1
  check_resources || failed=1
  check_official || true
  check_secrets || failed=1
  if [[ "${deep}" == "--deep" ]]; then
    check_rpc || failed=1
    check_health || failed=1
  else
    info_i "Use --check-all --deep to also invoke RPC and service checks." "需要调用 RPC 和服务检查时，使用 --check-all --deep。"
  fi
  return "${failed}"
}

run_deploy_menu() {
  DEPLOY_LANG="${UI_LANG}" bash "${DEPLOY_MENU}" "$@"
}

run_deploy_menu_readonly() {
  QA_READ_ONLY=true OFFICIAL_DEPLOY_UPDATE=never DEPLOY_LANG="${UI_LANG}" \
    bash "${DEPLOY_MENU}" "$@"
}

command_present() {
  command -v "$1" >/dev/null 2>&1
}

check_prerequisites() {
  info_i "Runtime prerequisites" "运行依赖"
  local failed=0 cmd
  for cmd in bash git curl tar zstd docker; do
    if command_present "${cmd}"; then
      ok_i "${cmd} is installed" "已安装 ${cmd}"
    else
      warn_i "${cmd} is missing" "缺少 ${cmd}"
      failed=1
    fi
  done
  if command_present docker && (docker compose version >/dev/null 2>&1 || command_present docker-compose); then
    ok_i "Docker Compose is available" "Docker Compose 可用"
  else
    warn_i "Docker Compose is missing or unavailable" "Docker Compose 缺失或不可用"
    failed=1
  fi
  return "${failed}"
}

fix_prerequisites() {
  info_i "Dependency remediation" "依赖修复"
  if [[ "${APPLY}" != "true" ]]; then
    printf "%s\n" "$(choose_text \
      "Run with --apply to let the official deployment menu install supported missing dependencies." \
      "带 --apply 运行后，可让官方部署菜单安装支持的缺失依赖。")"
    printf "  DEPLOY_LANG=%s bash scripts/qa-helper.sh --fix prerequisites --apply\n" "${UI_LANG}"
    return 0
  fi
  run_deploy_menu --install-deps
}

check_official() {
  info_i "Official deploy bundle checkout" "官方部署包 checkout"
  if [[ ! -d "${DEPLOY_BUNDLE_DIR}/.git" ]]; then
    warn_i "Official bundle has not been fetched yet; normal deployment fetches it automatically." "官方部署包尚未拉取；正常部署时会自动拉取。"
    return 0
  fi
  run_deploy_menu_readonly --official-status
  run_deploy_menu_readonly --validate-official
}

fix_official() {
  info_i "Official bundle update" "官方部署包更新"
  if [[ "${APPLY}" != "true" ]]; then
    printf "  DEPLOY_LANG=%s bash scripts/qa-helper.sh --fix official --apply\n" "${UI_LANG}"
    return 0
  fi
  run_deploy_menu --sync-official
}

find_fractald_conf_hint() {
  local candidate
  for candidate in \
    "${FRACTALD_CONF:-}" "${BITCOIN_CONF:-}" \
    /data/fractald-full/bitcoin.conf /data/fractald/bitcoin.conf \
    /var/lib/fractald-light/bitcoin.conf /var/lib/fractald/bitcoin.conf \
    "${HOME:-}/.fractalbitcoin/bitcoin.conf" "${HOME:-}/.bitcoin/bitcoin.conf"; do
    [[ -n "${candidate}" && -f "${candidate}" ]] && { printf "%s" "${candidate}"; return 0; }
  done
  return 1
}

check_fractald() {
  info_i "Fractald node detection" "Fractald 节点识别"
  local process conf failed=0
  process="$(ps -eo pid,cmd 2>/dev/null | grep -E '(^|/)(fractald|bitcoind)( |$)' | grep -v grep | head -n 1 || true)"
  if [[ -n "${process}" ]]; then
    printf "OK   process: %s\n" "${process}"
  else
    warn_i "No running fractald/bitcoind process was detected in this host namespace." "当前主机命名空间未识别到运行中的 fractald/bitcoind 进程。"
    failed=1
  fi
  conf="$(find_fractald_conf_hint || true)"
  if [[ -n "${conf}" ]]; then
    printf "OK   config: %s\n" "${conf}"
  else
    warn_i "No known local bitcoin.conf path was detected. Set FRACTALD_CONF if the node uses a custom path." "未识别到常见 bitcoin.conf 路径。如果节点使用自定义路径，请设置 FRACTALD_CONF。"
  fi
  return "${failed}"
}

fix_fractald() {
  info_i "Fractald is a prerequisite outside this repository." "Fractald 是本仓库之外的前置条件。"
  printf "%s\n" "$(choose_text \
    "After the node is installed and synced, set FRACTALD_CONF=/path/to/bitcoin.conf and run RPC validation." \
    "节点安装并同步后，设置 FRACTALD_CONF=/path/to/bitcoin.conf，再运行 RPC 校验。")"
  printf "  FRACTALD_CONF=/path/to/bitcoin.conf bash scripts/qa-helper.sh --check rpc\n"
}

check_rpc() {
  info_i "Container-visible RPC and pruning compatibility" "容器内 RPC 与剪枝兼容检查"
  run_deploy_menu_readonly --validate-rpc
}

fix_rpc() {
  info_i "RPC remediation path" "RPC 处理路径"
  printf "%s\n" "$(choose_text \
    "Use your real Fractald config path; the validator reports wrong credentials, wrong port, Docker binding, or pruned-block problems." \
    "填写真实 Fractald 配置路径；校验器会报告密码、端口、Docker 监听或剪枝缺块问题。")"
  printf "  FRACTALD_CONF=/path/to/bitcoin.conf DEPLOY_LANG=%s bash scripts/qa-helper.sh --check rpc\n" "${UI_LANG}"
}

listener_output() {
  if [[ -n "${QA_LISTENER_FIXTURE:-}" && -f "${QA_LISTENER_FIXTURE}" ]]; then
    cat "${QA_LISTENER_FIXTURE}"
  elif command_present ss; then
    ss -lntp 2>/dev/null || true
  elif command_present netstat; then
    netstat -lntp 2>/dev/null || true
  else
    warn_i "Neither ss nor netstat is installed; listener exposure cannot be checked." "未安装 ss 或 netstat，无法检查监听暴露范围。"
    return 1
  fi
}

check_port_group() {
  local label_en="$1" label_zh="$2"
  shift 2
  local output port lines failed=0 found=0
  output="$(listener_output)" || return 1
  info_i "${label_en}" "${label_zh}"
  for port in "$@"; do
    lines="$(printf "%s\n" "${output}" | grep -E "[:.]${port}([[:space:]]|$)" || true)"
    if [[ -z "${lines}" ]]; then
      printf "SKIP port %s: %s\n" "${port}" "$(choose_text "no local listener" "未发现本机监听")"
      continue
    fi
    found=1
    printf "%s\n" "${lines}"
    if printf "%s\n" "${lines}" | grep -Eq "(0\\.0\\.0\\.0|\\[::\\]|\\*|::):${port}([[:space:]]|$)"; then
      error_i "Port ${port} listens on all interfaces; verify external firewall exposure." "端口 ${port} 监听全部网卡；必须确认公网防火墙暴露情况。"
      failed=1
    else
      ok_i "Port ${port} is not bound to all local interfaces." "端口 ${port} 未绑定所有本地网卡。"
    fi
  done
  [[ "${found}" -eq 0 ]] && warn_i "No relevant running listeners were found." "没有发现相关运行中监听。"
  return "${failed}"
}

check_rpc_exposure() {
  check_port_group "Fractald RPC/ZMQ exposure check" "Fractald RPC/ZMQ 暴露检查" \
    8332 10332 10330 10331
}

fix_rpc_exposure() {
  local docker_cidr="${QA_DOCKER_CIDR:-<confirmed-docker-network-cidr>}"
  info_i "Keep Fractald RPC/ZMQ private" "保持 Fractald RPC/ZMQ 私有"
  cat <<EOF
$(choose_text "Recommended configuration shape:" "建议配置形态：")
  rpcbind=127.0.0.1
  rpcbind=<docker-bridge-ip>
  rpcallowip=127.0.0.1
  rpcallowip=${docker_cidr}
  zmqpubrawblock=tcp://<docker-bridge-ip>:10330
  zmqpubrawtx=tcp://<docker-bridge-ip>:10331

$(choose_text "Inspect the bridge/network subnet before applying a firewall rule:" "应用防火墙规则前先确认 bridge/network 网段：")
  docker network inspect bridge --format '{{(index .IPAM.Config 0).Subnet}}'

$(choose_text "Firewall action supported by this helper for host-run Fractald:" "本助手对宿主机运行的 Fractald 支持的防火墙动作：")
  DEPLOY_LANG=${UI_LANG} QA_DOCKER_CIDR=<confirmed-docker-network-cidr> bash scripts/qa-helper.sh --fix rpc-exposure --apply
EOF
  if [[ "${APPLY}" != "true" ]]; then
    warn_i "Preview only. It does not edit bitcoin.conf or firewall rules." "当前只展示方案，不会修改 bitcoin.conf 或防火墙规则。"
    return 0
  fi
  if [[ -z "${QA_DOCKER_CIDR}" ]]; then
    error_i "Set QA_DOCKER_CIDR to the confirmed container network CIDR before applying firewall rules." "应用防火墙规则前，请将 QA_DOCKER_CIDR 设置为已确认的容器网络 CIDR。"
    return 1
  fi
  if [[ ! "${QA_DOCKER_CIDR}" =~ ^[0-9a-fA-F:.]+/[0-9]+$ ]]; then
    error_i "QA_DOCKER_CIDR must be a CIDR value, for example 172.17.0.0/16." "QA_DOCKER_CIDR 必须是 CIDR 值，例如 172.17.0.0/16。"
    return 1
  fi
  if command_present docker && docker ps --format '{{.Ports}}' 2>/dev/null | grep -Eq ':(8332|10332|10330|10331)->'; then
    error_i "A Docker container publishes a Fractald port. Refusing automatic UFW remediation because Docker-published ports need Docker-aware firewall rules or private port bindings." "检测到 Docker 容器发布了 Fractald 端口。拒绝自动套用 UFW，因为 Docker 发布端口需要 Docker-aware 防火墙或私有端口绑定。"
    return 1
  fi
  if ! command_present ufw; then
    error_i "ufw is not installed; apply equivalent firewall rules manually." "未安装 ufw；请手动应用等效防火墙规则。"
    return 1
  fi
  if ! sudo ufw status 2>/dev/null | grep -q '^Status: active'; then
    error_i "ufw is not active. Refusing to enable a firewall automatically; allow SSH first, then enable and rerun." "ufw 未启用。不会自动开启防火墙；请先确保 SSH 放行后启用，再重新运行。"
    return 1
  fi
  local port
  for port in 8332 10332 10330 10331; do
    sudo ufw insert 1 deny in to any port "${port}" proto tcp
    sudo ufw insert 1 allow from "${QA_DOCKER_CIDR}" to any port "${port}" proto tcp
  done
  sudo ufw status numbered
  warn_i "Firewall rules were inserted before older allow rules. Update bitcoin.conf binding as shown above and verify the ports externally." "防火墙保护规则已插入到旧放行规则之前。仍应按上面的示例收紧 bitcoin.conf 监听，并从外部复查端口。"
}

check_api_exposure() {
  check_port_group "Indexer API/datastore exposure check" "索引器 API/数据存储暴露检查" \
    8000 9637 8080 9222 9432 9379
}

fix_api_exposure() {
  info_i "Protect indexer APIs and datastores" "保护索引器 API 和数据存储端口"
  cat <<EOF
$(choose_text "The indexer services are Docker-published ports. Do not assume UFW alone blocks Docker forwarding." "索引器服务是 Docker 发布端口，不能假设仅用 UFW 就能阻止 Docker 转发。")
$(choose_text "Safe remediation choices:" "安全处理选择：")
  1. $(choose_text "Allow public access only behind a reverse proxy with an allowlist/authentication." "只通过带白名单/认证的反向代理提供公网访问。")
  2. $(choose_text "Restrict Docker-published ports with a reviewed DOCKER-USER/nftables policy." "使用经过复核的 DOCKER-USER/nftables 策略限制 Docker 发布端口。")
  3. $(choose_text "Keep internal ports 9222/9432/9379 localhost-only by starting services through this menu." "始终通过本菜单启动服务，让内部端口 9222/9432/9379 保持 localhost-only。")
EOF
  if [[ "${APPLY}" == "true" ]]; then
    error_i "Automatic API firewall changes are intentionally refused because required public access and Docker firewall backend differ by host. Apply a reviewed policy for this machine." "有意拒绝自动修改 API 防火墙，因为每台机器所需公网访问和 Docker 防火墙后端不同。请按本机需求复核后应用策略。"
    return 1
  fi
}

check_snapshot() {
  info_i "Snapshot and pruned-node gate" "快照与剪枝节点关卡"
  printf "%s %s\n" "$(choose_text "Required retained snapshot height:" "必须保留的快照高度：")" "${SNAPSHOT_HEIGHT}"
  check_rpc
}

fix_snapshot() {
  info_i "Snapshot/pruning remediation" "快照/剪枝处理路径"
  printf "%s\n" "$(choose_text \
    "If required blocks are pruned, use another Fractald node with pruneheight at or below the snapshot height; the helper will not manufacture missing block history." \
    "如果必要区块已经被剪掉，请换用 pruneheight 不高于快照高度的 Fractald 节点；助手无法补造缺失历史块。")"
  printf "  bash scripts/deploy-menu.sh --beginner\n"
}

available_disk_gb() {
  local target="${DEPLOY_BUNDLE_DIR}/fractal-indexer"
  while [[ ! -e "${target}" && "${target}" != "/" ]]; do
    target="$(dirname "${target}")"
  done
  df -BG "${target}" 2>/dev/null | awk 'NR==2 {gsub("G","",$4); print $4}'
}

check_resources() {
  info_i "Resource and disk check" "资源和磁盘检查"
  local disk mem
  disk="$(available_disk_gb || printf "0")"
  mem="$(awk '/MemAvailable/ {printf "%.0f", $2/1024/1024}' /proc/meminfo 2>/dev/null || printf "unknown")"
  printf "  %s: %s GB\n" "$(choose_text "Free disk on deployment filesystem" "部署文件系统可用磁盘")" "${disk:-unknown}"
  printf "  %s: %s GB\n" "$(choose_text "Available memory" "当前可用内存")" "${mem}"
  if [[ "${disk}" =~ ^[0-9]+$ ]] && (( disk < SNAPSHOT_MIN_FREE_GB )); then
    error_i "Free disk is below snapshot guard ${SNAPSHOT_MIN_FREE_GB} GB." "可用磁盘低于快照保护线 ${SNAPSHOT_MIN_FREE_GB} GB。"
    return 1
  fi
  ok_i "Snapshot disk guard is satisfied or could not be strictly evaluated." "快照磁盘保护线已满足，或当前无法严格判定。"
}

fix_resources() {
  info_i "Resource remediation path" "资源处理路径"
  printf "%s\n" "$(choose_text \
    "Move the deployment directory to a larger SSD/NVMe filesystem or free space before snapshot restore. Do not lower SNAPSHOT_MIN_FREE_GB without confirming final data size." \
    "请在恢复快照前把部署目录放到更大的 SSD/NVMe 文件系统或释放空间。未确认最终数据大小前，不要降低 SNAPSHOT_MIN_FREE_GB。")"
  printf "  df -h .\n  bash scripts/deploy-menu.sh --doctor\n"
}

check_interrupted() {
  info_i "Interrupted deployment recovery" "部署中断恢复"
  printf "  tmux attach -t fractal-indexer-oneclick\n"
  printf "  bash scripts/deploy-menu.sh --health\n"
  printf "%s\n" "$(choose_text \
    "If restored data exists but services did not start, use main-menu option 8 for fractal-indexer, then option 9 for stake-indexer after statehash is ready." \
    "如果快照数据已存在但服务未启动，在主菜单用选项 8 启动 fractal-indexer，statehash 就绪后再用选项 9 启动 stake-indexer。")"
}

fix_interrupted() {
  if [[ "${APPLY}" != "true" ]]; then
    printf "  DEPLOY_LANG=%s bash scripts/qa-helper.sh --fix interrupted --apply\n" "${UI_LANG}"
    return 0
  fi
  if [[ ! -t 0 ]]; then
    error_i "Recovery menu requires an interactive terminal." "恢复菜单需要交互式终端。"
    return 1
  fi
  run_deploy_menu
}

check_statehash() {
  info_i "statehash readiness gate" "statehash 就绪关卡"
  run_deploy_menu_readonly --validate-statehash
}

fix_statehash() {
  info_i "statehash remediation path" "statehash 处理路径"
  printf "%s\n" "$(choose_text \
    "Keep fractal-indexer running until it catches up. Start stake-indexer only after this check passes." \
    "保持 fractal-indexer 运行并等待追平。只有本检查通过后才启动 stake-indexer。")"
  printf "  bash scripts/qa-helper.sh --check statehash\n"
}

check_health() {
  info_i "Service health" "服务健康"
  run_deploy_menu_readonly --health
}

fix_health() {
  info_i "Service health remediation" "服务健康处理"
  printf "%s\n" "$(choose_text \
    "Use the interactive main menu to inspect logs or restart only the affected official service after reviewing the health error." \
    "先查看健康检查错误，再通过主菜单查看日志或仅重启受影响的官方服务。")"
  printf "  DEPLOY_LANG=%s bash scripts/deploy-menu.sh\n" "${UI_LANG}"
}

check_proof() {
  info_i "proof-publisher broadcast safety" "proof-publisher 广播安全"
  if [[ ! -f "${PROOF_CONFIG}" ]]; then
    warn_i "proof-publisher config is not prepared; this is normal when proof-publisher is disabled." "proof-publisher 配置尚未准备；未启用该服务时这是正常状态。"
    return 0
  fi
  run_deploy_menu_readonly --validate-proof
}

fix_proof() {
  info_i "Force proof-publisher back to dry-run safety" "将 proof-publisher 恢复为 dry-run 安全模式"
  if [[ ! -f "${PROOF_CONFIG}" ]]; then
    warn_i "No config exists. Use the main menu proof-publisher setup, which writes dry_run=true and disable_broadcast=true." "配置不存在。请使用主菜单的 proof-publisher 配置入口；它会写入 dry_run=true 和 disable_broadcast=true。"
    return 0
  fi
  if [[ "${APPLY}" != "true" ]]; then
    printf "  DEPLOY_LANG=%s bash scripts/qa-helper.sh --fix proof --apply\n" "${UI_LANG}"
    return 0
  fi
  local backup="${PROOF_CONFIG}.bak.qa.$(date +%Y%m%d%H%M%S)"
  cp "${PROOF_CONFIG}" "${backup}"
  chmod 600 "${backup}" 2>/dev/null || true
  sed -E -i \
    -e 's/("dry_run"[[:space:]]*:[[:space:]]*)false/\1true/' \
    -e 's/("disable_broadcast"[[:space:]]*:[[:space:]]*)false/\1true/' \
    "${PROOF_CONFIG}"
  chmod 600 "${PROOF_CONFIG}" 2>/dev/null || true
  warn_i "A secret-bearing backup was created with restricted permissions: ${backup}" "已创建包含敏感内容且限制权限的备份：${backup}"
  run_deploy_menu_readonly --validate-proof
}

check_registration() {
  info_i "Operator registration boundary" "运营商注册边界"
  run_deploy_menu_readonly --proof-registration-checklist
}

fix_registration() {
  warn_i "There is no safe real-registration fix until official third-party registration rules are published. This helper will not sign or broadcast." "官方第三方注册规则公布前，不存在安全的真实注册修复动作。本助手不会签名或广播。"
  check_registration
}

check_secrets() {
  info_i "Sensitive runtime file check" "敏感运行时文件检查"
  local tracked failed=0
  tracked="$(git -C "${ROOT_DIR}" ls-files 2>/dev/null | grep -E '(^|/)(chain\\.yaml|config\\.json)$|(^|/)data/|(^|/)logs/' || true)"
  if [[ -n "${tracked}" ]]; then
    error_i "Potential runtime/secret-bearing files are tracked by git:" "Git 正在跟踪可能包含运行状态或密钥的文件："
    printf "%s\n" "${tracked}"
    failed=1
  else
    ok_i "No standard generated config/data/log files are tracked by git." "Git 未跟踪常见生成配置、数据或日志文件。"
  fi
  if git -C "${ROOT_DIR}" status --short --ignored 2>/dev/null | grep -Eq '(chain\\.yaml|config\\.json|data/|logs/)'; then
    warn_i "Ignored runtime files exist locally. Do not paste them into public issues." "本地存在已忽略的运行时文件。不要把它们贴到公开 issue。"
  fi
  return "${failed}"
}

fix_secrets() {
  info_i "Secret hygiene remediation" "敏感信息处理路径"
  printf "%s\n" "$(choose_text \
    "Remove generated configs, wallets, API keys, and RPC credentials from any public post. If a secret was pushed, rotate it; deleting a file from a later commit is not sufficient." \
    "从所有公开内容中删除生成配置、钱包、API key 和 RPC 凭证。如果密钥已推送，必须轮换；后续提交删除文件并不够。")"
  check_secrets
}

check_scope() {
  info_i "Official-only project boundary" "仅官方版本项目边界"
  printf "%s\n" "$(choose_text \
    "This project deploys official images and runtime official deployment templates only. It excludes dynamic commission and custom staking logic." \
    "本项目只部署官方镜像和运行时官方部署模板，不包含动态佣金或质押魔改。")"
  check_official
}

fix_scope() {
  warn_i "Custom staking or commission behavior is intentionally outside this official-only deployment project." "自定义质押或佣金逻辑明确不属于这个仅官方版本部署项目。"
  check_scope
}

preview_issue_report() {
  info_i "Issue-report content preview" "Issue 报告内容预览"
  printf "%s\n" "$(choose_text \
    "The report contains versions, local port/listener assessment, disk, and git status. It does not read RPC passwords, wallet keys, or generated config contents." \
    "报告包含版本、端口监听判断、磁盘和 git 状态；不会读取 RPC 密码、钱包私钥或生成配置内容。")"
}

fix_issue_report() {
  preview_issue_report
  if [[ "${APPLY}" != "true" ]]; then
    printf "  DEPLOY_LANG=%s bash scripts/qa-helper.sh --fix issue-report --apply\n" "${UI_LANG}"
    return 0
  fi
  mkdir -p "${QA_OUTPUT_DIR}"
  local report="${QA_OUTPUT_DIR}/qa-report-$(date +%Y%m%d%H%M%S).txt"
  {
    printf "Fractal Indexer One-Click Q&A report\n"
    printf "Generated: %s\n\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf "== Repository ==\n"
    git -C "${ROOT_DIR}" status --short --branch 2>&1 || true
    printf "\n== Disk ==\n"
    df -h "${ROOT_DIR}" 2>&1 || true
    printf "\n== Fractald process detection ==\n"
    ps -eo pid,cmd 2>/dev/null | grep -E '(^|/)(fractald|bitcoind)( |$)' | grep -v grep || printf "No process detected\n"
    printf "\n== Relevant listeners ==\n"
    listener_output 2>&1 | grep -E ':(8332|10332|10330|10331|8000|9637|8080|9222|9432|9379)([[:space:]]|$)' || printf "No listener detected\n"
    printf "\n== Tracked sensitive runtime paths ==\n"
    git -C "${ROOT_DIR}" ls-files 2>/dev/null | grep -E '(^|/)(chain\\.yaml|config\\.json)$|(^|/)data/|(^|/)logs/' || printf "None detected\n"
  } >"${report}"
  chmod 600 "${report}" 2>/dev/null || true
  printf "OK   %s\n" "${report}"
  warn_i "Review this report again before posting it publicly; remove public IPs or paths if needed." "公开粘贴前仍要再次审查报告；按需删除公网 IP 或路径。"
}

self_test() {
  local fixture
  fixture="$(mktemp)" || return 1
  printf "LISTEN 0 128 0.0.0.0:8332 0.0.0.0:*\nLISTEN 0 128 127.0.0.1:9222 0.0.0.0:*\n" >"${fixture}"
  QA_LISTENER_FIXTURE="${fixture}"
  export QA_LISTENER_FIXTURE
  if check_rpc_exposure >/dev/null 2>&1; then
    rm -f "${fixture}"
    error_i "Self-test failed: public RPC listener was not rejected." "自测失败：未拒绝公网 RPC 监听。"
    return 1
  fi
  printf "LISTEN 0 128 127.0.0.1:8332 0.0.0.0:*\nLISTEN 0 128 127.0.0.1:9222 0.0.0.0:*\n" >"${fixture}"
  check_rpc_exposure >/dev/null || {
    rm -f "${fixture}"
    error_i "Self-test failed: localhost RPC listener was rejected." "自测失败：错误拒绝了 localhost RPC 监听。"
    return 1
  }
  rm -f "${fixture}"
  unset QA_LISTENER_FIXTURE
  local old_apply="${APPLY}" old_cidr="${QA_DOCKER_CIDR}"
  APPLY="true"
  QA_DOCKER_CIDR=""
  if fix_rpc_exposure >/dev/null 2>&1; then
    APPLY="${old_apply}"
    QA_DOCKER_CIDR="${old_cidr}"
    error_i "Self-test failed: firewall apply did not require an explicit CIDR." "自测失败：防火墙 apply 未要求明确 CIDR。"
    return 1
  fi
  APPLY="${old_apply}"
  QA_DOCKER_CIDR="${old_cidr}"
  ok_i "Q&A helper exposure self-tests passed." "Q&A 助手暴露检查自测通过。"
}

main "$@"
