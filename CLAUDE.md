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

## Project: the iQLY mobile app (Flutter)

Targets: Android and iOS first, Windows kept responsive (no separate desktop design). Built from the expressive mobile design, section B of the Figma app file, using the Exp/* kit from the Figma design system. The sample dataset is wired first; the live API comes later behind the same repository interface.

- Figma design system (tokens and components): https://www.figma.com/design/eDc8PWheV2bcsZ4dRQni1M
- Figma app designs (page "Mobile app", section B): https://www.figma.com/design/uzZ7B2copJrWqiUhxjKVNH
- Where the Figma file and any brief disagree, Figma wins. Say so when you notice it.

### Layout
- `design/tokens.json`: the Figma variables, text styles and effects, pulled from the design system. Re-pull from Figma, never edit by hand.
- `tool/gen_tokens.dart`: generates `lib/theme/tokens.g.dart` (`IqColors`, `IqPrimitives`, `IqSpace`, `IqRadius`, `IqText`, `IqShadows`). Run `dart run tool/gen_tokens.dart` after updating the JSON; CI checks it is current.
- `lib/theme/`: theme built only from the generated tokens.
- `lib/ui/`: the Exp/* component library, one widget per Figma component, same names, variants and props.
- `lib/features/<row>/`: screens, grouped by the Figma row (splash, entry, onboarding, discover, submissions, wallet, profile, notifications, polls, submit, activations, help, outcomes, withdrawals, settings).
- `lib/data/`: models, `DemoData` (mirrors `src/data/demo.ts` in the web repo) and the `IqlyRepository` interface with its demo implementation.
- `lib/core/`: session state, feature flags (`Flags`), money formatting (`naira`, `rewardPool`), responsive helpers (`CenteredContent`).
- `assets/fonts/`: Bricolage Grotesque, Plus Jakarta Sans and Geist Mono as static instances of the Google Fonts variable files, with their OFL licences. `assets/brand/`: the official logo files, never redrawn or recoloured. `assets/icons/`, `assets/illustrations/`: SVG exports from Figma, 1x, never re-exported at a different stroke. `assets/splash/`: the splash layers derived from the official logomark (the grey boot state is authorised for the splash only) and the native splash PNGs.

### Rules of the build
- No literal colours, font sizes, radii or shadows in widgets. Everything comes from `tokens.g.dart`. A test fails on any `Color(0x...)` outside the token layer.
- One `Field` component for all text entry (Figma Exp/Field, size prop). The orange sticker shadow belongs to primary buttons and the next button only.
- Copy comes from the shipped product or the Figma frames, never paraphrased. "The business", never "brand". Statuses and withdrawal words exactly as the product shows them.
- Every number on a screen foots to `DemoData` or to the API. Reward pools show no decimals, wallet amounts show two.
- Proposals that the API may lag behind (polls, activations, saved briefs, close reminders, business note, notification preferences, delete account) sit behind `Flags`.
- Compare each screen against its Figma frame at 390 x 844 before calling it done.
- Local checks before every push: `dart run tool/gen_tokens.dart --check`, `dart format lib test tool`, `flutter analyze`, `flutter test`.
