# =============================================================================
# Board project configuration (Colorlight i9+ v6.1 / XI050AB, FPGA: XC7A50T-FGG484)
# All scripts read paths/parameters from this file.
# Edit this file to adapt to another board / project.
# NOTE: keep this file ASCII-only to avoid any encoding issues.
# =============================================================================

# ---- Repository root (directory of this file) ----
set ::cfg(root) [file normalize [file dirname [info script]]]

# ---- Part / project ----
set ::cfg(part)       "xc7a50tfgg484-1"   ;# FPGA part
set ::cfg(top)        "top"               ;# top-level RTL module
set ::cfg(proj_name)  "bigpig_i9p"        ;# project name (=> build/<name>.xpr)
set ::cfg(jobs)       6                   ;# parallel jobs for launch_runs

# ---- Directory layout ----
set ::cfg(rtl_dir)    [file join $::cfg(root) rtl]
set ::cfg(constr_dir) [file join $::cfg(root) constr]
set ::cfg(sim_dir)    [file join $::cfg(root) sim]
set ::cfg(ip_dir)     [file join $::cfg(root) ip]          ;# local IP repo (optional)
set ::cfg(build_dir)  [file join $::cfg(root) build]
set ::cfg(log_dir)    [file join $::cfg(build_dir) logs]

# ---- Simulation ----
set ::cfg(sim_top)    "tb_top"            ;# simulation top module
set ::cfg(sim_runtime) "310ms"            ;# xsim runtime (tb asserts at 300ms then $finish)

# ---- Derived artifact paths (do not edit) ----
set ::cfg(proj_dir)   [file join $::cfg(build_dir) $::cfg(proj_name)]
set ::cfg(xpr)        [file join $::cfg(proj_dir) $::cfg(proj_name).xpr]
set ::cfg(runs_dir)   [file join $::cfg(proj_dir) $::cfg(proj_name).runs]
set ::cfg(synth_dcp)  [file join $::cfg(runs_dir) synth_1 $::cfg(top).dcp]
set ::cfg(impl_dcp)   [file join $::cfg(runs_dir) impl_1 $::cfg(top)_routed.dcp]
set ::cfg(bit)        [file join $::cfg(runs_dir) impl_1 $::cfg(top).bit]
set ::cfg(rep_dir)    [file join $::cfg(build_dir) reports]

# ---- Board info (shown in logs) ----
set ::cfg(board)      "Colorlight i9+ v6.1 (XI050AB)"
set ::cfg(clk_freq_mhz) 25.0
