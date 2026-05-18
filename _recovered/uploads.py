"""File uploads — short-lived signed URLs only.

POST /uploads — multipart upload, returns a *signed* URL (sig + exp).
GET  /uploads/{filename} — serves the file only if `?sig=` is valid.

The DB stores only the bare path (`/uploads/<uuid>.<ext>`); signing happens
on serialisation. Swapping local volume for S3/R2 means replacing the
two filesystem calls below — the contract does not change.
"""
import os
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from fastapi.responses import FileResponse

from ..core.deps import get_optional_user
from ..core.signing import sign_path, verify_signature


router = APIRouter(prefix="/uploads", tags=["uploads"])

UPLOAD_DIR = Path(os.environ.get("UPLOAD_DIR", "/data/uploads"))
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

MAX_BYTES = 25 * 1024 * 1024  # 25 MB
ALLOWED_EXT = {
    "png", "jpg", "jpeg", "gif", "webp", "svg",
    "mp4", "webm", "mov", "mp3", "wav", "ogg",
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
        raise HTTPException(status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                            f"Тип файла .{ext} не поддерживается")
    contents = await file.read()
    if len(contents) > MAX_BYTES:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                            f"Файл больше {MAX_BYTES // (1024 * 1024)} МБ")

    name = f"{uuid.uuid4().hex}.{ext}"
    target = UPLOAD_DIR / name
    target.write_bytes(contents)

    bare = f"/uploads/{name}"
    return {
        "url": bare,                     # stored in DB
        "signed_url": sign_path(bare),   # use immediately for preview
        "filename": file.filename,
        "size": len(contents),
        "content_type": file.content_type,
    }


@router.get("/{filename}")
async def get_file(filename: str, sig: str | None = Query(default=None)):
    # Strict whitelist of filename charset to prevent path traversal.
    if not all(c.isalnum() or c in {".", "-", "_"} for c in filename):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Bad filename")
    path = f"/uploads/{filename}"
    if not verify_signature(path, sig):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Invalid or expired signature")
    fs_path = UPLOAD_DIR / filename
    if not fs_path.exists():
        raise HTTPException(status.HTTP_404_NOT_FOUND, "File not found")
    return FileResponse(fs_path)
