from __future__ import annotations

import argparse
import os
import re
import time
import threading
from concurrent.futures import ThreadPoolExecutor
from typing import Iterable

import clipboard
import requests

from TSRDownload import TSRDownload
from TSRSession import TSRSession
from TSRUrl import TSRUrl
from config import CONFIG, CURRENT_DIR
from exceptions import InvalidCaptchaCode, InvalidURL
from logger import logger


DETAILS_URL = "https://www.thesimsresource.com/downloads/details/id/"
TSR_HOST    = "https://www.thesimsresource.com"
STRICT_TSR_DETAILS_ID_RE = re.compile(
    r"^https?://(?:www\.)?thesimsresource\.com/(?:members/[^/\s\"'<>]+/)?downloads/details(?:/[^/\s\"'<>]+)*/id/\d+/?$",
    flags=re.IGNORECASE,
)

_print_lock = threading.Lock()

def safe_print(msg: str) -> None:
    with _print_lock:
        print(msg, flush=True)


# ── Helpers ───────────────────────────────────────────────────────────────────

def ensure_download_directory(download_path: str) -> str:
    os.makedirs(download_path, exist_ok=True)
    return download_path


def load_saved_session_id() -> str | None:
    session_path = os.path.join(CURRENT_DIR, "session")
    if os.path.exists(session_path):
        return open(session_path, "r", encoding="utf-8").read().strip() or None
    return None


def persist_session_id(session_id: str) -> None:
    open(os.path.join(CURRENT_DIR, "session"), "w", encoding="utf-8").write(session_id)


def create_session() -> TSRSession:
    session = None
    session_id = load_saved_session_id()
    while session is None:
        try:
            session = TSRSession(session_id)
            if getattr(session, "tsrdlsession", ""):
                persist_session_id(session.tsrdlsession)
                logger.info("Session created successfully")
        except InvalidCaptchaCode:
            logger.error("Invalid captcha code, please try again")
            session_id = None
    return session


def is_strict_tsr_details_url(url: str) -> bool:
    return bool(STRICT_TSR_DETAILS_ID_RE.match(url.strip()))


def expand_source_url(source_url: str) -> list[TSRUrl]:
    cleaned = source_url.strip()
    if not cleaned or not is_strict_tsr_details_url(cleaned):
        return []
    try:
        return [TSRUrl(cleaned)]
    except InvalidURL:
        return []


# ── Single-URL worker (thread pool) ──────────────────────────────────────────

def _download_one(url_obj: TSRUrl,
                  session_id: str,
                  download_path: str) -> tuple[bool, str]:
    safe_print(f"Starting download for: {url_obj.url}")
    try:
        downloader = TSRDownload(url_obj, session_id)
        downloader.download(download_path)
        safe_print(f"Completed download for: {url_obj.url}")
        return True, url_obj.url
    except Exception as exc:
        logger.error(f"Failed download for {url_obj.url}: {exc}")
        safe_print(f"Failed download for {url_obj.url}: {exc}")
        return False, url_obj.url


# ── Notepad batch mode ────────────────────────────────────────────────────────

def download_from_sources(source_urls: list[str],
                           download_path: str,
                           read_delay_s: float = 0.0,
                           max_workers: int | None = None) -> int:
    ensure_download_directory(download_path)
    session    = create_session()
    session_id = session.tsrdlsession

    if max_workers is None:
        max_workers = int(CONFIG.get("maxActiveDownloads", 5))
    max_workers = max(1, max_workers)

    total = len(source_urls)
    safe_print(f"[INFO] Starting batch: {total} URL(s), "
               f"max {max_workers} parallel, "
               f"{read_delay_s:.1f}s read-delay per URL")

    seen_ids: set[int] = set()

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        for idx, source_url in enumerate(source_urls, start=1):
            if not source_url.strip():
                continue

            try:
                targets = expand_source_url(source_url)
            except Exception as exc:
                logger.error(f"Failed to expand {source_url}: {exc}")
                continue

            if not targets:
                logger.error(f"No valid TSR items for: {source_url}")
                continue

            for target in targets:
                if target.itemId in seen_ids:
                    continue
                seen_ids.add(target.itemId)

                safe_print(f"Reading URL {idx}/{total}: {source_url}")
                executor.submit(_download_one, target, session_id, download_path)

            if read_delay_s > 0 and idx < total:
                time.sleep(read_delay_s)

    safe_print("All downloads have been completed")
    return 0


# ── Clipboard loop mode ───────────────────────────────────────────────────────

def run_clipboard_loop(download_path: str) -> int:
    """
    Clipboard loop mode:
    - Monitors the system clipboard for new TSR URLs
    - Downloads them immediately using the thread pool (maxActiveDownloads)
    - Runs until the process is killed (CTRL+C or QProcess::terminate)
    - Uses --download-dir if provided, otherwise falls back to config
    """
    ensure_download_directory(download_path)
    session    = create_session()
    session_id = session.tsrdlsession

    max_workers = int(CONFIG.get("maxActiveDownloads", 5))

    safe_print(f"Clipboard Mode active. Monitoring clipboard... (dest: {download_path})")

    last_text  = clipboard.paste()
    seen_ids: set[int] = set()

    # Use a persistent pool for the lifetime of clipboard mode
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        while True:
            try:
                current_text = clipboard.paste()
            except Exception:
                time.sleep(0.5)
                continue

            if current_text != last_text:
                last_text = current_text
                # Try every line / the whole text as a URL
                for line in current_text.splitlines():
                    line = line.strip()
                    if not is_strict_tsr_details_url(line):
                        continue
                    try:
                        target = TSRUrl(line)
                    except InvalidURL:
                        continue

                    if target.itemId in seen_ids:
                        safe_print(f"Duplicate skipped: {line}")
                        continue

                    seen_ids.add(target.itemId)
                    safe_print(f"Captured URL: {line}")
                    executor.submit(_download_one, target, session_id, download_path)

            time.sleep(0.3)

    return 0  # unreachable, process is killed externally


def read_source_urls_from_file(path: str) -> list[str]:
    if not os.path.exists(path):
        return []
    found: list[str] = []
    with open(path, "r", encoding="utf-8") as handle:
        for line in handle:
            for match in re.findall(r"https?://[^\s\"'<>]+", line):
                cleaned = match.rstrip(").,;]}")
                if is_strict_tsr_details_url(cleaned):
                    found.append(cleaned)
    return found


# ── Entry point ───────────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-url",     action="append", default=[])
    parser.add_argument("--source-file")
    parser.add_argument("--download-dir")
    parser.add_argument("--read-delay",     type=float, default=0.0)
    parser.add_argument("--max-workers",    type=int,   default=None)
    parser.add_argument("--clipboard-mode", action="store_true",
                        help="Run in clipboard-monitor mode (infinite loop)")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()

    target_dir = args.download_dir or CONFIG["downloadDirectory"]

    # ── Clipboard mode ────────────────────────────────────────────────────
    if args.clipboard_mode:
        raise SystemExit(run_clipboard_loop(target_dir))

    # ── Notepad batch mode ────────────────────────────────────────────────
    source_urls = list(args.source_url)
    if args.source_file:
        source_urls.extend(read_source_urls_from_file(args.source_file))

    if source_urls:
        read_delay  = args.read_delay
        max_workers = args.max_workers or int(CONFIG.get("maxActiveDownloads", 5))
        raise SystemExit(
            download_from_sources(source_urls, target_dir, read_delay, max_workers)
        )

    # ── Legacy clipboard loop (fallback, no args) ─────────────────────────
    raise SystemExit(run_clipboard_loop(target_dir))
