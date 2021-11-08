"""xipkg config file parser

    Simple Key value, supporting map-style objects and arrays

    ```
    key      value
    key2     another value

    # this is a commment

    map {
        mapkey1 value
        mapkey2 value
    }

    array [
        item1
        item2
        item3
        item4
    ]
    ```
"""
import sys
# TODO: add more validation to this

"""Parse a config file from a path into a python dict
    Args:
        file_path: (str) the path to the file
    Returns:
        (dict) the configuration
    

"""
def parse_file(file_path):
    with open(file_path, "r") as config_file:
        return _parse_config(config_file)


"""Parse a config file's lines, is also used for dictionaries within the config
    Args:
        config_file: (file) a file with the readline function
    Returns:
        (dict) the configuration that has been parsed

"""
def _parse_config(config_file):
    config = {}
    line = config_file.readline()
    while line:
        line = line.strip()
        if len(line) > 0 and (line[-1] == "}" or line[-1] == "]"):
            return config
        else:
            values = _parse_line(line.strip(), config_file)
            for k,v in values.items():
                config[k] = v
            line = config_file.readline()
    return config

"""Parse a single config ling
    Args:
        line: (str) the line to be parsed
        config_file: (file) the file that the line has been taken from
    Returns:
        (dict) the configuration that has been parsed from the single line

"""
def _parse_line(line, config_file):
    if len(line) == 0:
        return {}
    if line[0] == "#":
        return {}
    else:
        split = line.split(" ")
        key = split[0]
        value = " " if len(split) == 1 else " ".join(line.split(" ")[1:])

        # if starting with include, then include another file in the same config
        if key == "include":
            included = parse_conf(value)
            return included
        elif value[-1].endswith("{"):
            return {key: _parse_config(config_file)}
        elif value[-1].endswith("["):
            return {key: [k for k in _parse_config(config_file).keys()]}
        else:
            return {key: value}


