import os
import colors
import util
import shutil

import re

from verbs.sync import sync
from verbs.search import list_repos
from verbs.file import condition_file

def list_files(package_name, config, root="/"):
    file_list = util.add_path(root, config["dir"]["installed"], package_name, "files")
    if os.path.exists(file_list):
        with open(file_list, "r") as file:
            return [condition_file(line.strip()) for line in file]
    else:
        return []

def list_all_files(config, root="/"):
    packages = [ p.split("/")[-1] for p in list_repos(config["repos"], config["dir"]["packages"], config["dir"]["sources"])]
    file_list = {}
    for package in packages:
        file_list[package] = list_files(package, config, root=root)
    return file_list

def files(args, options, config):
    if len(args) > 0:
        [print(f) for f in list_files(args[0], config, options["r"])]

    else:
        print(colors.LIGHT_RED + "Nothing to do")
