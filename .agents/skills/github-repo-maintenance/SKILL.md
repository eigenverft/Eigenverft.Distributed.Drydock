---
name: github-repo-maintenance
description: Reusable skill for inspecting and auto-reconciling GitHub repository metadata, About content, and community surface with gh CLI using current-state-first and README-grounded derivation.
---

# GitHub Repo Maintenance

## Overview

Use this skill to inspect and auto-reconcile the GitHub-facing surface of a repository with `gh` CLI as the primary interface. The intended user experience is simple: invoke the skill and it should make the repository metadata and related community surface as correct and complete as possible from information that already exists in GitHub state, `README.md`, and a small set of supporting repo files.

The skill should behave like a safe repo-maintenance autopilot:
- inspect current GitHub state first
- distinguish the live default-branch GitHub surface from local branch-only or uncommitted changes
- read `README.md` and supporting repo files
- inspect deployment and publishing signals when present
- derive the best low-churn target state
- automatically fix what is clearly missing or stale and safely derivable
- leave already-good metadata alone
- report what could not be fixed because a prerequisite, asset, policy decision, or clear source of truth is missing

This should include lightweight README presentation polish when it is absent, clearly derivable, and appropriate, such as:
- a compact badge strip near the top
- a small footer attribution near the end
- restrained unicode or visual markers that improve scanning without over-styling the document
- a generic `SECURITY.md` that GitHub can recognize automatically when no better policy file exists

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
- absent but applicable standard README polish elements should be created automatically on the first reconcile instead of being left as suggestions
- generic repo-health files should be created automatically when a safe baseline template is acceptable and no stronger repo-specific source exists
- already-present surfaces should only be updated when the current version is materially weaker than the newly derived target or when medium/major repo change thresholds are met
- reruns should be close to no-op unless something is still missing or the repo meaningfully changed

If the user explicitly says inspect, review, or report only, do not apply changes.

## Fast No-Op Rules

Before doing deeper reconciliation work, prefer fast no-op decisions.

- If a surface is already present, coherent, and good enough, skip it.
- If the current state is accurate and the difference is only stylistic or marginal, skip it.
- If the repo already has a better repo-specific solution than the generic baseline, keep it.
- Do not classify a missing but clearly applicable standard README polish element as a no-op on the first reconcile.
- Only escalate from local inspection to external confirmation when a homepage, badge, or public distribution surface is still unresolved.
- Re-running the skill should mostly produce verification and no-op reporting once the repository is in good shape.

## Execution Boundary

- Prefer minimal changes. If current content already fits the repo identity and user-facing needs, make no change.
- Avoid churn. Do not rewrite working metadata just to mirror README wording more literally.
- If a standard GitHub-facing or README presentation element is missing and can be safely derived, create it rather than merely recommending it.
- Automatically fix clearly missing or stale GitHub-facing metadata when the correct value can be derived with low ambiguity.
- Automatically fix clearly missing or stale README presentation elements when the correct form can be derived with low ambiguity.
- Do not guess when a prerequisite, policy choice, or canonical source is missing. Report the blocker instead.
- Never print, log, or commit API tokens or secret values.

## Tooling Priority

Use tools in this order:

1. `gh` CLI
2. `gh api` for GitHub API calls that are not covered by a higher-level `gh` command
3. local repository files for grounding and decision-making
4. focused public package or documentation lookup when the repo appears to publish externally and confirmation is needed for badges, homepage targets, or public distribution surfaces

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
  - packaging, publishing, or release scripts
- Some GitHub-facing metadata may intentionally differ from README wording because it serves discovery, onboarding, or public user navigation.
- Treat concise, user-surface-optimized metadata as valid when it still accurately represents the repo.

Examples of acceptable deviation from README:
- a homepage that points to package documentation or a package listing instead of the repository root
- a shorter About description than the README opening paragraph
- topics that emphasize discoverability and search rather than repeating every README term
- a README badge set that surfaces the most useful public signals instead of mirroring every possible status source

