# Repository Setup

Before publishing, replace the example GitHub owner in docs:

```bash
grep -R "YOUR_ORG" -n README.md README.zh-CN.md docs
```

Example replacement:

```bash
perl -pi -e 's/YOUR_ORG/<your-github-owner>/g' README.md README.zh-CN.md docs/*.md
```

Then create the remote repository and push:

```bash
git remote add origin https://github.com/<your-github-owner>/fractal-indexer-oneclick.git
git push -u origin main
```

Do not push runtime files or secrets.
