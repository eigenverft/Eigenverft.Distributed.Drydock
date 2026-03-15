# Contributing

Thanks for helping improve Eigenverft.Distributed.Drydock.

## Before you open a pull request

- Keep changes focused and explain the user-facing reason for them.
- Update the README or related docs when behavior, commands, or outputs change.
- Call out packaging, publish, or workflow impact in the pull request description.

## Validate locally

Build the main solution:

```powershell
dotnet build .\source\Eigenverft.Distributed.Drydock.sln
```

If your change affects the sample WinForms project items, also build:

```powershell
dotnet build .\source\MyForms.sln
```

If you change CI or deployment automation and already have the required local configuration, run:

```powershell
pwsh .\.github\workflows\cicd.ps1
```

## Issues and pull requests

- Use GitHub issues for bugs, regressions, and feature proposals.
- Link the issue from your pull request when there is one.
- Call out breaking changes, new dependencies, and workflow changes clearly.
