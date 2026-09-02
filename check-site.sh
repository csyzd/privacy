#!/usr/bin/env bash
#
# 站点体检:推送前跑一遍,推送后再跑一遍(带 --live)。
#
#   Tools 无关 —— 这个脚本属于托管仓库本身,对**所有** App 的目录一起检查。
#
# 用法：
#     ./check-site.sh              # 本地文件检查 + 本地起服务验 200
#     ./check-site.sh --live       # 额外抓线上 GitHub Pages 验 200
#
# 为什么要有：ASC 里的隐私政策 URL 必须始终有效,而"改完忘了推"、"推了但
# Pages 没生效"、"目录名拼错"这三种失败都不会有任何东西提醒你 —— 直到审核被拒。
set -euo pipefail
cd "$(dirname "$0")"

BASE_URL="https://csyzd.github.io/privacy"
PASS=0; FAIL=0
ok()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "── 仓库结构 ──"
[ -f .nojekyll ] && ok ".nojekyll 在仓库根" \
    || bad ".nojekyll 缺失或不在根(放子目录对整站不生效)"
[ -f index.html ] && ok "根索引页存在" \
    || bad "根索引页缺失(访问 /privacy/ 会 404)"

APPS=()
for d in */; do
    d="${d%/}"
    [ -f "$d/privacy.html" ] && APPS+=("$d")
done
echo "  发现 App 目录: ${APPS[*]}"

echo "── 每个 App 的必备页面 ──"
for app in "${APPS[@]}"; do
    for f in privacy.html terms.html; do
        [ -f "$app/$f" ] && ok "$app/$f" || bad "$app/$f 缺失"
    done
    # 支持页:审核指南 1.5 要求能真的找到联系方式
    if [ -f "$app/support.html" ]; then
        grep -qE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$app/support.html" \
            && ok "$app/support.html 有真实联系方式" \
            || bad "$app/support.html 没有可联系的地址(1.5)"
    else
        echo "  ·  $app 无 support.html(若 ASC 的 Support URL 指向别处则可接受)"
    fi
    # 存档目录:发布即冻结,只是提示不判错
    ARCHIVES=$(find "$app" -maxdepth 1 -type d -name 'v[0-9]*' | wc -l | tr -d ' ')
    echo "  ·  $app 历史存档 $ARCHIVES 份"
done

echo "── 死链(仓库内相对链接) ──"
/usr/bin/python3 - <<'PYTHON'
import pathlib, re, sys
bad = []
for html in sorted(pathlib.Path('.').rglob('*.html')):
    if '.git' in html.parts:
        continue
    for href in re.findall(r'href="([^"]+)"', html.read_text(encoding='utf-8')):
        if href.startswith(('http', 'mailto:', '#')):
            continue
        if not (html.parent / href).resolve().exists():
            bad.append(f"{html} → {href}")
if bad:
    print("  ❌ 死链 %d 条:" % len(bad))
    for b in bad:
        print("     ", b)
    sys.exit(1)
print("  ✅ 无死链")
PYTHON
[ $? -eq 0 ] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))

echo "── 本地 HTTP 200 ──"
PORT=8799
/usr/bin/python3 -m http.server "$PORT" >/dev/null 2>&1 &
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null || true' EXIT
sleep 1.5
for app in "${APPS[@]}"; do
    for f in privacy.html terms.html support.html index.html; do
        [ -f "$app/$f" ] || continue
        code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/$app/$f")
        [ "$code" = "200" ] && ok "$app/$f → $code" || bad "$app/$f → $code"
    done
done
code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/")
[ "$code" = "200" ] && ok "/ → $code" || bad "/ → $code"
kill $SERVER_PID 2>/dev/null || true

if [ "${1:-}" = "--live" ]; then
    echo "── 线上 GitHub Pages ──"
    for app in "${APPS[@]}"; do
        for f in privacy.html terms.html; do
            code=$(curl -s -o /dev/null -w "%{http_code}" -L "$BASE_URL/$app/$f")
            [ "$code" = "200" ] && ok "$BASE_URL/$app/$f → $code" \
                || bad "$BASE_URL/$app/$f → $code(推了吗?Pages 生效要几分钟)"
        done
    done
fi

echo
echo "通过 $PASS · 失败 $FAIL"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
if [ "${1:-}" != "--live" ]; then
    echo "推送后再跑一次:./check-site.sh --live"
fi
