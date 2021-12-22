import os
import sys
import colors
import util
import shutil

from verbs.install import find_package, retrieve_package_info
from verbs.sync import sync

def list_repos(repos, packages_dir, sources):
    return [
            f"{repo}/{file}" for repo in repos for file in os.listdir(os.path.join(packages_dir, repo)) 
            ]

def search(args, options, config):
    if not options["l"]:
        sync(args, options, config)

    if len(args) > 0:
        packages = list_repos(config["repos"], config["dir"]["packages"], config["sources"])
        for package in args:

            # TODO fuzzy searching here
            results = [p for p in packages if package.lower() in p.lower()]
    
            if len(results) > 0:
                print(colors.GREEN + f"Search results for {package}:")
                for r in results:
                    print(colors.LIGHT_GREEN + f"\t{r}")

                sys.exit(0)
            else:
                print(colors.RED + f"Package {package} could not be found")
                sys.exit(1)
    else:
        print(colors.LIGHT_RED + "Nothing to do")

        
