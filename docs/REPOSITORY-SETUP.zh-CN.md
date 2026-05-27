# 仓库发布设置

发布前，把文档里的 GitHub owner 示例替换掉：

```bash
grep -R "YOUR_ORG" -n README.md README.zh-CN.md docs
```

替换示例：

```bash
perl -pi -e 's/YOUR_ORG/<your-github-owner>/g' README.md README.zh-CN.md docs/*.md
```

然后创建 GitHub 远程仓库并推送：

```bash
git remote add origin https://github.com/<your-github-owner>/fractal-indexer-oneclick.git
git push -u origin main
```

不要推送运行时文件或任何密钥。
