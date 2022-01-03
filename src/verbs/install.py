import os
import re
import util
import colors
import time
import requests
import hashlib

from verbs.sync import sync

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

    # TODO or find cached package checksum from the cache folder
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
        # TODO if exists maybe just use cached version
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
        
        # probably better way to implement this obligatory wildcard
        # 100% sure there is a better way of doing this than installing all packages from a repo
        # maybe some sort of package grouping (or empty package with deps on all needed)
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
                                if options["v"]: print(colors.YELLOW + f"Package {dep} has already been installed")
                            else:
                                to_check.append(dep)
            elif options["v"]:
                    util.print_reset(colors.CLEAR_LINE + colors.RED + f"Failed to retrieve info for {dep}")
        else:
            if options["v"]: util.print_reset(colors.CLEAR_LINE + colors.RED + f"Failed to find package {dep}")

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
        repo, source_url, key, post_install,
        config, verbose=False, root="/"):

    # TODO loading bar here
    files = util.extract_tar(package_path, root)
    if post_install:
        run_post_install(config, verbose=verbose, root=root)
    save_installed_info(package_name, package_info, files, repo, source_url, key, config, root=root)

    

def save_installed_info(package_name, package_info,
        files, repo, source_url, key, 
        config, root=""):
    installed_dir = util.add_path(root, config["dir"]["installed"], package_name)
    util.mkdir(installed_dir)

    name = package_info["NAME"]
    description = package_info["DESCRIPTION"] if "DESCRIPTION" in package_info else ""
    installed_checksum = package_info["CHECKSUM"]
    build_date = package_info["DATE"]
    version = package_info["VER_HASH"]
    installed_date = os.popen("date").read()

    package_url = util.add_path(source_url, repo, package_name + ".xipkg")

    info_file = util.add_path(installed_dir, "info")
    with open(info_file, "w") as file:
        file.write(f"NAME={name}\n")
        file.write(f"DESCRIPTION={description}\n")
        file.write(f"CHECKSUM={installed_checksum}\n")
        file.write(f"VERSION={version}\n")
        file.write(f"INSTALL_DATE={installed_date}")
        file.write(f"BUILD_DATE={build_date}\n")
        file.write(f"KEY={key}\n")
        file.write(f"URL={package_url}\n")
        file.write(f"REPO={repo}\n")

    files_file = util.add_path(installed_dir, "files")
    with open(files_file, "w") as file:
        file.write(files)

    pass

def install_single(package, options, config, post_install=True, verbose=False, unsafe=False):
    checksum, sources, repo = find_package(package, config["repos"],
            config["dir"]["packages"], config["sources"])

    info = retrieve_package_info(
                sources, checksum, package, config,
                verbose=verbose, skip_verification=unsafe
            )

    package_path, source, key = retrieve_package(sources, 
            info, package, config, 
            verbose=verbose, skip_verification=unsafe)

    files = install_package(package, package_path, info, 
            repo, sources[source], key, post_install,
            config, verbose=verbose, root=options["r"])

def run_post_install(config, verbose=False, root="/"):
    installed_dir = util.add_path(root, config["dir"]["postinstall"])
    if os.path.exists(installed_dir):
        files = os.listdir(installed_dir)
        for file in files:
            f = util.add_path(config["dir"]["postinstall"], file)
            command = f"sh {f}"
            if root != "/":
                os.chroot(root)
            os.chdir("/")
            os.system(command)
            os.remove(f)

def install(args, options, config):
    if not options["l"]:
        sync(args, options, config)

    sources = config["sources"]
    repos = config["repos"]

    v = options["v"]
    unsafe = options["u"]

    packages_dir = config["dir"]["packages"]

    # have some interaction with sudo when necessary rather than always require it
    # this check may need to be done sooner?
    if util.is_root() or options["r"] != "/":
        to_install = args if options["n"] else find_all_dependencies(args, options, config)

        if len(to_install) > 0:
            print(colors.CLEAR_LINE + colors.RESET, end="")
            print(colors.BLUE + "The following packages will be installed:")
            print(end="\t")
            for d in to_install:
                print(colors.BLUE if d in args else colors.LIGHT_BLUE, d, end="")
            print()

            if util.ask_confirmation(colors.BLUE + "Continue?", no_confirm=options["y"]):

                for package in to_install:
                    try:
                        install_single(package, options, config, verbose=v, unsafe=unsafe)
                        util.fill_line(f"Installed {package}", colors.BG_CYAN + colors.LIGHT_BLACK, end="\n")
                    except Exception as e:
                        util.fill_line(f"Failed to install {package}", colors.BG_RED + colors.LIGHT_BLACK, end="\n")
                        util.fill_line(str(e), colors.CLEAR_LINE + colors.RESET + colors.RED, end="\n")


            else:
                print(colors.RED + "Action cancelled by user")
        else:
            print(colors.LIGHT_RED + "Nothing to do")
    else:
        print(colors.RED + "Root is required to install packages")


