timescale 1ns/1ps
module SPICP_test;

  parameter BUS_LENGTH = 8;
  parameter CLK_DIV    = 4;

  // Clocks/Resets
  logic clk = 0;
  always #5 clk = ~clk; // 100 MHz system clock

  logic rst;
  logic tx_en;
  logic CPOL, CPHA;

  // SPI Wires
  logic [BUS_LENGTH-1:0] data_in_master, data_out_master;
  logic [BUS_LENGTH-1:0] data_in_slave,  data_out_slave;
  logic PICO, POCI;
  logic SCK, CS;

  // ---------------------------
  // Instantiate DUTs
  // ---------------------------

  // SPI Controller (Master)
  SPI_Controller #(.BUS_LENGTH(BUS_LENGTH), .CLK_DIV(CLK_DIV)) master (
    .clk(clk),
    .rst(rst),
    .tx_en(tx_en),
    .POCI(POCI),
    .CPOL(CPOL),
    .CPHA(CPHA),
    .data_in(data_in_master),
    .data_out(data_out_master),
    .PICO(PICO),
    .SCK(SCK),
    .CS(CS)
  );

  // SPI Peripheral (Slave)
  SPI_Peripheral #(.BUS_LENGTH(BUS_LENGTH)) slave (
    .clk(clk),
    .rst(rst),
    .PICO(PICO),
    .SCK(SCK),
    .CS(CS),
    .CPHA(CPHA),
    .CPOL(CPOL),
    .data_in(data_in_slave),
    .POCI(POCI),
    .data_out(data_out_slave)
  );

  // ---------------------------
  // Parity checker integration (tick-based)
  // ---------------------------
  // Monitor-only error injection (does not disturb the bus)
  logic inject_flip_pico, inject_flip_poci;
  wire  PICO_mon = PICO ^ inject_flip_pico;
  wire  POCI_mon = POCI ^ inject_flip_poci;

  // Edge detection for SCK and CS (in TB/system clock domain)
  logic SCK_prev, CS_prev;
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      SCK_prev <= 1'b0;
      CS_prev  <= 1'b1; // CS is active-low; idle high
    end else begin
      SCK_prev <= SCK;
      CS_prev  <= CS;
    end
  end
  wire sck_rising  =  SCK & ~SCK_prev;
  wire sck_falling = ~SCK &  SCK_prev;
  wire cs_rise     =  CS & ~CS_prev;  // CS deasserting (end of frame)

  // SAMPLE condition mirrored from your SPI_Peripheral:
  //   CPHA == 0 -> sample on rising edge
  //   CPHA == 1 -> sample on falling edge
  wire sample_tick = (!CS) && ((CPHA == 1'b0) ? sck_rising : sck_falling);

  // Track current bit index (for printing which bit we injected)
  integer sample_idx;
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      sample_idx <= 0;
    end else begin
      if (cs_rise) sample_idx <= 0;
      else if (sample_tick) begin
        if (sample_idx == BUS_LENGTH-1) sample_idx <= 0;
        else                            sample_idx <= sample_idx + 1;
      end
    end
  end

  // Parity checker (tick-enabled)
  wire parity_err;
  spi_parity_checker_tick #(.BUS_LENGTH(BUS_LENGTH)) mon (
    .clk(clk),
    .rst(rst),
    .sample_tick(sample_tick),
    .cs_rise(cs_rise),
    .PICO(PICO_mon),
    .POCI(POCI_mon),
    .parity_err(parity_err)
  );

  // Log parity_err assertion edges with time/mode
  int current_mode;
  always @(posedge parity_err) begin
    $display("[%0t ns] [MODE %0d CPOL=%0b CPHA=%0b] parity_err ASSERTED",
             $time, current_mode, CPOL, CPHA);
  end

  // ---------------------------
  // Helpers for prints
  // ---------------------------
  function automatic string mode_name(input int mode);
    case (mode)
      0: return "Mode 0 (CPOL=0, CPHA=0)";
      1: return "Mode 1 (CPOL=0, CPHA=1)";
      2: return "Mode 2 (CPOL=1, CPHA=0)";
      3: return "Mode 3 (CPOL=1, CPHA=1)";
      default: return "Unknown";
    endcase
  endfunction

  function automatic bit parity8(input logic [BUS_LENGTH-1:0] x);
    parity8 = ^x; // even parity (XOR reduction)
  endfunction

  task automatic print_parities(string tag, logic [BUS_LENGTH-1:0] m, logic [BUS_LENGTH-1:0] s);
    $display("[%0t ns] [%s] Expected parity: PICO=%0b (master 0x%0h), POCI=%0b (slave 0x%0h)",
             $time, tag, parity8(m), m, parity8(s), s);
  endtask

  // Wait for the next sample tick (aligned to the bus sampling)
  task automatic wait_sample_tick;
    @(posedge sample_tick);
  endtask

  // Flip the monitored line(s) for exactly one sample tick
  task automatic inject_one_bit_flip(input bit flip_pico, input bit flip_poci, input string why);
    $display("[%0t ns] [MODE %0d] Injecting monitor flip: PICO=%0b POCI=%0b at bit_idx=%0d (%s)",
             $time, current_mode, flip_pico, flip_poci, sample_idx, why);
    inject_flip_pico = flip_pico;
    inject_flip_poci = flip_poci;
    wait_sample_tick();
    inject_flip_pico = 1'b0;
    inject_flip_poci = 1'b0;
  endtask

  // ---------------------------
  // Your original tests (with extra parity/flag prints)
  // ---------------------------

  // Single-byte SPI test
  task run_spi_mode_test(input int mode);
    begin
      current_mode = mode;
      CPOL = mode[1]; CPHA = mode[0];
      $display("\n=== %s: Single-byte test ===", mode_name(mode));

      rst = 1; tx_en = 0;
      inject_flip_pico = 0; inject_flip_poci = 0;
      data_in_master = 8'hA5;
      data_in_slave  = 8'h5A;
      #20;  rst = 0;  #20;

      print_parities("pre", data_in_master, data_in_slave);

      tx_en = 1;
      #2000; // allow one frame
      tx_en = 0;

      $display("Master Sent: 0x%0h, Slave Received: 0x%0h", data_in_master, data_out_slave);
      $display("Slave  Sent: 0x%0h, Master Received: 0x%0h", data_in_slave,  data_out_master);
      $display("[RESULT] parity_err=%0b", parity_err);
    end
  endtask

  // Multi-byte SPI test with continuous clock
  task run_spi_multi_byte_test(input int mode);
    logic [BUS_LENGTH-1:0] master_tx_array [0:3];
    logic [BUS_LENGTH-1:0] slave_tx_array  [0:3];
    logic [BUS_LENGTH-1:0] master_rx_array [0:3];
    logic [BUS_LENGTH-1:0] slave_rx_array  [0:3];

    begin
      current_mode = mode;
      CPOL = mode[1]; CPHA = mode[0];
      $display("\n=== %s: Fixed multi-byte test ===", mode_name(mode));

      rst = 1; tx_en = 0;
      inject_flip_pico = 0; inject_flip_poci = 0;
      master_tx_array = '{8'h11, 8'h22, 8'h33, 8'h44};
      slave_tx_array  = '{8'hAA, 8'hBB, 0'hCC, 8'hDD}; // note: CC shown correctly
      #20; rst = 0; #20;

      tx_en = 1;
      for (int i = 0; i < 4; i++) begin
        data_in_master = master_tx_array[i];
        data_in_slave  = slave_tx_array[i];
        print_parities($sformatf("byte %0d pre", i), data_in_master, data_in_slave);
        #2000;
        master_rx_array[i] = data_out_master;
        slave_rx_array[i]  = data_out_slave;
        #50;
      end
      tx_en = 0;

      $display("SPI Mode %0d Multi-Byte Results:", mode);
      for (int i = 0; i < 4; i++) begin
        $display("Byte %0d: M_sent=0x%0h S_recv=0x%0h | S_sent=0x%0h M_recv=0x%0h",
                 i, master_tx_array[i], slave_rx_array[i], slave_tx_array[i], master_rx_array[i]);

        if (master_rx_array[i] !== slave_tx_array[i]) begin
          $error("Mode %0d Byte %0d: Master expected 0x%0h, got 0x%0h",
                 mode, i, slave_tx_array[i], master_rx_array[i]);
        end
        if (slave_rx_array[i] !== master_tx_array[i]) begin
          $error("Mode %0d Byte %0d: Slave expected 0x%0h, got 0x%0h",
                 mode, i, master_tx_array[i], slave_rx_array[i]);
        end
      end
      $display("[INFO] parity_err (don’t-care here; bytes differ) = %0b\n", parity_err);
    end
  endtask

  // Random multi-byte SPI test with continuous clock
  task run_spi_random_multi_byte_test(input int mode);
    logic [BUS_LENGTH-1:0] master_tx_array [0:3];
    logic [BUS_LENGTH-1:0] slave_tx_array  [0:3];
    logic [BUS_LENGTH-1:0] master_rx_array [0:3];
    logic [BUS_LENGTH-1:0] slave_rx_array  [0:3];

    begin
      current_mode = mode;
      CPOL = mode[1]; CPHA = mode[0];
      $display("\n=== %s: Random multi-byte test ===", mode_name(mode));

      rst = 1; tx_en = 0;
      inject_flip_pico = 0; inject_flip_poci = 0;

      for (int i = 0; i < 4; i++) begin
        master_tx_array[i] = $urandom_range(0, 255);
        slave_tx_array[i]  = $urandom_range(0, 255);
      end

      #20; rst = 0; #20;

      tx_en = 1;
      for (int i = 0; i < 4; i++) begin
        data_in_master = master_tx_array[i];
        data_in_slave  = slave_tx_array[i];
        print_parities($sformatf("byte %0d pre", i), data_in_master, data_in_slave);
        #2000;
        master_rx_array[i] = data_out_master;
        slave_rx_array[i]  = data_out_slave;
        #50;
      end
      tx_en = 0;

      $display("SPI Mode %0d Random Multi-Byte Results:", mode);
      for (int i = 0; i < 4; i++) begin
        $display("Byte %0d: M_sent=0x%0h S_recv=0x%0h | S_sent=0x%0h M_recv=0x%0h",
                 i, master_tx_array[i], slave_rx_array[i], slave_tx_array[i], master_rx_array[i]);

        if (master_rx_array[i] !== slave_tx_array[i]) begin
          $error("Mode %0d Byte %0d: Master expected 0x%0h, got 0x%0h",
                 mode, i, slave_tx_array[i], master_rx_array[i]);
        end
        if (slave_rx_array[i] !== master_tx_array[i]) begin
          $error("Mode %0d Byte %0d: Slave expected 0x%0h, got 0x%0h",
                 mode, i, master_tx_array[i], slave_rx_array[i]);
        end
      end
      $display("[INFO] parity_err (don’t-care here; bytes differ) = %0b\n", parity_err);
    end
  endtask

  // ---------------------------
  // NEW: Random Equal-Parity test (parity_err must remain 0)
  // Master and Slave send the same bytes -> parity must match (no error).
  // ---------------------------
  task run_spi_random_equal_parity_test(input int mode);
    logic [BUS_LENGTH-1:0] tx_array [0:3];
    logic [BUS_LENGTH-1:0] master_rx_array [0:3];
    logic [BUS_LENGTH-1:0] slave_rx_array  [0:3];

    begin
      current_mode = mode;
      CPOL = mode[1]; CPHA = mode[0];
      $display("\n=== %s: Random equal-parity test (expect parity_err==0) ===", mode_name(mode));

      rst = 1; tx_en = 0;
      inject_flip_pico = 0; inject_flip_poci = 0;
      for (int i = 0; i < 4; i++) tx_array[i] = $urandom_range(0,255);
      #20; rst = 0; #20;

      tx_en = 1;
      for (int i = 0; i < 4; i++) begin
        data_in_master = tx_array[i];
        data_in_slave  = tx_array[i];   // same both ways
        print_parities($sformatf("byte %0d pre", i), data_in_master, data_in_slave);
        #2000;
        master_rx_array[i] = data_out_master;
        slave_rx_array[i]  = data_out_slave;
        #50;
      end
      tx_en = 0;

      $display("[RESULT] parity_err=%0b (should be 0)\n", parity_err);
      if (parity_err !== 1'b0)
        $error("Parity checker flagged error unexpectedly in equal-parity test (mode %0d).", mode);
    end
  endtask

  // ---------------------------
  // NEW: Error injection test (parity_err must go 1 after injection)
  // Flip one monitored bit (PICO) for exactly one sample tick -> parity error expected.
  // ---------------------------
  task run_spi_parity_error_injection_test(input int mode);
    begin
      current_mode = mode;
      CPOL = mode[1]; CPHA = mode[0];
      $display("\n=== %s: Parity error injection test ===", mode_name(mode));

      // Reset everything (clear sticky parity_err)
      rst = 1; tx_en = 0; inject_flip_pico = 0; inject_flip_poci = 0;
      #20; rst = 0; #20;

      // One clean word first -> should NOT set parity_err
      tx_en = 1;
      data_in_master = 8'hB6;
      data_in_slave  = 8'hB6;
      print_parities("clean pre", data_in_master, data_in_slave);
      #2000;
      tx_en = 0;

      $display("[CHECK] pre-injection parity_err=%0b (should be 0)", parity_err);
      if (parity_err !== 1'b0)
        $error("Parity checker flagged error before injection (mode %0d).", mode);

      // Clear and inject on next frame
      rst = 1; #20; rst = 0; #20;

      tx_en = 1;
      data_in_master = 8'hC3;
      data_in_slave  = 8'hC3;
      print_parities("inject pre", data_in_master, data_in_slave);

      // Wait until CS active and then a couple sample ticks into the byte
      @(negedge CS);
      repeat (2) wait_sample_tick();

      // Flip PICO on exactly one sampling instant (monitor-only)
      inject_one_bit_flip(1'b1, 1'b0, "single-sample flip on PICO");

      // Finish the byte
      #1000;
      tx_en = 0;

      $display("[RESULT] post-injection parity_err=%0b (should be 1)\n", parity_err);
      if (parity_err !== 1'b1)
        $error("Parity checker DID NOT flag error after injection (mode %0d).", mode);
      else
        $display("Parity checker correctly flagged an error after injection (mode %0d).", mode);
    end
  endtask

  // ---------------------------
  // Run all tests
  // ---------------------------
  initial begin
    $display("Starting SPI Mode Tests...");
    for (int mode = 0; mode < 4; mode++) begin
      run_spi_mode_test(mode);
      #1000;

      run_spi_multi_byte_test(mode);
      #1000;

      run_spi_random_multi_byte_test(mode);
      #1000;

      run_spi_random_equal_parity_test(mode);
      #1000;

      run_spi_parity_error_injection_test(mode);
      #2000;
    end
    $display("All tests completed.");
    $finish;
  end
endmodule
