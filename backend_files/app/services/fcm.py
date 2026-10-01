"""Firebase Cloud Messaging push notification service.

Initialises the Firebase Admin SDK from a local service-account JSON
and exposes helpers to send push notifications to individual users or
broadcast to all users with stored FCM tokens.
"""
import json
import logging
import os
import uuid
from pathlib import Path
from typing import Optional

from bson import ObjectId

logger = logging.getLogger(__name__)
_firebase_app = None
_initialized = False


def _safe_oid(uid: str):
    """Convert a user id string to ObjectId when possible.

    Mongo documents store _id as ObjectId; passing a plain string never
    matches, which silently broke FCM token lookup (user_not_found).
    """
    try:
        return ObjectId(uid)
    except Exception:
        return uid


def _channel_for(data: Optional[dict]) -> str:
    """Android channel ID inayolingana na channels za Flutter app.

    App imeunda channels zenye KIANGIZI "_v2" (sauti + vibration +
    Importance.max ziko hapa): kubadilishana_messages_v2 /
    kubadilishana_matches_v2 / kubadilishana_general_v2.
    KUTUMA channel isiyokuwepo (bila _v2) kwenye Android 8+ kunatupilia
    channel ya fallback "Miscellaneous" BILA sauti, vibration wala
    heads-up — ndiyo chanzo cha arifa za kimya.
    """
    t = (data or {}).get("type", "")
    if "message" in t or "call" in t or "reply" in t:
        return "kubadilishana_messages_v2"
    if "match" in t or "verified" in t or "registered" in t:
        return "kubadilishana_matches_v2"
    return "kubadilishana_general_v2"


def _get_firebase_app():
    """Lazy-initialise the Firebase Admin SDK."""
    global _firebase_app, _initialized
    if _initialized:
        return _firebase_app

    try:
        import firebase_admin
        from firebase_admin import credentials

        # 1. Try environment variable (for Docker / production)
        svc_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON")
        if svc_json:
            info = json.loads(svc_json)
            cred = credentials.Certificate(info)
            _firebase_app = firebase_admin.initialize_app(cred)
            _initialized = True
            logger.info("[FCM] Firebase Admin SDK initialised from env var")
            return _firebase_app

        # 2. Try file path from env var
        cred_path = os.environ.get("FIREBASE_SERVICE_ACCOUNT_PATH", "")
        if cred_path and os.path.isfile(cred_path):
            cred = credentials.Certificate(cred_path)
            _firebase_app = firebase_admin.initialize_app(cred)
            _initialized = True
            logger.info("[FCM] Firebase Admin SDK initialised from %s", cred_path)
            return _firebase_app

        # ERROR (si warning): ishara wazi kwenye journalctl kwamba push
        # hazitafanya kazi mpaka env var iwekwe na service irestartiwe.
        logger.error(
            "[FCM] Hakuna Firebase service account — PUSH ZOTE ZIMEZIMWA. "
            "Weka FIREBASE_SERVICE_ACCOUNT_JSON (au FIREBASE_SERVICE_ACCOUNT_PATH) "
            "kwenye env ya kv_backend kisha restart.")
        _initialized = True  # Don't retry
        return None

    except Exception as exc:
        logger.error("[FCM] Failed to initialise Firebase Admin SDK: %s", exc)
        _initialized = True
        return None


async def send_push_to_user(
    user_id: str,
    title: str,
    body: str,
    data: Optional[dict] = None,
    image: Optional[str] = None,
) -> dict:
    """Send a push notification to a single user via FCM.

    Looks up the user's stored FCM tokens from the database and sends
    to all registered devices.
    """
    return await send_push_with_id(user_id, title, body, data, image)