### Branch Visibility And Surface Scope

When the repository is being inspected from a non-default branch or a dirty working tree, treat these as separate surfaces:

- the live GitHub-visible default-branch surface
- the local working tree or current branch surface

Use both when they matter, but do not conflate them.

Rules:

- GitHub community profile, rendered README, recognized community files, and security-policy recognition are default-branch GitHub surfaces first.
- If local files are stronger than what GitHub currently shows, classify that as `local-only pending merge`, not `already present on GitHub`.
- Do not describe README polish, `CONTRIBUTING`, issue templates, PR templates, or `SECURITY.md` as already fixed on GitHub when they only exist locally or on a feature branch.
- If a local branch already contains a richer draft of the README or community files than the default branch, use that draft as the local baseline for further edits instead of starting over.
- In verification and reporting, explicitly say which changes are visible on GitHub now and which remain local-only until commit and merge.

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
- publish scripts, release pipelines, package metadata, or release jobs when they expose external distribution targets

Do not assume one ecosystem. Detect the current repo first, then derive metadata from the files that actually exist.

### External Distribution Discovery

When the repo appears to publish packages, modules, containers, binaries, or hosted docs, confirm that public surface before deriving homepage targets or badges.

Useful signals include:

- package names and registries declared in manifests
- publish or release jobs in GitHub Actions or other pipeline definitions
- install instructions in `README.md`
- release artifacts and package references in release notes
- links to package listings, docs sites, or container registries already present in the repo

If the public distribution target is still unclear after local inspection, a focused public lookup is allowed to confirm whether a package, module, docs site, or artifact page actually exists.

## Auto-Reconcile Standard

### Phase Order

Run the reconciliation in this order:

1. prerequisite and auth checks
2. current GitHub-state snapshot
3. default-branch GitHub-visible README and community-surface inspection when branch visibility may differ
4. local repository-source inspection
5. fast no-op classification
6. deeper distribution or external-surface confirmation only when needed
7. minimal auto-fix pass
8. verification pass
9. report

Do not jump to deeper analysis or edits when an earlier phase already shows the surface is good enough.

### Core Workflow

1. Confirm `gh` availability.
2. Confirm repo access and authentication.
3. Inspect current GitHub state before reading local files. Prefer commands such as:
   - `gh repo view OWNER/REPO --json ...`
   - `gh api repos/OWNER/REPO`
   - `gh api repos/OWNER/REPO/community/profile`
   - `gh api repos/OWNER/REPO/private-vulnerability-reporting`
   - GraphQL checks when needed for fields such as custom social preview or discussions state
   - `gh api repos/OWNER/REPO/pages` when Pages status matters
4. If the current branch is not the default branch, or the working tree is dirty, inspect the default-branch versions of `README.md` and any community files that GitHub evaluates for the public repo surface.
   - Use `gh api repos/OWNER/REPO/contents/PATH?ref=<default-branch>` or `git show origin/<default-branch>:PATH` when practical.
   - Compare the GitHub-visible version with the local version before deciding whether the surface is already polished or complete.
5. Read `README.md`.
6. Read only the smallest helpful set of supporting repo files.
7. Mark already-good surfaces as `leave as is` as early as possible.
8. Classify GitHub-visible drift versus local-only pending changes before deciding whether more edits are needed.
9. Inspect packaging, publishing, and release signals only for surfaces that remain unresolved after local inspection.
10. Confirm externally visible package or docs targets only when needed for homepage or badge derivation.
11. Build a compact model of:
   - repo identity
   - current GitHub surface
   - current default-branch README/community visibility
   - local branch or working-tree-only improvements
   - justified public-surface deviations
   - public distribution surfaces and deploy chain signals
12. Classify findings into:
   - `auto-fix now`
   - `leave as is`
   - `local-only pending merge`
   - `blocked by prerequisite`
   - `needs explicit user direction`
