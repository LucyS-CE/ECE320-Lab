module dmemory #(parameter MEM_DEPTH = `MEM_DEPTH, 
                 parameter START_ADDR = 32'h1000_0000)
(
    input wire clock,
    input wire [31:0] address,
    input wire [31:0] data_in,
    input wire write_enable,
    input wire [1:0] access_size, // 0: byte, 2: word, 1: half word
    output reg [31:0] data_out
);

reg [7:0] mem [0 : MEM_DEPTH - 1];    // 8 bits = 1 byte, mem address in byte

// Little Endian
integer shifted_addr0 = address - START_ADDR;  // lowest addr ==> LSB
integer shifted_addr1 = shifted_addr0 + 1;
integer shifted_addr2 = shifted_addr1 + 1;
integer shifted_addr3 = shifted_addr2 + 1;   // highest addr ==> MSB

// combinational read "="
always @* begin
    if (!write_enable && (shifted_addr3 < MEM_DEPTH)) begin
        data_out = {mem[shifted_addr3], mem[shifted_addr2], mem[shifted_addr1], mem[shifted_addr0]};
    end
    else data_out = 32'b0;
end

// sequential write "<="
always @(posedge clock) begin
    if (write_enable) begin
        case (access_size)
            2'b00: begin // byte
                if (shifted_addr0 < MEM_DEPTH) mem[shifted_addr0] <= data_in[7:0];
            end
            2'b01: begin // half word
                if (shifted_addr0 < MEM_DEPTH) mem[shifted_addr0] <= data_in[7:0];
                if (shifted_addr1 < MEM_DEPTH) mem[shifted_addr1] <= data_in[15:8];
            end
            2'b10: begin // word
                if (shifted_addr0 < MEM_DEPTH) mem[shifted_addr0] <= data_in[7:0];
                if (shifted_addr1 < MEM_DEPTH) mem[shifted_addr1] <= data_in[15:8];
                if (shifted_addr2 < MEM_DEPTH) mem[shifted_addr2] <= data_in[23:16];
                if (shifted_addr3 < MEM_DEPTH) mem[shifted_addr3] <= data_in[31:24];
            end
            default: ;  // do nothing
        endcase
    end
end

integer i;
integer mem_base0 = 0;
integer mem_base1 = 0;
integer mem_base2 = 0;
integer mem_base3 = 0;

reg [31:0] temp_arr [0:`LINE_COUNT - 1];   // temp arr address # in 4 bytes

initial begin
    $readmemh(`MEM_PATH, temp_arr);

    for (i = 0; i < `LINE_COUNT; i = i+1) begin
        mem_base0 = i * 4;
        mem_base1 = mem_base0 + 1;
        mem_base2 = mem_base1 + 1;
        mem_base3 = mem_base2 + 1;

        if (mem_base0 < MEM_DEPTH) mem[mem_base0] = temp_arr[i][7:0];
        if (mem_base1 < MEM_DEPTH) mem[mem_base1] = temp_arr[i][15:8];
        if (mem_base2 < MEM_DEPTH) mem[mem_base2] = temp_arr[i][23:16];
        if (mem_base3 < MEM_DEPTH) mem[mem_base3] = temp_arr[i][31:24];
    end
end
endmodule
