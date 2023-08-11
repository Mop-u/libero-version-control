configure_tool -name {SYNTHESIZE} \
-params {ACTIVE_IMPLEMENTATION:} \
-params {AUTO_COMPILE_POINT:true} \
-params {BLOCK_MODE:false} \
-params {BLOCK_PLACEMENT_CONFLICTS:ERROR} \
-params {BLOCK_ROUTING_CONFLICTS:LOCK} \
-params {CDC_MIN_NUM_SYNC_REGS:2} \
-params {CDC_REPORT:true} \
-params {CLOCK_ASYNC:800} \
-params {CLOCK_DATA:5000} \
-params {CLOCK_GATE_ENABLE:false} \
-params {CLOCK_GATE_ENABLE_THRESHOLD_GLOBAL:1000} \
-params {CLOCK_GATE_ENABLE_THRESHOLD_ROW:100} \
-params {CLOCK_GLOBAL:2} \
-params {PA4_GB_COUNT:36} \
-params {PA4_GB_MAX_RCLKINT_INSERTION:16} \
-params {PA4_GB_MIN_GB_FANOUT_TO_USE_RCLKINT:1000} \
-params {RAM_OPTIMIZED_FOR_POWER:0} \
-params {RETIMING:true} \
-params {ROM_TO_LOGIC:true} \
-params {SEQSHIFT_TO_URAM:1} \
-params {SYNPLIFY_OPTIONS:# http://coredocs.s3.amazonaws.com/Libero/2023_1/Tool/libero_ecf_ug.pdf page 93
# https://www.microsemi.com/document-portal/doc_view/136666-synopsys-fpga-synthesis-command-reference-manual-l2016-09m-2-for-libero-soc-v11-8
set_option -hdl_define -set "BUILD_LIBERO"; # custom define for our multi target hdl
set_option -use_fsm_explorer 1; # 0/1
set_option -frequency auto
set_option -write_verilog 1; # 0/1
set_option -write_vhdl 0; # 0/1
set_option -resolve_multiple_driver 0; # 1/0
set_option -rw_check_on_ram 1; # 0/1
set_option -auto_constrain_io 1; # 0/1
set_option -run_prop_extract 1; # 1/0
set_option -default_enum_encoding default; # default/onehot/sequential/gray
set_option -maxfan 30000
set_option -report_path 5000
set_option -update_models_cp 1; # 0/1
set_option -preserve_registers 0; # 1/0
set_option -continue_on_error 0; # 1/0
set_option -symbolic_fsm_compiler 1; # 1/0
set_option -compiler_compatible 0; # 0/1 Disables pushing of tristates across process/block boundaries
set_option -resource_sharing 1; # 1/0
set_option -write_apr_constraint 1; # 1/0
set_option -dup 0; # 1/0 allow duplicate module names
set_option -enable64bit 1; # 1/0
set_option -fanout_limit 50
set_option -frequency auto
set_option -looplimit 3000
set_option -num_critical_paths 10
set_option -safe_case 0; # 0/1
} \
-params {SYNPLIFY_TCL_FILE:} 

configure_tool -name {PLACEROUTE} \
-params {TDPR:true} \
-params {PDPR:false} \
-params {IOREG_COMBINING:true} \
-params {GB_DEMOTION:true} \
-params {REPLICATION:true} \
-params {EFFORT_LEVEL:false} \
-params {REPAIR_MIN_DELAY:true} \
-params {INCRPLACEANDROUTE:false} \
-params {MULTI_PASS_LAYOUT:false}

organize_tool_files -tool {PLACEROUTE} \
-file {./src/user_fp.pdc} \
-file {./src/user_io.pdc} \
-file {./src/user.sdc} \
-module {top_level::work} -input_type {constraint}

organize_tool_files -tool {SYNTHESIZE} \
-file {./src/user.sdc} \
-module {top_level::work} -input_type {constraint}

organize_tool_files -tool {VERIFYTIMING} \
-file {./src/user.sdc} \
-module {top_level::work} -input_type {constraint}
