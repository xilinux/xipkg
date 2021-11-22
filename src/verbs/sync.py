import os
import util
import colors
import time

CACHE_DIR = "/var/cache/xipkg"

def list_packages(url):
    start = time.time()
    status, response = util.curl(url + "/packages.list")
    duration = (time.time() - start) * 1000
    if status != 200:
        return {}, -1
    else:
        duration /= len(response)
        return {
                line.split()[0].split(".")[0]: line.split()[1]
                for line in response.split("\n") if len(line.split()) >  0
                }, duration
        
def sync_packages(repo, sources, verbose=False):
    packages = {}

    speeds = {}
    for source,url in sources.items():

        listed, speed = list_packages(url + repo if url[-1] == "/" else f"/{repo}")

        if speed > 0:
            speeds[source] = speed

        if len(listed) == 0 and verbose:
            print(colors.RED + f"No packages found in {source}/{repo}" + colors.RESET)

        for p in listed:
            if not p in packages:
                packages[p] = []
            packages[p].append((listed[p], source))

    return packages, speeds

def validate_package(package, versions, repo, verbose=False):
    popularity = {}
    for v in versions:
        checksum = v[0]
        source = v[1]
        if not checksum in popularity:
            popularity[checksum] = 0
        popularity[checksum] += 1

    most_popular = sorted(popularity)[0]
    
    # change the packages dict to list all the sources
    return {
            "checksum": most_popular,
            "sources" : [v[1] for v in versions if v[0] == most_popular]
            }

def save_package(package, info, location):
    util.mkdir(location)
    package_file = os.path.join(location, package)
    
    content = ""
    with open(package_file, "w") as file:
        file.write("checksum=" + info["checksum"] + "\n")
        file.write("sources=" + " ".join([source for source in info["sources"]]))


###### !!! #######
# THIS SHOULD BE A USER ACTION 
# security problem to automatically decide to verify keys
# users should do this manually whenever they add a new source
###### !!! #######
def import_key(source, url, verbose=False):
    keyname = "xi.pub"
    status, response = curl(url + keyname if url[-1] == "/" else f"/{keyname}")

    if status == 200:
        key_path = os.path.join(config["dir"]["keychain"], source + ".pub")
        with open(key_path, "w"):
            key_path.write(key_path)

    elif verbose:
        print(colors.BG_RED + f"" + colors.RESET)


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

    # test_sources(sources, config["dir"]["sources"], test_count=int(config["pings"]))
    
    for repo in repos:
        if v:
            print(colors.LIGHT_BLACK + f"downloading package lists for {repo}...")
        packages, speeds = sync_packages(repo, sources, verbose=v)
        if v: print(colors.LIGHT_BLACK + f"downloaded {len(packages)} packages from {len(sources)} sources")
        
        sorted(speeds)
        with open(config["dir"]["sources"], "w") as file:
            for source,ping in speeds.items():
                file.write(f"{source} {ping}\n")
        
        # find the most popular hash to use
        done = 0 
        total = len(packages.items())
        for package,versions in packages.items():
            info = validate_package(package, versions, repo, verbose=v)
            save_package(package, info, os.path.join(config["dir"]["packages"], repo))
            done += 1
            util.loading_bar(done, total, f"Syncing {repo}")

        util.loading_bar(total, total, f"Synced {repo}")
        print(colors.RESET)
    

    #total = len(sources)
    #completed = 0
    #for source, url in sources:
        #compelted += 1 
        #util.loading_bar(completed, total, f"Importing keys")
