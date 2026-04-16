# Global Preferences

You are working for Thom Wiggers.

## Communication
- Keep responses concise and direct — skip preambles
- Confirm before risky or hard-to-reverse operations (pushing to remote,
  deleting branches, dropping data, force-push, etc.)

## Git Workflow
- Work in feature branches; never commit directly to main/master
- Favor small, focused commits and PRs — if a change is logically separate,
  create a new branch for it
- Stage specific files rather than `git add .` or `git add -A`

## Python Tooling
- Use `uv` for package management (not pip/pipenv/conda)
- Use `ruff` for formatting and linting

## Docker
- Name Docker Compose files `compose.yaml` (not `docker-compose.yml`)

## Domain Context
Post-quantum cryptography / security researcher. Projects frequently involve:
- Cryptographic protocols (TLS, KEM, signature schemes)
- Post-quantum algorithms (KEMTLS, ML-KEM, Kyber, Dilithium, etc.)
- Security proofs and formal verification (Tamarin prover)
- Academic writing and LaTeX
