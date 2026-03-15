---
name: github-repo-maintenance
description: Reusable skill for inspecting and auto-reconciling GitHub repository metadata, About content, and community surface with gh CLI using current-state-first and README-grounded derivation.
---

# GitHub Repo Maintenance

## Overview

Use this skill to inspect and auto-reconcile the GitHub-facing surface of a repository with `gh` CLI as the primary interface. The intended user experience is simple: invoke the skill and it should make the repository metadata and related community surface as correct and complete as possible from information that already exists in GitHub state, `README.md`, and a small set of supporting repo files.

The skill should behave like a safe repo-maintenance autopilot:
- inspect current GitHub state first
- read `README.md` and supporting repo files
- derive the best low-churn target state
- automatically fix what is clearly missing or stale and safely derivable
- leave already-good metadata alone
- report what could not be fixed because a prerequisite, asset, policy decision, or clear source of truth is missing

This may include lightweight README presentation polish when it is clearly derivable and appropriate, such as:
- a compact badge strip near the top
- a small footer attribution near the end
- restrained unicode or visual markers that improve scanning without over-styling the document

If a user says labels or tags in the About-section context, interpret that as repository topics unless they clearly mean issue labels.

## When To Use

- The user explicitly mentions this skill.
- The user asks to inspect or update GitHub repository metadata with `gh`.
- The user wants the repo’s GitHub-facing surface brought into good shape automatically.
- The user asks for About metadata, topics, homepage, community profile, or repository hygiene review.
- The user wants GitHub-facing metadata checked against the README and actual repo content.
- The user wants README presentation polished in a generic, repeatable way.

## When Not To Use

- Do not use this skill for normal source-code implementation work unrelated to GitHub repo maintenance.
- Do not use this skill for git-branch management, rebases, merges, or commits.
- Do not use this skill for package publishing or release execution unless the request is specifically about GitHub repository metadata or release discoverability.
- Do not use this skill to bypass `gh` by default; a non-`gh` fallback should be treated as exceptional and user-approved.

## Default Operating Mode

Unless the user explicitly asks for report-only behavior, invoking this skill means:

1. inspect
2. derive
3. reconcile
4. verify
5. report

Default interpretation:
- safe, clearly derivable fixes should be applied automatically
- missing items should be created automatically when a professional default can be derived from existing repo information
- reruns should be close to no-op unless something is still missing or the repo meaningfully changed

If the user explicitly says inspect, review, or report only, do not apply changes.

## Execution Boundary

- Prefer minimal changes. If current content already fits the repo identity and user-facing needs, make no change.
- Avoid churn. Do not rewrite working metadata just to mirror README wording more literally.
- Automatically fix clearly missing or stale GitHub-facing metadata when the correct value can be derived with low ambiguity.
- Automatically fix clearly missing or stale README presentation elements when the correct form can be derived with low ambiguity.
- Do not guess when a prerequisite, policy choice, or canonical source is missing. Report the blocker instead.
- Never print, log, or commit API tokens or secret values.

## Tooling Priority

Use tools in this order:

1. `gh` CLI
2. `gh api` for GitHub API calls that are not covered by a higher-level `gh` command
3. local repository files for grounding and decision-making

Do not switch to manual browser editing unless the user explicitly asks for that path.

## Prerequisite And Auth Workflow

Run these checks before any repository inspection or update:

1. Check whether `gh` is available, for example with `gh --version`.
2. If `gh` is not available:
   - stop the workflow
   - tell the user `gh` is missing
   - ask the user to install or enable `gh`, or explicitly approve a non-`gh` fallback
   - do not pretend a token alone solves missing `gh`
3. Resolve the target repository:
   - prefer the current git remote when working inside a repo
   - otherwise use the user-provided `owner/repo`
4. Test access with a harmless read command such as `gh repo view OWNER/REPO`.
5. If access fails because authentication is missing or insufficient:
   - ask the user for a GitHub API token
   - if the user points to a file that may contain the token, read only enough of that file to retrieve the token
   - if the user names a secret key inside a file, extract only that value
   - set `GH_TOKEN` only for the current command scope
   - never echo the token value back to the user
   - never write the token to disk or into repo files
