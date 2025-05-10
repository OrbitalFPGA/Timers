# System Timer Specification 

**IP Name:** wb_system_timer

**Version:** 1.0

**Author:** Michael B.

**Date:** May 10, 2025

---

## 1. Overview

The 'wb_system_timer' is a 64-bit monotonic timer with a Wishbone B4 interface. It supports a programmable compare register to trigger a one-shot interrupt when the counter reaches a set value. An optional 'AUTO_RELOAD' mode enables periodic interrupts using a configurable 'PERIOD'. The timer includes control logic to start, stop, and clear interrupts in software.

## 2. Functional Requirements
| ID          | Requirement Description                               |
| ----------- | ----------------------------------------------------- |
| REQ-FUNC-01 | Provide a 64-bit free-running monotonic counter                     |
| REQ-FUNC-02 | Allow software to enable or disable the counter via a control register           |
| REQ-FUNC-03 | Provide a programmable 64-bit compare register to trigger a one-shot interrupt                            |
| REQ-FUNC-04 | Support periodic interrupt generation via 'AUTO_RELOAD' using a configurable 'PERIOD'                           |
| REQ-FUNC-05 | Provide an interrupt pending flag and software-clearable interrupt control         |
| REQ-FUNC-06 | Comply with the Wishbone B4 Pipeline specification as a subordinate|


## 3. Non-Functional Requirements
| ID           | Requirement Description                               |
| ------------ | ----------------------------------------------------- |
| REQ-NFUNC-01 | Synthesizable Verilog                                    |
| REQ-NFUNC-02 | Fully synchronous to `i_wb_clk`                       |
| REQ-NFUNC-03 | Timer behavior must be deterministic and monotonic |
| REQ-NFUNC-04 | Register interface must be memory-mapped and byte-addressable |


## 4. Interface Definition

### 4.1 Parameters
| Name                      | Default Value | Description                                                      |
| ------------------------- | ------------- | ---------------------------------------------------------------- |
| WB_ADDRESS_WIDTH          | 32            | Number of bits in address                                        |
| WB_BASE_ADDRESS           | 0x4001_0000   | Base address of interface/IP                                     | 
| WB_REGISTER_ADDRESS_WIDTH | 16            | Number of least-significant address bits used for register space |
| WB_DATA_WIDTH             | 32            | Number of bits in data bus                                       |
| WB_DATA_GRANULARITY       | 8             | Smallest unit of transfer interface support                      |
| IP_VERSION                | WB_DATA_WIDTH | Value to expose in the VERSION Register                          |
| IP_DEVICE_ID              | WB_DATA_WIDTH | Value to expose in the DEVICE_ID Register                        |


### 4.2 Wishbone Signals
| Signal  | Direction | Width                                | Description         |
| ------- | --------- | ------------------------------------ | ------------------- |
| i_wb_clk   | Input     | 1                                    | System Clock        |
| i_wb_rst   | Input     | 1                                    | Active-high reset   |
| i_wb_cyc   | Input     | 1                                    | Bus cycle indicator | 
| i_wb_stb   | Input     | 1                                    | Data Strobe signal  |
| i_wb_we    | Input     | 1                                    | Write Enable        |
| i_wb_addr  | Input     | WB_ADDRESS_WIDTH                     | Address Bus         |
| i_wb_dat   | Input     | WB_DATA_WIDTH                        | Data input Bus      |
| i_wb_sel   | Input     | WB_DATA_WIDTH  / WB_DATA_GRANULARITY | Data select         | 
| o_wb_dat   | Output    | WB_DATA_WIDTH                        | Data output Bus     |
| o_wb_stall | Output    | 1                                    | Stall signal        | 
| o_wb_ack | Output    | 1                                    | Acknowledge      | 

### 4.3 IP Signals
| Signal  | Direction | Width                                | Description         |
| ------- | --------- | ------------------------------------ | ------------------- |
| o_interrupt | Output  | 1                                  | Interrupt signal, oneshot when `COUNT` equals `COMP`  |  

