# Security Policy

## Reporting a vulnerability

Please do not open a public issue for a security vulnerability.

Report vulnerabilities through GitHub Security Advisories for the repository, or contact the maintainer through the repository profile if advisories are not available.

Include:

- affected version or commit
- reproduction steps
- expected impact
- any suggested fix or mitigation

## Scope

`stringlocale` calls OpenRouter only when compiling locale JSON or when rendering `translatable` / `userAdapted` params at runtime. Avoid passing secrets, tokens, private user data, or regulated data into LLM-backed params.

Use `literal` or `user` params for values that must not be sent to an external API.
