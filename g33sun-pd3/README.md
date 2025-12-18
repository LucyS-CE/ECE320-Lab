# PD3: Register File and Execute Stage

This document guides you through the completion of your register file and execute stage.

**Deadline**: Friday, October 3, 2025 at 11:59 PM

**Weight**: 10% of total lab grade

## Environment Setup

### Getting the repository

Use `git` to clone the repository to your Linux environment. This can be done using:

```bash
git clone ist-git@git.uwaterloo.ca:ece320-f25/project/g33sun-pd3.git
```

### Setup of simulators and environment variables

Before beginning, ensure that your terminal is using the `bash` shell.
If you run `echo $SHELL`, it should return `/bin/bash` or similar.
If it returns a different shell (e.g. `zsh` or `tcsh`), run the following command:

```bash
chsh -s /bin/bash
```

Log out and log back in and your `echo $SHELL` should now return `/bin/bash`.

Next, go to the root of the project repository and execute the command `source env.sh`.
You should get an output similar to the following.

```bash
$ source env.sh
================ Computer Architecture Course Environment Setup ================

Project Root ($PROJECT_ROOT):           /home/your/path/to/repo
verilator Version ($VERILATOR_VERSION): Verilator 4.210 2021-07-07 rev v4.210
Vivado Version ($VIVADO_VERSION):       Vivado v2022.1 (64-bit)

================ Computer Architecture Course Environment Done =================
```

Note that you will need to run `source env.sh` *every time* you use a different `bash` session.
Otherwise, the scripts will not be able to locate the files.
If the script is unable to locate the verilator or vivado version, the corresponding line will be empty.

## Specification

### Register File

Implement a register file as presented in class for the subset of the RISC-V ISA instructions decoded in PD2.
We discussed the register file datapath design in class.
That is the register file you are required to implement.
The register file will be a synchronous component.
Once again, reads in the register file are combinational, and the writes are sequential.
The timing behaviour of the register file should be as follows: the output of the reads are available within the same clock cycle as when the address for the registers is supplied, and the writes to the registers are only available to be read in the next clock cycle.
You should see a resemblance between your memory module implementation and your register file.

Your register file module must have the following ports, with the exact port names provided:

- `clock` (1 bit): input
- `addr_rs1` (5 bits): input to select the first source register
- `addr_rs2` (5 bits): input to select the second source register
- `addr_rd` (5 bits): input to select the destination register
- `data_rd` (32 bits): input to write into the destination register
- `data_rs1` (32 bits): output of the contents of register specified by `addr_rs1`
- `data_rs2` (32 bits): output of the contents of register specified by `addr_rs2`
- `write_enable` (1 bit): input to write the contents of destination register specified by `addr_rd`.
If `write_enable` is not asserted, then the register file does not do any writes.
`write_enable` must be active-high, that is, use 1 to denote a write.

Please initialize `x2`, the stack pointer, to ``32'h01000000 + `MEM_DEPTH``.
All other registers should be initialized to 0.