## 5. Register Map
| Offset | Name         | Description                                 | R/W  |
| ------ | ------------ | ------------------------------------------- | ---- |
| 0x00   | VERSION      | Version number of IP                        | R    | 
| 0x04   | DEVICE_ID    | Unique 32-bit identifier for IP             | R    |
| 0x08   | CONTROL      | Control bits for module operation           | R    |  
| 0x0C   | RESERVED     | RESERVED                                    | R    |  
| 0x10   | RESERVED     | RESERVED                                    | R    |  
| 0x14   | RESERVED     | RESERVED                                    | R    |  
| 0x18   | RESERVED     | RESERVED                                    | R    |  
| 0x1C   | RESERVED     | RESERVED                                    | R    |
| 0x20   | COUNT_LO     | Lower 32-bit of counter                     | R  |
| 0x24   | COUNT_HI     | Upper 32-btis of counter                    | R  | 
| 0x28   | COMP_LO      | Lower 32-bits of compare value              | R/W  | 
| 0x2C   | COMP_HI      | Upper 32-bits of compare value              | R/W  | 
| 0x30   | PERIOD_LO    | Lower 32-bits of period value               | R/W  | 
| 0x34   | PERIOD_HI    | Upper 32-bits of period value               | R/W  | 

R/WC: Read/Write 1 to bit to clear

### 5.1 Control Register
| Bit  | Field Name       | Access Type | Reset Value | Description                                                           |
| ---- | ---------------- | ----------- | ----------- | --------------------------------------------------------------------- |
| 0    | `ENABLE`         | R/W         | 0           | Enables the 64-bit counter when set.                                  |
| 1    | `COMPARE_ENABLE` | R/W         | 0           | Enables interrupt generation on counter/compare match.                |
| 2    | `INT_PENDING`    | R           | 0           | Set when counter matches compare; cleared by writing `INT_CLEAR = 1`. |
| 3    | `INT_CLEAR`      | W           | -           | Write `1` to clear the interrupt pending flag (`INT_PENDING`).        |
| 4    | `AUTO_RELOAD`    | R/W         | 0           | Enables automatic compare reload using the `PERIOD` value.            |
| 31:5 | `RESERVED`       | -           | 0           | Reserved for future use; must be written as zero.                     |

### 5.2 COUNT, COMP, PERIOD
| Bit  | Field Name | Access Type | Reset Value              | Description                                                                        |
| ---- | ---------- | ----------- | ------------------------ | ---------------------------------------------------------------------------------- |
| 63:0 | `COUNT`    | R/W         | 0x0000\_0000\_0000\_0000 | 64-bit free-running counter. Increments continuously when `ENABLE` is set.         |
| 63:0 | `COMP`     | R/W         | 0xFFFF\_FFFF\_FFFF\_FFFF | 64-bit compare value. Interrupt triggers when `COUNT == COMP`.                     |
| 63:0 | `PERIOD`   | R/W         | 0x0000\_0000\_0000\_0000 | 64-bit reload interval. Added to `COMP` after match when `AUTO_RELOAD` is enabled. |

## 6. Timing Diagrams

## 7. Verification Strategy
A self-checking SystemVerilog testbench will be developed to verify the functional correctness of the timer IP.
Test Coverage will include the following
* Counter enable/disable behavior.
* Compare match interrupt triggering.
* `INT_CLEAR` and `INT_PENDING` interaction.
* Auto-reload mode and periodic interrupt behavior.

## 8. Future Enhancements


## 9. Change History

| Version | Date             | Changes                   |
|---------|----------------  |---------------------------|
| 1.0     | May 10, 2025   | Initial draft             |

## 10. References

- [Wishbone B4 Specification](https://cdn.opencores.org/downloads/wbspec_b4.pdf), OpenCores, Revision B4.
- [Wishbone Interface Logic](https://github.com/OrbitalFPGA/wb-subordinate-if-sv)