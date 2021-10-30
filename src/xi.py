import options

def search(terms):
    print(f"searching for {terms}")
    pass

def install(terms):
    print(f"installing for {terms}")
    pass

def remove(terms):
    print(f"removing for {terms}")
    pass

verbs = { v: globals()[v] for v in [
                "search",
                "install"
                "remove"
            ]
        }

def main():
    opts = options.parse_args()
    args = opts["args"]

    if opts["h"]:
        options.print_usage()
        return

    if len(args) > 0:
        verb = args[0].lower()
        (
            verbs[verb] if verb in verbs else search
        )(
            args[1:] if len(args) > 1 else []
        )
    else:
        options.print_usage()
        return
