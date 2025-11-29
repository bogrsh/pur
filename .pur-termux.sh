#!/usr/bin/env python3
import curses
import os
import xml.etree.ElementTree as ET
import threading
from datetime import datetime, timezone
from urllib.request import urlopen
import subprocess

RSS_DIR = os.path.expanduser("~/rss")
URLS_FILE = os.path.join(RSS_DIR, "urls.md")
SEEN_FILE = os.path.join(RSS_DIR, "seen.txt")
CACHE_FILE = os.path.join(RSS_DIR, "cache.txt")
os.makedirs(RSS_DIR, exist_ok=True)

class FeedItem:
    def __init__(self, title, link, date, source):
        self.title = title
        self.link = link
        self.date = date
        self.source = source

class FeedManager:
    def __init__(self):
        self.items = []
        self.seen = set()
        self.status = "Starting..."
        self.load_seen()
        self.load_cache()

    def load_seen(self):
        if os.path.exists(SEEN_FILE):
            self.seen = {line.strip() for line in open(SEEN_FILE) if line.strip()}

    def save_seen(self):
        with open(SEEN_FILE, "w") as f:
            f.write("\n".join(sorted(self.seen)) + "\n")

    def save_cache(self):
        with open(CACHE_FILE, "w", encoding="utf-8") as f:
            for item in self.items:
                f.write(f"{item.date.isoformat()}|{item.source}|{item.title}|{item.link}\n")

    def load_cache(self):
        self.items = []
        if not os.path.exists(CACHE_FILE):
            return
        for line in open(CACHE_FILE, encoding="utf-8"):
            line = line.strip()
            if not line: continue
            try:
                d,s,t,l = line.split('|',3)
                self.items.append(FeedItem(t,l,datetime.fromisoformat(d),s))
            except Exception:
                continue

    def parse_date(self, s):
        if not s: return datetime.now(timezone.utc)
        s = s.strip().replace('Z', '+00:00')
        for fmt in ("%a, %d %b %Y %H:%M:%S %z", "%Y-%m-%dT%H:%M:%S%z", "%Y-%m-%dT%H:%M:%S.%f%z"):
            try:
                return datetime.strptime(s, fmt)
            except:
                continue
        try:
            return datetime.fromisoformat(s.replace('Z','+00:00'))
        except:
            return datetime.now(timezone.utc)

    def fetch_feed(self, url, name):
        try:
            root = ET.parse(urlopen(url, timeout=8)).getroot()
            items = []
            if root.tag == 'rss':
                for i in root.findall('./channel/item'):
                    items.append(FeedItem((i.findtext('title') or '').strip(), i.findtext('link') or '', self.parse_date(i.findtext('pubDate')), name))
            elif root.tag.endswith('feed'):
                ns = {'a':'http://www.w3.org/2005/Atom'}
                for e in root.findall('a:entry', ns):
                    l = e.find('a:link', ns)
                    items.append(FeedItem((e.findtext('a:title', namespaces=ns) or '').strip(), l.get('href') if l is not None else '', self.parse_date(e.findtext('a:updated', namespaces=ns)), name))
            return items
        except Exception as e:
            self.status = f"Failed to fetch {name}"
            return []

    def reload(self):
        if not os.path.exists(URLS_FILE):
            self.status = "No urls.md"
            return
        new_items = []
        for line in open(URLS_FILE, encoding='utf-8'):
            line = line.strip()
            if not line or line.startswith('#'): continue
            parts = line.split('#',1)
            url = parts[0].strip().split()[0]
            name = parts[1].strip() if len(parts)>1 else '?'
            new_items.extend(self.fetch_feed(url,name))
        new_items.sort(key=lambda x: x.date, reverse=True)
        self.items = new_items
        self.save_cache()
        self.status = f"Updated {len(self.items)} items"

    def background_update(self):
        self.status = "Updating feeds..."
        threading.Thread(target=self.reload, daemon=True).start()

