import os
import re
import util
import colors
import time
import requests
import hashlib

from verbs.sync import sync, run_post_install

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
                size = file.readline().strip().split("=")[-1]
                filecount = file.readline().strip().split("=")[-1]
                listed_sources = file.readline().strip().split("=")[-1].split()
                found_sources = {
                            source: util.add_path(url, repo) 
                            for source, url in sources.items() 
                            if source in listed_sources
                        }
                return checksum, found_sources, requested_repo, int(size)*1000, int(filecount)
    return None, [], None, 0, 0


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

# Does not verify the package itself, will only blindly accept the best size it can
def query_package_size(sources, package_info, package_name, config, verbose=False):
    sources_list=config["dir"]["sources"]
    for source in get_best_source(sources, sources_list=sources_list):
        url = sources[source]
        if verbose:
            print(colors.LIGHT_BLACK + f"using source {source} at {url} for {package_name}")

        package_url = util.add_path(url, package_name + ".xipkg")
        size = util.query_size(package_url)
        if size > 0:
            return size
    return 0

def retrieve_package(sources, package_info, package_name, config, completed=0, total_download=-1,
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

        if total_download == -1:
            text = package_name + ".xipkg"
        else:
            text = "packages..."

        # TODO if package already downloaded maybe just use cached version
        status, package_path, size = util.curl_to_file(package_url, util.add_path(package_dir, package_name + ".xipkg"),
                start=completed, total=total_download, text=text)

        if status == 200:
            downloaded_checksum = util.md5sum(package_path)
            
            if not skip_verification:
                if downloaded_checksum == checksum:
                    sig = verify_signature(package_path, package_info, 
                            cache_dir=cache_dir, keychain_dir=keychain_dir, verbose=verbose)
                    if len(sig) > 0:
                        return package_path, source, sig, size
                    elif verbose:
                        print(colors.RED 
                                + f"Failed to verify signature for {package_name} in {source}" 
                                + colors.RESET)
                elif verbose:
                        print(colors.RED 
                                + f"Checksum verification failed for {package_name} in {source}" 
                                + colors.RESET)
            else:
                return package_path, source, "none", size
    print(colors.RESET + colors.RED + f"No valid packages found for {package_name}" + colors.RESET)
    return "", "", "", 0

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

def get_available_version(package_name, config, root="/"):
    repos = config["repos"]
    packages_dir = config["dir"]["packages"]
    sources = config["sources"]
    checksum, found_sources, requested_repo, size, files = find_package(package_name, repos, packages_dir, sources)
    return checksum
    
def get_installed_version(package, config, root="/"):

    installed_info = util.add_path(root, config["dir"]["installed"], package, "info")
    if os.path.exists(installed_info):
        with open(installed_info) as file:
            for line in file:
                if line.startswith("CHECKSUM"):
                    return line.strip().split("=")[-1]
    return None

def update_needed(package, new_checksum, config, root="/"):
    version = get_installed_version(package, config, root)
    return not new_checksum == version

def resolve_dependencies(package_info):
    d = [
                dep 
                for dep in re.findall("[\w,-]*", package_info["DEPS"]) 
                if len(dep) > 0
            ]
    return d 

def find_all_dependencies(package_names, options, config):
    # this is all assuming that the order of deps installed doesn't matter
    failed = []
    to_check = [p for p in package_names]
    dependencies = {}

    while len(to_check) > 0:
        util.loading_bar(len(dependencies), len(dependencies) + len(to_check), "Resolving dependencies...")
        dep = to_check.pop()
        
        dep_checksum, dep_sources, dep_repo, size, files = find_package(dep, config["repos"], config["dir"]["packages"], config["sources"])

        if dep_checksum is not None:
            dependencies[dep] = dep_checksum

            info = retrieve_package_info(
                        dep_sources, dep_checksum, dep, config,
                        verbose=options["v"], skip_verification=options["u"]
                    )

            if len(info) > 0:
                    [to_check.append(d) for d in resolve_dependencies(info) if not (d in dependencies or d in to_check)]

            else:
                if not dep in failed: failed.append(dep)
                if options["v"]:
                        util.print_reset(colors.CLEAR_LINE + colors.RED + f"Failed to retrieve info for {dep}")
        else:
            if not dep in failed: failed.append(dep)
            if options["v"]: util.print_reset(colors.CLEAR_LINE + colors.RED + f"Failed to find package {dep}")

    util.loading_bar(len(dependencies), len(dependencies) + len(to_check), "Resolved dependencies")
    print(colors.RESET)

    to_install = []
    to_update = []
    for dep,checksum in dependencies.items():
        if not is_installed(dep, config, options["r"]):
            to_install.append(dep)
        elif update_needed(dep, checksum, config, options["r"]):
            to_update.append(dep)

    # assuming that the latter packages are core dependencies
    # we can reverse the array to reflect the more important packages to install
    to_install.reverse()
    to_update.reverse()
    return to_install, to_update, failed

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
    return files

    

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


def install_single(package, options, config, post_install=True, verbose=False, unsafe=False):
    checksum, sources, repo, size, files = find_package(package, config["repos"],
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


def install_multiple(to_install, args, options, config, terminology=("install", "installed", "installing")):
    v = options["v"]
    unsafe = options["u"]

    length = 0
    total_files = 0
    infos = []
    for package in to_install:
        util.loading_bar(len(infos), len(to_install), "Preparing Download")
        checksum, sources, repo, size, filecount = find_package(package, config["repos"],
                config["dir"]["packages"], config["sources"])

        if checksum != None:
            info = retrieve_package_info(
                        sources, checksum, package, config,
                        verbose=v, skip_verification=unsafe
                )

            # TODO make package_size be written in package info or sync list instead
            length += int(size)
            total_files += int(filecount)

            infos.append(
                    (package, sources, repo, info)
                    )

    divisor, unit = util.get_unit(length)

    util.loading_bar(len(infos), len(to_install), "Preparing Download")
    print(colors.RESET + colors.CLEAR_LINE, end="\r")

    print(colors.WHITE + "Total download size: " + colors.LIGHT_WHITE + str(round(length / divisor, 2)) + unit)

    if options["y"] or util.ask_confirmation(colors.WHITE + "Continue?"):
        # TODO try catch over each package in each stage so that we can know if there are errors

        downloaded = 0
        pkg_files = []
        for package_info in infos:
            (package, sources, repo, info) = package_info

            package_path, source, key, size = retrieve_package(sources, 
                    info, package, config, 
                    completed=downloaded, total_download=length,
                    verbose=v, skip_verification=unsafe)

            if package_path == "":
                print(colors.RED + f"Failed to download {package}")
            else:
                downloaded += size

                pkg_files.append(
                        (package, package_path, sources[source], key, repo, info)
                        )
        
        util.loading_bar(int(length/divisor), int(length/divisor), "Downloaded packages", unit=unit)
        print(colors.RESET)

        extracted = 0
        for f in pkg_files:
            util.loading_bar(extracted, total_files, terminology[2].capitalize() + " files")

            (package, package_path, source, key, repo, info) = f

            files = install_package(package, package_path, info, 
                    repo, source, key, options["r"] == "/",
                    config, verbose=v, root=options["r"])
            extracted += len(files.split("\n"))

        util.loading_bar(extracted, total_files, terminology[1].capitalize() + " files")
        print(colors.RESET)
    else:
        print(colors.RED + "Action cancelled by user")


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
        to_install, to_update, location_failed = args, [], []
        if options["n"]:
            for dep in to_install:
                dep_checksum, dep_sources, dep_repo, size, files = find_package(dep, config["repos"], config["dir"]["packages"], config["sources"])
                if dep_checksum is None:
                    to_install.remove(dep)
                    location_failed.append(dep)
    
        else:
            to_install, to_update, location_failed = find_all_dependencies(args, options, config)


        if len(location_failed) > 0:
            print(colors.RED + "Failed to locate the following packages:")
            print(end="\t")
            for d in location_failed:
                print(colors.RED if d in args else colors.LIGHT_RED, d, end="")
            print()

        together = []
        [together.append(p) for p in to_install]
        [together.append(p) for p in to_update]

        if len(together) > 0:

            if len(to_install) > 0:
                print(colors.BLUE + f"The following will be installed:")
                print(end="\t")
                for d in to_install:
                    print(colors.BLUE if d in args else colors.LIGHT_BLUE, d, end="")
                print()
            if len(to_update) > 0:
                print(colors.GREEN + f"The following will be updated:")
                print(end="\t")
                for d in to_update:
                    print(colors.GREEN if d in args else colors.LIGHT_GREEN, d, end="")
                print()

            install_multiple(together, args, options, config)
        else:
            installed = " ".join([arg for arg in args
                if is_installed(arg, config, options["r"])])
            if len(installed) > 0:
                print(colors.CYAN + "Already installed", colors.LIGHT_CYAN + installed)
            else:
                print(colors.LIGHT_BLACK + "Nothing to do")
    else:
        print(colors.RED + "Root is required to install packages")


