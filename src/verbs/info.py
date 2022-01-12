import os
import colors
import util
import shutil

from verbs.install import find_package, retrieve_package_info, is_installed
from verbs.sync import sync

def get_installed_info(package, config, options):
    installed_info = {}

    info_file = util.add_path(options["r"], config["dir"]["installed"], package, "info")
    with open(info_file, "r") as file:
        for line in file:
            line = line.strip()
            key = line.split("=")[0]
            value = "=".join(line.split("=")[1:])

            installed_info[key] = value

    return installed_info

def package_info(package, config, options):
            checksum, sources, repo, size, files = find_package(package, config["repos"], config["dir"]["packages"], config["sources"])

            if not checksum is None:
                info = retrieve_package_info(
                        sources, checksum, package, config, 
                        verbose=options["v"], skip_verification=options["u"]
                        )
                installed = is_installed(package, config, options["r"])
                installed_info = get_installed_info(package, config, options) if installed else {}
                
                print(colors.CYAN + f"Information for {package}:")
                print(colors.CYAN + "\tName: " + colors.LIGHT_CYAN + f"{info['NAME']}")
                print(colors.CYAN + "\tDescription: " + colors.LIGHT_CYAN + f"{info['DESCRIPTION']}")
                print(colors.CYAN + "\tRepo: " + colors.LIGHT_CYAN + f"{repo}")
                print(colors.CYAN + "\tChecksum: " + colors.LIGHT_CYAN + f"{info['CHECKSUM']}")
                print(colors.CYAN + "\tVersion Hash: " + colors.LIGHT_CYAN + f"{info['VER_HASH']}")
                print(colors.CYAN + "\tBuild Date: " + colors.LIGHT_CYAN + f"{info['DATE']}")
                print(colors.CYAN + "\tSource: " + colors.LIGHT_CYAN + f"{info['SOURCE']}")
                print(colors.CYAN + "\tDependencies: " + colors.LIGHT_CYAN + f"{info['DEPS']}")
                print(colors.CYAN + "\tInstalled: " + colors.LIGHT_CYAN + f"{installed}")

                if installed:
                    print(colors.CYAN + "\t\tDate: " + colors.LIGHT_CYAN + f"{installed_info['INSTALL_DATE']}")
                    print(colors.CYAN + "\t\tChecksum: " + colors.LIGHT_CYAN + f"{installed_info['CHECKSUM']}")
                    print(colors.CYAN + "\t\tURL: " + colors.LIGHT_CYAN + f"{installed_info['URL']}")
                    print(colors.CYAN + "\t\tValidation Key: " + colors.LIGHT_CYAN + f"{installed_info['KEY']}")
            else:
                print(colors.RED + f"Package {package} could not be found")


def info(args, options, config):
    if not options["l"]:
        sync(args, options, config)

    if len(args) == 0:
        installed_path = util.add_path(options["r"], config["dir"]["installed"])
        installed = os.listdir(installed_path)
        if len(installed) > 0:
            [args.append(i) for i in installed]
        else:
            print(colors.RED + f"No packages have been specified nor installed")

    for package in args:
        package_info(package, config, options)



        
