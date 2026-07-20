# Security Policy

## Supported versions

| Version | Supported |
| ------- | --------- |
| `main` (latest) | ✅ |
| Older commits / forks | Community best-effort |

This is an **offline iOS game** with no backend. Still, we take supply-chain and repo security seriously.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security problems.

1. Use GitHub’s **[Private vulnerability reporting](https://github.com/DarkFleetGameStudios/PocketLittleFarm/security/advisories/new)** for this repository, or  
2. Email the maintainers via the org contact on [DarkFleetGameStudios](https://github.com/DarkFleetGameStudios) if private reporting is unavailable.

Include:

- Description of the issue  
- Steps to reproduce  
- Impact (e.g. local data exposure, build pipeline abuse)  
- Suggested fix if you have one  

We aim to acknowledge reports within **7 days** and ship a fix or mitigation as soon as practical.

## Scope

**In scope**

- Secrets or credentials accidentally committed  
- Unsafe handling of local save data (path traversal, unexpected code execution)  
- CI / GitHub Actions supply-chain issues in this repo  
- Dependency or workflow misconfiguration that could compromise contributors or users  

**Out of scope**

- Jailbreak / sideload policy on personal devices  
- Social engineering of individual developers  
- Issues that require physical access to an unlocked device with a debug build  

## Hardening already in place

- Public MIT source with no server-side auth surface  
- CI builds and tests on PRs  
- CodeQL (Swift + Actions)  
- OpenSSF Scorecard  
- Dependabot for GitHub Actions  
- Secret pattern hygiene check in CI  

Thank you for helping keep contributors and players safe.
