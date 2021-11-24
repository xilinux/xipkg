import os
import re
import util
import colors
import time
import requests
import hashlib

def get_best_source(available, sources_list="/var/lib/xipkg/sources"):
    source_speeds = {}
    with open(sources_list, "r") as file:
        for line in file.readlines():
            split = line.split(" ")
            if len(split) > 0:
                try:
                    if split[0] in available:
                        source_speeds[split[0]] = float(split[1])
                except:
                    pass

    return sorted(source_speeds.keys(), key=lambda k: source_speeds[k])
        

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

def verify_signature(package_file, package_info, 
                            cache_dir="/var/cache/xipkg", keychain_dir="/var/lib/xipkg/keychain",
                            verbose=False):

    checksum = package_info["CHECKSUM"]
    
    sig_cached_path = util.add_path(cache_dir, checksum + ".sig")
    with open(sig_cached_path, "wb") as file:
        file.write(package_info["SIGNATURE"])

    if os.path.exists(keychain_dir):
        keys = os.listdir(keychain_dir)
        for key in keys:
            key_path = util.add_path(keychain_dir, key)
            
            command = f"openssl dgst -verify {key_path} -signature {sig_cached_path} {package_file}" 

            if "OK" in os.popen(command).read():
                return key
            elif verbose:
                print(colors.RED 
                        + f"Failed to verify signature against {key}"
                        + colors.RESET)

    elif verbose:
        print(colors.BLACK + "There are no keys to verify with")
    return ""

def retrieve_package_info(sources, checksum, package_name, config,
                            verbose=False, skip_verification=False):

    sources_list=config["dir"]["sources"]
    cache_dir=config["dir"]["cache"]
    
    # TODO we may potentially do this a few times while resolving deps, might want to cache things here
    for source in get_best_source(sources, sources_list=sources_list):
        url = sources[source]

        package_info_url = util.add_path(url, package_name + ".xipkg.info")
        status, response = util.curl(package_info_url, raw=True)
   
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

def retrieve_package(sources, package_info, package_name, config,
                            verbose=False, skip_verification=False):

    sources_list=config["dir"]["sources"]
    cache_dir=config["dir"]["cache"]
    keychain_dir=config["dir"]["keychain"]
    
    checksum = package_info["CHECKSUM"]

    for source in get_best_source(sources, sources_list=sources_list):
        url = sources[source]
        if verbose:
            print(colors.LIGHT_BLACK + f"using source {source} at {url}")
        package_url = util.add_path(url, package_name + ".xipkg")
        package_dir = util.add_path(cache_dir, source)

        util.mkdir(package_dir)
        status, package_path = util.curl_to_file(package_url, util.add_path(package_dir, package_name + ".xipkg"), text=package_name + ".xipkg")

        if status == 200:
            downloaded_checksum = util.md5sum(package_path)
            
            if not skip_verification:
                if downloaded_checksum == checksum:
                    sig = verify_signature(package_path, package_info, 
                            cache_dir=cache_dir, keychain_dir=keychain_dir, verbose=verbose)
                    if len(sig) > 0:
                        print(colors.RESET)
                        return package_path, source, sig
                    elif verbose:
                        print(colors.RED 
                                + f"Failed to verify signature for {package_name} in {source}" 
                                + colors.RESET)
                elif verbose:
                        print(colors.RED 
                                + f"Checksum verification failed for {package_name} in {source}" 
                                + colors.RESET)
            else:
                print(colors.RESET)
                return package_path, source, "none"
    print(colors.RESET + colors.RED + f"No valid packages found for {package_name}" + colors.RESET)
    return ""

def parse_package_info(packageinfo):
    info = {}
    lines = packageinfo.split(b"\n")

    index = 0
    while index < len(lines):
        line = lines[index]
        split = line.split(b"=")
        if len(split) > 1:
            if split[0] == b"SIGNATURE":
                index += 1
                digest = b"\n".join(lines[index:])
                info["SIGNATURE"] = digest
                break;
            else:
                info[str(split[0], "utf-8")] = str(b"=".join(split[1:]), "utf-8")
        index += 1
    return info

def resolve_dependencies(package_info):
    return [
                dep 
                for dep in re.findall("\w*", package_info["DEPS"]) 
                if len(dep) > 0
            ]

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
                        dep_sources, dep_checksum, dep, config,
                        verbose=options["v"], skip_verification=options["u"]
                    )

            if len(info) > 0:
                if not dep in all_deps:
                    all_deps.append(dep)
                    deps = resolve_dependencies(info)
                    for dep in deps:
                        if not dep in all_deps:
                            if is_installed(dep, config, options["r"]):
                                print(colors.YELLOW + f"Package {query} has already been installed")
                            else:
                                to_check.append(dep)
            elif options["v"]:
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

def is_installed(package_name, config, root="/"):
    installed_dir = util.add_path(root, config["dir"]["installed"])
    if os.path.exists(installed_dir):
        files = os.listdir(installed_dir)
        return package_name in files
    return False

def install_package(package_name, package_path, package_info, 
        repo, source_url, key,
        config, root="/"):
    # untar and move into root
    # then add entry in the config["dir"]["installed"]

    installed_dir = util.add_path(root, config["dir"]["installed", package_name])
    util.mkdir(installed_dir)

    # TODO save which files are installed in installed/package/files for futher reference (ie which package does this file belong to?)
    
    name = package_info["NAME"]
    description = package_info["DESCRIPTION"]
    installed_checksum = package_info["CHECKSUM"]
    build_date = package_info["DATE"]
    version = package_info["VER_HASH"]
    installed_date = os.popen("date").read()

    package_url = util.add_path(source_url, repo, package_name + ".xipkg")

    info_file = util.add_path(installed_dir, info)
    with open(info_file, "w") as file:
        file.write(f"NAME={name}\n")
        file.write(f"DESCRIPTION={description}\n")
        file.write(f"CHECKSUM={installed_checksum}\n")
        file.write(f"VERSION={version}\n")
        file.write(f"INSTALL_DATE={installed_date}\n")
        file.write(f"BUILD_DATE={build_date}\n")
        file.write(f"KEY={key}\n")
        file.write(f"URL={package_url}\n")
        file.write(f"REPO={repo}\n")
        file.write(f"URL={}\n")

    pass


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

            for package in to_install:
                checksum, sources, repo = find_package(package, config["repos"],
                        config["dir"]["packages"], config["sources"])

                info = retrieve_package_info(
                            sources, checksum, package, config,
                            verbose=v, skip_verification=unsafe
                        )

                retrieve_package(sources, info, package, config,
                        verbose=v, skip_verification=unsafe)
        else:
            print(colors.RED + "Action cancelled by user")
    else:
        print(colors.LIGHT_RED + "Nothing to do")


