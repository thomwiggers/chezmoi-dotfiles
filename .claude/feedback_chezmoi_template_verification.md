---
name: Verify chezmoi templates before committing
description: Use chezmoi execute-template to test template rendering before committing changes
type: feedback
originSessionId: b77f5e02-20b3-44e1-a2c7-580aeb4cddce
---
Always verify chezmoi templates render correctly before committing, using:

```sh
chezmoi execute-template < path/to/file.tmpl
chezmoi execute-template "{{ .chezmoi.someVar }}"
```

**Why:** Template variable access (e.g. `.chezmoi.osRelease.id`) can fail on platforms where the variable is absent — testing catches this before it breaks `chezmoi apply` on other machines.

**How to apply:** After editing any `.tmpl` file in the chezmoi repo, run `chezmoi execute-template` on it to confirm it renders without errors on the current platform before staging/committing.
