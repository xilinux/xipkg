import os
import re
import util
import colors
import time


def find_package(query, repos, packages_dir, sources):
    for repo in repos:
        repo_dir = os.path.join(packages_dir, repo)
        files = os.listdir(repo_dir)

        if query in files:
            requested_repo = repo
            with open(os.path.join(repo_dir, query)) as file:
                checksum = file.readline().strip().split("=")[-1]
                listed_sources = file.readline().strip().split("=")[-1].split()
                found_sources = {
                            source: util.add_path(url, repo) 
                            for source, url in sources.items() 
                            if source in listed_sources
                        }
                return checksum, found_sources, requested_repo

    return None, [], None

def retrieve_package_info(sources, checksum, package_name, 
                            verbose=False, skip_verification=False):
    
    # TODO we may potentially do this a few times while resolving deps, might want to cache things here
    # TODO actually use the ping times we made earlier to decide which source to pick
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

    # TODO actually use the ping times we made earlier to decide which source to pick
    # TODO actually save tar file, and add loading bar
    for source,url in sources.items():
        package_info_url = util.add_path(url, package_name + ".xipkg")
        status, response = util.curl(package_info_url)
   
        if status == 200:
            downloaded_checksum = util.md5sum(response)
            print(downloaded_checksum, "compared to requested", checksum)
            if downloaded_checksum == checksum or skip_verification:
                return reponse
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

def resolve_dependencies(package_info, config):
    getpkgs = lambda deps: re.findall("\w*", deps)
    deps = getpkgs(package_info["DEPS"])

    deps = [
                dep for dep in deps if len(dep) > 0
            ]

    return deps

def find_all_dependencies(package_names, options, config):
    # this is all assuming that the order of deps installed doesn't matter
    to_check = [p for p in package_names]
    all_deps = []

    while len(to_check) > 0:
        util.loading_bar(len(all_deps), len(all_deps) + len(to_check), "Resolving dependencies...")
        dep = to_check.pop()

        dep_checksum, dep_sources, dep_repo = find_package(dep, config["repos"], config["dir"]["packages"], config["sources"])
        if dep_checksum is not None:
            info = retrieve_package_info(
                        dep_sources, dep_checksum, dep,
                        verbose=options["v"], skip_verification=options["u"]
                    )

            if len(info) > 0:
                all_deps.append(dep)
                deps = resolve_dependencies(info, config)
                for dep in deps:
                    if not dep in all_deps:

                        if is_installed(dep, config):
                            print(colors.YELLOW + f"Package {query} has already been installed")
                        else:
                            to_check.append(dep)
            else:
                if options["v"]:
                    util.print_reset(colors.CLEAR_LINE + colors.RED + f"Failed to retrieve info for {query}")
        else:
            util.print_reset(colors.CLEAR_LINE + colors.RED + f"Failed to find package {dep}")

    if len(all_deps) > 0:
        util.loading_bar(len(all_deps), len(all_deps) + len(to_check), "Resolved dependencies")
        print(colors.RESET)

    # assuming that the latter packages are core dependencies
    # we can reverse the array to reflect the more important packages to install
    all_deps.reverse()
    return all_deps

def is_installed(package_name, config):
    # TODO actually find out if its installed
    return False

def install(args, options, config):
    sources = config["sources"]
    repos = config["repos"]

    v = options["v"]
    unsafe = options["u"]

    packages_dir = config["dir"]["packages"]

    to_install = args if options["n"] else find_all_dependencies(args, options, config)

    if len(to_install) > 0:
        print(colors.BLUE + "The following packages will be installed:")
        print(end="\t")
        for d in to_install:
            print(colors.BLUE if d in args else colors.LIGHT_BLUE, d, end="")
        print()

        if util.ask_confirmation(colors.BLUE + "Continue?", no_confirm=options["y"]):
            print("installed")
        else:
            print(colors.RED + "Action cancelled by user")
    else:
        print(colors.LIGHT_RED + "Nothing to do")


