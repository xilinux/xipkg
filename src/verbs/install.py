import os
import util
import colors
import time

def install(args, options, config):
    for query in args:
        sources = config["sources"]
        repos = config["repos"]

        v = options["v"]

        packages_dir = config["dir"]["packages"]
        
        sources = []
        checksum = None
        requested_repo = None

        for repo in repos:
            repo_dir = os.path.join(packages_dir, repo)
            files = os.listdir(repo_dir)

            if query in files:
                requested_repo = repo
                with open(os.path.join(repo_dir, query)) as file:
                    checksum = file.read().split("=")[-1]
                    sources = file.read().split("=")[-1].split()
                break
        if checksum is not None:
            print(query)
            print(checksum)
            print(sources)
            print(requested_repo)
        else:
            print(colors.RED + "Package not found")
        print(colors.RESET, end="")

