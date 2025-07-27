# Kubeflow OIDC

## Upstream Kubeflow Manifests (`third_party/kubeflow/manifests/`)

- Authentication handled at Istio gateway level
- Uses oauth2-proxy as OIDC client
- Uses dex as identity provider proxy
- Sets `kubeflow-userid` and `kubeflow-groups` headers via Istio RequestAuthentication
- Expects external OIDC providers (Google, GitHub, etc.)

## Our Implementation

- Authentication handled at Envoy Gateway level
- Uses Envoy Gateway SecurityPolicy with native OIDC
- Direct integration with Pocket-ID OIDC provider
- Sets same `kubeflow-userid` and `kubeflow-groups` headers via claimToHeaders
- Eliminates oauth2-proxy and dex components