For this project, use an `initial` block instead of adding ports to the register file.
The reason we are doing this is that, in PD6, we will be mapping the register file onto a block RAM (BRAM) on the FPGA.
When we do this, Vivado will expect an initial block to initialize the contents of the memory, whether it is specified directly in Verilog assignments or in an external file that we read with `$readmemh()`, as shown in the [Vivado manual](https://docs.amd.com/r/2022.1-English/ug901-vivado-synthesis/Initializing-RAM-Contents).
You can refer to the PD6 section in the project deliverables document on Learn for more information on how we will be dealing with the register file.

You may encounter issues with `write_enable` being asserted during reset. To get around this, you can have the reset logic embedded inside `write_enable` (i.e. `write_enable` must be 0 when reset is high).

### Execute Stage

The execute stage implements branch comparison and arithmetic logic unit (ALU) components.
Note that branches get resolved in the execute stage and the effective address is also computed in the execute stage.
The entire execute stage is combinational.
The result of LUI and AUIPC instructions should be calculated in ALU.

Note that you should not update the PC on branches and jumps yet.
We will implement this in PD4.

## Probes

You will need to fill in `design/signals.h` with your signal names in `design/code/pd.v` to wire up the probes.
The new probes are as follows:

```verilog
`define R_WRITE_ENABLE      ???
`define R_WRITE_DESTINATION ???
`define R_WRITE_DATA        ???
`define R_READ_RS1          ???
`define R_READ_RS2          ???
`define R_READ_RS1_DATA     ???
`define R_READ_RS2_DATA     ???

`define E_PC                ???
`define E_ALU_RES           ???
`define E_BR_TAKEN          ???
```

## Tests

We provide simple tests that test for signal presence and basic timing correctness.

- `test_register_file`: Tests some correctness properties of your register file.
- `test_pd`: Tests for basic signal presence and to generate trace files (see below).  Note that `test_pd` does not check correctness properties, so it does not output `Test passed` even if it successfully completes.

To run these tests, go to `verif/scripts` and use the following command:

```bash
make -s run [TEST=<test_name>] [MEM_PATH=<mem_path>]
```

If you do not supply a `TEST`, the command will default to the `test_pd` test.
We use the [rv32-benchmarks](https://git.uwaterloo.ca/ece320-f25/rv32-benchmarks) to test your design.
The path to the input `.x` file is provided to you as a macro of string named `MEM_PATH`.
You can set this macro when you run `make` to test different benchmarks.

We will be using trace files to output signal values at each pipeline stage every clock cycle.
For PD3, we will output information from the fetch, decode, and execute stages.
If it doesn't encounter any errors, the `test_pd` test will generate a `.trace` file for a given benchmark located in `verif/sim/verilator/test_pd/`.
This time, your output will consist of two new lines for each instruction:

- Register file `[R]`: formatted as `[R] addr_rs1 addr_rs2 data_rs1 data_rs2` in hexadecimal format.
- Execute stage `[E]`: formatted as `[E] pc_address alu_result branch_taken` in hexadecimal format.

For PD3, we provide you with the first 1450 lines of the golden trace files for the individual instruction benchmarks in `verif/golden`.
Make sure that your output lines up with these.

## Testbench

Apart from the tests we provided, you may write your own testbenches.
This is not required, but may help you find new bugs that the other tests cannot find.

You need to place your testbench in a module called `top`, located in `verif/tests/` (e.g. `verif/tests/test_my_pd.v`).
You may refer to `test_pd.v` and extend from that file.
By creating `test_my_pd.v`, you will be able to run the test in `verif/scripts` using `make run TEST=test_my_pd`.
Make sure that your design does not report any warning during compilation.

We provide the verilator `verif/tests/test_pd.cpp` that drives your testbench. 
However, your testbench should not depend on any modifications to the `test_pd.cpp`.

## Troubleshooting your Design

You may be tempted to rely on `$display()` tasks to debug your design.
However, it can be difficult to determine when signals change value with these statements.
Instead, you can plot the waves using `gtkwave`.
We have provided a Makefile target to do this:

```bash
make waves [MEM_PATH=<mem_path>]
```

You can edit `verif/scripts/waves.tcl` to automatically add specific signals to your screen, group signals together, set colours and zoom level, etc.
If you would like to do this Appendix C in the project deliverables document on LEARN.

Remember that if you add any verilog files to `design/code`, be sure to add them to `verif/scripts/design.f`.

## Submission

The following are deliverables for PD3.

1. Implement a register file module that meets the specifications above.
2. Implement the execute stage logic to determine the

   - ALU result
   - whether a branch is taken

3. Instantiate your register file and execute stage module (if applicable) in `design/code/pd.v`.
4. Add probe mappings to `design/signals.h`.
5. Make sure that your trace files are consistent with those in `verif/golden`.

Since we are not performing any writeback in PD3, we will be grading your execute stage as follows.
Every operation will be graded assuming the initialized register file state.
This means that the program execution will not be correct, but this will be resolved when you implement writeback in PD4.
A portion of your grade will also come from passing `test_register_file`.

When you are finished, remember to commit and push your changes to your GitLab repository.
Be sure to execute `git add <PATH(S) TO NEW FILE(S)>` if you add any new files before committing your changes.

```bash
git commit -am "<message>"
git push origin master
```

Your most recently pushed code prior to the deadline will be treated as your submission when we grade.

## Credits


The project structure heavily borrows the AWS EC2 FPGA HDK structure, [see here](https://github.com/aws/aws-fpga).
