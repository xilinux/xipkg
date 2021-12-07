import os
import util
import colors
import time

from verbs.install import find_package, install_single
from verbs.sync import sync

VERSION_COMPARED = "CHECKSUM"

def get_installed_versions(config, root="/"):
    packages = {}

    installed_dir = util.add_path(root, config["dir"]["installed"])
    if os.path.exists(installed_dir):
        files = os.listdir(installed_dir)
        for package in files:
            with open(util.add_path(installed_dir, package, "info")) as file:
                for line in file:
                    if line.startswith(VERSION_COMPARED):
                        packages[package] = line.strip().split("=")[-1]

    return packages

def get_available_version(package_name, config, root="/"):
    repos = config["repos"]
    packages_dir = config["dir"]["packages"]
    sources = config["sources"]
    checksum, found_sources, requested_repo = find_package(package_name, repos, packages_dir, sources)
    return checksum
    
def update(args, options, config):
    if not options["l"]:
        sync(args, options, config)

    v = options["v"]

    updates = [package for package,checksum in get_installed_versions(config, options["r"]).items() if not checksum == get_available_version(package, config, options["r"])]

    if len(args) > 0:
        updates = [update for update in updates if update in args]

    if len(updates) > 0:
        print(colors.CLEAR_LINE + colors.RESET, end="")
        print(colors.BLUE + "The following packages will be updated:")
        print(end="\t")
        for d in updates:
            print(colors.BLUE if d in args else colors.LIGHT_BLUE, d, end="")
        print()

        if util.ask_confirmation(colors.BLUE + "Continue?", no_confirm=options["y"]):
            for package in updates:
                install_single(package, options, config, verbose=v, unsafe=options["u"])
                util.fill_line(f"Updated {package}", colors.BG_CYAN + colors.LIGHT_BLACK, end="\n")
    else:
        print(colors.LIGHT_RED + "Nothing to do")

    
