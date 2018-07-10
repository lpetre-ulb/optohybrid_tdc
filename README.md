# TDC module for the OptoHybrid in the GE1/1 project

Here is a quick description how to use the TDC module (hdl/tdc.vhd) with an example of integration in the OH v2a (example/tdc_wrapper_ohv2a.vhd).

The module measures the difference of time of arrival between the external trigger and the sbits with a VFAT granularity. It resolution is less than 150ps for time difference of up to 3.2µs (limit of the tested range).

## Ports of the module
* *clk_1x_i* is the main clock throughout the module, all the signals are synchronous to this clock.
* *clk_8x_i* is the clock used for sampling the delay line. It must be synchronous to *clk_1x_i*.
* Asserting *reset_i* during 1 clock cycle resets the module. The module must be reset each time the clocks change to align the clock domain crosser. Note that the calibration LUT is not reset and so a calibration must be launched once the reset is finished.
* *resetting_o* is asserted during reset.
* Asserting *calibrate_i* during 1 clock cycle starts a calibration using the internal ring oscillator as event source.
* *calibrating_o* is asserted during calibration. Note that when both *resetting_o* and *calibrating_o* are de-asserted, the module is active.
* *window_mask_i* defines the TDC window (1 bit = 25ns).
* *vfat_mask_i* disable the TDC for the defined VFATs.
* *trigger_i* is the asynchronous external trigger. Ideally, it is directly connected to the input pad.
* *sbits_i* is the logical OR of the sbits coming from the VFATs.
* *fifo_* * are the 24 FIFOs signals used to read the acquired events.
* *callut_* * allow to read the calibration LUT. It is a BRAM of 512 elements (hence 9 address bits) of 12 bits.

## Implementation on the OH v2a
Within the OH v2a, the communication is based on Wishbone. The reset, calibration, window mask, FIFOs and calibration LUT are read/written through "registers". To save address space, the calibration LUT is read through a single Wishbone address. The BRAM address is auto-increasing with each read while a write sets it to zero.
The clocks, external trigger, VFAT mask and sbits are collected among the existing signals.

