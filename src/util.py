import shutil
import requests
import colors
import time
import os

def loading_bar(completed, total, text, 
        unit=""):

    columns, rows = shutil.get_terminal_size((80, 20))
    
    count = f"[{completed}{unit}/{total}{unit}]"
    
    spaces = columns - (len(count) + len(text))
    info = text +  "".join([" " for i in range(spaces)]) + count


    reset_at = int((completed/total)*len(info)) if total > 0 else 0
    info = "".join([info[i] + (colors.RESET if i == reset_at else "") for i in range(len(info))]) 

    print(colors.BLACK + colors.BG_GREEN + info, end="\r")




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
