module alu (
    input               i_clk,
    input               i_rst_n,
    input               i_valid,
    input signed [11:0] i_data_a,
    input signed [11:0] i_data_b,
    input        [2:0]  i_inst,
    output              o_valid,
    output       [11:0] o_data,
    output              o_overflow
);
    
// ---------------------------------------------------------------------------
// Wires and Registers
// ---------------------------------------------------------------------------
reg  [11:0] o_data_w, o_data_r;
reg         o_valid_w, o_valid_r;
reg         o_overflow_w, o_overflow_r;
reg  [19:0] data_old;
reg         overflow_old;
wire [12:0] data_add, data_sub, data_mean;
wire [23:0] data_mul;
wire [19:0] data_mul_round;
wire [20:0] data_mac;
wire [11:0] data_a_abs, data_b_abs;
// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------
assign o_valid = o_valid_r;
assign o_data = o_data_r;
assign o_overflow = o_overflow_r;
assign data_add = {i_data_a[11], i_data_a} + {i_data_b[11], i_data_b};
assign data_sub = {i_data_a[11], i_data_a} - {i_data_b[11], i_data_b};
assign data_mul = {{12{i_data_a[11]}}, i_data_a} * {{12{i_data_b[11]}}, i_data_b};
assign data_mul_round = {data_mul[23], data_mul[23:5]} + {19'd0, data_mul[4]};
assign data_mac = {data_mul_round[19], data_mul_round} + {data_old[19], data_old};
assign data_mean = data_add >> 1;
assign data_a_abs = i_data_a[11]? ~(i_data_a)+12'd1: i_data_a;
assign data_b_abs = i_data_b[11]? ~(i_data_b)+12'd1: i_data_b;

// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------
always@(*) begin
  o_data_w = 12'd0;
  o_valid_w = i_valid;
  o_overflow_w = 1'b0;
  case(i_inst)
    3'b000: begin // Signed Addition
      o_overflow_w = ^data_add[12:11];
      o_data_w = data_add[11:0];
    end
    3'b001: begin // Signed Subtraction
      o_overflow_w = ^data_sub[12:11];
      o_data_w = data_sub[11:0];
    end
    3'b010: begin // Signed Multiplication
      o_data_w = data_mul_round[11:0];
      o_overflow_w = ~(data_mul_round[19:11] == 9'b1_1111_1111 | data_mul_round[19:11] == 9'b0_0000_0000);
    end
    3'b011: begin // MAC
      o_data_w = data_mac[11:0]; 
      o_overflow_w = ~(data_mac[20:11] == 10'b11_1111_1111 | data_mac[20:11] == 10'b00_0000_0000) | overflow_old;
    end
    3'b100: begin // XNOR
      o_data_w = ~(i_data_a ^ i_data_b);
    end
    3'b101: begin // ReLU
      o_data_w = ~i_data_a[11]? i_data_a: 12'd0;
    end
    3'b110: begin // Mean
      o_data_w = data_mean[11:0];
    end
    3'b111: begin // Absolute Max
      o_data_w = (data_a_abs >= data_b_abs)? data_a_abs: data_b_abs;
    end
  endcase
end

// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
always@(posedge i_clk or negedge i_rst_n) begin
  if(~i_rst_n) begin
    o_data_r <= 12'd0;
    o_overflow_r <= 1'b0;
    o_valid_r <= 1'b0;
  end 
  else begin
    o_data_r <= o_data_w;
    o_overflow_r <= o_overflow_w;
    o_valid_r <= o_valid_w;
  end
end

always@(posedge i_clk or negedge i_rst_n) begin
  if(~i_rst_n) begin
    data_old <= 20'd0;
    overflow_old <= 1'b0;
  end
  else if(i_inst == 3'b011)begin
    data_old <= {{8{o_data_w[11]}}, o_data_w};
    overflow_old <= o_overflow_w;
  end
  else begin
    data_old <= 20'd0;
    overflow_old <= 1'b0;
  end
end

endmodule
