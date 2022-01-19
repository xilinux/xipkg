import options
import config
import util
import os
import colors

from verbs.sync import sync
from verbs.file import file
from verbs.files import files
from verbs.search import search
from verbs.info import info, get_installed_info
from verbs.remove import remove
from verbs.install import install
from verbs.update import update
from verbs.sync import keyimport

verbs = { v: globals()[v] for v in [
                "search",
                "keyimport",
                "file",
                "files",
                "info",
                "update",
                "install",
                "remove",
                "sync"
            ]
        }

def print_stats(conf, opts):
    pkg_count = {}
    installed_dir = util.add_path(opts["r"], conf["dir"]["installed"])

    for package in os.listdir(installed_dir):
        installed_info = get_installed_info(package, conf, opts)
        repo = installed_info["REPO"]
        
        if repo not in pkg_count: pkg_count[repo] = 0
        pkg_count[repo] += 1

    key_count = len(os.listdir(util.add_path(opts["r"], conf["dir"]["keychain"])))

    total = sum(pkg_count.values())

    distro = util.get_distro()["NAME"]

    w = 16
    print(colors.LIGHT_CYAN + "xipkg", end="")
    print(colors.CYAN + " on ", end="")
    print(colors.LIGHT_CYAN + distro, end="") 
    print(colors.CYAN + ":")
        

    for repo,count in pkg_count.items():
        print(f"{colors.BLUE}{repo}: {colors.LIGHT_BLUE}{count}")
    print(colors.BLUE + ("~"*w) + colors.RESET)
    print(colors.BLUE + f"Total: {colors.LIGHT_BLUE}{total}" + colors.RESET)



def main():
    opts = options.parse_args()
    args = opts["args"]
    
    if opts["h"]:
        options.print_usage()
        return
    
    conf = config.parse_file(opts["c"])
    if len(args) > 0:
        verb = args[0].lower()

        try: 
            (
                verbs[verb] if verb in verbs else search
            )(
                args[1:] if len(args) > 1 else [], opts, conf
            )
        except KeyboardInterrupt:
            print(colors.RESET + colors.CLEAR_LINE + colors.RED + "Action cancelled by user")
    else:
        print_stats(conf, opts)
        return

    print(colors.RESET + colors.CLEAR_LINE, end="")
