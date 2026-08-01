# =============================================================================
# build.tcl -- command-line workflow entry for the board project
# (Vivado Project Mode, Tcl-driven, no GUI)
#
# Usage (wrapped by build.ps1 / build.bat; can also be run directly):
#   vivado -mode batch -notrace -nojournal -source scripts/build.tcl -tclargs <target>
#
# Targets:
#   init      create project, add RTL / constraints / sim sources (idempotent)
#   synth     run synthesis (incremental)
#   impl      run implementation up to route_design (no bitstream, faster)
#   bitstream run implementation and generate .bit bitstream
#   program   download bitstream to FPGA over JTAG (SRAM config)
#   flash     generate SPI Flash image and program it (overwrites Flash!)
#   sim       run behavioral RTL simulation (xsim)
#   report    generate reports under build/reports/
#   clean     delete project and artifacts (keeps build/logs)
#   help      print this help
#
# Design principles (AI-friendly workflow):
#   - all paths are computed absolutely from the script location, cwd-independent
#   - on failure prints "ERROR: ..." and exits non-zero, so scripts/AI can tell
#   - all artifacts go under build/; source directories stay clean
#   - ASCII-only output: avoids Windows GBK/UTF-8 console encoding issues
# =============================================================================

# ---------------- Environment ----------------
# Force UTF-8 for reading Tcl sources (safe even if Chinese is added later).
encoding system utf-8

set script_dir [file dirname [info script]]
set root_dir   [file normalize [file join $script_dir ..]]
source [file join $root_dir config.tcl]

proc log {msg} {
    puts "\[build.tcl\] $msg"
    flush stdout
}

proc die {msg} {
    puts "ERROR: $msg"
    flush stdout
    exit 1
}

# ---------------- File collection ----------------
# Recursively collect matching files under dir (skips hidden and sim tmp dirs).
proc collect_files {dir patterns} {
    set result {}
    if {![file isdirectory $dir]} { return $result }
    foreach pat $patterns {
        foreach f [glob -nocomplain -dir $dir $pat] {
            if {[file isfile $f]} { lappend result $f }
        }
    }
    foreach sub [glob -nocomplain -dir $dir -type d *] {
        set name [file tail $sub]
        if {[string match ".*" $name]} { continue }
        if {$name eq "xsim.dir" || $name eq ".Xil"} { continue }
        foreach f [collect_files $sub $patterns] { lappend result $f }
    }
    return [lsort -unique $result]
}

# ---------------- Project management ----------------
proc project_open_p {} {
    set ok [catch {current_project} p]
    return [expr {$ok == 0 && [string length $p] > 0}]
}

proc ensure_project_open {} {
    if {[project_open_p]} { return }
    if {![file exists $::cfg(xpr)]} {
        die "project not found: $::cfg(xpr) -- run 'init' first"
    }
    open_project $::cfg(xpr)
    log "opened project: $::cfg(xpr)"
}

# ---------------- Target implementations ----------------
proc do_init {} {
    if {[file exists $::cfg(xpr)]} {
        log "project already exists: $::cfg(xpr) (run 'clean' to rebuild)"
        return
    }
    file mkdir [file dirname $::cfg(xpr)]

    create_project $::cfg(proj_name) [file dirname $::cfg(xpr)] -part $::cfg(part) -force

    # RTL sources
    set rtl_files [collect_files $::cfg(rtl_dir) {*.v *.sv *.vh}]
    if {[llength $rtl_files] > 0} {
        add_files -norecurse $rtl_files
        log "added RTL sources: [llength $rtl_files] file(s)"
    } else {
        log "WARNING: no .v/.sv source files under rtl/"
    }

    # Constraints
    set xdc_files [collect_files $::cfg(constr_dir) {*.xdc}]
    if {[llength $xdc_files] > 0} {
        add_files -fileset constrs_1 -norecurse $xdc_files
        log "added constraints: [llength $xdc_files] file(s)"
    }

    # Simulation sources
    set sim_files [collect_files $::cfg(sim_dir) {*.v *.sv}]
    if {[llength $sim_files] > 0} {
        add_files -fileset sim_1 -norecurse $sim_files
        set_property top $::cfg(sim_top) [get_filesets sim_1]
        log "added sim sources: [llength $sim_files] file(s) (top $::cfg(sim_top))"
    }

    # Local IP repo (enabled when ip/ contains .xci files)
    set ip_files [collect_files $::cfg(ip_dir) {*.xci}]
    if {[llength $ip_files] > 0} {
        set_property ip_repo_paths $::cfg(ip_dir) [current_project]
        add_files -norecurse $ip_files
        log "added IP: [llength $ip_files] file(s)"
    }

    set_property top $::cfg(top) [get_filesets sources_1]
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1

    log "project created: $::cfg(xpr)"
    log "board: $::cfg(board) (part $::cfg(part), clock $::cfg(clk_freq_mhz) MHz)"
}

