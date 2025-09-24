`timescale 1ns / 1ps

module i2c_master #(
    parameter SYS_CLK  = 50_000_000,  // Hz
    parameter I2C_FREQ = 100_000      // Hz
)(
    input  wire clk,      // system clock
    input  wire rst_n,    // async reset
    inout  wire sda,
    output reg  scl,
    input  wire start,        // start transaction
    input  wire rw,           // 0=write, 1=read
    input  wire [6:0] addr,   // 7-bit slave address
    input  wire [7:0] wr_data,
    output reg  [7:0] rd_data,
    output reg  busy,
    output reg  done
);

    // FSM states
    localparam IDLE      = 4'd0,
               START     = 4'd1,
               SEND_ADDR = 4'd2,
               ADDR_ACK  = 4'd3,
               WRITE     = 4'd4,
               WR_ACK    = 4'd5,
               READ      = 4'd6,
               RD_ACK    = 4'd7,
               STOP      = 4'd8;

    reg [3:0] state, next_state;
    reg [7:0] shift_reg;
    reg [3:0] bit_cnt;

    // Baud rate divider for SCL generation
    localparam DIVISOR = (SYS_CLK / (2*I2C_FREQ));
    reg [$clog2(DIVISOR)-1:0] count;

    // SCL generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl   <= 1'b1;
            count <= 0;
        end else begin
            if (count == DIVISOR-1) begin
                scl   <= ~scl;
                count <= 0;
            end else begin
                count <= count + 1;
            end
        end
    end

    // SDA control
    reg sda_out_en, sda_out_bit;
    assign sda = sda_out_en ? sda_out_bit : 1'bz;

    // FSM sequential
    always @(posedge scl or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            bit_cnt   <= 0;
            rd_data   <= 0;
            done      <= 0;
            busy      <= 0;
        end else begin
            state <= next_state;
            case (state)
                SEND_ADDR, WRITE, READ: bit_cnt <= bit_cnt + 1;
                default: bit_cnt <= 0;
            endcase
        end
    end

    // FSM combinational
    always @(*) begin
        next_state  = state;
        sda_out_en  = 1'b0;
        sda_out_bit = 1'b1;
        busy        = 1;
        done        = 0;

        case (state)
            IDLE: begin
                busy = 0;
                if (start) next_state = START;
            end

            START: begin
                sda_out_en  = 1'b1;
                sda_out_bit = 0;   // SDA low while SCL high
                next_state  = SEND_ADDR;
                shift_reg   = {addr, rw}; // 7-bit addr + R/W
            end

            SEND_ADDR: begin
                sda_out_en  = 1'b1;
                sda_out_bit = shift_reg[7-bit_cnt];
                if (bit_cnt == 7) next_state = ADDR_ACK;
            end

            ADDR_ACK: begin
                sda_out_en  = 1'b0; // slave drives ACK
                if (rw==0) next_state = WRITE;
                else       next_state = READ;
            end

            WRITE: begin
                sda_out_en  = 1'b1;
                sda_out_bit = wr_data[7-bit_cnt];
                if (bit_cnt == 7) next_state = WR_ACK;
            end

            WR_ACK: begin
                sda_out_en  = 1'b0; // slave ACK
                next_state  = STOP;
            end

            READ: begin
                sda_out_en  = 1'b0; // release SDA (slave drives data)
                rd_data[7-bit_cnt] = sda;
                if (bit_cnt == 7) next_state = RD_ACK;
            end

            RD_ACK: begin
                sda_out_en  = 1'b1;
                sda_out_bit = 0; // ACK
                next_state  = STOP;
            end

            STOP: begin
                sda_out_en  = 1'b1;
                sda_out_bit = 1; // SDA high while SCL high
                done        = 1;
                next_state  = IDLE;
            end
        endcase
    end
endmodule

module i2c_slave (
    input  wire scl,
    inout  wire sda,
    input  wire rst_n,
    input  wire [6:0] slave_addr, // slave address
    input  wire [7:0] data_in,    // data to send in read mode
    output reg  [7:0] data_out    // data received in write mode
);

    localparam IDLE     = 3'd0,
               ADDR     = 3'd1,
               ACK_ADDR = 3'd2,
               WRITE    = 3'd3,
               ACK_WR   = 3'd4,
               READ     = 3'd5,
               ACK_RD   = 3'd6,
               NACK     = 3'd7;   // new state for NACK

    reg [2:0] state, next_state;
    reg [7:0] shift_reg;
    reg [2:0] bit_cnt;
    reg rw;
    reg sda_out_en, sda_out_bit;

    assign sda = sda_out_en ? sda_out_bit : 1'bz;

    // FSM sequential
    always @(posedge scl or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            bit_cnt   <= 0;
            shift_reg <= 0;
            data_out  <= 0;
        end else begin
            state <= next_state;

            case (state)
                ADDR: begin
                    shift_reg <= {shift_reg[6:0], sda};
                    bit_cnt   <= bit_cnt + 1;
                end
                WRITE: begin
                    shift_reg <= {shift_reg[6:0], sda};
                    bit_cnt   <= bit_cnt + 1;
                end
                READ: begin
                    bit_cnt   <= bit_cnt + 1;
                end
                default: bit_cnt <= 0;
            endcase
        end
    end

    // FSM combinational
    always @(*) begin
        next_state  = state;
        sda_out_en  = 1'b0;
        sda_out_bit = 1'b1; // default release = '1'

        case (state)
            IDLE: begin
                // Detect START condition: SDA goes low while SCL high
                if (sda == 0 && scl == 1) next_state = ADDR;
            end

            ADDR: begin
                // After 7 bits + R/W
                if (bit_cnt == 3'd7) begin
                    rw         = sda; // last bit is R/W
                    next_state = ACK_ADDR;
                end
            end

            ACK_ADDR: begin
                if (shift_reg[7:1] == slave_addr) begin
                    // Address matches → ACK
                    sda_out_en  = 1'b1;
                    sda_out_bit = 1'b0; // drive low = ACK
                    if (rw == 0) next_state = WRITE;
                    else          next_state = READ;
                end else begin
                    // Address mismatch → NACK
                    sda_out_en  = 1'b0; // release line → SDA=1 (NACK)
                    next_state  = NACK;
                end
            end

            WRITE: if (bit_cnt == 3'd7) begin
                       data_out   = {shift_reg[6:0], sda};
                       next_state = ACK_WR;
                   end

            ACK_WR: begin
                sda_out_en  = 1'b1;
                sda_out_bit = 0; // ACK
                next_state  = IDLE;
            end

            READ: begin
                sda_out_en  = 1'b1;
                sda_out_bit = data_in[7-bit_cnt];
                if (bit_cnt == 3'd7) next_state = ACK_RD;
            end

            ACK_RD: begin
                sda_out_en  = 1'b0; // master drives ACK/NACK
                next_state  = IDLE;
            end

            NACK: begin
                // Stay idle until next START
                sda_out_en  = 1'b0; // keep line released (SDA=1)
                next_state  = IDLE;
            end
        endcase
    end
endmodule  
module i2cslave (
    input  wire scl,
    inout  wire sda,
    input  wire rst_n,
    input  wire [6:0] slave_addr, // slave address
    input  wire [7:0] data_in,    // data to send in read mode
    output reg  [7:0] data_out    // data received in write mode
);

    localparam IDLE     = 3'd0,
               ADDR     = 3'd1,
               ACK_ADDR = 3'd2,
               WRITE    = 3'd3,
               ACK_WR   = 3'd4,
               READ     = 3'd5,
               ACK_RD   = 3'd6,
               NACK     = 3'd7;   // new state for NACK

    reg [2:0] state, next_state;
    reg [7:0] shift_reg;
    reg [2:0] bit_cnt;
    reg rw;
    reg sda_out_en, sda_out_bit;

    assign sda = sda_out_en ? sda_out_bit : 1'bz;

    // FSM sequential
    always @(posedge scl or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            bit_cnt   <= 0;
            shift_reg <= 0;
            data_out  <= 0;
        end else begin
            state <= next_state;

            case (state)
                ADDR: begin
                    shift_reg <= {shift_reg[6:0], sda};
                    bit_cnt   <= bit_cnt + 1;
                end
                WRITE: begin
                    shift_reg <= {shift_reg[6:0], sda};
                    bit_cnt   <= bit_cnt + 1;
                end
                READ: begin
                    bit_cnt   <= bit_cnt + 1;
                end
                default: bit_cnt <= 0;
            endcase
        end
    end

    // FSM combinational
    always @(*) begin
        next_state  = state;
        sda_out_en  = 1'b0;
        sda_out_bit = 1'b1; // default release = '1'

        case (state)
            IDLE: begin
                // Detect START condition: SDA goes low while SCL high
                if (sda == 0 && scl == 1) next_state = ADDR;
            end

            ADDR: begin
                // After 7 bits + R/W
                if (bit_cnt == 3'd7) begin
                    rw         = sda; // last bit is R/W
                    next_state = ACK_ADDR;
                end
            end

            ACK_ADDR: begin
                if (shift_reg[7:1] == slave_addr) begin
                    // Address matches → ACK
                    sda_out_en  = 1'b1;
                    sda_out_bit = 1'b0; // drive low = ACK
                    if (rw == 0) next_state = WRITE;
                    else          next_state = READ;
                end else begin
                    // Address mismatch → NACK
                    sda_out_en  = 1'b0; // release line → SDA=1 (NACK)
                    next_state  = NACK;
                end
            end

            WRITE: if (bit_cnt == 3'd7) begin
                       data_out   = {shift_reg[6:0], sda};
                       next_state = ACK_WR;
                   end

            ACK_WR: begin
                sda_out_en  = 1'b1;
                sda_out_bit = 0; // ACK
                next_state  = IDLE;
            end

            READ: begin
                sda_out_en  = 1'b1;
                sda_out_bit = data_in[7-bit_cnt];
                if (bit_cnt == 3'd7) next_state = ACK_RD;
            end

            ACK_RD: begin
                sda_out_en  = 1'b0; // master drives ACK/NACK
                next_state  = IDLE;
            end

            NACK: begin
                // Stay idle until next START
                sda_out_en  = 1'b0; // keep line released (SDA=1)
                next_state  = IDLE;
            end
        endcase
    end
endmodule
