import os
import util
import colors
import shutil
import time

CACHE_DIR = "/var/cache/xipkg"

# returns a dictionary, and duration:
#   key: package name
#   value: list of info [checksum, size]
def list_packages(url):
    start = time.time()
    status, response = util.curl(url + "/packages.list")
    duration = (time.time() - start) * 1000
    if status != 200:
        return {}, -1
    else:
        duration /= len(response)
        return {
                line.split()[0].split(".")[0]: " ".join(line.split()[1:])
                for line in response.split("\n") if len(line.split()) >  0
                }, duration
        

def sync_packages(repo, sources, verbose=False):
    versions = {}

    speeds = {}
    for source,url in sources.items():
        listed, speed = list_packages(url + repo if url[-1] == "/" else f"/{repo}")

        if speed > 0:
            speeds[source] = speed

        if verbose:
            if len(listed) == 0:
                print(colors.RED + f"No packages found in {source}/{repo}" + colors.RESET)
            else:
                print(colors.BLACK + f"{len(listed)} packages found in {source}/{repo}" + colors.RESET)

        for p in listed:
            if not p in versions: versions[p] = []
            versions[p].append((listed[p], source))

    return versions, speeds

def validate_package(package, versions, repo, verbose=False):
    popularity = {}
    for v in versions:
        info = v[0]
        source = v[1]
        if not info in popularity:
            popularity[info] = 0
        popularity[info] += 1

    most_popular = ""
    p_count = -1
    for p,c in popularity.items():
        if c > p_count:
            most_popular = p
            p_count = c

    sources = [v[1] for v in versions if v[0] == most_popular]
    
    # change the packages dict to list all the sources
    # maybe some validation here
    info = {
            "checksum": most_popular.split()[0],
            "size": most_popular.split()[1],
            "files": most_popular.split()[2],
            "sources" : sources
            }
    return info

def save_package(package, info, location):
    util.mkdir(location)
    package_file = os.path.join(location, package)
    
    exists = False
    if os.path.exists(package_file):
        with open(package_file, "r") as file:
            text = file.read()
            exists = info["checksum"] in text

    content = ""
    with open(package_file, "w") as file:
        file.write("checksum=" + info["checksum"] + "\n")
        file.write("size=" + info["size"] + "\n")
        file.write("files=" + info["files"] + "\n")
        file.write("sources=" + " ".join([source for source in info["sources"]]))

    return exists


def test_source(source, url):
    # requesting a resource may not be the best way to do this, caching etc
    start = time.time()
    code, reponse = util.curl(util.add_path(url, "index.html"))
    if code == 200:
        return int((time.time() - start) * 1000)
    else:
        return -1

def test_sources(sources, file_path, test_count=10):
    if test_count > 0:
        pings = {}
        checked = 0
        for source,url in sources.items():
            total = 0
            for i in range(test_count):
                total += test_source(source, url)
                util.loading_bar(checked, len(sources) * test_count, f"Pinging Sources")
                checked += 1
            if total > 0:
                pings[source] = int(total / test_count) if total > 0 else 0


        sorted(pings)
        
        with open(file_path, "w") as file:
            for source,ping in pings.items():
                file.write(f"{source} {ping}\n")

        util.loading_bar(checked, len(sources) * test_count, f"Pinged Sources")
        print()


def sync(args, options, config):
    sources = config["sources"]
    repos = config["repos"]

    v = options["v"]

    new = 0
    
    for repo in repos:
        if v: print(colors.LIGHT_BLACK + f"downloading package lists for {repo}...")

        packages, speeds = sync_packages(repo, sources, verbose=v)
        if v: print(colors.LIGHT_BLACK + f"downloaded {len(packages)} packages from {len(sources)} sources")
        
        sorted(speeds)
        with open(config["dir"]["sources"], "w") as file:
            for source,ping in speeds.items():
                file.write(f"{source} {ping}\n")
        
        repo_dir = os.path.join(config["dir"]["packages"], repo)
        if os.path.exists(repo_dir):
            shutil.rmtree(repo_dir)

        # find the most popular hash to use
        done = 0 
        total = len(packages.items())
        for package, versions in packages.items():
            info = validate_package(package, versions, repo, verbose=v)
            if not save_package(package, info, repo_dir):
                new += 1
            done += 1
            util.loading_bar(done, total, f"Syncing {repo}")

        util.loading_bar(total, total, f"Synced {repo}")
        print(colors.RESET)

    # this isnt new updates for install, this is new packages
    #if new > 0:
    #    util.fill_line(f"There are {new} new updates", colors.LIGHT_GREEN)



def import_key(name, url, config, verbose=False, root="/"):
    keychain_dir = util.add_path(root, config["dir"]["keychain"])
    util.mkdir(keychain_dir)
    key_path = os.path.join(keychain_dir, name + ".pub")

    if os.path.exists(key_path):
        print(colors.RED + f"Skipping existing key with name {name}")
    else:
        try:
            key_path = util.curl_to_file(url, key_path)
            print(colors.GREEN + f"Imported {name}.pub")
        except Exception as e:
            print(colors.RED + f"Failed to import key:", colors.RED + str(e))

def keyimport(args, options, config):
    if len(args) > 1:
        alias = args[0]
        url = args[1]
        
        import_key(alias, url, config, verbose=options["v"], root=options["r"])

    else:
        print(colors.RED + "Usage: keyimport <alias> <url>")

