# 02. Configurable UART Transmitter (TX) with FSM

## Overview
A synthesizable, parameterized UART (Universal Asynchronous Receiver-Transmitter) transmitter implemented in Verilog HDL. The module serializes an 8-bit parallel byte using standard NRZ (Non-Return-to-Zero) framing protocol controlled by an internal Finite State Machine (FSM).

## Architecture & Specifications
- **Baud Rate Generator:** Parameterized clock divider derived from `CLK_FREQ` and `BAUD_RATE`.
- **Frame Format:** 1 Start bit (active-low), 8 Data bits (LSB-first), 1 Stop bit (active-high).
- **Interface Ports:**
  - `clk`: System clock.
  - `rst_n`: Active-low asynchronous reset.
  - `tx_start`: Single-cycle strobe to latch input byte and initiate transfer.
  - `tx_data [7:0]`: 8-bit parallel data word to be transmitted.
  - `tx`: Serial output pin (idles high).
  - `tx_busy`: Status flag indicating transmission in progress.

## FSM State Implementation
The transmission cycle progresses through four distinct hardware states:
1. **IDLE (`3'b000`):** Drive `tx = 1'b1`, wait for assertion of `tx_start`.
2. **START (`3'b001`):** Drive `tx = 1'b0` for one full bit duration (`CLKS_PER_BIT`).
3. **DATA (`3'b010`):** Iteratively shift out bits 0 through 7 across respective bit periods.
4. **STOP (`3'b011`):** Return `tx = 1'b1` to signify frame completion and release `tx_busy`.

## Verification & Simulation
- **Simulator:** Icarus Verilog (`iverilog`) via EDA Playground.
- **Waveform Viewer:** EPWave.
- **Test Scenarios Covered:**
  1. Reset recovery and verification of default idle line level (`tx = 1`).
  2. Transmission of `0xA5` (`10100101b`) with timing analysis on individual LSB-to-MSB data windows.
  3. Subsequent back-to-back transmission of `0x3C` (`00111100b`) confirming correct `tx_busy` de-assertion and frame recovery.

### Simulation Waveform
![UART TX Simulation Waveform](uart_tx_waveform.png)
