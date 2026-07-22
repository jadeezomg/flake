# VERSION: 1.0
from urllib.parse import quote_plus, urljoin
from bs4 import BeautifulSoup
from helpers import download_file, retrieve_url
from novaprinter import prettyPrinter

class sukebeisi:
    name = "Sukebei Nyaa"
    url = "https://sukebei.nyaa.si/"
    supported_categories = {"all": "0_0", "anime": "1_0"}

    def search(self, what, cat="all"):
        category = self.supported_categories.get(cat, "0_0")
        search_url = f"{self.url}?f=0&c={category}&q={quote_plus(what)}"
        try:
            html = retrieve_url(search_url)
        except Exception:
            return
        soup = BeautifulSoup(html, "html.parser")
        for row in soup.select("table.torrent-list tbody tr"):
            title_link = row.select_one('a[href^="/view/"]')
            if not title_link:
                continue
            title = title_link.get_text(" ", strip=True)
            details_url = urljoin(self.url, title_link.get("href", ""))
            magnet = row.select_one('a[href^="magnet:"]')
            torrent = row.select_one('a[href*="/download/"]')
            if magnet:
                download_url = magnet.get("href")
            elif torrent:
                download_url = urljoin(self.url, torrent.get("href"))
            else:
                download_url = details_url
            cells = row.find_all("td")
            prettyPrinter({
                "name": title,
                "link": download_url,
                "size": cells[3].get_text(" ", strip=True) if len(cells) > 3 else "",
                "seeds": cells[5].get_text(" ", strip=True) if len(cells) > 5 else "",
                "leech": cells[6].get_text(" ", strip=True) if len(cells) > 6 else "",
                "engine_url": details_url,
                "pub_date": cells[4].get_text(" ", strip=True) if len(cells) > 4 else "",
            })

    def download(self, link):
        if link.startswith("magnet:"):
            return link
        if "/download/" in link:
            return download_file(link)
        return None
