import shutil
import requests
import colors
import time
import os

DEFAULT_BAR_COLOR = colors.BLACK + colors.BG_CYAN
DEFAULT_BAR_COLOR_RESET = colors.BG_BLACK + colors.CYAN

def loading_bar(completed, total, text, 
        unit="", color=DEFAULT_BAR_COLOR, reset=DEFAULT_BAR_COLOR_RESET):

    columns, rows = shutil.get_terminal_size((80, 20))
    
    count = f"[{completed}{unit}/{total}{unit}]"
    
    spaces = columns - (len(count) + len(text))
    info = text +  "".join([" " for i in range(spaces)]) + count

    reset_at = int((completed/total)*len(info)) if total > 0 else 0
    info = "".join([info[i] + (reset if i == reset_at else "") for i in range(len(info))]) 

    print(color + info, end="\r")




def curl(url):
    r = requests.get(url)
    return r.status_code, r.text

def mkdir(path):
    if not os.path.exists(path):
        os.makedirs(path)

if __name__ == "__main__":
    for i in range(1000):
        loading_bar(i, 1000, "it is loading...")
        time.sleep(0.01)
