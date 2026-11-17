"""Enable megolm room-key backfill for authorised Matrix users.

Hermes inherits mautrix's default key-share policy, which ignores
``m.room_key_request`` events from every user except the bot's own. A client that
missed the one-off megolm key distribution therefore shows "Waiting for this
message" forever, because nothing ever re-sends the key. This patch answers such
requests for devices belonging to ``MATRIX_ALLOWED_USERS``, which is how every
other Matrix client recovers a missing session.

The target is an emptyDir mount point, so files are copied individually: copying
directory metadata onto the mount point is refused for the unprivileged user.

The patch fails open: if the anchor text is absent, for example after an image
bump, the adapter is left untouched and the gateway still starts.
"""

from __future__ import annotations

import pathlib
import shutil
import sys

SOURCE = pathlib.Path("/opt/hermes/plugins/platforms/matrix")
TARGET = pathlib.Path("/patched")

ANCHOR = """            olm.share_keys_min_trust = TrustState.UNVERIFIED
            olm.send_keys_min_trust = TrustState.UNVERIFIED
"""

PATCH = """            # Answer room-key requests from devices of authorised users so a client
            # that missed a megolm key share can backfill it instead of showing
            # "Waiting for this message" indefinitely. Upstream only serves the
            # bot's own devices and never answers another user's client.
            _key_share_users = {
                user.strip()
                for user in _get_scoped_secret("MATRIX_ALLOWED_USERS", "").split(",")
                if user.strip()
            }
            _default_allow_key_share = olm.allow_key_share

            async def _allow_key_share(device, request):
                if device.user_id != client.mxid and (
                    not _key_share_users or str(device.user_id) in _key_share_users
                ):
                    return device.trust != TrustState.BLACKLISTED
                return await _default_allow_key_share(device, request)

            olm.allow_key_share = _allow_key_share

            # MemoryStateStore marks a room's member cache complete after any single
            # membership event, and share_group_session then trusts that cache. A
            # collapsed cache yields a session with no recipients at all, which no
            # client can decrypt. Always ask the homeserver for the joined members.
            async def _always_fetch_members(room_id):
                return False

            state_store.has_full_member_list = _always_fetch_members

            # Diagnostic logging: which side creates olm sessions and which key
            # requests arrive, so a client that keeps re-establishing sessions can
            # be identified from the bot side.
            _known_users = {str(client.mxid)} | _key_share_users

            async def _describe_identity(identity_key):
                for user in _known_users:
                    try:
                        found = await olm.crypto_store.find_device_by_key(user, identity_key)
                    except Exception:
                        found = None
                    if found:
                        return f"{found.user_id}/{found.device_id}"
                return "unknown device"

            _orig_add_session = olm.crypto_store.add_session

            async def _add_session(identity_key, session):
                who = await _describe_identity(identity_key)
                logger.warning("Matrix: new olm session %s with %s", session.id, who)
                return await _orig_add_session(identity_key, session)

            olm.crypto_store.add_session = _add_session

            _orig_create_outbound_sessions = olm._create_outbound_sessions

            async def _create_outbound_sessions(users, _force_recreate_session=False):
                for user_id, devices in (users or {}).items():
                    for device_id in (devices or {}):
                        logger.warning(
                            "Matrix: claiming olm session with %s/%s (force=%s)",
                            user_id,
                            device_id,
                            _force_recreate_session,
                        )
                return await _orig_create_outbound_sessions(users, _force_recreate_session)

            olm._create_outbound_sessions = _create_outbound_sessions

            _orig_handle_key_request = olm._handle_room_key_request

            async def _handle_key_request(device, request):
                held = await olm.crypto_store.get_group_session(
                    request.room_id, request.session_id
                )
                logger.warning(
                    "Matrix: key request from %s/%s for session %s held=%s",
                    device.user_id,
                    device.device_id,
                    request.session_id,
                    bool(held),
                )
                return await _orig_handle_key_request(device, request)

            olm._handle_room_key_request = _handle_key_request
"""


def populate() -> None:
    """Copy the bundled plugin into the emptyDir without touching its metadata."""
    TARGET.mkdir(parents=True, exist_ok=True)
    for stale in TARGET.iterdir():
        if stale.is_dir() and not stale.is_symlink():
            shutil.rmtree(stale, ignore_errors=True)
        else:
            stale.unlink(missing_ok=True)
    for item in SOURCE.iterdir():
        if item.is_file():
            destination = TARGET / item.name
            shutil.copyfile(item, destination)
            destination.chmod(0o644)


def main() -> int:
    populate()

    adapter = TARGET / "adapter.py"
    text = adapter.read_text()
    if text.count(ANCHOR) != 1:
        print(
            "matrix adapter patch: anchor not found; key-share backfill disabled",
            file=sys.stderr,
        )
        return 0

    adapter.write_text(text.replace(ANCHOR, ANCHOR + PATCH))
    print("matrix adapter patch: key-share backfill enabled")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
