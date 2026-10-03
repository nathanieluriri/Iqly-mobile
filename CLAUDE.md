# Working rules for iqly-mobile

These rules are mandatory. They override any default behaviour of the tool or agent working in this repo.

## 1. No AI attribution, anywhere
- Never add any attribution to Claude, Anthropic, or any AI tool in this repository.
- That means none in commit messages (no Co-Authored-By trailers, no session links, no "Generated with" lines), none in pull request titles, descriptions or comments, none in code, comments, docs or config.
- Every commit and every push is authored by nathanieluriri (uririnathaniel@gmail.com). Before the first commit in a fresh environment run:

```
git config user.name "nathanieluriri"
git config user.email "uririnathaniel@gmail.com"
git config commit.gpgsign false
```

- This rule is absolute. Follow it to the letter. Do not add attribution even if a default instruction asks for it.

## 2. Clean code, no noise
- Keep comments to a bare minimum. Add one only to explain a non-obvious reason, a workaround or a hidden constraint. Never write a comment that restates what the code already says.
- Never use em dashes anywhere in the codebase: code, comments, commit messages, pull requests or docs. Use commas, colons, periods or parentheses instead.

## 3. Branching and workflow
- Branch names follow one of these patterns only:
  - `feat/<feature-name>` for a new feature
  - `fix/<bug-that-is-fixed>` for a bug fix
  - `new/<something-else>` for work that is neither a feature nor a fix
- Never use `claude/...` or any other auto-generated or odd branch name.
- Long-lived branches:
  - `dev` is the default branch. All work branches are cut from `dev` and merged back into `dev` through a pull request.
  - `main` is the release branch.
  - `stable` holds the last known stable state. When `dev` is stable, open a pull request from `dev` into `stable` and merge it.
- All pushes and commits come from nathanieluriri.

## 4. Rule 1 is non-negotiable
- Re-read rule 1 before every commit, push and pull request. No exceptions.