class CursesUI:
    def __init__(self, manager):
        self.manager = manager
        self.pos = 0
        self.query = ''
        self.matches = []
        self.mpos = -1

    def find_matches(self, q):
        q = q.lower()
        self.matches = [i for i, x in enumerate(self.manager.items) if q in x.title.lower() or q in x.source.lower()]
        self.mpos = -1

    def next_match(self, fwd=True):
        if not self.matches: return -1
        self.mpos = (self.mpos + (1 if fwd else -1)) % len(self.matches)
        return self.matches[self.mpos]

    def input_search(self, stdscr):
        curses.echo()
        stdscr.addstr(0,0,'/'+self.query.ljust(60))
        s = stdscr.getstr(0,1,70)
        curses.noecho()
        q = s.decode().strip()
        if q: self.query = q; self.find_matches(self.query)

    def help(self, stdscr):
        lines = [" UR — RSS ",""," j/k move"," d/u half"," g/G top/bot"," o open",
                 " a read"," A unread"," m all read"," M all unread"," r reload",
                 " / search"," n/N next"," ? help"," q quit"]
        h,w = stdscr.getmaxyx()
        win = curses.newwin(len(lines)+2,38,h//2-8,w//2-19)
        win.box()
        for i,t in enumerate(lines): win.addstr(i+1,2,t.center(34))
        win.refresh(); stdscr.getch()

    def draw(self, stdscr):
        h,w = stdscr.getmaxyx()
        start = max(0,self.pos-h//2)
        stdscr.erase()
        for i in range(h-1):
            if start+i >= len(self.manager.items): break
            it = self.manager.items[start+i]
            mark = "*" if it.link and it.link not in self.manager.seen else " "
            date = it.date.strftime("%H:%M")
            line = f"{mark} {date} {it.title}"[:w-1]
            if start+i == self.pos: stdscr.attron(curses.A_REVERSE)
            stdscr.addstr(i,0,line)
            if start+i == self.pos: stdscr.attroff(curses.A_REVERSE)
        s = self.manager.status
        if self.query: s = f"/{self.query} | {self.manager.status}"
        stdscr.addstr(h-1,0,s[:w-1].ljust(w-1),curses.A_BOLD)

    def main(self, stdscr):
        curses.curs_set(0)
        self.manager.background_update()
        while True:
            self.draw(stdscr)
            k = stdscr.getch()
            if k in (ord('q'),27): break
            if k in (ord('j'),curses.KEY_DOWN) and self.pos < len(self.manager.items)-1: self.pos +=1
            if k in (ord('k'),curses.KEY_UP) and self.pos>0: self.pos-=1
            if k==ord('d'): self.pos = min(len(self.manager.items)-1,self.pos+curses.LINES//2)
            if k==ord('u'): self.pos = max(0,self.pos-curses.LINES//2)
            if k==ord('g'): self.pos=0
            if k==ord('G'): self.pos=len(self.manager.items)-1
            if k in (10, ord('o'), ord(' ')):
                l = self.manager.items[self.pos].link
                if l: subprocess.Popen(['xdg-open', l], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL); self.manager.seen.add(l)
            if k==ord('a') and self.manager.items[self.pos].link: self.manager.seen.add(self.manager.items[self.pos].link)
            if k==ord('A') and self.manager.items[self.pos].link: self.manager.seen.discard(self.manager.items[self.pos].link)
            if k==ord('m'): [self.manager.seen.add(x.link) for x in self.manager.items if x.link]
            if k==ord('M'): self.manager.seen.clear()
            if k==ord('r'): self.manager.background_update(); self.pos=0
            if k==ord('/'): self.input_search(stdscr); self.pos=self.next_match() if self.matches else self.pos
            if k==ord('n') and self.matches: self.pos=self.next_match()
            if k==ord('N') and self.matches: self.pos=self.next_match(False)
            if k==ord('?'): self.help(stdscr)
        self.manager.save_seen()

if __name__ == '__main__':
    manager = FeedManager()
    ui = CursesUI(manager)
    curses.wrapper(ui.main)
