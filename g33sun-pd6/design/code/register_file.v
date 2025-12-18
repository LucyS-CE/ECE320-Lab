module register_file
(
    input clock,
    input write_enable,  // 1: write enable
    input [4:0] addr_rs1,
    input [4:0] addr_rs2,
    input [4:0] addr_rd,
    input [31:0] data_rd,
    output reg [31:0] data_rs1,
    output reg [31:0] data_rs2
);

(* ram_style = "block" *) reg [31:0] regs [0:31];

integer i;
initial begin
    for (i = 0; i < 32; i = i + 1) begin
        regs[i] = 32'b0;
    end
    regs[2] = 32'h0100_0000 + `MEM_DEPTH;
end

// sequential write
always @ (posedge clock) begin
    if (write_enable && addr_rd != 5'd0) begin
        regs[addr_rd] <= data_rd;
    end
end

// sequential read
always @ (posedge clock) begin
    data_rs1 <= regs[addr_rs1];
    data_rs2 <= regs[addr_rs2];
end

endmodule
