from __future__ import annotations
import requests, time, os, re
from TSRUrl import TSRUrl
from logger import logger
from exceptions import *

# Tiempo mínimo que el servidor requiere entre initDownload y getdownloadurl.
TICKET_WAIT_SECONDS = 4


def stripForbiddenCharacters(string: str) -> str:
    return re.sub('[\\<>/:"|?*]', "", string)


class TSRDownload:
    """
    Each instance gets its own requests.Session so that parallel downloads
    in different threads never share cookies (tsrdlticket is per-request).
    """

    def __init__(self, url: TSRUrl, sessionId: str):
        # ── Isolated session per instance ─────────────────────────────────
        self.session: requests.Session = requests.Session()
        self.session.trust_env = False
        self.session.proxies.clear()

        # Carry the authenticated tsrdlsession cookie from the shared login
        self.session.cookies.set(
            "tsrdlsession", sessionId,
            domain=".thesimsresource.com",
            path="/",
        )

        self.url: TSRUrl     = url
        self.ticket: str     = ""
        self.ticket_time: float = 0.0

        # Each instance fetches its OWN ticket — no shared state with other threads
        self.__getTSRDLTicketCookie()

    # ── Public ────────────────────────────────────────────────────────────

    def download(self, downloadPath: str) -> str:
        logger.info(f"Starting download for: {self.url.url}")

        downloadUrl = self.__getDownloadUrl()
        logger.debug(f"Got downloadUrl: {downloadUrl}")
        fileName = stripForbiddenCharacters(self.__getFileName(downloadUrl))
        logger.debug(f"Got fileName: {fileName}")

        partPath = os.path.join(downloadPath, fileName + ".part")
        finalPath = os.path.join(downloadPath, fileName)

        startingBytes = os.path.getsize(partPath) if os.path.exists(partPath) else 0
        logger.debug(f"Got startingBytes: {startingBytes}")

        request = self.session.get(
            downloadUrl,
            stream=True,
            headers={"Range": f"bytes={startingBytes}-"},
        )
        logger.debug(f"Request status is: {request.status_code}")

        with open(partPath, "wb") as f:
            for index, chunk in enumerate(request.iter_content(1024 * 128)):
                logger.debug(f"Downloading chunk #{index} of {downloadUrl}")
                f.write(chunk)

        logger.debug(f"Removing .part from file name: {fileName}")
        if os.path.exists(finalPath):
            logger.debug(f"{finalPath} already exists — replacing")
            os.replace(partPath, finalPath)
        else:
            logger.debug(f"{finalPath} does not exist — renaming")
            os.rename(partPath, finalPath)

        return fileName

    # ── Private ───────────────────────────────────────────────────────────

    def __getFileName(self, downloadUrl: str) -> str:
        return re.search(
            r'(?<=filename=").+(?=")',
            requests.get(downloadUrl, stream=True).headers["Content-Disposition"],
        )[0]

    def __getDownloadUrl(self) -> str:
        # Wait the minimum time the server requires after the ticket was issued
        elapsed   = time.time() - self.ticket_time
        remaining = TICKET_WAIT_SECONDS - elapsed
        if remaining > 0:
            logger.debug(f"Waiting {remaining:.1f}s for ticket to become valid server-side...")
            time.sleep(remaining)

        url = (
            f"https://www.thesimsresource.com/ajax.php"
            f"?c=downloads&a=getdownloadurl&ajax=1"
            f"&itemid={self.url.itemId}&mid=0&lk=0"
            f"&ticket={self.ticket}"
        )
        logger.debug(f"Calling getdownloadurl: {url}")

        response     = self.session.get(url)
        responseJSON = response.json()
        error        = responseJSON.get("error", "")

        logger.debug(f"getdownloadurl response: {response.text}")

        if response.status_code == 200:
            if not error:
                return responseJSON["url"]
            elif error == "Invalid download ticket":
                raise InvalidDownloadTicket(response.url, self.session.cookies)
            else:
                raise Exception(f"getdownloadurl error: {repr(error)}")
        else:
            raise requests.exceptions.HTTPError(response)

    def __getTSRDLTicketCookie(self) -> None:
        """
        Calls initDownload to obtain a ticket for THIS specific item.
        Each instance calls this independently — thread-safe because
        self.session is not shared with any other TSRDownload instance.
        """
        logger.debug(f"Getting 'tsrdlticket' cookie for: {self.url.url}")

        response = self.session.get(
            f"https://www.thesimsresource.com/ajax.php"
            f"?c=downloads&a=initDownload"
            f"&itemid={self.url.itemId}&setItems=&format=zip"
        )
        data = response.json()

        if data.get("error", ""):
            raise Exception(f"initDownload error: {data['error']}")

        redirect_url  = data.get("url", "")
        ticket_match  = re.search(r"/ticket/([^/]+?)/?$", redirect_url)
        if ticket_match:
            self.ticket = ticket_match.group(1)
            logger.debug(f"Got ticket: {self.ticket}")
        else:
            raise Exception(f"Could not extract ticket from: {redirect_url}")

        # Copy tsrdlticket into our isolated session if present
        tsrdlticket = response.cookies.get("tsrdlticket") or self.session.cookies.get("tsrdlticket")
        if tsrdlticket:
            self.session.cookies.set(
                "tsrdlticket", tsrdlticket,
                domain=".thesimsresource.com",
                path="/",
            )

        # Visit the wait page — server starts counting ticket validity from here
        wait_page = f"https://www.thesimsresource.com{redirect_url}"
        logger.debug(f"Visiting wait page: {wait_page}")
        wait_resp = self.session.get(wait_page, allow_redirects=True)

        # Record time AFTER visiting wait page (server counts from this moment)
        self.ticket_time = time.time()

        # Update tsrdlsession if the server rotated it
        new_session = wait_resp.cookies.get("tsrdlsession")
        if new_session:
            self.session.cookies.set(
                "tsrdlsession", new_session,
                domain=".thesimsresource.com",
                path="/",
            )
            logger.debug(f"Updated tsrdlsession: {new_session}")