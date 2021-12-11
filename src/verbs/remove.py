import os
import colors
import util
import shutil

from verbs.sync import sync
from verbs.install import is_installed

BAR_COLOR = colors.BLACK + colors.BG_RED
BAR_COLOR_RESET = colors.BG_BLACK + colors.RED

def list_files(package_name, config, root="/"):
    file_list = util.add_path(root, config["dir"]["installed"], package_name, "files")
    with open(file_list, "r") as file:
        return [util.add_path(root, line.strip()) for line in file]

def remove_package(package, options, config):
    if is_installed(package, config, options["r"]):
        files = list_files(package, config, options["r"])
        done = 0
        for file in files:
            util.loading_bar(done, len(files), f"Removing {package}", color=BAR_COLOR, reset=BAR_COLOR_RESET)
            if os.path.exists(file):
                os.remove(file)
                if options["v"]:
                    print(colors.GREEN + f"{file} removed") 

                # TODO delete the file's parent dirs if they are empty
            else:
                if options["v"]:
                    print(colors.RED + f"{file} is missing: not removed!") 
            done += 1
            
        
        installed_path = util.add_path(options["r"], config["dir"]["installed"], package)
        shutil.rmtree(installed_path)
        util.loading_bar(done, len(files), f"Removed {package}", color=BAR_COLOR, reset=BAR_COLOR_RESET)
        print()
    else:
        print(colors.LIGHT_RED + package + colors.RED + " is not installed")

def remove(args, options, config):
    if not options["l"]:
        sync(args, options, config)

    # potential to find all the orphaned deps or something, but that would require knowing why someone installed a package, so you dont lose packages that you want

    uninstall = [package for package in args if is_installed(package, config, options["r"])]
    not_found = [package for package in args if not package in uninstall]

    if len(not_found) > 0:
        print(colors.RED + ", ".join(not_found), "are" if len(not_found) > 1 else "is", "not installed!")
    if len(uninstall) > 0:
        print(colors.CLEAR_LINE + colors.RESET, end="")
        print(colors.RED + "The following packages will be removed:")
        print(end="\t")
        for d in uninstall:
            print(colors.RED , d, end="")
        print()

        if util.ask_confirmation(colors.RED + "Continue?", no_confirm=options["y"]):
            for package in uninstall:
                remove_package(package, options, config)
