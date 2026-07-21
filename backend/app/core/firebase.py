"""Firebase Admin initialization and ID-token verification.

The backend trusts Firebase to authenticate users. Every protected request
carries a Firebase ID token (a signed JWT); we verify it here with the Admin
SDK, which checks the signature, expiry, issuer, and audience against our
project. A valid token yields the caller's Firebase UID.

Initialization is LAZY: the server boots (and serves /health) without the
service-account key present. The key is only required the first time a protected
endpoint is called.
"""

import json

import firebase_admin
from firebase_admin import auth as firebase_auth
from firebase_admin import credentials

from app.core.config import settings

_initialized = False


def _load_credential() -> credentials.Certificate:
    # Cloud: the whole JSON supplied as an env var (secret) — takes precedence.
    if settings.firebase_service_account_json:
        return credentials.Certificate(
            json.loads(settings.firebase_service_account_json)
        )
    # Local dev: a path to the JSON file on disk.
    if settings.google_application_credentials:
        return credentials.Certificate(settings.google_application_credentials)
    raise RuntimeError(
        "No Firebase credentials configured. Set FIREBASE_SERVICE_ACCOUNT_JSON "
        "(cloud) or GOOGLE_APPLICATION_CREDENTIALS (local file path)."
    )


def _ensure_initialized() -> None:
    global _initialized
    if _initialized:
        return
    firebase_admin.initialize_app(_load_credential())
    _initialized = True


def verify_id_token(id_token: str) -> dict:
    """Verify a Firebase ID token; return its decoded claims (includes 'uid')."""
    _ensure_initialized()
    return firebase_auth.verify_id_token(id_token)