# Reset a run so it can be relaunched. "not started" runs are left alone;
# complete runs are reset too when the caller decided a rebuild is needed.
proc reset_if_needed {run} {
    set st [string tolower [get_property STATUS [get_runs $run]]]
    if {$st eq "not started"} { return }
    log "resetting $run (status: \"$st\")"
    reset_run $run
}

# True if any RTL/constraint source is newer than the given artifact (mtime).
# Vivado's own out-of-date tracking can miss source edits (e.g. tools that
# preserve mtime, or runs already marked complete), so we check explicitly.
proc sources_newer_than {out} {
    if {![file exists $out]} { return 1 }
    set out_mtime [file mtime $out]
    foreach f [concat [collect_files $::cfg(rtl_dir) {*.v *.sv *.vh}] \
                     [collect_files $::cfg(constr_dir) {*.xdc}]] {
        if {[file mtime $f] > $out_mtime} { return 1 }
    }
    return 0
}

proc do_build {stage} {
    ensure_project_open

    switch -exact $stage {
        "synth"     { set run synth_1; set out $::cfg(synth_dcp) }
        "impl"      { set run impl_1;  set out $::cfg(impl_dcp) }
        "bitstream" { set run impl_1;  set out $::cfg(bit) }
        default     { die "internal error: unknown stage $stage" }
    }

    # Skip only if run is complete, artifact exists and no source is newer.
    set st_now [string tolower [get_property STATUS [get_runs $run]]]
    if {[file exists $out] && [string match "*complete*" $st_now] \
            && ![sources_newer_than $out]} {
        log "run $run already complete and up to date: $out (skip)"
        return
    }

    # For impl/bitstream, a stale synth checkpoint also forces a re-synthesis.
    if {$stage ne "synth" && [sources_newer_than $::cfg(synth_dcp)]} {
        reset_if_needed synth_1
    }
    reset_if_needed $run

    switch -exact $stage {
        "synth"     { launch_runs synth_1 -jobs $::cfg(jobs) }
        "impl"      { launch_runs impl_1 -to_step route_design -jobs $::cfg(jobs) }
        "bitstream" { launch_runs impl_1 -to_step write_bitstream -jobs $::cfg(jobs) }
    }

    log "running: $run (jobs=$::cfg(jobs)) ..."
    if {[catch {wait_on_run $run} err]} {
        die "run failed: $run -- $err (see build/logs or run reports)"
    }
    if {![file exists $out]} {
        die "run finished but artifact not found: $out -- check the log"
    }
    log "OK: $stage succeeded, artifact: $out"
}

proc do_program {} {
    if {![file exists $::cfg(bit)]} {
        die "bitstream not found: $::cfg(bit) -- run 'bitstream' first"
    }
    log "JTAG download: $::cfg(bit)"
    open_hw_manager
    if {[catch {
        connect_hw_server
        open_hw_target
    } err]} {
        close_hw_manager
        die "failed to connect JTAG: $err -- check board power, cable, drivers"
    }
    set devs [get_hw_devices]
    if {[llength $devs] == 0} {
        close_hw_manager
        die "no JTAG device found -- check cable and hw_server target"
    }
    current_hw_device [lindex $devs 0]
    set_property PROGRAM.FILE $::cfg(bit) [current_hw_device]
    program_hw_devices [current_hw_device]
    refresh_hw_device [current_hw_device]
    close_hw_manager
    log "programmed: SRAM config active (lost on power-off; use 'flash' to persist)"
}

