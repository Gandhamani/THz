`timescale 1ns / 1ps

module i2c_tb;

  // --------------------
  // Signals
  // --------------------
  reg clk, rst_n, start, rw;
  wire scl;
  tri1 sda;  // open-drain SDA
  pullup(sda);

  reg  [6:0] addr;
  reg  [7:0] wr_data;
  wire [7:0] rd_data;
  wire [7:0] slave_data;
  wire busy, done;

  // --------------------
  // Instantiate Master
  // --------------------
  i2c_master #(.SYS_CLK(50_000_000), .I2C_FREQ(100_000)) master (
    .clk(clk),
    .rst_n(rst_n),
    .sda(sda),
    .scl(scl),
    .start(start),
    .rw(rw),
    .addr(addr),
    .wr_data(wr_data),
    .rd_data(rd_data),
    .busy(busy),
    .done(done)
  );

  // --------------------
  // Instantiate Slave
  // --------------------
  i2c_slave slave (
    .scl(scl),
    .sda(sda),
    .rst_n(rst_n),
    .slave_addr(7'h55),
    .data_in(8'hA5),
    .data_out(slave_data)
  );

  // --------------------
  // Clock generation
  // --------------------
  initial begin
    clk = 0;
    forever #10 clk = ~clk;  // 50 MHz
  end

  // --------------------
  // Reset
  // --------------------
  initial begin
    rst_n = 0;
    repeat(5) @(posedge clk);
    rst_n = 1;
  end

  // --------------------
  // Tasks for transactions
  // --------------------
  task master_write(input [7:0] data);
    begin
      rw = 0;
      wr_data = data;
      @(posedge clk);
      start = 1;
      wait (busy);
      start = 0;
      @(posedge done);
      wait (!busy);
      $display("[%0t] WRITE: %h", $time, data);
    end
  endtask

  task master_read(input [7:0] exp_data);
    begin
      rw = 1;
      @(posedge clk);
      start = 1;
      wait (busy);
      start = 0;
      @(posedge done);
      wait (!busy);
      $display("[%0t] READ: %h (exp=%h)", $time, rd_data, exp_data);
    end
  endtask

  // --------------------
  // Stimulus
  // --------------------
  initial begin
    start = 0; rw = 0; addr = 7'h55; wr_data = 8'h3C;
    @(posedge rst_n);

    // Single-byte write
    $display("\n==== SINGLE BYTE WRITE ====");
    master_write(8'h44);

    // Single-byte read
    $display("\n==== SINGLE BYTE READ ====");
    master_read(8'hA5);

    // Multi-byte write
    $display("\n==== MULTI BYTE WRITE ====");
    master_write(8'h11);
    master_write(8'h22);
    master_write(8'h33);

    // Multi-byte read
    $display("\n==== MULTI BYTE READ ====");
    force slave.data_in = 8'h44; master_read(8'h44);
    force slave.data_in = 8'h55; master_read(8'h55);
    force slave.data_in = 8'h66; master_read(8'h66);
    release slave.data_in;

    // Random multi-byte write/read
    $display("\n==== RANDOM MULTI BYTE ====");
    repeat (5) begin
      reg [7:0] rand_data;
      rand_data = $urandom_range(0, 255);
      master_write(rand_data);
    end

    repeat (5) begin
      reg [7:0] rand_data;
      rand_data = $urandom_range(0, 255);
      force slave.data_in = rand_data;
      master_read(rand_data);
    end
    release slave.data_in;
    #200;
    $display("\n==== ALL TESTS COMPLETE ====");
    $finish;
  end

endmodule
