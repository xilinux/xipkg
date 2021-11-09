import os
import requests

TEMP_DIR = "/tmp/xipkg"

def curl(url):
    r = requests.get(url)
    return r.status_code, r.text

def mkdir(path):
    if not os.path.exists(path):
        os.makedirs(path)

def download_repo(output, url):
    pkg_list_url = url + "/packages.txt"

    status, response = curl(pkg_list_url)
    if status == 404:
        print("repo does not exist at", pkg_list_url)
    else:
        packages = response.split("\n")
        for package in packages:
            if len(package) > 0:
                pkg_url = url + "/" + package
                status, package_info = curl(pkg_url)

                if status == 200:
                    with open(os.path.join(output, package), "w") as file:
                        file.write(package_info)
                else:
                    print("package is missing at", pkg_url)

# have separate list and download methods for each scheme
def sync_package_infos(source_name, url, repos):

    source_dir = os.path.join(TEMP_DIR, source_name)

    scheme = url.split(":")[0]
    
    print(url)
    # TODO: add ftp
    if scheme.startswith("http"):
        sync_func = download_repo
    else:
        # Assume its a location on the file system
        sync_func = copy_repo

    for repo in repos:
        out = os.path.join(TEMP_DIR, repo)
        mkdir(out)
        sync_func(out, url + repo if url[-1] == "/" else f"/{repo}")

        
def sync(options, config):
    sources = config["sources"]
    repos = config["repos"]

    mkdir(TEMP_DIR)
    for source, url in sources.items():
        sync_package_infos(source, url, repos)
    print("Synced!")
