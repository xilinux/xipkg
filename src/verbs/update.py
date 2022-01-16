import os
import util
import colors
import time

from verbs.install import find_package, install
from verbs.sync import sync

VERSION_COMPARED = "CHECKSUM"

def get_installed_list(config, root="/"):
    installed_dir = util.add_path(root, config["dir"]["installed"])
    if os.path.exists(installed_dir):
        files = os.listdir(installed_dir)
        return files
    return []


def update(args, options, config):
    if not options["l"]:
        sync(args, options, config)

    packages = [package for package in get_installed_list(config, options["r"]) if len(args) == 0 or package in args]
    options["l"] = True
    install(packages, options, config)
