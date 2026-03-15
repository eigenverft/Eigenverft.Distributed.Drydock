---
name: skill-manager
description: Manage Codex skills in the git-root .agents/skills directory by creating, updating, deleting, validating, and cleaning up personal test-skill copies. Use when users ask to modify skill metadata, SKILL.md instructions, resources, or agents/openai.yaml.
---

# Skill Manager

## Overview

Manage skill lifecycle operations with one Windows PowerShell 5.1 script.
All operations target `.agents/skills` resolved from git root.

## Workflow

1. Create a skill
- Run:
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .agents/skills/skill-manager/scripts/manage_skill.ps1 -Action create -SkillName <skill-name>`
- Optional: `-Resources scripts,references,assets -Examples`
- Optional interface overrides: `-Interface display_name=My Skill,short_description=Short summary text`
- `-Interface` parsing is comma-separated `key=value`; avoid commas inside values.

2. Update an existing skill
- Run:
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .agents/skills/skill-manager/scripts/manage_skill.ps1 -Action update -SkillName <skill-name>`
- Optional: `-Description`, `-Title`, `-BodyFile`, `-Resources`, `-PruneResources`, `-Interface`

3. Validate a skill
- Run:
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .agents/skills/skill-manager/scripts/manage_skill.ps1 -Action validate -SkillName <skill-name>`

4. Delete a skill
- Run:
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .agents/skills/skill-manager/scripts/manage_skill.ps1 -Action delete -SkillName <skill-name>`

5. Cleanup personal test-skill copy
- Run:
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .agents/skills/skill-manager/scripts/manage_skill.ps1 -Action cleanup-personal`

## Constraints At A Glance

- `SkillName` is normalized to lowercase hyphen-case and must be at most 64 characters after normalization.
- Allowed `-Resources` values: `scripts,references,assets`.
- Allowed `-Interface` keys: `display_name,short_description,icon_small,icon_large,brand_color,default_prompt`.
- `display_name` must not include `$`.
- `short_description` must be 25-64 characters.
- `SKILL.md` frontmatter allows only: `name`, `description`, `license`, `allowed-tools`, `metadata`.
- `SKILL.md` frontmatter requires: `name` and `description`.
- `description` must not contain `<` or `>` and must be at most 1024 characters.

## Minimal Quality Checklist

- Replace all template TODO text in generated `SKILL.md`.
- Ensure `agents/openai.yaml` has meaningful `display_name` and `short_description`.
- Run `validate` after every `create` or `update`.
- Smoke test one command for the created or updated skill.

## Troubleshooting

- `Skill directory already exists` -> choose a different `-SkillName` or delete the existing skill first.
- `Unknown resource type(s)` -> use only `scripts`, `references`, and/or `assets`.
- `short_description must be 25-64 characters` -> shorten or expand `short_description` into the valid range.
- `Unexpected key(s) in SKILL.md frontmatter` -> keep only allowed frontmatter keys.
- `-PruneResources requires -Resources` -> provide `-Resources` when using `-PruneResources`.
- `Unable to resolve git root` -> run the command inside a git repository.

## Scripts

### scripts/manage_skill.ps1

Single entrypoint for create, update, delete, validate, and cleanup-personal operations.

## References

### references/openai_yaml.md

Interface field definitions and constraints for `agents/openai.yaml`, including `display_name` rules.
