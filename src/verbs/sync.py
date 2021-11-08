

# have separate list and download methods for each scheme
def sync_package_infos(source_name, url, repos):
    scheme = url.split(":")[0]
    
    # TODO: add ftp
    if scheme.startswith("http"):
        sync_func = download_repo
    else:
        # Assume its a location on the file system
        sync_func = copy_repo

    for repo in repos:
        sync_func(output, url + f"/{repo}" if url[-1] == "/" else repo)

        
def sync(options, config):
    sources = config["sources"]
    print("Synced!")
