import sys
import os
import re
import json
import argparse

parser = argparse.ArgumentParser(
    prog='genproj',
    description='generate libero project from version-controllable source files'
)
parser.add_argument('-c', '--config',
    default='genproj.json'
)
parser.add_argument('-e', '--executable',
    default='libero'
)
args = parser.parse_args()

# load the config json
with open(args.config, encoding='utf8') as f:
    config = json.load(f)

# set working directory to the config's location, to ensure relative paths resolve properly.
os.chdir(os.path.dirname(args.config))

print(config['libero'])

re_edif       = re.compile(".*\\.edif$",       re.IGNORECASE)
re_sdc        = re.compile(".*\\.sdc$",        re.IGNORECASE)
re_ndc        = re.compile(".*\\.ndc$",        re.IGNORECASE)
re_fp_pdc     = re.compile(".*_fp\\.pdc$",     re.IGNORECASE)
re_io_pdc     = re.compile(".*_io\\.pdc$",     re.IGNORECASE)
re_net_fdc    = re.compile(".*\\.fdc$",        re.IGNORECASE)
re_vcd        = re.compile(".*\\.vcd$",        re.IGNORECASE)
re_hdl_source = re.compile(".*\\.(sv|v|vhd)$", re.IGNORECASE)
re_tcl_source = re.compile(".*\\.tcl$",        re.IGNORECASE)
