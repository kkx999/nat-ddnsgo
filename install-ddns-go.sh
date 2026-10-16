#!/usr/bin/env bash
# nat-ddnsgo: install the latest official stable DDNS-GO release on Linux.
# Usage (root): bash install-ddns-go.sh [listen-port]
set -Eeuo pipefail
umask 077

fail() { printf '错误：%s\n' "$*" >&2; exit 1; }

[[ "$(id -u)" -eq 0 ]] || fail "请使用 root 用户运行。"
[[ "$(uname -s)" == "Linux" ]] || fail "本脚本只支持 Linux。"

PORT="${1:-10005}"
[[ "$PORT" =~ ^[1-9][0-9]{0,4}$ ]] && (( PORT <= 65535 )) || fail "端口必须为 1–65535 的十进制整数。"

for cmd in curl tar sha256sum awk install uname mktemp; do
    command -v "$cmd" >/dev/null 2>&1 || fail "缺少依赖：$cmd"
done

case "$(uname -m)" in
    x86_64|amd64) ARCH=x86_64 ;;
    aarch64|arm64) ARCH=arm64 ;;
    i386|i686) ARCH=i386 ;;
    armv7l|armv7) ARCH=armv7 ;;
    armv6l|armv6) ARCH=armv6 ;;
    riscv64) ARCH=riscv64 ;;
    *) fail "不支持的 CPU 架构：$(uname -m)" ;;
esac

BIN=/usr/local/bin/ddns-go
# This script is for first-time installation: never overwrite a running installation.
if [[ -e "$BIN" ]] || command -v ddns-go >/dev/null 2>&1; then
    fail "检测到已有 DDNS-GO 可执行文件，为避免覆盖现有安装已停止。"
fi
if command -v systemctl >/dev/null 2>&1 && systemctl cat ddns-go.service >/dev/null 2>&1; then
    fail "检测到已有 ddns-go.service；请先核实原服务，不要重复安装。"
fi

printf '正在查询官方最新正式版本...\n'
LATEST_URL="$(curl -fsSL --proto '=https' --tlsv1.2 --retry 3 \
    -o /dev/null -w '%{url_effective}' \
    'https://github.com/jeessy2/ddns-go/releases/latest')" || fail "无法查询 GitHub 最新版本。"
TAG="${LATEST_URL##*/}"
[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "获取到的版本号不符合预期：$TAG"

VERSION="${TAG#v}"
ARCHIVE="ddns-go_${VERSION}_linux_${ARCH}.tar.gz"
RELEASE_BASE="https://github.com/jeessy2/ddns-go/releases/download/${TAG}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf -- "$WORKDIR"' EXIT

printf '最新正式版：%s；系统架构：%s；端口：%s\n' "$TAG" "$ARCH" "$PORT"
printf '下载并校验发布包...\n'
curl -fsSL --proto '=https' --tlsv1.2 --retry 3 \
    -o "$WORKDIR/$ARCHIVE" "$RELEASE_BASE/$ARCHIVE" || fail "下载失败：$ARCHIVE"
curl -fsSL --proto '=https' --tlsv1.2 --retry 3 \
    -o "$WORKDIR/checksums.txt" "$RELEASE_BASE/checksums.txt" || fail "无法下载官方 checksums.txt。"

awk -v name="$ARCHIVE" '$2 == name { print; matched = 1 } END { if (!matched) exit 1 }' \
    "$WORKDIR/checksums.txt" > "$WORKDIR/verify.sha256" || fail "校验文件中找不到 $ARCHIVE。"
(
    cd "$WORKDIR"
    sha256sum -c verify.sha256
) || fail "SHA256 校验失败，安装已中止。"

tar -xzf "$WORKDIR/$ARCHIVE" -C "$WORKDIR" ddns-go || fail "解压失败。"
[[ -f "$WORKDIR/ddns-go" && ! -L "$WORKDIR/ddns-go" ]] || fail "压缩包内找不到正常的 ddns-go 可执行文件。"

# Install at a permanent path: system services must not point to the temporary directory.
install -m 0755 "$WORKDIR/ddns-go" "$BIN" || fail "安装可执行文件失败。"
printf '正在注册 DDNS-GO 系统服务...\n'
"$BIN" -s install -l ":$PORT" || fail "服务安装失败；程序保留在 $BIN 以便排查。"

printf '\n安装成功：%s\n程序位置：%s\n监听端口：%s\n' "$TAG" "$BIN" "$PORT"
printf '%s\n' '注意：这会监听全部网络接口；请限制管理端公网访问，并尽快完成账号初始化。'
printf '%s\n' '本脚本每次执行时获取最新正式版，但不会在后台自动升级已安装的 DDNS-GO。'
