# 仓库发布设置

当前发布仓库使用：

```bash
https://github.com/EY-hungry/fractal-indexer-oneclick
```

如果发布 fork，再替换文档里的 owner：

```bash
perl -pi -e 's/EY-hungry/<your-github-owner>/g' README.md README.zh-CN.md docs/*.md
```

然后创建 GitHub 远程仓库并推送：

```bash
git remote add origin https://github.com/EY-hungry/fractal-indexer-oneclick.git
git push -u origin main
```

不要推送运行时文件或任何密钥。
