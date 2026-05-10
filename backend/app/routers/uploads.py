"""Lightweight file upload endpoint.

Stores files on a mounted volume and serves them back via StaticFiles.
Designed to keep media OUT of the database — DB stores only short URLs.

For production, swap the local volume for S3 / Yandex Cloud Object Storage /
Google Cloud Storage by replacing the `_save` implementation. The endpoint
contract (multipart -> JSON {url}) does not change.
"""
import os
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

from ..core.deps import get_optional_user


router = APIRouter(prefix="/uploads", tags=["uploads"])

UPLOAD_DIR = Path(os.environ.get("UPLOAD_DIR", "/data/uploads"))
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

MAX_BYTES = 25 * 1024 * 1024  # 25 MB
ALLOWED_EXT = {
    # images
    "png", "jpg", "jpeg", "gif", "webp", "svg",
    # video / audio (small clips)
    "mp4", "webm", "mov", "mp3", "wav", "ogg",
    # docs
    "pdf", "doc", "docx", "xls", "xlsx", "csv", "txt",
}


def _ext(filename: str) -> str:
    return filename.rsplit(".", 1)[-1].lower() if "." in filename else ""


@router.post("", status_code=201)
async def upload_file(
    file: UploadFile = File(...),
    _user=Depends(get_optional_user),
) -> dict:
    ext = _ext(file.filename or "")
    if ext not in ALLOWED_EXT:
        raise HTTPException(
            status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            f"Тип файла .{ext} не поддерживается",
        )

    contents = await file.read()
    if len(contents) > MAX_BYTES:
        raise HTTPException(
            status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            f"Файл больше {MAX_BYTES // (1024 * 1024)} МБ",
        )

    name = f"{uuid.uuid4().hex}.{ext}"
    target = UPLOAD_DIR / name
    target.write_bytes(contents)

    return {
        "url": f"/uploads/{name}",
        "filename": file.filename,
        "size": len(contents),
        "content_type": file.content_type,
    }
