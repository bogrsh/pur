#!/usr/bin/env python3
import curses, os, xml.etree.ElementTree as ET, threading
from datetime import datetime, timezone
from urllib.request import urlopen

DIR = os.path.expanduser("~/rss")
URLS = f"{DIR}/urls.md"
SEEN = f"{DIR}/seen.txt"
CACHE = f"{DIR}/cache.txt"
os.makedirs(DIR, exist_ok=True)

seen, items = set(), []
query, matches, mpos = "", [], -1
status = "Starting..."

def load_seen():
    global seen
    if os.path.exists(SEEN):
        seen = {l.strip() for l in open(SEEN) if l.strip()}

def save_seen():
    open(SEEN,"w").write("\n".join(sorted(seen))+"\n")

def save_cache():
    open(CACHE,"w",encoding="utf-8").write("\n".join(f"{i['d'].isoformat()}|{i['s']}|{i['t']}|{i['l']}" for i in items))

def load_cache():
    global items
    items = []
    if not os.path.exists(CACHE): return
    try:
        for line in open(CACHE,encoding="utf-8"):
            if not line.strip(): continue
            d,s,t,l = line.strip().split("|",3)
            items.append({"t":t,"l":l,"d":datetime.fromisoformat(d),"s":s})
    except: pass

def parse_date(s):
    if not s: return datetime.now(timezone.utc)
    s = s.strip().replace("Z","+00:00")
    for f in ("%a, %d %b %Y %H:%M:%S %z","%Y-%m-%dT%H:%M:%S%z","%Y-%m-%dT%H:%M:%S.%f%z"):
        try: return datetime.strptime(s,f)
        except: pass
    try: return datetime.fromisoformat(s.replace("Z","+00:00"))
    except: return datetime.now(timezone.utc)

def fetch(url, name):
    try:
        root = ET.parse(urlopen(url,timeout=8)).getroot()
        res = []
        if root.tag == "rss":
            for i in root.findall("./channel/item"):
                res.append({"t":(i.findtext("title")or"").strip(),
                            "l":i.findtext("link")or"",
                            "d":parse_date(i.findtext("pubDate")),
                            "s":name})
        elif root.tag.endswith("feed"):
            ns = {"a":"http://www.w3.org/2005/Atom"}
            for e in root.findall("a:entry",ns):
                l = e.find("a:link",ns)
                res.append({"t":(e.findtext("a:title",namespaces=ns)or"").strip(),
                            "l":l.get("href")if l is not None else"",
                            "d":parse_date(e.findtext("a:updated",namespaces=ns)),
                            "s":name})
        return res
    except: return []

def reload():
    global items, status
    if not os.path.exists(URLS):
        status = "No urls.md"
        return
    new = []
    for line in open(URLS,encoding="utf-8"):
        line = line.strip()
        if not line or line[0]=="#": continue
        p = line.split("#",1)
        url = p[0].strip().split()[0]
        name = p[1].strip() if len(p)>1 else "?"
        new.extend(fetch(url,name))
    new.sort(key=lambda x:x["d"],reverse=True)
    items = new
    save_cache()
    status = f"Updated {len(items)} items"

def background_update():
    global status
    status = "Updating feeds..."
    threading.Thread(target=reload,daemon=True).start()

def find(q):
    global matches, mpos
    q = q.lower()
    matches = [i for i,x in enumerate(items) if q in x["t"].lower() or q in x["s"].lower()]
    mpos = -1

def next_match(fwd=True):
    global mpos
    if not matches: return -1
    mpos = (mpos + (1 if fwd else -1)) % len(matches)
    return matches[mpos]

def input_search(stdscr):
    global query
    curses.echo()
    stdscr.addstr(0,0,"/" + query.ljust(60))
    s = stdscr.getstr(0,1,70)
    curses.noecho()
    q = s.decode().strip()
    if q: query = q; find(query)

def help(stdscr):
    lines = [" UR — RSS ",""," j/k move"," d/u half"," g/G top/bot"," o open",
             " a read"," A unread"," m all read"," M all unread"," r reload",
             " / search"," n/N next"," ? help"," q quit"]
    h,w = stdscr.getmaxyx()
    win = curses.newwin(len(lines)+2,38,h//2-8,w//2-19)
    win.box()
    for i,t in enumerate(lines): win.addstr(i+1,2,t.center(34))
    win.refresh(); stdscr.getch()

def main(stdscr):
    global status
    curses.curs_set(0)
    load_seen()
    load_cache()
    status = f"Loaded {len(items)} cached" if items else "First run"
    background_update()
    pos = 0

    while True:
        h,w = stdscr.getmaxyx()
        start = max(0,pos-h//2)
        stdscr.erase()

        for i in range(h-1):
            if start+i >= len(items): break
            it = items[start+i]
            mark = "★" if it["l"] and it["l"] not in seen else " "
            date = it["d"].strftime("%m-%d %H:%M")
            line = f"{mark} {date} [{it['s']}] {it['t']}"[:w-1]
            if start+i == pos: stdscr.attron(curses.A_REVERSE)
            stdscr.addstr(i,0,line)
            if start+i == pos: stdscr.attroff(curses.A_REVERSE)

        s = status
        if query: s = f"/{query} | {status}"
        stdscr.addstr(h-1,0,s[:w-1].ljust(w-1),curses.A_BOLD)

        k = stdscr.getch()
        if k in (ord('q'),27): break
        if k in (ord('j'),curses.KEY_DOWN) and pos < len(items)-1: pos += 1
        if k in (ord('k'),curses.KEY_UP) and pos > 0: pos -= 1
        if k == ord('d'): pos = min(len(items)-1,pos+h//2)
        if k == ord('u'): pos = max(0,pos-h//2)
        if k == ord('g'): pos = 0
        if k == ord('G'): pos = len(items)-1
        if k in (10,ord('o'),ord(' ')):
            l = items[pos]["l"]
            if l: os.system(f"xdg-open '{l}' &>/dev/null &"); seen.add(l)
        if k == ord('a') and items[pos]["l"]: seen.add(items[pos]["l"])
        if k == ord('A') and items[pos]["l"]: seen.discard(items[pos]["l"])
        if k == ord('m'): [seen.add(x["l"]) for x in items if x["l"]]
        if k == ord('M'): seen.clear()
        if k == ord('r'): background_update(); pos = 0
        if k == ord('/'): input_search(stdscr); pos = next_match() if matches else pos
        if k == ord('n') and matches: pos = next_match()
        if k == ord('N') and matches: pos = next_match(False)
        if k == ord('?'): help(stdscr)

    save_seen()

if __name__ == "__main__":
    curses.wrapper(main)
