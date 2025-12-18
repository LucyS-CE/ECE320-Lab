
/* Your Code Below! Enable the following define's 
 * and replace ??? with actual wires */
// ----- signals -----
// You will also need to define PC properly
`define F_PC                    imemory_pc  // address
`define F_INSN                  imemory_insn  // data_out

`define D_PC                    pd_pc
`define D_OPCODE                pd_opcode
`define D_RD                    pd_rd
`define D_RS1                   pd_rs1
`define D_RS2                   pd_rs2
`define D_FUNCT3                pd_funct3
`define D_FUNCT7                pd_funct7
`define D_IMM                   pd_imm
`define D_SHAMT                 pd_shamt

`define R_WRITE_ENABLE          register_file_write_enable
`define R_WRITE_DESTINATION     register_file_write_destination
`define R_WRITE_DATA            register_file_write_data
`define R_READ_RS1              register_file_read_rs1
`define R_READ_RS2              register_file_read_rs2
`define R_READ_RS1_DATA         register_file_read_rs1_data
`define R_READ_RS2_DATA         register_file_read_rs2_data


`define E_PC                    pd_es_pc    
`define E_ALU_RES               pd_es_alu_res
`define E_BR_TAKEN              pd_es_br_taken

// ----- signals -----

// ----- design -----
`define TOP_MODULE                 pd
// ----- design -----
