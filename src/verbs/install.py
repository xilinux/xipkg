import os
import util
import colors
import time

def find_package(query, repos, packages_dir):
    sources = []
    checksum = None
    requested_repo = None

    for repo in repos:
        repo_dir = os.path.join(packages_dir, repo)
        files = os.listdir(repo_dir)

        if query in files:
            requested_repo = repo
            with open(os.path.join(repo_dir, query)) as file:
                checksum = file.readline().strip().split("=")[-1]
                sources = file.readline().strip().split("=")[-1].split()
                return checksum, sources, requested_repo
    return None, [], None

def retrieve_package_info(sources, checksum, package_name, 
                            verbose=False, skip_verification=False):
    for source,url in sources.items():
        package_info_url = util.add_path(url, package_name + ".xipkg.info")
        status, response = util.curl(package_info_url)
   
        if status == 200:
            info = parse_package_info(response)
            if info["CHECKSUM"] == checksum or skip_verification:
                return info
            else:
                if verbose:
                    print(colors.RED 
                            + f"Checksum verification failed for {package_name} in {source}" 
                            + colors.RESET)
    if verbose:
        print(colors.RED + f"No matching hashes found" + colors.RESET)
    return {}

def retrieve_package(sources, checksum, package_name, 
                            verbose=False, skip_verification=False):
    for source,url in sources.items():
        package_info_url = util.add_path(url, package_name + ".xipkg.info")
        status, response = util.curl(package_info_url)
   
        if status == 200:
            info = parse_package_info(response)
            if info["CHECKSUM"] == checksum or skip_verification:
                return info
            else:
                if verbose:
                    print(colors.RED 
                            + f"Checksum verification failed for {package_name} in {source}" 
                            + colors.RESET)
    if verbose:
        print(colors.RED + f"No matching hashes found" + colors.RESET)
    return {}

def parse_package_info(packageinfo):
    info = {}

    for line in packageinfo.split("\n"):
        split = line.split("=")
        if len(split) > 1:
            info[split[0]] = "=".join(split[1:])
    return info

def install(args, options, config):
    sources = config["sources"]
    repos = config["repos"]

    v = options["v"]
    unsafe = options["u"]

    packages_dir = config["dir"]["packages"]
    for query in args:

        # FIRST CHECK IF ALREADY INSTALLED
        checksum, listed_sources, repo = find_package(query, repos, packages_dir)

        if checksum is not None:
            repo_sources = {
                        source: util.add_path(url, repo) 
                        for source, url in sources.items() 
                        if source in listed_sources
                    }

            info = retrieve_package_info(
                        repo_sources, checksum, query,
                        verbose=v, skip_verification=unsafe
                    )

            print(info)
        else:
            print(colors.RED + "Package not found")
        print(colors.RESET, end="")

