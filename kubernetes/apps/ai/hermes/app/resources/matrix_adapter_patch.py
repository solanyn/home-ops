"""Enable megolm room-key backfill for authorised Matrix users.

Hermes inherits mautrix's default key-share policy, which ignores
``m.room_key_request`` events from every user except the bot's own. A client that
missed the one-off megolm key distribution therefore shows "Waiting for this
message" forever, because nothing ever re-sends the key. This patch answers such
requests for devices belonging to ``MATRIX_ALLOWED_USERS``, which is how every
other Matrix client recovers a missing session.

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
"""


def main() -> int:
    shutil.rmtree(TARGET, ignore_errors=True)
    shutil.copytree(SOURCE, TARGET, dirs_exist_ok=True)

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
