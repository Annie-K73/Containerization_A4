# Optional auto-deploy extension

Automatic deployment is deliberately absent from the assessed core workflow.
The core stops after publishing and scanning an immutable candidate. A human
must review `release.env`, `sbom.cdx.json`, and `vulnerability-report.json`
before manual promotion with `scripts/deploy.sh`.

An advanced student may propose automatic promotion only as an extension. The
proposal must add, and demonstrate, all of these controls:

- protected GitHub Environment approval and least-privilege permissions;
- an exact digest passed between jobs without reconstructing a tag;
- protected SSH host verification and a constrained deployment account;
- serialized deployments, bounded readiness waiting, post-deploy smoke tests,
  and automatic recovery to an already-pulled previous digest;
- an auditable promotion record and a manual stop switch;
- no reduction in the common evidence, recovery, or defense requirements.

Do not copy an SSH deployment job blindly. The extension is evaluated through
its threat model, failure tests, and recovery evidence, not by the presence of
the word “automatic.”