proc do_flash {} {
    if {![file exists $::cfg(bit)]} {
        die "bitstream not found: $::cfg(bit) -- run 'bitstream' first"
    }
    # MX25L128 = 128 Mbit = 16 MB, SPIx1 (matches CONFIG_MODE in top.xdc)
    set bin [file rootname $::cfg(bit)].bin
    log "generating SPI Flash image: $bin"
    write_cfgmem -format bin -interface SPIx1 -size 16 \
        -loadbit "up 0x0 $::cfg(bit)" -force -file $bin

    log "programming SPI Flash (MX25L128) -- this OVERWRITES flash content ..."
    open_hw_manager
    connect_hw_server
    open_hw_target
    set devs [get_hw_devices]
    if {[llength $devs] == 0} {
        close_hw_manager
        die "no JTAG device found"
    }
    current_hw_device [lindex $devs 0]
    set_property PROGRAM.FILE $bin [current_hw_device]
    program_hw_devices [current_hw_device]
    close_hw_manager
    log "flash programmed: board will boot from SPI Flash on power-up"
}

proc do_sim {} {
    ensure_project_open
    if {[llength [get_files -of_objects [get_filesets sim_1]]] == 0} {
        die "sim_1 file set is empty -- check sim/ dir and re-run 'init'"
    }
    set_property top $::cfg(sim_top) [get_filesets sim_1]
    # In batch mode launch_simulation runs automatically until xsim.simulate.runtime;
    # set it first so the full testbench runs (default is only 1000ns).
    set_property -name {xsim.simulate.runtime} -value $::cfg(sim_runtime) -objects [get_filesets sim_1]
    log "starting behavioral simulation (top $::cfg(sim_top), runtime $::cfg(sim_runtime)) ..."
    launch_simulation -mode behavioral -simset sim_1
    log "simulation finished"
}

proc do_report {} {
    ensure_project_open
    file mkdir $::cfg(rep_dir)
    set generated {}

    if {[file exists $::cfg(impl_dcp)]} {
        open_run impl_1 -name impl_1
        report_timing_summary -delay_type min_max -max_paths 10 \
            -file [file join $::cfg(rep_dir) timing_impl.rpt]
        report_utilization -file [file join $::cfg(rep_dir) utilization_impl.rpt]
        report_power -file [file join $::cfg(rep_dir) power_impl.rpt]
        set generated [list timing_impl.rpt utilization_impl.rpt power_impl.rpt]
    } elseif {[file exists $::cfg(synth_dcp)]} {
        open_run synth_1 -name synth_1
        report_utilization -file [file join $::cfg(rep_dir) utilization_synth.rpt]
        set generated [list utilization_synth.rpt]
    } else {
        die "no run results available -- run 'synth' or 'bitstream' first"
    }
    log "reports generated (build/reports/):"
    foreach f $generated { log "  $f" }
}

proc do_clean {} {
    # Keep build/logs for traceability; delete project and artifacts.
    foreach p [list [file dirname $::cfg(xpr)] $::cfg(runs_dir) $::cfg(rep_dir)] {
        if {[file exists $p]} {
            file delete -force $p
            log "deleted $p"
        }
    }
    log "clean finished (to remove build/logs too, run: Remove-Item -Recurse -Force build)"
}

proc do_help {} {
    puts "Usage:"
    puts "  build.ps1 <target> \[-VivadoBin <path>\] \[-NoLog\]"
    puts "  or: vivado -mode batch -notrace -nojournal -source scripts/build.tcl -tclargs <target>"
    puts ""
    puts "Targets:"
    puts "  init       create project, add RTL/constraints/sim sources (idempotent)"
    puts "  synth      run synthesis"
    puts "  impl       run implementation to route_design (no bitstream)"
    puts "  bitstream  run implementation and generate .bit"
    puts "  program    download bitstream to FPGA over JTAG (SRAM config)"
    puts "  flash      generate .bin and program SPI Flash (OVERWRITES flash!)"
    puts "  sim        run behavioral simulation"
    puts "  report     generate reports under build/reports/"
    puts "  clean      delete project and artifacts (keeps logs)"
    puts "  help       this help"
}

# ---------------- Entry dispatch ----------------
set target [lindex $argv 0]
if {$target eq ""} { set target "help" }

log "target: $target (board: $::cfg(board), part: $::cfg(part))"

switch -exact $target {
    init      { do_init }
    synth     { do_build synth }
    impl      { do_build impl }
    bitstream { do_build bitstream }
    program   { do_program }
    flash     { do_flash }
    sim       { do_sim }
    report    { do_report }
    clean     { do_clean }
    help      { do_help }
    default   {
        puts "ERROR: unknown target '$target'"
        do_help
        exit 1
    }
}

exit 0