6. After a token is supplied or discovered, retry the repo-access check before continuing.
7. If the token still does not grant repo access, report that clearly and stop rather than guessing.

## Source Hierarchy And Decision Model

Use this comparison model in order:

1. current GitHub state
2. `README.md`
3. a small set of supporting repo files
4. user-facing surface needs that may intentionally diverge from README phrasing

Interpretation rules:
- Current GitHub metadata is the operational baseline, not automatically wrong.
- `README.md` is the primary semantic source for what the project is and how it should be represented.
- Supporting files can justify or refine GitHub metadata, for example:
  - project manifests and lockfiles
  - workflow files
  - `SECURITY.md`
  - release configuration
  - install or runtime entrypoints
- Some GitHub-facing metadata may intentionally differ from README wording because it serves discovery, onboarding, or public user navigation.
- Treat concise, user-surface-optimized metadata as valid when it still accurately represents the repo.

Examples of acceptable deviation from README:
- a homepage that points to package documentation or a package listing instead of the repository root
- a shorter About description than the README opening paragraph
- topics that emphasize discoverability and search rather than repeating every README term
- a README badge set that surfaces the most useful public signals instead of mirroring every possible status source

### Supporting File Discovery

When deriving metadata, prefer the smallest useful set of stack signals for the current repo. Examples include:

- `package.json`, `pnpm-workspace.yaml`, `yarn.lock`
- `pyproject.toml`, `requirements.txt`
- `Cargo.toml`
- `go.mod`
- `*.csproj`, `*.fsproj`, `Directory.Build.props`
- `pom.xml`, `build.gradle`, `build.gradle.kts`
- `composer.json`
- container, deployment, or workflow files when they expose the runtime or user surface

Do not assume one ecosystem. Detect the current repo first, then derive metadata from the files that actually exist.

## Auto-Reconcile Standard

### Core Workflow

1. Confirm `gh` availability.
2. Confirm repo access and authentication.
3. Inspect current GitHub state before reading local files. Prefer commands such as:
   - `gh repo view OWNER/REPO --json ...`
   - `gh api repos/OWNER/REPO`
   - `gh api repos/OWNER/REPO/community/profile`
   - GraphQL checks when needed for fields such as custom social preview or discussions state
   - `gh api repos/OWNER/REPO/pages` when Pages status matters
4. Read `README.md`.
5. Read only the smallest helpful set of supporting repo files.
6. Build a compact model of:
   - repo identity
   - current GitHub surface
   - justified public-surface deviations
7. Classify findings into:
   - `auto-fix now`
   - `leave as is`
   - `blocked by prerequisite`
   - `needs explicit user direction`
8. Apply all `auto-fix now` items.
9. Re-inspect the affected GitHub surface.
10. Report what changed, what stayed intentionally unchanged, and what remains blocked.

### Auto-Fix Eligibility

Automatically fix an item when all of these are true:

- the item is missing, clearly stale, or materially weaker than what the repo already supports
- the correct replacement can be derived from existing GitHub state, `README.md`, or supporting repo files
- the update is low-ambiguity and low-risk
- the change improves the public repo surface without introducing policy or ownership guesses

### Blocked Or Manual Items

Do not auto-fix when a required input is missing or the decision is fundamentally policy-based. Report these clearly instead.

Common blockers include:
- no `gh` binary
- no repo access or no usable token
- no clear canonical homepage target
- no suitable image asset for a social preview image
- no clear owner or team mapping for `CODEOWNERS`
- no funding target for `FUNDING.yml`
- no clear policy choice for enabling Discussions or Pages
- no clear basis for choosing a code of conduct variant

## Idempotency And Change Thresholds

The skill should be safe to re-run repeatedly.

### First Run

- create or update clearly missing or stale items that are safely derivable
- prefer professional defaults over leaving obvious holes

### Later Runs

- do nothing when the current state remains good enough
- update existing metadata only when the repo meaningfully changed or the current value is clearly weaker than the newly derivable value

### Minor Changes

Do not update for minor changes such as:
- wording preferences
- equivalent phrasing
- topic ordering differences
- already-acceptable short descriptions
- weak stylistic improvements with no practical user benefit

### Medium Changes

