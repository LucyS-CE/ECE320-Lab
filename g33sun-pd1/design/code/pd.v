module pd (
  input clock,
  input reset
);

  reg [31:0] imemory_pc;
  wire [31:0] imemory_insn;
  imemory imemory_0 (
    .clock(clock),
    .address(imemory_pc),
    .data_in(32'b0),    // no data in @ fetch stage
    .read_write(1'b0),  // no write @ fetch stage
    .data_out(imemory_insn)
  );

initial begin
  imemory_pc = 32'h0100_0000;
end

// PC fetch stage
always @(posedge clock) begin
  if(reset) imemory_pc <= 32'h0100_0000;
  else imemory_pc <= imemory_pc + 32'd4;
end

endmodule
