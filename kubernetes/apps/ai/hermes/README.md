# Hermes Agent

Hermes runs its messaging gateway, dashboard and API server in a single pod. Its
state, including the Matrix encryption store, is persisted on the Hermes PVC.

## Matrix account

Hermes uses the dedicated Matrix account `@hawow:goyangi.io` on the Continuwuity
homeserver at `https://matrix.goyangi.io`.

The `matrix` item in the `kubernetes` 1Password vault provides:

- `MATRIX_BOT_PASSWORD`
- `MATRIX_BOT_ACCESS_TOKEN`
- `MATRIX_BOT_DEVICE_ID`

The ExternalSecret maps the access token and device ID into the `hermes` Secret.
The access token and device ID must always come from the same Matrix login
response. Do not choose a different device ID after creating the token.

Hermes uses `MATRIX_E2EE_MODE=required`. Its Matrix store is located at
`/opt/data/platforms/matrix/store/` on the persistent volume. Preserve this store
across ordinary restarts and upgrades.

## Provision a bot account

Hermes uses a normal dedicated Matrix user, not an appservice or server admin.
Provision a new account from Continuwuity's admin room:

```text
!admin users create hawow
```

Continuwuity returns the new user ID and a generated password. Store that password
as `MATRIX_BOT_PASSWORD` in the `matrix` item in the `kubernetes` 1Password vault.
Do not grant the account server-admin privileges.

Create the persistent Hermes device using the client login API described below.
The API returns both the access token and its server-generated device ID. Store
both in 1Password, deploy Hermes and preserve its crypto store from then on.

After Hermes has started and uploaded its device keys, sign into the bot account
in Element temporarily and complete its encryption setup:

1. Set the bot's display name and avatar.
2. Enable secure key storage and save the recovery key outside Matrix.
3. Verify the server-generated `Hermes Agent` device.
4. Sign out of the temporary Element session.

Invite `@hawow:goyangi.io` to the intended private room from `@andrew:goyangi.io`.
Hermes automatically accepts invitations from authorised users. Run
`/discardsession` in the room after verifying the device, then send a new message.

Restrict access with `MATRIX_ALLOWED_USERS` and, for rooms shared with other
people, `MATRIX_ALLOWED_ROOMS`. An authorised Matrix user can exercise Hermes'
agent and tool permissions, so the bot should not be invited to untrusted rooms.

## Rotate the Matrix device

Rotate the device only when its token is compromised or its encryption identity
is no longer usable. Create a fresh device with the Matrix client API and allow
the homeserver to generate its ID:

```bash
matrix_password="$(op item get matrix --vault kubernetes --field MATRIX_BOT_PASSWORD --reveal)"

login_response="$(jq -n \
  --arg user '@hawow:goyangi.io' \
  --arg password "$matrix_password" \
  '{
    type: "m.login.password",
    identifier: {type: "m.id.user", user: $user},
    password: $password,
    initial_device_display_name: "Hermes Agent"
  }' | curl -fsS https://matrix.goyangi.io/_matrix/client/v3/login \
    -H 'Content-Type: application/json' \
    --data-binary @-)"

access_token="$(jq -er '.access_token' <<<"$login_response")"
device_id="$(jq -er '.device_id' <<<"$login_response")"

op item edit matrix --vault kubernetes \
  "password[password]=$matrix_password" \
  "MATRIX_BOT_ACCESS_TOKEN[password]=$access_token" \
  "MATRIX_BOT_DEVICE_ID[text]=$device_id"

unset matrix_password access_token device_id login_response
```

The built-in `password` field is populated because 1Password requires it for a
Password-category item. Hermes does not consume that field.

Commit and push any accompanying manifest changes, then reconcile and refresh the
ExternalSecret:

```bash
flux reconcile ks cluster-apps --with-source
kubectl annotate externalsecret -n ai hermes force-sync="$(date +%s)" --overwrite
kubectl wait --for=condition=Ready externalsecret/hermes -n ai --timeout=120s
```

Confirm the live Secret contains the generated ID before resetting encryption
state:

```bash
expected_device="$(op item get matrix --vault kubernetes --field MATRIX_BOT_DEVICE_ID)"
live_device="$(kubectl get secret hermes -n ai \
  -o jsonpath='{.data.MATRIX_DEVICE_ID}' | base64 -d)"
test "$expected_device" = "$live_device"
```

Delete the crypto database once after rotating the device, then recreate the pod:

```bash
pod="$(kubectl get pod -n ai -l app.kubernetes.io/name=hermes \
  -o jsonpath='{.items[0].metadata.name}')"
kubectl exec -n ai "$pod" -c app -- python -c \
  'from pathlib import Path; Path("/opt/data/platforms/matrix/store/crypto.db").unlink(missing_ok=True)'
kubectl delete pod -n ai "$pod"
kubectl rollout status deployment/hermes -n ai --timeout=240s
```

This deletion must not be placed in an init container. Repeating it on every pod
start would replace the encryption identity while reusing the same Matrix device,
causing other clients to distrust Hermes.

After rotation, verify the new `Hermes Agent` device in Element and run
`/discardsession` in the encrypted room before sending a new message. Events
encrypted for the previous device may remain undecryptable.

## Verification

Check the application container rather than relying only on Flux readiness:

```bash
kubectl get pods -n ai -l app.kubernetes.io/name=hermes
kubectl logs -n ai deployment/hermes -c app --since=10m | \
  rg 'Matrix|E2EE|decrypt|megolm|cross-sign'
```

The gateway should report Matrix as connected without stale device keys, invalid
signatures or missing Megolm sessions for newly sent messages.

See the [Hermes Matrix documentation](https://hermes-agent.nousresearch.com/docs/user-guide/messaging/matrix/)
for upstream configuration and migration guidance.
