# Eigenverft.Distributed.Drydock

[![CI](https://github.com/eigenverft/Eigenverft.Distributed.Drydock/workflows/cicd.yml/badge.svg)](https://github.com/eigenverft/Eigenverft.Distributed.Drydock/actions/workflows/cicd.yml) [![License](https://img.shields.io/github/license/eigenverft/Eigenverft.Distributed.Drydock)](LICENSE)

Command-line .NET tool for inspecting `.sln` and `.csproj` files and extracting MSBuild properties for automation, build orchestration, and CI/CD workflows.

The packaged tool command name is `drydock`.

## ▸ Capabilities

- Read solution files and enumerate project paths.
- Extract project properties from SDK-style and non-SDK-style `.csproj` files.
- Surface MSBuild values for automation scenarios.
- Support repository workflows that build, pack, publish, and analyze .NET projects.

## ▸ Local Build

Build the main solution:

```powershell
dotnet build .\source\Eigenverft.Distributed.Drydock.sln
```

If you change the sample WinForms project items, also validate:

```powershell
dotnet build .\source\MyForms.sln
```

## ▸ Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for pull request and validation guidance.

---

Made with care by [Eigenverft](https://github.com/eigenverft).