async def send_push_with_id(
    user_id: str,
    title: str,
    body: str,
    data: Optional[dict] = None,
    image: Optional[str] = None,
) -> dict:
    """Push moja ya FCM — data inayotumwa inabaki kama ilivyo (mlio
    wa 'notification_id' kutoka caller unahifadhiwa ili app ifanye dedupe
    sahihi kati ya FCM na WS event ile ile)."""
    from ..db import get_db

    app = _get_firebase_app()
    if not app:
        # ERROR (si debug): lazima ionekane kwenye `journalctl -u kv_backend`
        # — hii ndiyo ishara pekee kwamba FIREBASE_SERVICE_ACCOUNT_JSON
        # haipo kwenye env ya service na push zote zinaachwa kimya.
        logger.error(
            "[FCM] Firebase HAIJAANZISHWA — push kwa user %s imeachwa. "
            "Weka FIREBASE_SERVICE_ACCOUNT_JSON (au _PATH) kwenye env ya "
            "service kisha restart kv_backend.", user_id)
        return {"sent": 0, "error": "firebase_not_initialised"}

    try:
        from firebase_admin import messaging

        db = get_db()
        user = await db.users.find_one({"_id": _safe_oid(user_id)})
        if not user:
            return {"sent": 0, "error": "user_not_found"}

        tokens = user.get("fcm_tokens", [])
        if not tokens:
            return {"sent": 0, "error": "no_tokens"}

        # Build notification
        notification = messaging.Notification(
            title=title,
            body=body,
            image=image,
        )

        # Android config — channel kulingana na aina ya event.
        # icon: drawable nyeupe maalum ya app (ic_notification) — bila hii
        # Android inaonyesha duara jeupe kwenye status bar/heads-up.
        # color: accent ya brand kwenye icon na heads-up.
        channel = _channel_for(data)
        android_config = messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                title=title,
                body=body,
                image=image,
                click_action="FLUTTER_NOTIFICATION_CLICK",
                channel_id=channel,
                icon="ic_notification",
                color="#1E40AF",
            ),
        )

        # APNs config (iOS)
        apns_config = messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    alert=messaging.ApsAlert(title=title, body=body),
                    badge=1,
                    sound="default",
                )
            )
        )

        # Send to multiple tokens (batch)
        # Hakikisha 'type' + 'notification_id' zipo kwenye data — app
        # inaitumia kufungua screen sahihi (deep-link) + dedupe na WS.
        fcm_data = {"type": (data or {}).get("type", "notification")}
        fcm_data.update(data or {})
        if not fcm_data.get("notification_id"):
            fcm_data["notification_id"] = str(uuid.uuid4())
        # FCM data lazima iwe na maandishi (strings) TUTU — thamani
        # zisizo-string (float n.k.) zinashindwa kimya na ujumbe hutumwa.
        fcm_data = {str(k): str(v) for k, v in fcm_data.items()
                    if v is not None}

        sent_count = 0
        failed_tokens = []
        batch_size = 500  # FCM limit per batch

        for i in range(0, len(tokens), batch_size):
            batch_tokens = tokens[i : i + batch_size]
            messages = [
                messaging.Message(
                    notification=notification,
                    android=android_config,
                    apns=apns_config,
                    token=token,
                    data=fcm_data,
                )
                for token in batch_tokens
            ]

            response = await messaging.send_each_async(messages)
            sent_count += response.success_count

            # Collect failed tokens for cleanup
            for idx, resp in enumerate(response.responses):
                if not resp.success:
                    failed_tokens.append(batch_tokens[idx])
                    logger.warning("[FCM] Failed to send to %s: %s", batch_tokens[idx], resp.exception)

        # Remove invalid tokens from DB
        if failed_tokens:
            await db.users.update_one(
                {"_id": _safe_oid(user_id)},
                {"$pull": {"fcm_tokens": {"$in": failed_tokens}}},
            )
            logger.info("[FCM] Removed %d invalid tokens for user %s", len(failed_tokens), user_id)

        return {"sent": sent_count, "failed": len(failed_tokens), "total": len(tokens)}

    except Exception as exc:
        logger.error("[FCM] Push failed for user %s: %s", user_id, exc)
        return {"sent": 0, "error": str(exc)}


async def send_push_to_admins(
    title: str,
    body: str,
    data: Optional[dict] = None,
) -> dict:
    """Send push notification to all admin users."""
    from ..db import get_db

    db = get_db()
    admins = await db.users.find({"is_admin": True}).to_list(100)
    total_sent = 0

    for admin in admins:
        result = await send_push_to_user(
            user_id=str(admin["_id"]),
            title=title,
            body=body,
            data=data,
        )
        total_sent += result.get("sent", 0)

    return {"admins_notified": len(admins), "total_sent": total_sent}
