import shutil
import csv
import requests
import colors
import time
import os
import hashlib
import tarfile

DEFAULT_BAR_COLOR = colors.BLACK + colors.BG_WHITE
DEFAULT_BAR_COLOR_RESET = colors.BG_BLACK + colors.WHITE

def extract_tar(package_path, destination):
    cmd = f"tar -h --no-overwrite-dir -xvf {package_path} -C {destination}"
    
    os.popen(cmd).read()
    with tarfile.open(package_path) as tar:
        return "\n".join(["".join(m.name[1:]) for m in tar.getmembers() if not m.isdir()])
            

def add_path(*argv):
    a = argv[0]
    for b in argv[1:]:
        a = a + ("" if a[-1] == "/"  else "/") + (b[1:] if b[0] == "/" else b)
    return a

def is_root():
    return os.environ.get("SUDO_UID") or os.geteuid() == 0 


def get_area():
    columns, rows = shutil.get_terminal_size((80, 20))

def loading_bar(completed, total, text, 
        unit="", color=DEFAULT_BAR_COLOR, reset=DEFAULT_BAR_COLOR_RESET):

    columns, rows = get_area()
    
    count = f"[{completed}{unit}/{total}{unit}]"
    
    spaces = columns - (len(count) + len(text))
    info = text +  "".join([" " for i in range(spaces)]) + count

    reset_at = int((completed/total)*len(info)) if total > 0 else len(info)
    info = "".join([info[i] + (reset if i == reset_at else "") for i in range(len(info))]) 

    print(color + info, end="\r")

def fill_line(text, color, end="\n"):
    columns, rows = get_area()
    spaces = columns - (len(text))
    print(color + text +  "".join([" " for i in range(spaces)]), end=end)

def print_reset(text):
    print(colors.RESET + text)

def curl(url, raw=False):
    try:
        r = requests.get(url)
    except:
        return 500, ""
    return r.status_code, r.content if raw else r.text

def get_unit(n):
    base = 1000
    if n > base**4: return base**4, "TB"
    elif n > base**3: return base**3, "GB"
    elif n > base**2: return base**2, "MB"
    elif n > base**1: return base**1, "KB"
    else: return 1, "B"

def query_size(url):
    length = 0
    with requests.get(url, stream=True) as r:
        r.raise_for_status()
        if r.status_code == 200:
            length = int(r.headers['content-length']) if "content-length" in r.headers else 0
        else:
            length = 0
    return length

def curl_to_file(url, path, text="", start=0, total=-1):
    with requests.get(url, stream=True) as r:
        r.raise_for_status()

        length = int(r.headers['content-length']) if "content-length" in r.headers else 1000
        if total == -1: total = length
        with open(path, "wb") as f:

            c_size = 4096
            ic = r.iter_content(chunk_size=c_size)
            done = 0

            for chunk in ic:
                if text:
                    divisor, unit = get_unit(done+start)
                    loading_bar(round((done+start)/divisor, 2), round(total/divisor, 2), "Downloading " + text, unit=unit)

                f.write(chunk)
                done += c_size
        if text:
            divisor, unit = get_unit(length)
            
            # Only print the "Downloaded" text if global download is actually complete
            if done+start > total:
                loading_bar(int((done+start)/divisor), int(total/divisor), "Downloaded " + text, unit=unit)

        return r.status_code, path, done


def mkdir(path):
    if not os.path.exists(path):
        os.makedirs(path)

def md5sum(filename):
    md5_hash = hashlib.md5()

    with open(filename,"rb") as f:
        for byte_block in iter(lambda: f.read(4096),b""):
            md5_hash.update(byte_block)

        return md5_hash.hexdigest()

def ask_confirmation(text, default=True, no_confirm=False):
    yes = "Y" if default else "y"
    no = "n" if default else "N"

    if no_confirm:
        reponse = "y" if default else "n"
        print(f"{text} [{yes},{no}] {colors.RESET} {reponse}")
    else:
        reponse = input(f"{text} [{yes},{no}] " + colors.RESET)

    return reponse.lower() == "y" or len(reponse) == 0 

def get_distro():

    RELEASE_DATA = {}

    with open("/etc/os-release") as f:
        reader = csv.reader(f, delimiter="=")
        for row in reader:
            if row:
                RELEASE_DATA[row[0]] = row[1]

        if RELEASE_DATA["ID"] in ["debian", "raspbian"]:
            with open("/etc/debian_version") as f:
                DEBIAN_VERSION = f.readline().strip()
            major_version = DEBIAN_VERSION.split(".")[0]
            version_split = RELEASE_DATA["VERSION"].split(" ", maxsplit=1)
            if version_split[0] == major_version:
                # Just major version shown, replace it with the full version
                RELEASE_DATA["VERSION"] = " ".join([DEBIAN_VERSION] + version_split[1:])

    return RELEASE_DATA
