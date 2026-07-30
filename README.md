# SocaToDate 📺⚡

**SocaToDate** is a lightweight Shell script designed for **Enigma2** set-top boxes (OpenATV, OpenPLi, VTi, BlackHole, etc.). It automatically fetches an IPTV provider's M3U playlist, checks your existing Enigma2 IPTV userbouquet file, and updates outdated stream URLs seamlessly without messing up your channel names, positions, or EPG references.

---

## ✨ Features

- **Strict URL Syncing:** Updates stream links in your current bouquet file without deleting channels or resetting custom channel numbers.
- **Flash Memory Protection:** Utilizes external storage (`/media/hdd` or `/media/usb`) for processing and downloading, preventing receiver memory depletion or crash logs.
- **Anti-Blocking Wget:** Spoofs browser User-Agents to prevent IPTV provider blockages.
- **Unmatched Channels Bouquet:** Generates a secondary bouquet for newly added provider channels that are not yet in your primary bouquet.
- **OpenWebif Integration:** Shows real-time pop-up notifications on your TV screen upon completion.
- **Auto GUI Reload:** Automatically reloads Enigma2 interface to apply stream changes immediately.

---

## 🛠️ Prerequisites

- **Enigma2 Receiver** running OpenATV, OpenPLi, VTi, or similar Linux-based firmware.
- An existing IPTV bouquet file located in `/etc/enigma2/` starting with `userbouquet.iptv*.tv`.
- An attached USB drive or HDD mounted on `/media/hdd` or `/media/usb`.
- An active OpenWebif installation (enabled by default on most images).

---

## 📥 Installation

1. Connect to your Enigma2 receiver via SSH / FTP (e.g., using **WinSCP** or **PuTTY**).
2. Download `socaToDate.sh` and upload it to `/usr/script/` (create the folder if it does not exist).
3. Set executable permissions on the script:
   ```bash
   chmod +x /usr/script/socaToDate.sh
   ```

## ⚙️ Configuration
   
Open `/usr/script/socaToDate.sh` with a text editor and configure the variables at the top:

```bash
# Paste your M3U playlist URL inside quotes:
M3U_URL="[http://your-iptv-provider.com/get.php?username=XXX&password=YYY&type=m3u_plus](http://your-iptv-provider.com/get.php?username=XXX&password=YYY&type=m3u_plus)"

# Path for temporary files (Recommended: /media/hdd/socaToDate or /media/usb/socaToDate)
BASE_DIR="/media/hdd/socaToDate"

# Enable/Disable TV pop-up messages (1 = Enabled, 0 = Disabled)
SHOW_OSD=1

# Restart Enigma2 GUI automatically after update (1 = Yes, 0 = No)
RESTART_GUI=1
```

## 🚀 Usage

### Manual Execution via Command Line
Run the script from the terminal to test it:
```bash
/usr/script/socaToDate.sh
```

## 🔘 Mapping to Remote Control (Long Press Blue Button)

To run **SocaToDate** directly from your TV remote (e.g., holding down the **Blue Button**):

### Method 1: Via OpenATV / OpenPLi Hotkey
1. Go to **Menu > Setup > System > Expert settings > Hotkey** (or **QuickButton**).
2. Scroll down to **Long Press Blue Button**.
3. Select **Executes Shell Script** (or search for `socaToDate.sh` under `/usr/script/`).
4. Save the settings. Now, holding the **Blue Button** will trigger the update on demand!

### Method 2: Via CronJob (Scheduled Auto-Update)
To run the script automatically every night at 4:00 AM without user intervention:
1. Open terminal on your receiver and edit the crontab:
   ```bash
   crontab -e
   0 4 * * * /usr/script/socaToDate.sh >/dev/null 2>&1
   ```
## 🔍 How It Works

1. **Camouflaged Download:** Downloads your M3U file safely using a desktop User-Agent string to bypass provider rate limits or basic bot blocks.
2. **Smart Parsing:** Filters out VOD, Series, and Movies, extracting only Live TV streams and mapping them to a temporary array.
3. **Bouquet Scanning:** Reads your active `/etc/enigma2/userbouquet.iptv*.tv` file line-by-line.
4. **Strict Matching:** Matches existing channel names in your decoder against the freshly downloaded URLs.
5. **Precision Update:** Replaces *only* the stream links that have changed, leaving custom channel ordering and un-matched channels completely intact.
6. **Apply & Reload:** Saves the new bouquet file and forces a GUI reload via OpenWebif to apply the changes instantly.

## 📜 License

Distributed under the **MIT License**. See `LICENSE` for more information.