Update when medium repo changes make the public metadata meaningfully outdated, for example:
- the README summary changed meaningfully
- the install or onboarding entrypoint changed
- the canonical package or docs target changed
- a new major user-facing surface appeared, such as docs, package publishing, a service endpoint, or a CLI entrypoint

### Major Changes

Update when the repo’s identity clearly changed, for example:
- renamed or substantially repositioned project
- changed platform or language focus
- changed primary product surface
- materially different contribution or user-entry flow

## Inspection And Managed Surface

Inspect these areas as applicable and auto-fix only where derivation is strong enough.

### About Metadata

- description
- homepage or website URL
- repository topics
- custom social preview image status

### README Presentation

- title and top-of-file layout
- badge strip presence, relevance, and single-line formatting
- tasteful section markers or lightweight unicode styling
- footer presence and tone

### Community Profile And Repo Files

- `README.md`
- license
- `SECURITY.md`
- `CODE_OF_CONDUCT`
- `CONTRIBUTING`
- issue templates
- pull request template
- documentation or homepage linkage
- `CODEOWNERS`
- `FUNDING.yml`

### Repository Features And User Surface

- Discussions
- Pages
- releases
- wiki when relevant
- community profile health

## Derivation Rules

### Safe Derivation Candidates

These are usually safe to auto-create or auto-update when missing or stale:

- About description from the README summary and supporting manifests
- homepage from a clear package page, docs page, or canonical project URI
- repository topics from repeated README concepts and obvious repo surfaces
- a README badge strip when badge-worthy signals are clearly available
- a lightweight README footer when repository owner attribution is clearly derivable
- issue templates when issues are enabled and the repo purpose is clear
- a pull request template when pull requests are enabled
- a lightweight `CONTRIBUTING` guide when contribution expectations can be derived from the repo’s current contribution surface, support links, and security handling

### Conditional Derivation Candidates

These may be fixable automatically only when strong source information exists:

- documentation link or homepage linkage
- `CODEOWNERS`
- release discoverability text or related metadata

### Usually Report-Only By Default

These usually require an asset, policy choice, or explicit maintainer direction:

- custom social preview image
- `FUNDING.yml`
- enabling Discussions
- enabling Pages
- choosing a code of conduct when none is implied by existing policy

## About Metadata Guidance

### Description

- Keep it short, accurate, and aligned with the repo identity.
- A shorter user-facing summary than the README opener is acceptable.
- Only change it when the current description is missing, stale, or materially weaker than what the repo now supports.

### Homepage

- Set a homepage only when there is a clear canonical target, such as project docs, a package page, or another stable entry point.
- Do not invent a homepage just to fill the field.
- A package page or docs page can be a better user-facing homepage than the repo root.

### Topics

- Use lowercase hyphenated topics.
- Keep the set compact and professional.
- Base topics on repeated README concepts and actual repo surfaces.
- Avoid redundant topics that merely restate the owner or repo name.
- In About-section context, tags or labels mean repository topics.
- Derive topics from the current repository, not from prior runs or prior repositories.

Good topic sources include:

- primary language or runtime
- framework or platform
- delivery form such as `cli`, `library`, `api`, `plugin`, `sdk`, or `module`
- deployment or packaging surface
- major domain concepts repeated in the README
- operating-system focus when it is explicit and important

Choose only the concepts the repo actually supports. A Node.js repo, Python repo, .NET repo, or PowerShell repo should each produce a different topic set from the same workflow.

### Custom Social Preview

- Inspect and report the status.
- Auto-configure only when the repo already contains a clearly suitable public image asset and the request allows it.

## README Presentation Guidance

### General Presentation Rules

- Preserve an existing coherent README style instead of restyling it gratuitously.
- Keep presentation changes small and functional.
- Prefer one polished visual language per README rather than mixing unrelated styles.
- Only add presentation elements when they improve scannability or trust for the reader.
- If the README is already clear and polished, leave it alone.

### Badge Strip

- If the README has a top title and the repo exposes clear badge-worthy signals, keep or create a compact badge strip directly below the main title.
- Prefer a single badge line when practical. If too many badges would wrap or clutter, reduce the set instead of stacking many lines.
- Derive badges only from real, stable surfaces such as:
  - GitHub Actions workflow status
  - license
  - GitHub release version
  - package registry version such as npm, PyPI, NuGet, or PowerShell Gallery
  - package download count only when a real package distribution exists and the badge source is stable
