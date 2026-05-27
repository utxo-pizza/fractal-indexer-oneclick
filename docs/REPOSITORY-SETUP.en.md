# Repository Setup

This published repository uses:

```bash
https://github.com/EY-hungry/fractal-indexer-oneclick
```

Before publishing a fork, replace the owner in docs:

```bash
perl -pi -e 's/EY-hungry/<your-github-owner>/g' README.md README.zh-CN.md docs/*.md
```

Then create the remote repository and push:

```bash
git remote add origin https://github.com/EY-hungry/fractal-indexer-oneclick.git
git push -u origin main
```

Do not push runtime files or secrets.
