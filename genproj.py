''' script to generate libero project from version-controllable source files '''

# MIT License
#
# Copyright (c) 2023 Quinn Unger
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import sys
import os
import re
import json
import time
import shutil
import argparse
from enum import IntEnum

parser = argparse.ArgumentParser(
    prog='genproj',
    description='generate libero project from version-controllable source files'
)
parser.add_argument('-c', '--config',
    default='config.json'
)
parser.add_argument('-e', '--executable',
    default='libero'
)
args = parser.parse_args()

# load the config json
with open(args.config, encoding='utf8') as f:
    config = json.load(f)['libero']['project']

# set working directory to the config's location, to ensure relative paths resolve properly.
chdir_target = os.path.dirname(args.config)
if chdir_target == '':
    chdir_target = os.path.dirname(f'./{args.config}')
os.chdir(chdir_target)

class SG(IntEnum):
    ''' Enum indexes for search_group array '''
    REGEX = 0
    FILE = 1
search_group = {
    'search_hdl':    [ re.compile(".*\\.(sv|v|vhd)$", re.IGNORECASE), [] ],
    'search_sdc':    [ re.compile(".*\\.sdc$",        re.IGNORECASE), [] ],
    'search_ndc':    [ re.compile(".*\\.ndc$",        re.IGNORECASE), [] ],
    'search_fdc':    [ re.compile(".*\\.fdc$",        re.IGNORECASE), [] ],
    'search_vcd':    [ re.compile(".*\\.vcd$",        re.IGNORECASE), [] ],
    'search_fp_pdc': [ re.compile(".*\\.pdc$",        re.IGNORECASE), [] ],
    'search_io_pdc': [ re.compile(".*\\.pdc$",        re.IGNORECASE), [] ],
    'search_edif':   [ re.compile(".*\\.edif$",       re.IGNORECASE), [] ],
    'search_tcl':    [ re.compile(".*\\.tcl$",        re.IGNORECASE), [] ]
}

class Lookup:
    ''' File list lookup table builder with warning and error messages '''
    PATH = 0
    DUPE = 1
    file_dict = {}
    def record(self,file_path):
        ''' Record filename & path to a dictionary & check for duplicate file basenames '''
        file_full = os.path.abspath(file_path)
        file_base = os.path.basename(file_path)
        if file_base in self.file_dict:
            print('Warning: Duplicate file found! This may screw with path substitutions!'\
                f'\n\tStored: {self.file_dict[file_base][self.PATH]}\n\tFound: {file_full}')
            self.file_dict[file_base][self.DUPE] += 1
        else:
            self.file_dict[file_base] = [file_full,0]
    def recall(self,file_path):
        ''' Strip file path down to the basename and look for a match in the dictionary '''
        file_base = os.path.basename(file_path)
        if file_base in self.file_dict:
            if self.file_dict[file_base][self.DUPE] > 0:
                print('Warning: Multiple files encountered while trying to do a path substitution!'\
                    f'\n\tPath to substitute: {file_path}'\
                    f'\n\tChoosing file: {self.file_dict[file_base][self.PATH]}')
            return self.file_dict[file_base][self.PATH]
        print('Error: Unable to find suitable path substitution! (local file not found)'\
            f'\n\tSearch target: {file_base}\n\tReferenced from: {file_path}')
        sys.exit()

tracker = Lookup()

for search_key, search_type in search_group.items():
    if search_key not in config:
        continue
    for entry in config[search_key]:
        recurse = bool('recursive' in entry and entry['recursive'] is True)
        for path, dirs, files in os.walk(entry['path']):
            for file in files:
                if search_type[SG.REGEX].match(file):
                    search_type[SG.FILE].append(os.path.abspath(f'{path}/{file}'))
                    tracker.record(f'{path}/{file}')
            if recurse is False:
                break

proj_name = config['name']
library   = config['library']
top       = config['top']
out_root  = os.path.abspath(config['output'])
out_tcl   = os.path.abspath(f'{out_root}/{proj_name}.tcl')
out_proj  = os.path.abspath(f'{out_root}/{proj_name}')
device    = config['device']
settings  = config['project_settings']

# clear the tcl if exists
with open(out_tcl, 'w', encoding='utf8'):
    pass
