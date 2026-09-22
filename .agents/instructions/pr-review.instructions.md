# Home-ops PR review conventions

The repository's `AGENTS.md` is authoritative. These rules supplement it for code and infrastructure reviews.

## Review priorities

- Findings come first, ordered by severity.
- Prioritise behavioural regressions, security risks, data-loss risks, broken reconciliation, and missing validation.
- Do not flag documented repository conventions as issues.
- Separate confirmed facts, likely causes, assumptions, and residual risks.
- Treat unavailable render or runtime evidence as unknown, not as a clean result.

## Documented conventions

- `metadata.namespace` may be omitted where the parent Kustomization injects it.
- OCI Helm artifacts are pinned by version tags; container images should use digests where practical.
- Kopiur is the required persistence component for new persistent applications.
- `flux-system` and `flux-system-private` are independent sources; inspect both when a change may affect either repository.
- A Flux Kustomization reporting Ready does not prove that a child HelmRelease, Deployment, or workload is healthy.

## Validation expectations

- Render the affected Flux Kustomization locally when the repository tools are available.
- Inspect the rendered resources for RBAC, routes, persistence, secret references, pruning, and immutable-field changes.
- Verify the relevant Helm chart and container image sources when versions change.
- For live fixes, check Flux status, HelmRelease status, workload rollout, recent logs, and externally visible behaviour.
- Do not approve a change solely because the YAML parses.
