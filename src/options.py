import sys

options = {
        "h": {
                "name": "help",
                "flag" : True,
                "desc" : "prints the command usage and exists the program",
            },
        "y" : {
                "name" : "no-confirm",
                "flag" : True,
                "desc": "will not prompt the user"
            },
        "r" : {
                "name" : "root",
                "flag" : False,
                "desc" : "specify the directory to use as the system root",
                "default" : "/"
            },
        "l": {
                "name" : "no-sync",
                "flag" : True,
                "desc" : "skip syncing with repo sources (not recommended)"
            },
        "u": {
                "name" : "unsafe",
                "flag" : True,
                "desc" : "skip any checksum or signature verification"
                },
        "n": {
                "name" : "no-deps",
                "flag" : True,
                "desc" : "do not resolve dependencies"
                },
        "v": {
                "name" : "verbose",
                "flag" : True,
                "desc" : "print more"
            },
        "c": {
                "name" : "config",
                "flag" : False,
                "desc" : "specify the configuration file to use",
                "default" : "/etc/xipkg.conf"
            }
        }

def parse_args():

    # re-organise the options by name rather than by single letter
    # a dict with "name": option_leter
    names = { v["name"] if v["name"] else k : k for k,v in options.items()}

    args = sys.argv
    index = 1

    # save all of the options into a "parsed" dictionary
    parsed = {"args" : []}

    while index < len(args):
        arg = args[index]

        if len(arg) > 1 and arg[0] == "-":
            option = []

            # is a named argument with a --
            if arg[1] == "-" and len(arg) > 2 and arg[2:].split("=")[0] in names:
                option.append(names[arg[2:].split("=")[0]])
            # is a single letter argument with a -
            else:
                for letter in arg[1:]:
                    if letter in options:
                        option.append(letter)

                if len(option) == 0:
                    parsed["args"].append(arg)


            # add the option and any values ot the parsed dict
            for opt in option:
                if opt is not None:
                    if options[opt]["flag"]:
                        parsed[opt] = True
                    else:
                        if "=" in arg:
                            parsed[opt] = arg.split("=")[1]
                        else:
                            index += 1
                            parsed[opt] = args[index]
        else:
            parsed["args"].append(arg)
    

        index += 1

    # add all default values to the parsed options
    for option in options:
        if not option in parsed:
            if options[option]["flag"]:
                parsed[option] = False
            else:
                parsed[option] = options[option]["default"]

    return parsed

def print_usage():
    for option,o in options.items():
        name = o["name"]
        description = o["desc"]
        d = ("[default=" + o["default"] + "]") if not o["flag"] else ""

        print(f"\t-{option}, --{name}\t{d}")
        print(f"\t\t{description}\n")

        if "verbs" in globals():
            print("Available actions:")
            for verb in verbs:
                print(f"\t{verb}")



