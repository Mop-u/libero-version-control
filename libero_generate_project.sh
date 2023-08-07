#!/bin/bash

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

# Generate tcl commands 

re_edif=".*\.edif$"
re_sdc=".*\.sdc$"
re_ndc=".*\.ndc$"
re_fp_pdc=".*_fp\.pdc$"
re_io_pdc=".*_io\.pdc$"
re_net_fdc=".*\.fdc$"
re_vcd=".*\.vcd$"
re_hdl_source=".*\.(sv|v|vhd)$"
re_tcl_source=".*\.tcl$"

usage() {
    #echo "$name [-Uh] [-e libero_exe] [-l library] [-x exclude_file_name] [-X exclude_folder_name] [-p link_path] [-P link_path_recursive] [-f link_file]"
    #echo "where:"
    echo "-U force resolving to Unix paths intead of Windows paths if running under WSL"
    echo "-h <arg> print this help message"
    echo "-e <arg> libero executable e.g. path/to/Libero/bin/libero (only needed if libero or libero.exe isn't on your PATH)"
    echo "-l <arg> libero library name e.g. 'work'"
    echo "-n <arg> libero project name"
    echo "-o <arg> libero project output path (<arg>/projname/*)"
    echo "-F <arg> libero family"
    echo "-D <arg> libero die"
    echo "-K <arg> libero package"
    echo "-S <arg> libero speed"
    echo "-R <arg> libero part range"
    echo "-L <arg> libero language"
    echo "-t <arg> project top level"
    echo "-x <arg> exclude filename from search"
    echo "-X <arg> exclude folder name from search"
    echo "-p <arg> link all files in a specified path (not recursive) e.g. path/to/rtl"
    echo "-P <arg> link all files in a specified path (recursive)"
    echo "-f <arg> link a single file e.g. path/to/rtl/module.v"
    echo "Link mapping as follows:"
    echo "    edif       <= $re_edif"
    echo "    sdc        <= $re_sdc "
    echo "    ndc        <= $re_ndc"
    echo "    fp_pdc     <= $re_fp_pdc"
    echo "    io_pdc     <= $re_io_pdc"
    echo "    net_fdc    <= $re_net_fdc"
    echo "    vcd        <= $re_vcd"
    echo "    hdl_source <= $re_hdl_source"
    echo "    tcl        <= $re_tcl_source"
}

libero="libero"
toplevel="TopLevel"
library="work"
name="project"
output_path=$(pwd)
family="PolarFire"
die="MPF300TS"
speed="STD"
package="FCG784"
part_range="IND"
language="VERILOG"

unset folder_arg
unset recursive_arg
unset file_arg
unset exclude_file_arg
unset exclude_folder_arg

convert_path() {
    if [ $is_wsl == true ]
    then
        echo $(wslpath -w "$1")
    else
        echo $(realpath "$1")
    fi
}
if [ -z ${WSL_DISTRO_NAME+x} ]
then 
    is_wsl=false
else 
    is_wsl=true
fi

# parse options
while getopts ":Uh:e:l:n:o:F:D:K:S:L:t:x:X:p:P:f:" OPTION; do
case "$OPTION" in 
    U) is_wsl=false ;;
    h) usage; exit 1 ;;
    e) libero="$OPTARG" ;;
    l) library="$OPTARG" ;;
    n) name="$OPTARG" ;;
    o) output_path="$(realpath "$OPTARG")" ;;
    F) family="$OPTARG" ;;
    D) die="$OPTARG" ;;
    K) package="$OPTARG" ;;
    S) speed="$OPTARG" ;;
    R) part_range="$OPTARG" ;;
    L) language="$OPTARG" ;;
    t) toplevel="$OPTARG" ;;
    x) exclude_file_arg+=("$(basename "$OPTARG")") ;;
    X) exclude_folder_arg+=("$(basename "$OPTARG")") ;;
    p) folder_arg+=("$(realpath "$OPTARG")") ;;
    P) recursive_arg+=("$(realpath "$OPTARG")") ;;
    f) file_arg+=("$(realpath "$OPTARG")") ;;
    ?) usage; exit 1 ;;
esac
done

