timescale 1ns/1ps
module ram4x4 (
    input wire clk,
    input wire rst,
    
    // Write interface
    input wire write_en,
    input wire [9:0] pixel_data_in,
    input wire [3:0] pixel_addr_in,
    input wire [4:0] frame_sel,         // 0 to 29
    input wire [2:0] pixel_index_in,    // 0 to 7 (8 pixels/frame)

    // Read interface
    input wire read_en,
    input wire [4:0] frame_read_sel,
    input wire [2:0] pixel_index_out,   // 0 to 7

    output reg [9:0] pixel_data_out,
    output reg [3:0] pixel_addr_out,
    output reg valid_out
);

    // Memory: 240 entries × 14 bits (10 data + 4 address)
    reg [13:0] mem [0:239];

    // Registered read address and pipeline control
    reg [7:0] read_addr_reg;
    reg read_pending;

    // Compute flat write address combinationally
    wire [7:0] write_addr = frame_sel * 8 + pixel_index_in;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_out <= 1'b0;
            read_pending <= 1'b0;
            pixel_data_out <= 10'b0;
            pixel_addr_out <= 4'b0;
            read_addr_reg <= 8'b0;
        end else begin
            // Write operation
            if (write_en) begin
                mem[write_addr] <= {pixel_addr_in, pixel_data_in};
            end

            // Read operation pipeline
            if (read_en) begin
                read_addr_reg <= frame_read_sel * 8 + pixel_index_out;
                read_pending <= 1'b1;
                valid_out <= 1'b0;  // Data not valid yet
            end else if (read_pending) begin
                {pixel_addr_out, pixel_data_out} <= mem[read_addr_reg];
                valid_out <= 1'b1;  // Data now valid
                read_pending <= 1'b0;
            end else begin
                valid_out <= 1'b0;
            end
        end
    end

endmodule
