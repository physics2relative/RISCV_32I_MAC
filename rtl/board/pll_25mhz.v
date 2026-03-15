// pll_25mhz.v
// Quartus altpll wrapper: 50MHz input -> 25MHz output
// - SYNTHESIS : uses Quartus altpll megafunction (clean, low-jitter PLL)
// - SIMULATION: uses a simple flip-flop divider (no altpll dependency)
//
// Pass +define+SIMULATION to xrun/vcs/ncverilog to select sim path.

module pll_25mhz (
    input  inclk0,    // 50MHz input
    output clk0,      // 25MHz output
    output locked     // PLL lock indicator
);

`ifdef SIMULATION
    // ----------------------------------------------------------------
    // Simulation path: plain flip-flop divide-by-2
    // locked is immediately asserted so downstream logic doesn't stall.
    // ----------------------------------------------------------------
    reg clk_div = 1'b0;
    always @(posedge inclk0) clk_div <= ~clk_div;
    assign clk0   = clk_div;
    assign locked = 1'b1;

`else
    // ----------------------------------------------------------------
    // Synthesis path: Quartus altpll megafunction
    // ----------------------------------------------------------------

    altpll #(
        // Input: 50MHz (period = 20000 ps)
        .inclk0_input_frequency (20000),
        
        // Output clk0: divide by 2 → 25MHz
        .clk0_divide_by         (2),
        .clk0_multiply_by       (1),
        .clk0_duty_cycle        (50),
        .clk0_phase_shift       ("0"),

        .intended_device_family ("Cyclone V"),
        .lpm_type               ("altpll"),
        .operation_mode         ("NORMAL"),
        .pll_type               ("Auto"),
        .port_activeclock       ("PORT_UNUSED"),
        .port_areset            ("PORT_UNUSED"),
        .port_clkbad0           ("PORT_UNUSED"),
        .port_clkbad1           ("PORT_UNUSED"),
        .port_clkloss           ("PORT_UNUSED"),
        .port_clkswitch         ("PORT_UNUSED"),
        .port_configupdate      ("PORT_UNUSED"),
        .port_fbin              ("PORT_UNUSED"),
        .port_inclk0            ("PORT_USED"),
        .port_inclk1            ("PORT_UNUSED"),
        .port_locked            ("PORT_USED"),
        .port_pfdena            ("PORT_UNUSED"),
        .port_phasecounterselect("PORT_UNUSED"),
        .port_phasedone         ("PORT_UNUSED"),
        .port_phasestep         ("PORT_UNUSED"),
        .port_phaseupdown       ("PORT_UNUSED"),
        .port_pllena            ("PORT_UNUSED"),
        .port_scanaclr          ("PORT_UNUSED"),
        .port_scanclk           ("PORT_UNUSED"),
        .port_scanclkena        ("PORT_UNUSED"),
        .port_scandata          ("PORT_UNUSED"),
        .port_scandataout       ("PORT_UNUSED"),
        .port_scandone          ("PORT_UNUSED"),
        .port_scanread          ("PORT_UNUSED"),
        .port_scanwrite         ("PORT_UNUSED"),
        .port_clk0              ("PORT_USED"),
        .port_clk1              ("PORT_UNUSED"),
        .port_clk2              ("PORT_UNUSED"),
        .port_clk3              ("PORT_UNUSED"),
        .port_clk4              ("PORT_UNUSED"),
        .port_clk5              ("PORT_UNUSED"),
        .port_clkena0           ("PORT_UNUSED"),
        .port_clkena1           ("PORT_UNUSED"),
        .port_clkena2           ("PORT_UNUSED"),
        .port_clkena3           ("PORT_UNUSED"),
        .port_clkena4           ("PORT_UNUSED"),
        .port_clkena5           ("PORT_UNUSED"),
        .port_extclk0           ("PORT_UNUSED"),
        .port_extclk1           ("PORT_UNUSED"),
        .port_extclk2           ("PORT_UNUSED"),
        .port_extclk3           ("PORT_UNUSED")
    ) altpll_component (
        .inclk  ({1'b0, inclk0}),
        .clk    (sub_wire0),
        .locked (locked),
        .activeclock (),
        .areset  (1'b0),
        .clkbad  (),
        .clkena  ({6{1'b1}}),
        .clkloss (),
        .clkswitch    (1'b0),
        .configupdate (1'b0),
        .enable0 (),
        .enable1 (),
        .extclk  (),
        .extclkena    ({4{1'b1}}),
        .fbin    (1'b1),
        .fbmimicbidir (),
        .fbout   (),
        .fref    (),
        .icdrclk (),
        .pfdena  (1'b1),
        .phasecounterselect ({4{1'b1}}),
        .phasedone   (),
        .phasestep   (1'b1),
        .phaseupdown (1'b1),
        .pllena  (1'b1),
        .scanaclr    (1'b0),
        .scanclk     (1'b0),
        .scanclkena  (1'b1),
        .scandata    (1'b0),
        .scandataout (),
        .scandone    (),
        .scanread    (1'b0),
        .scanwrite   (1'b0),
        .sclkout0    (),
        .sclkout1    (),
        .vcooverrange  (),
        .vcounderrange ()
    );

    wire [5:0] sub_wire0;
    assign clk0 = sub_wire0[0];

`endif

endmodule
