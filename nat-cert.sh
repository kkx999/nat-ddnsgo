#!/usr/bin/env bash
# nat-ddnsgo: Cloudflare DNS-01 + acme.sh certificate setup for Debian/Ubuntu NAT VPS.
# Run as root. The certificate is issued before 3X-UI is installed (README step 5).
set -Eeuo pipefail
umask 077

export HOME=/root
ACME=/root/.acme.sh/acme.sh
INSTALLER_URL=https://get.acme.sh
INSTALLER_FILE=""

fail() {
    printf '错误：%s\n' "$*" >&2
    exit 1
}

cleanup() {
    if [[ -n "$INSTALLER_FILE" ]]; then
        rm -f -- "$INSTALLER_FILE"
    fi
    unset CF_TOKEN CF_Token || true
}
trap cleanup EXIT

[[ "$(id -u)" -eq 0 ]] || fail '请使用 root 用户执行。'
[[ -f /etc/debian_version ]] && command -v apt-get >/dev/null 2>&1 || fail '只支持 Debian / Ubuntu（使用 apt 和 cron）。'
[[ -t 0 ]] || fail '此脚本需要交互式终端，请在 SSH 终端中运行。'

printf '%s\n' '==========================================' ' NAT-DDNSGO SSL 证书一键配置' ' Cloudflare DNS-01，无需开放 80/443 端口' '=========================================='
read -r -p '请输入接收证书通知的邮箱: ' EMAIL
read -r -p '请输入证书域名（如 nat.example.com）: ' DOMAIN
read -r -s -p '请输入 Cloudflare API Token（输入不显示）: ' CF_TOKEN
printf '\n'

DOMAIN="${DOMAIN,,}"
DOMAIN="${DOMAIN%.}"
DOMAIN_PATTERN='^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]([a-z0-9-]{0,61}[a-z0-9])?$'
EMAIL_PATTERN='^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
[[ "$EMAIL" =~ $EMAIL_PATTERN ]] || fail '邮箱格式不正确。'
[[ "${#DOMAIN}" -le 253 && "$DOMAIN" =~ $DOMAIN_PATTERN ]] || fail '域名格式不正确；不要输入协议、端口、路径或通配符。'
[[ -n "$CF_TOKEN" ]] || fail 'Cloudflare API Token 不能为空。'

# Only install missing requirements; do not overwrite apt/dpkg configuration.
PACKAGES=()
command -v curl >/dev/null 2>&1 || PACKAGES+=(curl ca-certificates)
command -v openssl >/dev/null 2>&1 || PACKAGES+=(openssl)
if ! dpkg-query -W -f='${Status}' cron 2>/dev/null | grep -qx 'install ok installed'; then
    PACKAGES+=(cron)
fi
if ((${#PACKAGES[@]} > 0)); then
    printf '\n[1/4] 安装依赖：%s\n' "${PACKAGES[*]}"
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${PACKAGES[@]}"
else
    printf '\n[1/4] 所需依赖已经安装。\n'
fi
command -v crontab >/dev/null 2>&1 || fail '未找到 crontab，无法设置自动续签。'

# Ensure cron actually runs: acme.sh installs a crontab entry, not a daemon.
if [[ -d /run/systemd/system ]] && command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now cron || fail '无法启动 cron 服务。'
    systemctl is-active --quiet cron || fail 'cron 服务未运行。'
elif command -v service >/dev/null 2>&1; then
    service cron start >/dev/null || fail '无法启动 cron 服务。'
    service cron status >/dev/null 2>&1 || fail 'cron 服务未运行。'
else
    fail '无法检测或启动 cron 服务，自动续签不可用。'
fi

printf '\n[2/4] 安装或检查 acme.sh...\n'
if [[ ! -x "$ACME" ]] || ! crontab -l 2>/dev/null | grep -Eq 'acme\.sh.*--cron'; then
    INSTALLER_FILE="$(mktemp)"
    curl -fsSL --proto '=https' --tlsv1.2 "$INSTALLER_URL" -o "$INSTALLER_FILE"
    # Installer does not receive the Cloudflare credential.
    env -u CF_Token -u CF_Key -u CF_Email sh "$INSTALLER_FILE" "email=$EMAIL"
fi
[[ -x "$ACME" ]] || fail 'acme.sh 安装失败。'
crontab -l 2>/dev/null | grep -Eq 'acme\.sh.*--cron' || fail '未检测到 acme.sh 的定时续签任务。'
"$ACME" --register-account --server letsencrypt -m "$EMAIL"

printf '\n[3/4] 使用 Cloudflare DNS 验证申请证书...\n'
# Only this command inherits the API Token; acme.sh securely retains DNS renewal credentials.
CF_Token="$CF_TOKEN" "$ACME" --issue --server letsencrypt --dns dns_cf -d "$DOMAIN" --keylength ec-256 || fail '证书申请失败；检查域名、Cloudflare Token 和 DNS 权限。'
unset CF_TOKEN

printf '\n[4/4] 安装证书并保存续签后的重启回调...\n'
CERT_DIR="/root/cert/$DOMAIN"
install -d -m 700 "$CERT_DIR"

# README step 5 happens before installing 3X-UI. Missing x-ui is expected on first run.
# After installation, a genuine restart failure must propagate (no blanket success fallback).
RELOAD_CMD='if command -v systemctl >/dev/null 2>&1 && systemctl cat x-ui.service >/dev/null 2>&1; then systemctl restart x-ui; elif command -v x-ui >/dev/null 2>&1; then x-ui restart; else echo "x-ui 尚未安装，本次跳过重启"; fi'
"$ACME" --install-cert -d "$DOMAIN" --ecc \
    --key-file "$CERT_DIR/privkey.pem" \
    --fullchain-file "$CERT_DIR/fullchain.pem" \
    --reloadcmd "$RELOAD_CMD" || fail '证书部署或重启回调失败。'

chmod 600 "$CERT_DIR/privkey.pem"
chmod 644 "$CERT_DIR/fullchain.pem"
[[ -s "$CERT_DIR/privkey.pem" && -s "$CERT_DIR/fullchain.pem" ]] || fail '证书文件缺失或为空。'
openssl x509 -in "$CERT_DIR/fullchain.pem" -noout -dates || fail '证书文件不是有效的 X.509 证书。'

printf '\n%s\n' '==========================================' '证书签发成功，自动续签已配置。'
printf '证书路径：%s/fullchain.pem\n' "$CERT_DIR"
printf '私钥路径：%s/privkey.pem\n' "$CERT_DIR"
printf '%s\n' '第 6 步安装 3X-UI 后，将以上路径填入面板 SSL 设置并重启面板。' '后续续签成功时，acme.sh 会更新证书文件并重启已安装的 x-ui。' '=========================================='
