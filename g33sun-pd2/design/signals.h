
/* Your Code Below! Enable the following define's 
 * and replace ??? with actual wires */
// ----- signals -----
// You will also need to define PC properly
`define F_PC                imemory_pc  // address
`define F_INSN              imemory_insn  // data_out

`define D_PC                pd_pc
`define D_OPCODE            pd_opcode
`define D_RD                pd_rd
`define D_RS1               pd_rs1
`define D_RS2               pd_rs2
`define D_FUNCT3            pd_funct3
`define D_FUNCT7            pd_funct7
`define D_IMM               pd_imm
`define D_SHAMT             pd_shamt


// ----- signals -----

// ----- design -----
`define TOP_MODULE          pd
// ----- design -----
