# Traffic Pro (personal iOS app)

Personal project. The FINDEP rules in the global CLAUDE.md (Azure DevOps, Work Items,
`#ID:` commit format, ADO PRs) do NOT apply here.

## Workflow
- GitHub repo `juanroman/traffic-pro`. Never push to
  `main`: one `feature/...` branch and one GitHub PR per slice, plain commit messages, merge with
  `gh pr merge --merge`.
- Git identity is repo-local: Juan Roman Escamilla <68346610+juanroman@users.noreply.github.com>.
  Check `git config user.email` before committing.
- Run `ios/check.sh` and commit/push only when it passes. Chain with `&&`, never `;`.
- Plan small, ask before big changes. Reply in the language the owner writes in (English or Spanish).
- Don't create worktrees/clones/copies outside this folder, and never copy `Secrets.plist`.
- Uploading to TestFlight needs the owner's explicit OK each time.

## Releases
Every TestFlight upload is recorded in `CHANGELOG.md` and by a git tag.
- `ios/upload-testflight.sh` refuses unless you are on a clean `main` equal to `origin/main`. After
  a successful upload it creates the local tag `testflight/<version>-<build>` and prints the
  CHANGELOG heading to add. It never pushes.
- Afterwards: push the tag (`git push origin <tag>`), then a small PR that moves the Unreleased
  notes under the new `## <version> (<build>) - <date>` heading, written for the owner, not copied
  from commit messages.
- Add a bullet under Unreleased in each PR that changes what the app does or how it is built.
- Bump `MARKETING_VERSION` (the same value in every target) only for a change the owner calls a
  release; the build number is the timestamp the script makes.

## Secrets
Google Routes key in git-ignored `ios/TrafficPro/TrafficPro/Secrets.plist` (template `ios/Secrets.example.plist`).
`ios/check.sh` fails if it is tracked. Never print or commit the key.

## Tooling
Xcode (iOS 27.2 SDK), Swift 6 strict concurrency, warnings as errors, swift-format + SwiftLint strict,
Swift Testing. `brew install swiftlint`. Gate: `ios/check.sh`.

## Read before changing things
`docs/decisions.md` (product decisions, Google terms, localization, pitfalls).
