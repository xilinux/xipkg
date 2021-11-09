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
        
def sync_packages(repo, sources):
    packages = {}
    total = 0
    completed = 0
    for source,url in sources.items():

        listed = list_packages(url + repo if url[-1] == "/" else f"/{repo}")
        total += len(listed)
        for p in listed:
            if not p in packages:
                packages[p] = []

            packages[p].append((listed[p], source))
            completed += 1
            util.loading_bar(completed, total, f"Syncing {repo}")
    return packages

def validate_packages(packages, repo):
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

    


def sync(args, options, config):
    sources = config["sources"]
    repos = config["repos"]

    for repo in repos:
        packages = sync_packages(repo, sources)
        
        # find the most popular hash to use
        validated = validate_packages(packages, repo)

        save_package_list(validated, os.path.join(config["dir"]["packages"], repo))

        num_packages = len(validated)
        util.loading_bar(num_packages, num_packages, f"Synced {repo}")
        print(colors.RESET)

            
            
            

    print("Synced!")