13. Apply all `auto-fix now` items.
14. Re-inspect only the affected GitHub or repo surfaces.
15. Report what changed, what is already visible on GitHub, what remains local-only, what stayed intentionally unchanged, and what remains blocked.

### Auto-Fix Eligibility

Automatically fix an item when all of these are true:

- the item is missing, clearly stale, or materially weaker than what the repo already supports
- the correct replacement can be derived from existing GitHub state, `README.md`, or supporting repo files
- the update is low-ambiguity and low-risk
- the change improves the public repo surface without introducing policy or ownership guesses

For README presentation on the first reconcile, treat a missing but clearly applicable standard element as auto-fix eligible rather than optional.

### Leave-As-Is Eligibility

Prefer `leave as is` when any of these are true:

- the surface already exists and is accurate enough
- the current wording is different from the newly derived wording but not materially worse
- the current formatting is coherent even if it differs from the generic baseline
- a repo-specific solution is already better than the generic template
- the remaining gain would be mostly cosmetic or stylistic

Do not use `leave as is` when the only acceptable version exists locally but the live GitHub-visible default branch is still missing that surface.

### Blocked Or Manual Items

Do not auto-fix when a required input is missing or the decision is fundamentally policy-based. Report these clearly instead.

Common blockers include:
- no `gh` binary
- no repo access or no usable token
- no clear canonical homepage target
- no confirmed public package, module, registry, or docs surface for a proposed external badge
- no suitable image asset for a social preview image
- no clear owner or team mapping for `CODEOWNERS`
- no funding target for `FUNDING.yml`
- no clear policy choice for enabling Discussions or Pages
- no clear basis for choosing a code of conduct variant

Do not treat `SECURITY.md` as blocked by default. A generic security policy file is often safer to create than to omit, as long as it does not invent unsupported promises or contact paths.

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

### Step-Level Skip Behavior

- Skip About updates when description, homepage, and topics are already accurate enough.
- Do not skip GitHub-visible README or community work solely because a better version exists only in the current branch or working tree.
- Skip README badge work when the current badge strip is present, coherent, and already surfaces the most useful public signals.
- Skip footer work when a suitable footer already exists or the README tone is better without one. Do not skip solely because the footer is missing; add one on the first reconcile when it is clearly applicable.
- Skip unicode styling changes when the README already has a coherent visual style or when restrained markers would not materially improve scanning. Do not skip solely because the README is plain if restrained markers would clearly help.
- Skip `SECURITY.md` creation when a recognized security policy file already exists and is acceptable.
- Skip template or community-file generation when the current files already cover the need well enough.
- Skip external registry or docs lookup when local evidence already confirms the correct public surface.

## Derivation Rules

### Safe Derivation Candidates

These are usually safe to auto-create or auto-update when missing or stale:

- About description from the README summary and supporting manifests
- homepage from a clear package page, docs page, or canonical project URI
- repository topics from repeated README concepts and obvious repo surfaces
- a README badge strip when badge-worthy signals are clearly available
- registry, package, release, or docs badges when those public surfaces are confirmed
- a lightweight README footer when repository owner attribution is clearly derivable
- restrained unicode section markers when the README tone supports a polished but minimal visual style
- a generic `SECURITY.md` when no security policy file exists
- enabling GitHub private vulnerability reporting when it is available, disabled, and the repository permissions and policy signals make it a safe default
- issue templates when issues are enabled and the repo purpose is clear
- a pull request template when pull requests are enabled
- a lightweight `CONTRIBUTING` guide when contribution expectations can be derived from the repo’s current contribution surface, support links, and security handling

### Conditional Derivation Candidates

These may be fixable automatically only when strong source information exists:

