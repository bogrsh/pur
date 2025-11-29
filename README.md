# **pur — Python UNIX RSS**
### _A tiny, stupidly simple, cross-platform TUI RSS reader for Linux, macOS, WSL, and Android (Termux)._

`pur` is a minimalist terminal RSS reader written in Python + curses.  
It stores read/unread state, keeps a cache for instant startup, and runs entirely inside the terminal.

Supported platforms:
- Linux  
- macOS  
- WSL  
- Android (Termux)

---

## **Features**
- ✔️ TUI interface (curses)  
- ✔️ Supports RSS 2.0 & Atom  
- ✔️ Caching for instant startup  
- ✔️ Optional sync via `rclone`  
- ✔️ Works offline using cache  
- ✔️ Vim-like navigation  
- ✔️ Marks items as read/unread  
- ✔️ Tiny and easy-to-read code  

---

## **Requirements**
- A UNIX-like OS  
- Python 3  
- (optional) `rclone` if you want multi-device sync

---

## **Installation**

Clone the repository:

```bash
git clone https://github.com/USERNAME/pur.git
cd pur
```

Copy the script to your home directory:

```bash
cp .pur.sh ~/
# or for Termux:
cp .pur-termux.sh ~/
```

Make the script executable:

```bash
chmod +x ~/.pur.sh
chmod +x ~/.pur-termux.sh
```

add a shell function to `~/.bashrc` or `~/.zshrc`:

```bash
cat >> ~/.bashrc << 'EOF'
pur() {
    rclone sync youtcloud:rss/ ~/rss/ --progress
    ~/.pur.sh
    rclone sync ~/rss/ yourcloud:rss/ --progress
}
EOF
```

## **Installing Python**

If Python isn’t installed:

| OS            | Command                    |
| ------------- | -------------------------- |
| Termux        | `pkg install python`       |
| Debian/Ubuntu | `sudo apt install python3` |
| Arch Linux    | `sudo pacman -S python`    |
| Fedora/RHEL   | `sudo dnf install python3` |

## **Directory Structure**
'pur' keeps its data in:

```bash
~/rss/
├── urls.md          # your RSS sources
├── seen.txt         # auto-created list of read links
└── cache.txt        # auto-created feed cache
```

## **Example** `urls.md`

```bash
https://example.com/rss.xml # Example News
https://planetpython.org/rss20.xml # Python
https://hnrss.org/frontpage # HackerNews
```

## **Usage**
run:

```bash
$ pur
```

## **Keyboard shortcuts (Vim-style)**

| Key           | Action                   |
| ------------- | ------------------------ |
| **j/k**       | move down / up           |
| **d/u**       | half-page down / up      |
| **g/G**       | top / bottom             |
| **o / Enter** | open link via `xdg-open` |
| **a**         | mark as read             |
| **A**         | mark as unread           |
| **m**         | mark all as read         |
| **M**         | mark all as unread       |
| **r**         | reload all feeds         |
| **/**         | search                   |
| **n/N**       | next / previous match    |
| **?**         | help                     |
| **q**         | quit                     |

## **Screenshots (placeholder)**
```bash
┌───────────────────────────────────────────────┐
│ ★ 12-01 14:22 [Python] New release of X       │
│   12-01 12:10 [HN] Interesting article        │
│   12-01 10:00 [News] Something happened       │
└───────────────────────────────────────────────┘
```

## **pur-termux**

The Termux version uses:

- shorter time format (`HH:MM`)
- shortened source name (8 characters)

Otherwise, it works exactly the same as the desktop version.

## **FAQ**
**Why the name “pur”?**

It stands for **P**ython **U**NIX **R**SS.

**Why “a stupid RSS parser”?**

Because it’s:

- simple
- tiny
- a bit hacky
- but works reliably 😄

**How do I sync between devices?**

Using `rclone`, for example with any Cloud or any other remote.

**Why is it so fast?**

Because:

- it caches feeds
- reloads in a background thread
- curses-based interface is extremely lightweight

## **License**

MIT
