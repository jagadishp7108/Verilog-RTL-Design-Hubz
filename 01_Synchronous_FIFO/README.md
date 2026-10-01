# 01. Parameterized Synchronous FIFO

## Overview
A synthesizable, parameterized synchronous FIFO (First-In, First-Out) buffer implemented in Verilog HDL. The design buffers parallel data words across write and read operations synchronized to a single clock domain.

## Architecture & Specifications
- **Data Bus Width:** Configurable via `DATA_WIDTH` (Default: 8-bit).
- **Buffer Depth:** Configurable via `ADDR_WIDTH` (Default: $2^4 = 16$ words).
- **Control Interface:** 
  - `clk`: System clock.
  - `rst_n`: Active-low asynchronous reset.
  - `wr_en`: Synchronous write enable (blocked automatically when `full`).
  - `rd_en`: Synchronous read enable (blocked automatically when `empty`).
- **Flags:** Full-depth status indicators (`full`, `empty`).

## Design Highlights
- **Pointer Wrap-Around Logic:** Pointers utilize an additional MSB (`ADDR_WIDTH + 1` bits) to eliminate flag ambiguity without extra counter registers.
  - **Empty Condition:** Asserted when write pointer equals read pointer (`wr_ptr == rd_ptr`).
  - **Full Condition:** Asserted when MSBs differ while base index bits match (`wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]` and `wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]`).
- **Synthesis-Ready:** Clean separation of clocked registers and combinational flag detection logic.

## Verification & Simulation
- **Simulator:** Icarus Verilog (`iverilog`) via EDA Playground.
- **Waveform Viewer:** EPWave.
- **Test Scenarios Covered:**
  1. Reset assertion and initial empty flag verification.
  2. 16 consecutive writes up to memory saturation (asserting `full = 1`).
  3. 16 consecutive reads verifying strict FIFO ordering (`24h`, `81h`, `09h`, `63h`, etc.) until drain (asserting `empty = 1`).

### Simulation Waveform
![FIFO Simulation Waveform](01_Synchronous_FIFO/Sync_FIFO.png)
