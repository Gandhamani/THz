module SPI_Controller #(parameter BUS_LENGTH = 8, parameter CLK_DIV = 4)
(
  input clk, rst, tx_en,
  input POCI, CPOL, CPHA,
  input [BUS_LENGTH-1:0] data_in,
  output logic [BUS_LENGTH-1:0] data_out,
  output logic PICO, SCK, CS
);

  typedef enum logic [2:0] {IDLE, LOAD, SHIFT, WAIT_SAMPLE, SAMPLE, DONE} state_t;
  state_t state;

  logic [BUS_LENGTH-1:0] shift_reg;
  logic [BUS_LENGTH-1:0] sample_reg;
  logic [3:0] clk_count;
  logic [2:0] bit_cnt;
  logic sck_toggle;

  assign CS = ~tx_en;

  // Baud rate generator
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      clk_count <= 0;
      sck_toggle <= CPOL;
    end else if (!CS) begin
      clk_count <= clk_count + 1;
      if (clk_count == CLK_DIV - 1) begin
        clk_count <= 0;
        sck_toggle <= ~sck_toggle;
      end
    end else begin
      clk_count <= 0;
      sck_toggle <= CPOL;
    end
  end

  assign SCK = sck_toggle;

  // FSM
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= IDLE;
      bit_cnt <= 0;
      PICO <= 0;
      data_out <= 0;
    end else begin
      case (state)
        IDLE: if (tx_en) state <= LOAD;

        LOAD: begin
          shift_reg <= data_in;
          bit_cnt <= 0;
          state <= SHIFT;
        end

        SHIFT: begin
          if ((CPHA == 0 && SCK == ~CPOL) || (CPHA == 1 && SCK == CPOL)) begin
            PICO <= shift_reg[BUS_LENGTH-1];
            shift_reg <= {shift_reg[BUS_LENGTH-2:0], 1'b0};
            state <= WAIT_SAMPLE;
          end
        end

        WAIT_SAMPLE: begin
          if ((CPHA == 0 && SCK == CPOL) || (CPHA == 1 && SCK == ~CPOL)) begin
            state <= SAMPLE;
          end
        end

        SAMPLE: begin
          sample_reg <= {sample_reg[BUS_LENGTH-2:0], POCI};
          bit_cnt <= bit_cnt + 1;
          if (bit_cnt == BUS_LENGTH - 1)
            state <= DONE;
          else
            state <= SHIFT;
        end

        DONE: begin
          data_out <= sample_reg;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule


module SPI_Peripheral #(parameter BUS_LENGTH = 8)
(
  input clk, rst,
  input PICO, SCK, CS, CPHA, CPOL,
  input [BUS_LENGTH-1:0] data_in,
  output logic POCI,
  output logic [BUS_LENGTH-1:0] data_out
);

  typedef enum logic [2:0] {IDLE, LOAD, SHIFT, SAMPLE, DONE} state_t;
  state_t state;

  logic [BUS_LENGTH-1:0] shift_reg;
  logic [BUS_LENGTH-1:0] sample_reg;
  logic [2:0] bit_cnt;

  logic SCK_prev;
  logic sck_rising, sck_falling;

  // Edge detection
  always_ff @(posedge clk or posedge rst) begin
    if (rst)
      SCK_prev <= CPOL;
    else
      SCK_prev <= SCK;
  end

  assign sck_rising  = (SCK == 1) && (SCK_prev == 0);
  assign sck_falling = (SCK == 0) && (SCK_prev == 1);

  // FSM
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= IDLE;
      bit_cnt <= 0;
      shift_reg <= 0;
      sample_reg <= 0;
      POCI <= 0;
      data_out <= 0;
    end else if (!CS) begin
      case (state)
        IDLE: state <= LOAD;

        LOAD: begin
          shift_reg <= data_in;
          bit_cnt <= 0;
          if (CPHA == 1) begin
            POCI <= data_in[BUS_LENGTH-1]; // preload first bit
            shift_reg <= {data_in[BUS_LENGTH-2:0], 1'b0};
            state <= SAMPLE; // skip first SHIFT
          end else begin
            state <= SHIFT;
          end
        end

        SHIFT: begin
          if ((CPHA == 0 && sck_falling) || (CPHA == 1 && sck_rising)) begin
            POCI <= shift_reg[BUS_LENGTH-1];
            shift_reg <= {shift_reg[BUS_LENGTH-2:0], 1'b0};
            state <= SAMPLE;
          end
        end

        SAMPLE: begin
          if ((CPHA == 0 && sck_rising) || (CPHA == 1 && sck_falling)) begin
            sample_reg <= {sample_reg[BUS_LENGTH-2:0], PICO};
            bit_cnt <= bit_cnt + 1;
            if (bit_cnt == BUS_LENGTH - 1)
              state <= DONE;
            else
              state <= SHIFT;
          end
        end

        DONE: begin
          data_out <= sample_reg;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule

// spi_parity_checker_tick.sv
// Very small SPI parity checker driven by a sample_tick (enable on sys clk).
// Computes even parity per word on PICO and POCI and flags if they differ.
// Sticky parity_err until rst.

module spi_parity_checker_tick #(
  parameter int BUS_LENGTH = 8
)(
  input  logic clk,          // system TB clock
  input  logic rst,          // active-high reset
  input  logic sample_tick,  // 1 pulse per sampled bit (from TB)
  input  logic cs_rise,      // 1-cycle pulse when CS deasserts (end of frame)
  input  logic PICO, POCI,   // monitored data lines
  output logic parity_err    // sticky until rst
);
  localparam int CNTW = (BUS_LENGTH <= 1) ? 1 : $clog2(BUS_LENGTH);
  logic [CNTW-1:0] bit_cnt;
  logic xor_pico, xor_poci;

  // Single clocked process: sample on sample_tick, clear on cs_rise.
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      bit_cnt    <= '0;
      xor_pico   <= 1'b0;
      xor_poci   <= 1'b0;
      parity_err <= 1'b0;
    end else begin
      // Clear accumulators when chip select deasserts (frame boundary)
      if (cs_rise) begin
        bit_cnt  <= '0;
        xor_pico <= 1'b0;
        xor_poci <= 1'b0;
      end

      // Sample and accumulate parity on each sample tick
      if (sample_tick) begin
        xor_pico <= xor_pico ^ PICO;
        xor_poci <= xor_poci ^ POCI;

        if (bit_cnt == BUS_LENGTH-1) begin
          // Compare even parity for the completed word; sticky flag
          if ((xor_pico ^ PICO) != (xor_poci ^ POCI))
            parity_err <= 1'b1;

          bit_cnt  <= '0;
          xor_pico <= 1'b0;
          xor_poci <= 1'b0;
        end else begin
          bit_cnt <= bit_cnt + 1'b1;
        end
      end
    end
  end

endmodule

