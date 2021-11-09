import os
import util
import colors
import time

CACHE_DIR = "/var/cache/xipkg"

def list_packages(url):
    status, response = util.curl(url + "/packages.list")
    if status != 200:
        return {}
    else:
        return {
                line.split()[0].split(".")[0]: line.split()[1]
                for line in response.split("\n") if len(line.split()) >  0
                }
        
def sync_packages(repo, sources, verbose=False):
    packages = {}
    total = 0
    completed = 0
    for source,url in sources.items():

        listed = list_packages(url + repo if url[-1] == "/" else f"/{repo}")
        if len(listed) == 0 and verbose:
            print(colors.BG_RED + f"No packages found in {source}/{repo}" + colors.RESET)
        total += len(listed)
        for p in listed:
            if not p in packages:
                packages[p] = []

            packages[p].append((listed[p], source))
            completed += 1
            util.loading_bar(completed, total, f"Syncing {repo}")
    return packages

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

def sync(args, options, config):
    sources = config["sources"]
    repos = config["repos"]

    v = options["v"]

    for repo in repos:
        packages = sync_packages(repo, sources, verbose=v)
        
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
