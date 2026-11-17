# Traffic Pro (personal iOS app)

Personal project. The FINDEP rules in the global CLAUDE.md (Azure DevOps, Work Items,
`#ID:` commit format, ADO PRs) do NOT apply here.

## Workflow
- GitHub repo `juanroman/traffic-pro` (remote not added yet while setup is local). Never push to
  `main`: one `feature/...` branch and one GitHub PR per slice, plain commit messages, merge with
  `gh pr merge --merge`.
- Git identity is repo-local: Juan Roman Escamilla <68346610+juanroman@users.noreply.github.com>.
  Check `git config user.email` before committing.
- Run `ios/check.sh` and commit/push only when it passes. Chain with `&&`, never `;`.
- Plan small, ask before big changes. Reply in the language the owner writes in (English or Spanish).
- Don't create worktrees/clones/copies outside this folder, and never copy `Secrets.plist`.
- Uploading to TestFlight needs the owner's explicit OK each time.

## Secrets
Google Routes key in git-ignored `ios/TrafficPro/TrafficPro/Secrets.plist` (template `ios/Secrets.example.plist`).
`ios/check.sh` fails if it is tracked. Never print or commit the key.

## Tooling
Xcode (iOS 27.2 SDK), Swift 6 strict concurrency, warnings as errors, swift-format + SwiftLint strict,
Swift Testing. `brew install swiftlint`. Gate: `ios/check.sh`.

## Read before changing things
`docs/decisions.md` (product decisions, Google terms, localization, pitfalls).