- documentation link or homepage linkage
- `CODEOWNERS`
- release discoverability text or related metadata
- public package, module, or docs listings inferred from workflow or manifest evidence
- a maintainer-specific private vulnerability contact path beyond the generic baseline

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
- If the current description is already solid, skip it.

### Homepage

- Set a homepage only when there is a clear canonical target, such as project docs, a package page, or another stable entry point.
- Do not invent a homepage just to fill the field.
- A package page or docs page can be a better user-facing homepage than the repo root.
- If the repo publishes to a public registry and that listing is a better onboarding surface than the repo root, prefer the registry page once confirmed.
- If the current homepage is already a good canonical entry point, skip it.

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
- If the current topic set is already tight, relevant, and not missing anything important, skip it.

### Custom Social Preview

- Inspect and report the status.
- Auto-configure only when the repo already contains a clearly suitable public image asset and the request allows it.

## Security Policy Guidance

### Generic SECURITY.md Baseline

- If no `SECURITY.md` exists, create a lightweight generic security policy by default unless the user explicitly asked for report-only behavior.
- Prefer placing the file where GitHub recognizes it clearly, usually the repository root unless a repo convention points to `.github/` or `docs/`.
- Treat adding a recognized `SECURITY.md` as the practical way to turn on GitHub security-policy recognition for the repository surface.
- Keep the policy generic, accurate, and low-commitment.
- If a recognized `SECURITY.md` already exists and is broadly adequate, skip it.
- If GitHub private vulnerability reporting is available but disabled, enable it by default when repo access and policy signals make that a safe, low-ambiguity action.

### Content Rules

- Include a short supported-versions section only when a reasonable generic statement can be made.
- Prefer neutral wording such as supporting the latest release, default branch, or currently maintained versions when that is true enough from repo context.
- Include a reporting section that prefers GitHub private vulnerability reporting when it is enabled or clearly intended.
- Before falling back to generic wording, inspect repository owner and maintainer GitHub profile data with `gh` to discover a public maintainer email or other clearly published private security contact path.
- If a real maintainer-controlled public email is discoverable via `gh` and is not a GitHub noreply address, include it as the private reporting address in `SECURITY.md`.
- If no private reporting path is known after those checks, use generic wording that asks for private contact through the maintainer’s published security channel or another clearly private route instead of inventing an email address.
- Explicitly discourage public issue filing for vulnerabilities.
- Include a short expectations section about reasonable investigation and disclosure timing when helpful.

### Safety Rules

- Do not invent a private email address, SLA, or guarantee.
- Do not claim private vulnerability reporting is enabled unless GitHub state confirms it.
- Only use a maintainer email in `SECURITY.md` when it was actually discovered from GitHub state or another clear repo source and is suitable for private contact.
- If neither private reporting nor a private maintainer contact path can be derived, still prefer a minimal generic policy over no policy, but keep the reporting instructions carefully conditional.

### Recognition And Verification

- After creating or updating `SECURITY.md`, verify that the file sits in a GitHub-recognized location.
- After enabling private vulnerability reporting, re-check its state with `gh` and align `SECURITY.md` wording to prefer that path.
- When `gh` or GitHub metadata can confirm security-policy recognition, re-check and report the final state.

## README Presentation Guidance

### General Presentation Rules

- Preserve an existing coherent README style instead of restyling it gratuitously.
- Keep presentation changes small and functional.
- Prefer one polished visual language per README rather than mixing unrelated styles.
- Only add presentation elements when they improve scannability or trust for the reader.
- On the first reconcile, add missing standard presentation elements when they are clearly applicable instead of merely reporting that they could exist.
- When a README is sparse but the repo provides enough source material, prefer a cohesive polish pass across the whole document instead of isolated cosmetic tweaks.
- Do not stop at cosmetic markers alone when the README is still structurally thin and the repo supports a fuller reader journey.
- If the default-branch README is sparse but the local branch already contains a richer draft, continue that draft or report it as `local-only pending merge`; do not describe the live GitHub README as already polished.
- Prefer README polish that improves narrative flow from top to bottom, not just headings in place.
- If the README is already clear and polished and the remaining benefit would be marginal, leave it alone.
- When a presentation element is already present, update it only for medium or major repo changes, or when the current element is materially weaker than the newly derived target.

