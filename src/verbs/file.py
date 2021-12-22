import os
import colors
import util
import shutil

import re

from verbs.sync import sync
from verbs.search import list_repos

# since we symlink /bin to /usr, we should make sure we are always looking for the same place
def condition_file(file_path):
    file_path = re.sub("^/bin", "/usr/bin", file_path)
    file_path = re.sub("^/sbin", "/usr/bin", file_path)
    file_path = re.sub("^/usr/sbin", "/usr/bin", file_path)
    file_path = re.sub("^/lib", "/usr/lib", file_path)
    file_path = re.sub("^/lib64", "/usr/lib", file_path)
    file_path = re.sub("^/usr/lib64", "/usr/lib", file_path)
    return file_path

def absolute_path(file_path, root="/"):
    if file_path[0] == "/":
        return file_path
    else:
        root_path = os.path.realpath(root)
        file_path = os.path.realpath(file_path)
        # this is a bad way of doing this
        file_path = file_path.replace(root_path, "")
        return file_path

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

def file(args, options, config):
    if len(args) > 0:
        file_list = list_all_files(config, options["r"])
        for file in args:
            file = condition_file(absolute_path(file, options["r"]))
            found = False
            for package, files in file_list.items():
                if file in files:
                    found = True
                    print(colors.LIGHT_CYAN + file, colors.CYAN + "belongs to", colors.LIGHT_CYAN + package)
                    break
            if not found:
                print(colors.RED + "Could not determine which package owns " + colors.LIGHT_CYAN + file)


    else:
        print(colors.LIGHT_RED + "Nothing to do")