# recursively obtain folder names
for folder in "${recursive_arg[@]}"; do
    while IFS= read -r -d '' x; do
        folder_arg+=("$x")
    done < <(find "$folder/" -type d -exec bash -c 'printf "%s\0" "$1"' bash "{}" \; )
done
unset recursive_arg

# generate file list from folders
for folder in "${folder_arg[@]}"; do
    do_exclude=false
    for exclude in "${exclude_folder_arg[@]}"; do
        if [ "$(basename "$folder")" == "$exclude" ]; then
            do_exclude=true
        fi
    done
    if [ $do_exclude == false ]; then
        for file in "$folder"/*; do
            if [ -f "$file" ]; then
                do_exclude=false
                for exclude in "${exclude_file_arg[@]}"; do
                    if [ "$(basename "$file")" == "$exclude" ]; then
                        do_exclude=true
                    fi
                done
                if [ $do_exclude == false ]; then
                    file_arg+=("$(realpath "$file")")
                fi
            fi
        done
    fi
done
unset folder_arg

# sort file list & remove duplicates
file_list=()
while IFS= read -r -d '' x; do 
    file_list+=("$x") 
done < <(printf "%s\0" "${file_arg[@]}" | sort -uz)
unset file_arg

unset edif_list
unset sdc_list
unset ndc_list
unset fp_pdc_list
unset io_pdc_list
unset net_fdc_list
unset vcd_list
unset hdl_source_list
unset hdl_source_dict
unset tcl_source_list
declare -A hdl_source_dict

# sort files into individual lists for processing
for file in "${file_list[@]}"; do
    if   [[ $file =~ $re_edif ]]; then
        edif_list+=("$file")
    elif [[ $file =~ $re_sdc ]]; then
        sdc_list+=("$file")
    elif [[ $file =~ $re_ndc ]]; then
        ndc_list+=("$file")
    elif [[ $file =~ $re_fp_pdc ]]; then
        fp_pdc_list+=("$file")
    elif [[ $file =~ $re_io_pdc ]]; then
        io_pdc_list+=("$file")
    elif [[ $file =~ $re_net_fdc ]]; then
        net_fdc_list+=("$file")
    elif [[ $file =~ $re_vcd ]]; then
        vcd_list+=("$file")
    elif [[ $file =~ $re_hdl_source ]]; then
        hdl_source_list+=("$file")
        hdl_source_dict["$(basename "$file")"]="$file"
    elif [[ $file =~ $re_tcl_source ]]; then
        tcl_source_list+=("$file")
    fi 
done
unset file_list

base() {
    echo "$(basename "$(echo "$1" | sed 's#\\#/#g')")"
}

sed_rhs() {
    echo "$(echo "$1" | sed 's:[\\/&]:\\&:g;$!s/$/\\/')"
}

get_sd_hdl_base() {
    echo "$(base "$(echo "$line" | sed '/\(^sd_instantiate_hdl_module.*-hdl_file {\)\(.*\)\(} -instance_name.*$\)/!d;s//\2/')")"
}

convert_sd_hdl_ref() {
    try_base="$(get_sd_hdl_base "$1")"
    if [ -n "$try_base" ]; then
        echo "$(convert_path "${hdl_source_dict["$try_base"]}")"
    else
        echo ""
    fi
}

replace_sd_hdl_ref() {
    echo "$(echo "$1" | sed 's/\(^sd_instantiate_hdl_module.*-hdl_file {\)\(.*\)\(} -instance_name.*$\)/\1'"$(sed_rhs "$(convert_sd_hdl_ref "$1")")"'\3/')"
}

process_tcl() {
    echo "$(replace_sd_hdl_ref "$1")"
}

stringify() {
    printf '%s' "$(echo "$1" | sed 's/\\/\\\\/g')\n"
}

mkdir -p "$output_path"
project_root="$(realpath "$output_path/project")"
gen_tcl="$(realpath "$output_path/genproj.tcl")"
gen_log="$(realpath "$output_path/genproj.log")"
rm "$gen_tcl"
rm "$gen_log"
rm -rf "$project_root"

str_out="$(stringify "# generated tcl script for creating this libero project")"

str_out+="$(stringify "# create new project")"
str_out+="$(stringify "new_project \\")"
str_out+="$(stringify "-location {$(convert_path "$project_root")} \\")"
str_out+="$(stringify "-name {$name} -family {$family} -die {$die} \\")"
str_out+="$(stringify "-package {$package} -speed {$speed} \\")"
str_out+="$(stringify "-part_range {$part_range} -hdl {VERILOG}")"

str_out+="$(stringify "# make sure all cores are downloaded so tcl core imports don't fail")"
str_out+="$(stringify "download_latest_cores")"

# link all files
for i in "${hdl_source_list[@]}"; do 
    str_out+="$(stringify "create_links -library {$library} -hdl_source {$(convert_path "$i")}")"
done
for i in "${sdc_list[@]}"; do 
    str_out+="$(stringify "create_links -library {$library} -sdc {$(convert_path "$i")}")"
done
for i in "${ndc_list[@]}"; do 
    str_out+="$(stringify "create_links -library {$library} -ndc {$(convert_path "$i")}")"
done
for i in "${fp_pdc_list[@]}"; do 
    str_out+="$(stringify "create_links -library {$library} -fp_pdc {$(convert_path "$i")}")"
done
for i in "${io_pdc_list[@]}"; do 
    str_out+="$(stringify "create_links -library {$library} -io_pdc {$(convert_path "$i")}")"
done
for i in "${net_fdc_list[@]}"; do 
    str_out+="$(stringify "create_links -library {$library} -net_fdc {$(convert_path "$i")}")"
done
for i in "${vcd_list[@]}"; do 
    str_out+="$(stringify "create_links -library {$library} -vcd {$(convert_path "$i")}")"
done
for i in "${edif_list[@]}"; do
    str_out+="$(stringify "create_links -library {$library} -convert_EDN_to_HDL 1 -edif {$(convert_path "$i")}")"
done
str_out+="$(stringify "build_design_hierarchy")\n"
for i in "${tcl_source_list[@]}"; do 
    while read -r line; do
        str_out+="$(stringify "$(replace_sd_hdl_ref "$line")")"
    done < $i
done
str_out+="$(stringify "set_root {$toplevel}")"
str_out+="$(stringify "build_design_hierarchy")"

if ! [[ -z ${sdc_list+x}  &&  -z ${io_pdc_list+x}  &&  -z ${fp_pdc_list+x} ]] ; then 
    str_out+="$(stringify "organize_tool_files -tool {PLACEROUTE} \\")"
    if ! [ -z ${sdc_list+x} ]; then
        str_out+="$(stringify "-file {$(convert_path "${sdc_list[0]}")} \\")"
    fi
    if ! [ -z ${io_pdc_list+x} ]; then
        str_out+="$(stringify "-file {$(convert_path "${io_pdc_list[0]}")} \\")"
    fi
    if ! [ -z ${fp_pdc_list+x} ]; then
        str_out+="$(stringify "-file {$(convert_path "${fp_pdc_list[0]}")} \\")"
    fi
    str_out+="$(stringify "-module {$toplevel::$library} -input_type {constraint}")"
fi

if ! [ -z ${sdc_list+x} ]; then
    str_out+="$(stringify "organize_tool_files -tool {SYNTHESIZE} \\")"
    str_out+="$(stringify "-file {$(convert_path "${sdc_list[0]}")} \\")"
    str_out+="$(stringify "-module {$toplevel::$library} -input_type {constraint}")"
    str_out+="$(stringify "organize_tool_files -tool {VERIFYTIMING} \\")"
    str_out+="$(stringify "-file {$(convert_path "${sdc_list[0]}")} \\")"
    str_out+="$(stringify "-module {$toplevel::$library} -input_type {constraint}")"
fi

# save the project
str_out+="$(stringify "save_project")"
str_out+="$(stringify "close_project")"

printf '%b\n' "$str_out" > "$gen_tcl"

#echo "TCL file for project generation saved at $(convert_path "$gen_log")"
$libero SCRIPT:"$(convert_path "$gen_tcl")" LOGFILE:"$(convert_path "$gen_log")"
cat "$gen_log"
echo "Log file saved at $(convert_path "$gen_log")"
