# Production security baseline

Phase 9 adds application and deployment controls, but this repository cannot activate a cloud WAF, issue real TLS certificates, create cloud IAM roles, or connect a specific secret manager by itself.

## Edge / TLS / WAF

- Terminate TLS 1.2+ at a managed load balancer, ingress, CDN/WAF, or the provided Nginx baseline.
- Redirect port 80 to 443 before traffic reaches the API.
- Configure the application with `SAVESTREAM_FORCE_HTTPS=true`.
- Configure `SAVESTREAM_TRUSTED_PROXY_CIDRS` to the actual ingress/proxy network only.
- Do not trust arbitrary `X-Forwarded-For` or `X-Forwarded-Proto` from the public internet.
- Put a managed WAF/rate-limit policy in front of login, billing and webhook endpoints. App-level rate limiting is defense in depth, not a DDoS service.

The supplied Nginx configuration is a baseline, not a managed WAF.

## Secrets / rotation

Sensitive settings support `SAVESTREAM_<NAME>_FILE` for mounted Docker/Kubernetes/CSI secrets. Do not bake secret values into images or Git.

JWT rotation:

1. generate a new current secret;
2. move the old current secret into `SAVESTREAM_JWT_PREVIOUS_SECRETS`;
3. deploy all API instances;
4. wait longer than the longest JWT/one-time-token TTL;
5. remove the retired previous secret.

New JWTs are always signed by the current secret. Decode accepts current + previous secrets during the rotation window.

For payment webhook/API keys, use the provider's overlap/rotation procedure and deploy the new secret atomically.

## IAM

Application pods do not need Kubernetes API access; the baseline ServiceAccount disables token automount.

Use workload identity/service accounts with least privilege for cloud resources. Separate identities for API, recording worker, scheduler and backup jobs when the platform supports it. Storage permissions should be limited to the SaveStream bucket/prefixes.

## Network policy

The Kubernetes baseline defaults to deny ingress/egress and opens only known service ports. Vanilla NetworkPolicy cannot restrict external payment/TikTok endpoints by FQDN; use a CNI/cloud egress policy or egress proxy to tighten the example broad HTTPS rule.

## Production CORS

Production settings reject wildcard, localhost and non-HTTPS origins. Only list the actual SaveStream web origins. Mobile clients do not require CORS origins.

## Security headers

The API emits HSTS when HTTPS is effective, CSP, frame denial, nosniff, referrer policy, permissions policy and no-store on sensitive routes. The edge should mirror these headers.