# write line-by-line
with open(out_tcl, 'a', encoding='utf8') as o:
    # Create project
    o.write(f'new_project -location {{{out_proj}}}'\
        f' -name {{{proj_name}}} -family {{{device["family"]}}} -die {{{device["die"]}}}'\
        f' -package {{{device["package"]}}} -speed {{{device["speed"]}}}'\
        f' -part_range {{{device["part_range"]}}} -hdl {{{settings["hdl"]}}}\n')
    # Project settings
    o.write('project_settings')
    for key, val in settings.items():
        o.write(f' -{key} {str(int(val is True)) if isinstance(val,bool) else f"{{{str(val)}}}"}')
    o.write('\n')
    # Get cores up to date
    o.write('download_latest_cores\n')
    # Link files
    for file in search_group['search_hdl'][SG.FILE]:
        o.write(f'create_links -library {{{library}}} -hdl_source {{{file}}}\n')
    for file in search_group['search_sdc'][SG.FILE]:
        o.write(f'create_links -library {{{library}}} -sdc {{{file}}}\n')
    for file in search_group['search_ndc'][SG.FILE]:
        o.write(f'create_links -library {{{library}}} -ndc {{{file}}}\n')
    for file in search_group['search_fdc'][SG.FILE]:
        o.write(f'create_links -library {{{library}}} -fdc {{{file}}}\n')
    for file in search_group['search_vcd'][SG.FILE]:
        o.write(f'create_links -library {{{library}}} -vcd {{{file}}}\n')
    for file in search_group['search_fp_pdc'][SG.FILE]:
        o.write(f'create_links -library {{{library}}} -fp_pdc {{{file}}}\n')
    for file in search_group['search_io_pdc'][SG.FILE]:
        o.write(f'create_links -library {{{library}}} -io_pdc {{{file}}}\n')
    for file in search_group['search_edif'][SG.FILE]:
        o.write(f'create_links -library {{{library}}} -convert_EDN_to_HDL -edif {{{file}}}\n')
    # Build heirarchy
    o.write('build_design_hierarchy\n')
    # Fix file links in TCL includes
    for file in search_group['search_tcl'][SG.FILE]:
        o.write(f'\n# File: {file}\n')
        with open(file, encoding='utf8') as f:
            lines = f.readlines()
        for line in lines:
            o.write(re.sub(r'(^sd_instantiate_hdl_module.*-hdl_file {)(.*)(} -instance_name.*$)',
                lambda m : m.group(1)+tracker.recall(m.group(2))+m.group(3), line))
    # Set top level and rebuild heirarchy after running the tcl scripts
    o.write(f'set_root {{{top}}}\n')
    o.write('build_design_hierarchy\n')
    # Assign constraints
    if 'enable_constraint' in config:
        constraint = config['enable_constraint']
        if 'PLACEROUTE' in constraint and constraint['PLACEROUTE']:
            o.write(r'organize_tool_files -tool {PLACEROUTE}')
            for file in constraint['PLACEROUTE']:
                o.write(f' -file {{{os.path.abspath(file)}}}')
            o.write(f' -module {{{top}::{library}}} -input_type {{constraint}}\n')
        if 'SYNTHESIZE' in constraint and constraint['SYNTHESIZE']:
            o.write(r'organize_tool_files -tool {SYNTHESIZE}')
            for file in constraint['SYNTHESIZE']:
                o.write(f' -file {{{os.path.abspath(file)}}}')
            o.write(f' -module {{{top}::{library}}} -input_type {{constraint}}\n')
        if 'VERIFYTIMING' in constraint and constraint['VERIFYTIMING']:
            o.write(r'organize_tool_files -tool {VERIFYTIMING}')
            for file in constraint['VERIFYTIMING']:
                o.write(f' -file {{{os.path.abspath(file)}}}')
            o.write(f' -module {{{top}::{library}}} -input_type {{constraint}}\n')
    # Save and close project
    o.write('save_project\n')
    o.write('close_project\n')

if config['backup'] is True and os.path.isdir(out_proj):
    shutil.make_archive(f'{out_root}/backup/{proj_name}-{time.strftime("%Y%m%d-%H%M%S")}',
        'zip', root_dir=out_proj, base_dir=out_proj)