### Section Architecture

- When the repo content clearly supports it, prefer a fuller but still concise README structure over a thin summary-only document.
- A strong generic flow often looks like: summary, motivation or purpose, requirements, installation, quick start, capability or command reference, operational notes, license, and contact or support.
- For a first-run polish on a sparse README, aim for a materially better reader journey, not just surface decoration. In practice this usually means a summary plus at least a few meaningful sections such as capabilities, installation or build, usage or quick start, and contributing or support when the repo provides enough source material.
- Do not force every section into every repository. Derive only the sections that have strong support in the repo's README, manifests, workflows, scripts, or contribution surface.
- Prefer short explanatory lead-in sentences before dense bullet lists or code blocks so readers understand why the next block matters.
- Use subheadings to group alternate installation paths, usage paths, or feature clusters when that makes the document easier to scan.
- If the repo already has enough material for a richer structure, reorganize the README into a coherent reader journey instead of merely appending a footer or adding one or two markers.
- If issue tracking, pull requests, docs, discussions, package pages, or other support paths are clearly available, include a compact contact or support section near the end.
- Horizontal separators such as `---` may be used between major section groups when they improve rhythm and scanning without making the README feel busy.

### Badge Strip

- If the README has a top title and the repo exposes clear badge-worthy signals, keep or create a compact badge strip directly below the main title.
- Prefer a single badge line when practical. If too many badges would wrap or clutter, reduce the set instead of stacking many lines.
- A polished README may reasonably carry more than two badges when each badge conveys a distinct high-value signal such as version, downloads, runtime support, build status, or license.
- Derive badges only from real, stable surfaces such as:
  - GitHub Actions workflow status
  - license
  - GitHub release version
  - package registry version such as npm, PyPI, NuGet, or PowerShell Gallery
  - package download count only when a real package distribution exists and the badge source is stable
  - docs or hosted-site status only when a stable public docs surface clearly exists
- Prefer authoritative or standard badge sources and stable URLs.
- When a package or registry badge is used, choose the logo or icon that matches the confirmed platform or registry.
- Avoid vanity badges, technology keyword badges, or decorative badges that do not help a reader evaluate the project quickly.
- If a badge strip exists but is fragmented, inconsistent, or spread across multiple lines near the top, normalize it only when the result is clearly cleaner.
- If the badge strip is already present, coherent, and surfaces the right signals, skip badge changes entirely.

### Distribution-Aware Badge Derivation

- Inspect release workflows, publish scripts, manifests, and install instructions to infer likely public distribution surfaces.
- Confirm public package or docs availability before adding external badges that point outside GitHub.
- If multiple public surfaces exist, prefer the ones most useful for a first-time reader, usually:
  - build or verification status
  - current public version
  - license
  - one meaningful distribution or docs badge
- Do not add badges for unpublished or private package targets.
- Do not add speculative registry badges just because a workflow name suggests publishing.

### Footer

- If the README lacks a footer and a small closing footer would fit the document tone, add a lightweight generic footer near the end on the first reconcile.
- Derive the owner or maintainer attribution from the repository owner, explicit author metadata, or other clear repo signals.
- Prefer simple wording such as `Made with care by <owner>` or another similarly neutral phrase.
- Keep the footer compact and unobtrusive.
- Skip the footer when the README tone is intentionally formal, minimal, or when owner attribution is unclear.
- If the footer already exists, keep it unless a medium or major repo change, or a materially better derivation, justifies an update.
- If the README already has a centered or visually separated footer style, preserve that pattern and only normalize wording.
- A centered HTML footer block may be used when the README already supports a more presentation-forward style and the result stays restrained.
- If a suitable footer already exists, skip it.

