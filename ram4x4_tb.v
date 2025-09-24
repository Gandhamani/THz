`timescale 1ns/1ps

module ram4x4_tb;

  logic clk, rst;
  logic write_en, read_en;
  logic [9:0] pixel_data_in;
  logic [3:0] pixel_addr_in;
  logic [4:0] frame_sel, frame_read_sel;
  logic [2:0] pixel_index_in, pixel_index_out;
  logic [9:0] pixel_data_out;
  logic [3:0] pixel_addr_out;
  logic valid_out;

  // Instantiate the DUT
  ram4x4 dut (
    .clk(clk),
    .rst(rst),
    .write_en(write_en),
    .read_en(read_en),
    .pixel_data_in(pixel_data_in),
    .pixel_addr_in(pixel_addr_in),
    .frame_sel(frame_sel),
    .frame_read_sel(frame_read_sel),
    .pixel_index_in(pixel_index_in),
    .pixel_index_out(pixel_index_out),
    .pixel_data_out(pixel_data_out),
    .pixel_addr_out(pixel_addr_out),
    .valid_out(valid_out)
  );

  // Clock generation
  always #5 clk = ~clk;

  typedef struct packed {
    logic [9:0] pixel;
    logic [3:0] addr;
  } pixel_entry_t;

  pixel_entry_t golden_mem [0:239]; // 30 frames × 8 pixels each = 240 entries //Visual Monitor

  // Write procedure
  task write_pixel(input [4:0] frame, input [2:0] index, input [9:0] data, input [3:0] addr);
    begin
      @(posedge clk);
      write_en = 1;
      read_en = 0;
      frame_sel = frame;
      pixel_index_in = index;
      pixel_data_in = data;
      pixel_addr_in = addr;
      @(posedge clk);
      write_en = 0;
      golden_mem[frame * 8 + index] = '{pixel: data, addr: addr};
      $display("WRITE: frame=%0d index=%0d data=%0d addr=%0d", frame, index, data, addr);
    end
  endtask

  // Read procedure with assertions and coverage
  task read_pixel(input [4:0] frame, input [2:0] index);
    begin
      @(posedge clk);
      write_en = 0;
      read_en = 1;
      frame_read_sel = frame;
      pixel_index_out = index;
      @(posedge clk);
      read_en = 0;

      // Wait for valid_out
      wait (valid_out == 1);
      @(posedge clk);

      // Assertion checks
      if (pixel_data_out !== golden_mem[frame * 8 + index].pixel) begin
        $error("ASSERTION FAILED: Data mismatch at frame %0d index %0d: expected %0d, got %0d", 
               frame, index, golden_mem[frame * 8 + index].pixel, pixel_data_out);
      end else begin
        $display("Read PASS: frame %0d index %0d data %0d", frame, index, pixel_data_out);
      end
    end
  endtask

  initial begin
    clk = 0;
    rst = 1;
    write_en = 0;
    read_en = 0;
    #20 rst = 0;

    // Test Case 1: Write and Read Fixed Pattern for frame 0
    for (int i = 0; i < 8; i++) begin
      write_pixel(0, i, 100 + i, i[3:0]);
    end
    #10;
    for (int i = 0; i < 8; i++) begin
      read_pixel(0, i);
    end

    // Test Case 2: Random Write and Read for frame 1
    for (int i = 0; i < 8; i++) begin
      write_pixel(1, i, $urandom_range(0, 1023), $urandom_range(0, 15));
    end
    #20;
    for (int i = 0; i < 8; i++) begin
      read_pixel(1, i);
    end

    // Test Case 3: Exhaustive testing for all 30 frames
    for (int frame = 0; frame < 30; frame++) begin
      for (int i = 0; i < 8; i++) begin
        write_pixel(frame[4:0], i[2:0], $urandom_range(0, 1023), $urandom_range(0, 15));
      end
      #20;
      for (int i = 0; i < 8; i++) begin
        read_pixel(frame[4:0], i[2:0]);
      end
    end

    $display("All test cases completed.");
    $finish;
  end

endmodule
