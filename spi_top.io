###############################################################
#  IO File for spi_top  (fits ~70×70 µm core, 1×1 µm pins)
#  Offsets difference = 2 µm
###############################################################

(globals
    version = 3
    io_order = default
)

(iopin
    # ---- TOP (clock/reset/mode) ----
    (top
        (pin name="clk"   offset=2  layer=2 width=1 depth=1 )
        (pin name="rst"   offset=4  layer=2 width=1 depth=1 )
        (pin name="CPOL"  offset=6  layer=2 width=1 depth=1 )
        (pin name="CPHA"  offset=8  layer=2 width=1 depth=1 )
    )

    # ---- BOTTOM (SPI serial interface) ----
    (bottom
        (pin name="SCK"   offset=2  layer=2 width=1 depth=1 )
        (pin name="CS"    offset=4  layer=2 width=1 depth=1 )
        (pin name="PICO"  offset=6  layer=2 width=1 depth=1 )
        (pin name="POCI"  offset=8  layer=2 width=1 depth=1 )
    )

    # ---- LEFT (parallel input bus) ----
    (left
        (pin name="data_in[7]" offset=2  layer=2 width=1 depth=1 )
        (pin name="data_in[6]" offset=4  layer=2 width=1 depth=1 )
        (pin name="data_in[5]" offset=6  layer=2 width=1 depth=1 )
        (pin name="data_in[4]" offset=8  layer=2 width=1 depth=1 )
        (pin name="data_in[3]" offset=10 layer=2 width=1 depth=1 )
        (pin name="data_in[2]" offset=12 layer=2 width=1 depth=1 )
        (pin name="data_in[1]" offset=14 layer=2 width=1 depth=1 )
        (pin name="data_in[0]" offset=16 layer=2 width=1 depth=1 )
    )

    # ---- RIGHT (parallel output bus + debug/status) ----
    (right
        (pin name="data_out[7]"      offset=2  layer=2 width=1 depth=1 )
        (pin name="data_out[6]"      offset=4  layer=2 width=1 depth=1 )
        (pin name="data_out[5]"      offset=6  layer=2 width=1 depth=1 )
        (pin name="data_out[4]"      offset=8  layer=2 width=1 depth=1 )
        (pin name="data_out[3]"      offset=10 layer=2 width=1 depth=1 )
        (pin name="data_out[2]"      offset=12 layer=2 width=1 depth=1 )
        (pin name="data_out[1]"      offset=14 layer=2 width=1 depth=1 )
        (pin name="data_out[0]"      offset=16 layer=2 width=1 depth=1 )

        (pin name="parity_err"       offset=20 layer=2 width=1 depth=1 )
        (pin name="sample_tick_dbg"  offset=22 layer=2 width=1 depth=1 )
        (pin name="cs_rise_dbg"      offset=24 layer=2 width=1 depth=1 )
    )
)