### Unicode And Visual Markers

- Unicode symbols may be used sparingly to improve scanability in section headings, callouts, or short emphasis lines.
- Prefer consistency over novelty.
- If the README already uses unicode markers coherently, preserve that style.
- If the README is plain but the overall document would clearly benefit from a consistent set of section markers, add them in a restrained way on the first reconcile.
- Section-heading markers may be semantic emoji or simple symbols when they form a coherent system across the document and fit the repo tone.
- Short labeled callouts such as feature intros, tips, or support hints may use one leading marker when they improve scanning and do not become decorative noise.
- Do not flood the README with icons, emoji-like markers, or decorative noise.
- Favor stable, broadly readable markers for common sections such as features, installation, usage, license, support, or notes when they fit the README tone.
- If the current heading and marker style already reads cleanly, skip visual-marker changes unless a medium or major repo change makes the current structure materially weaker than the derived target.

### Applicability Rules

- Badge strips are applicable only when the repo has real public signals worth surfacing.
- A footer is applicable only when it fits the README tone and the owner attribution is clearly derivable.
- Unicode styling is applicable only when it improves readability without making the document feel noisy or off-brand.
- Richer README restructuring is applicable only when the repository already provides enough trustworthy source material to support the added sections.
- If a presentation element is not clearly applicable, do not add it.
- `SECURITY.md` is broadly applicable unless the repository already has a recognized security policy file or the user explicitly wants report-only inspection.

## Community And Feature Guidance

### Issue Templates And Pull Request Template

- If issues are enabled and templates are missing, create professional, minimal templates when the repo purpose and workflow are clear enough.
- If pull requests are enabled and no template exists, create a concise PR template focused on summary, validation, and scope.
- Generated templates should use repo terminology from the README and stay lightweight.
- If the current templates already guide contributors well enough, skip them.

### CONTRIBUTING

- If `CONTRIBUTING` is missing and the repo clearly accepts issues or pull requests, create a compact guide when it can be derived from the existing repo surface.
- Reuse support and security guidance already present in the repo instead of inventing a new policy.
- If a suitable contribution guide already exists, skip it.

### Other Community Files

- Check `CODE_OF_CONDUCT`, `CODEOWNERS`, `FUNDING.yml`, and `SECURITY.md`.
- Auto-create `SECURITY.md` from the generic baseline when it is missing.
- Auto-create the others only when a clear source of truth exists.
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
- Do not treat the local working tree as the same thing as the live GitHub-visible default branch when summarizing results.
- Do not skip reading `README.md` before recommending substantive metadata changes.
- Do not treat every deviation from the README as a problem; account for user-surface needs.
- Do not create optional metadata just to maximize a checklist score.
- Do not over-style the README or force one repo's visual conventions onto another repo.
- Do not add package or registry badges without confirming that the public target actually exists.
- Do not confuse repository topics with issue labels.
- If the user says labels or tags in the About-section context, interpret that as repository topics and proceed accordingly.
- Do not carry topic candidates, wording, or ecosystem assumptions from one repository into another.

## Output Contract

When using this skill, structure the response in this order:

1. Objective confirmation
2. Constraints and assumptions
3. Reconcile plan
4. Applied GitHub-visible actions, local-only repo-surface actions, no-op decisions, and blocked items
5. Validation notes, visibility caveats, and remaining risks

## Typical Invocation Phrases

- `[$github-repo-maintenance] reconcile this repo's GitHub surface`
- `use the GitHub repo maintenance skill and bring the repo metadata into shape`
- `[$github-repo-maintenance] check whether gh can access this repo, then fix what is safely derivable`
- `[$github-repo-maintenance] inspect current GitHub metadata first, then reconcile it with the README and repo content`
- `[$github-repo-maintenance] the token may be in this file, use it only if gh auth is missing`
