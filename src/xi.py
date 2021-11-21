import options
import config

from verbs.sync import sync
from verbs.install import install

def search():
    pass
def remove():
    pass

verbs = { v: globals()[v] for v in [
                "search",
                "install",
                "remove",
                "sync"
            ]
        }

def main():
    opts = options.parse_args()
    args = opts["args"]
    
    if opts["h"]:
        options.print_usage()
        return

    conf = config.parse_file(opts["c"])
    if len(args) > 0:
        verb = args[0].lower()
        (
            verbs[verb] if verb in verbs else search
        )(
            args[1:] if len(args) > 1 else [], opts, conf
        )
    else:
        options.print_usage()
        return
