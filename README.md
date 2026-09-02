# privacy

全部 iOS App 的**隐私政策、用户协议、支持页**托管仓库，发布到 GitHub Pages：
<https://csyzd.github.io/privacy/>

App Store Connect 里填的 Privacy Policy URL 与 Support URL 指向这里，
**这些 URL 必须始终有效** —— 失效等于审核被拒。

## 结构（每个 App 一个目录，固定形状）

```
privacy/
├── index.html          仓库根索引：列出各 App（没有它，访问 /privacy/ 直接 404）
├── .nojekyll           必须在**仓库根** —— 放子目录里对整站不生效
├── check-site.sh       站点体检（见下）
└── <App-Name>/
    ├── privacy.html    ← ASC 的 Privacy Policy URL 指向它
    ├── terms.html      ← 商店描述末尾的 Terms 链接
    ├── support.html    ← ASC 的 Support URL；必须有真实可联系的地址（指南 1.5）
    ├── index.html      落地页
    └── vYYYYMMDD/      发布即冻结的历史存档，不再改动
```

**不带日期的是当前版，ASC 永远指向它**；`vYYYYMMDD/` 只是留档。

## 这些页面不是手写的

每个 App 的 `Tools/generate-site.sh` 从该项目的
`Resources/*.lproj/Localizable.strings` 生成 —— 与 **App 内展示的法律文本同源**。

App Store 要求商店页的隐私政策与 App 内呈现实质一致；手工维护两份迟早漂移
（改了 App 里的忘了改网页，或者反过来），所以这里**不接受手写的 html**。
要改文案，改 `.strings`，重新生成。

## 标准流程

```bash
# 1. 在 App 项目里改 .strings，然后
cd Apps/<AppName> && Tools/generate-site.sh --deploy

# 2. 回到本仓库体检（本地文件 + 死链 + 本地 200）
cd ../../privacy && ./check-site.sh

# 3. 自己 review 后提交推送（脚本不替你做这一步）
git status --short
git add -A && git commit -m "..." && git push

# 4. Pages 生效后（几分钟）再验一次线上
./check-site.sh --live
```

`--deploy` 只复制、不提交、不推送：往公开仓库推东西该由人自己按下去。

存档目录**只在内容真的变了时才开**。判断时只比对生成的 `.html`——
用 `diff -rq` 比整个目录会把 `site/` 里的 `.DS_Store` 和历史存档子目录也算成差异，
于是每跑一次就多一个内容相同的日期目录（OnDeck 上真踩过，2026-08-24 修）。

## 新增一个 App 时

1. 在该 App 项目里照抄一份 `Tools/generate-site.sh` 与 `Tools/generate_site.py`，
   改掉 `APP_NAME`、`SITE_DIR`、`<ENV>_SITE_REPO` 变量名
2. 跑 `--deploy` 生成目录
3. **在本仓库根 `index.html` 里加一行** —— 否则从索引页找不到它
4. `./check-site.sh` 全绿后再推
5. 把两个 URL 填进 ASC，并实际访问验证返回 200

## 仓库搬家时要一起改的地方

（2026-08-24 从 `~/Development/personal/github/privacy` 移进 iOS 工作区时的教训：
OnDeck 的脚本当时还指着旧的绝对路径，不改就会静默失效。）

- 每个 App 的 `Tools/generate-site.sh` 里的 `SITE_REPO` 默认值
  —— 用**相对路径**（`$REPO_ROOT/../../privacy`），别用 `$HOME/...`
- 同文件顶部注释里的路径说明
- 各项目 `docs/` 里提到该路径的地方
- 换了仓库名/用户名的话：ASC 的两个 URL，改完实际访问验证 200
