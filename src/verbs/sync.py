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
    total = 0
    completed = 0

    speeds = {}
    for source,url in sources.items():

        listed, speed = list_packages(url + repo if url[-1] == "/" else f"/{repo}")

        if speed > 0:
            speeds[source] = speed

        if len(listed) == 0 and verbose:
            print(colors.BG_RED + f"No packages found in {source}/{repo}" + colors.RESET)

        total += len(listed)
        for p in listed:
            if not p in packages:
                packages[p] = []

            packages[p].append((listed[p], source))
            completed += 1
            util.loading_bar(completed, total, f"Syncing {repo}")

    return packages, speeds

def validate_packages(packages, repo, verbose=False):
    output = {}
    completed = 0
    total = len(packages)
    for package, versions in packages.items():
        popularity = {}
        for v in versions:
            checksum = v[0]
            source = v[1]
            if not checksum in popularity:
                popularity[checksum] = 0
            popularity[checksum] += 1

        most_popular = sorted(popularity)[0]
        
        # change the packages dict to list all the sources
        output[package] = {
                "checksum": most_popular,
                "sources" : [v[1] for v in versions if v[0] == most_popular]
                }
        completed += 1
        util.loading_bar(completed, total, f"Validating {repo}")
    return output

def save_package_list(validated, location):
    util.mkdir(location)
    for package,info in validated.items():
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
        packages, speeds = sync_packages(repo, sources, verbose=v)
        
        sorted(speeds)
        with open(config["dir"]["sources"], "w") as file:
            for source,ping in speeds.items():
                file.write(f"{source} {ping}\n")
        
        # find the most popular hash to use
        validated = validate_packages(packages, repo, verbose=v)

        save_package_list(validated, os.path.join(config["dir"]["packages"], repo))

        num_packages = len(validated)
        util.loading_bar(num_packages, num_packages, f"Synced {repo}")
        print(colors.RESET)
    

    #total = len(sources)
    #completed = 0
    #for source, url in sources:
        #compelted += 1 
        #util.loading_bar(completed, total, f"Importing keys")
