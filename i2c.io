###############################################################
#  IO File for I2C Slave  (fits ~70×70 µm core, 1×1 µm pins)
#  Offsets difference = 2 µm
###############################################################

(globals
    version = 3
    io_order = default
)

(iopin
    # ---- TOP (clock/reset/control) ----
    (top
        (pin name="scl"     offset=2   layer=2 width=1 depth=1 )
        (pin name="rst_n"   offset=4   layer=2 width=1 depth=1 )
    )

    # ---- BOTTOM (serial interface) ----
    (bottom
        (pin name="sda"     offset=2   layer=2 width=1 depth=1 )
    )

    # ---- LEFT (slave address & input data) ----
    (left
        (pin name="slave_addr[6]" offset=2  layer=2 width=1 depth=1 )
        (pin name="slave_addr[5]" offset=4  layer=2 width=1 depth=1 )
        (pin name="slave_addr[4]" offset=6  layer=2 width=1 depth=1 )
        (pin name="slave_addr[3]" offset=8  layer=2 width=1 depth=1 )
        (pin name="slave_addr[2]" offset=10 layer=2 width=1 depth=1 )
        (pin name="slave_addr[1]" offset=12 layer=2 width=1 depth=1 )
        (pin name="slave_addr[0]" offset=14 layer=2 width=1 depth=1 )

        (pin name="data_in[7]" offset=16 layer=2 width=1 depth=1 )
        (pin name="data_in[6]" offset=18 layer=2 width=1 depth=1 )
        (pin name="data_in[5]" offset=20 layer=2 width=1 depth=1 )
        (pin name="data_in[4]" offset=22 layer=2 width=1 depth=1 )
        (pin name="data_in[3]" offset=24 layer=2 width=1 depth=1 )
        (pin name="data_in[2]" offset=26 layer=2 width=1 depth=1 )
        (pin name="data_in[1]" offset=28 layer=2 width=1 depth=1 )
        (pin name="data_in[0]" offset=30 layer=2 width=1 depth=1 )
    )

    # ---- RIGHT (output data) ----
    (right
        (pin name="data_out[7]" offset=2  layer=2 width=1 depth=1 )
        (pin name="data_out[6]" offset=4  layer=2 width=1 depth=1 )
        (pin name="data_out[5]" offset=6  layer=2 width=1 depth=1 )
        (pin name="data_out[4]" offset=8  layer=2 width=1 depth=1 )
        (pin name="data_out[3]" offset=10 layer=2 width=1 depth=1 )
        (pin name="data_out[2]" offset=12 layer=2 width=1 depth=1 )
        (pin name="data_out[1]" offset=14 layer=2 width=1 depth=1 )
        (pin name="data_out[0]" offset=16 layer=2 width=1 depth=1 )
    )
)