- Prefer authoritative or standard badge sources and stable URLs.
- Avoid vanity badges, technology keyword badges, or decorative badges that do not help a reader evaluate the project quickly.
- If a badge strip exists but is fragmented, inconsistent, or spread across multiple lines near the top, normalize it only when the result is clearly cleaner.

### Footer

- If the README lacks a footer and a small closing footer would fit the document tone, add a lightweight generic footer near the end.
- Derive the owner or maintainer attribution from the repository owner, explicit author metadata, or other clear repo signals.
- Prefer simple wording such as `Made with care by <owner>` or another similarly neutral phrase.
- Keep the footer compact and unobtrusive.
- Skip the footer when the README tone is intentionally formal, minimal, or when owner attribution is unclear.

### Unicode And Visual Markers

- Unicode symbols may be used sparingly to improve scanability in section headings, callouts, or short emphasis lines.
- Prefer consistency over novelty.
- If the README already uses unicode markers coherently, preserve that style.
- If the README is plain, add unicode only when it materially improves readability and still fits the repo tone.
- Do not flood the README with icons, emoji-like markers, or decorative noise.

### Applicability Rules

- Badge strips are applicable only when the repo has real public signals worth surfacing.
- A footer is applicable only when it fits the README tone and the owner attribution is clearly derivable.
- Unicode styling is applicable only when it improves readability without making the document feel noisy or off-brand.
- If a presentation element is not clearly applicable, do not add it.

## Community And Feature Guidance

### Issue Templates And Pull Request Template

- If issues are enabled and templates are missing, create professional, minimal templates when the repo purpose and workflow are clear enough.
- If pull requests are enabled and no template exists, create a concise PR template focused on summary, validation, and scope.
- Generated templates should use repo terminology from the README and stay lightweight.

### CONTRIBUTING

- If `CONTRIBUTING` is missing and the repo clearly accepts issues or pull requests, create a compact guide when it can be derived from the existing repo surface.
- Reuse support and security guidance already present in the repo instead of inventing a new policy.

### Other Community Files

- Check `CODE_OF_CONDUCT`, `CODEOWNERS`, and `FUNDING.yml`.
- Auto-create only when a clear source of truth exists.
- Otherwise report them as blocked or optional rather than guessing.

### Discussions And Pages

- Check whether they are enabled or configured.
- Treat them as user-surface features that may intentionally remain disabled.
- Report missing or disabled state separately from actual misconfiguration.
- Only enable or configure them automatically when the repo already signals a clear need and there is little policy ambiguity; otherwise report.

## Guardrails

- Do not expose tokens, secret names, or secret values in normal output.
- Do not persist temporary auth unless the user explicitly asks to configure `gh auth login`.
- Do not skip `gh` inspection of the current state before reading the README.
- Do not skip reading `README.md` before recommending substantive metadata changes.
- Do not treat every deviation from the README as a problem; account for user-surface needs.
- Do not create optional metadata just to maximize a checklist score.
- Do not over-style the README or force one repo's visual conventions onto another repo.
- Do not confuse repository topics with issue labels.
- If the user says labels or tags in the About-section context, interpret that as repository topics and proceed accordingly.
- Do not carry topic candidates, wording, or ecosystem assumptions from one repository into another.

## Output Contract

When using this skill, structure the response in this order:

1. Objective confirmation
2. Constraints and assumptions
3. Reconcile plan
4. Applied GitHub or repo-surface actions, no-op decisions, and blocked items
5. Validation notes and remaining risks

## Typical Invocation Phrases

- `[$github-repo-maintenance] reconcile this repo's GitHub surface`
- `use the GitHub repo maintenance skill and bring the repo metadata into shape`
- `[$github-repo-maintenance] check whether gh can access this repo, then fix what is safely derivable`
- `[$github-repo-maintenance] inspect current GitHub metadata first, then reconcile it with the README and repo content`
- `[$github-repo-maintenance] the token may be in this file, use it only if gh auth is missing`
