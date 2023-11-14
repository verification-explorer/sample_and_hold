//--------------------------------------------------------------------
// Sampale and hold model
//--------------------------------------------------------------------

`timescale 1ns/1ps
import cds_rnm_pkg::*;
import EE_pkg::*;
`define twopi 6.283185307


module samp_hold (vdd, vss, en, inp, inm, samp, hold, outp, outm, vcm);

    input logic en;
    input logic samp, hold;
    input wreal4state inp, inm;
    input wreal4state vcm;
    output wreal4state outp, outm;
    inout EEnet vdd, vss;

    parameter real vddMin = 1.6;        // Minimum supply voltage
    parameter real vddMax = 2.0;        // Maximum supply voltage
    parameter real vssMax = 0.1;        // Maximum ground voltgae
    parameter real Ts = 0.25;           // Finite bandwidth filter sampling rate
    parameter real Fp = 10.0e6;         // Finite bandwidth pole frequency
    parameter real InNsStd  = 1.0e-6;   // Input Noise standard deviation
    parameter real outNsStd = 1.0e-6;   // Output Noise standard deviation


    logic vddGood; logic vddGoodFilt;   // Signals for checking supply range
    logic vssGood; logic vssGoodFilt;   // Signals for checking ground range
    logic supplyOK;                     // Signal for checking all supplies range

    logic clk=0;                        // Internal clock to activate finite bandwidth filter
    logic enInt;                    // Internal integer to represent enable input signal
    logic shOn;                         // Sample and Hold on based on supplies and enable signals

    real sampInt;                       // Internal variable to sample input pins
    real outReal;                       // Internal variable that represent output signal
    real outLimit;                      // Internal variable that reoresent limit output signal

    // Internal variables for finite bandwidth filter
    real K, num_0,num_1,den_0,den_1,inNew,inOld,outNew,outOld;

    int seedp = 123;
    int seedm = 456;

    // Check supply range
    always begin
        vddGood = ((vdd.V >= vddMin) && (vdd.V <= vddMax));
        @ (vdd.V);
    end
    assign #(0.5e-9) vddGoodFilt = vddGood;

    // Check ground range
    always begin
        vssGood = ((vss.V <= vssMax) && (vss.V >= -vssMax));
        @ (vss.V);
    end
    assign #(0.5e-9) vssGoodFilt = vssGood;

    // Check if both supplies are in range
    assign supplyOK = vssGoodFilt && vddGoodFilt;

    // Enable pin
    always begin
        if (en === 1'b1)
            enInt = 1;
        else enInt = 0;
        @ (en);
    end

    // Turn on circuit if both enable and supplies are active
    always begin
        if ((enInt === 1'b1) && (supplyOK === 1'b1)) begin
            shOn = 1;
        end else begin
            shOn = 0;
        end
        @ (enInt or supplyOK);
    end

    // At sample phase sample input voltage and add noise
    always @ (posedge samp) begin
        sampInt = ((inp + InNsStd * $dist_normal(seedp,0,33)) - (inm + InNsStd * $dist_normal(seedm,0,33)));
    end

    // At hold phase vout = sample input voltage
    always @ (posedge hold) begin
        outReal = sampInt + outNsStd * $dist_normal(seedm,0,33);
    end

    // Filter sample rate
    always #(Ts*1e-9*1s) clk = ~clk;

    // Calculate finite bandwidth filter coefficients
    initial begin
        K = 2.0 / (Ts*Fp*`twopi/1s); den_0 = 1.0 + K; den_1 = 1.0 - K;
        inNew = 0; inOld = inNew; outNew = inNew; outOld = inNew;
    end

    // filter output voltage
    always @(clk) begin
        inOld=inNew;                                     // Set input [n-1]
        inNew = outReal;                                 // Set current input
        outOld=outNew;                                   // Set output [n-1]
        outNew=(inNew + inOld - outOld * den_1) / den_0; // compute new output
    end

    // Limit output voltage
    always_comb outLimit = vddMax * $tanh(outNew / vddMax);

    // Set outputs as a function of supplies and enable signals
    assign outp = (shOn == 1) ? (vcm + outLimit / 2.0) : `wrealZState;
    assign outm = (shOn == 1) ? (vcm - outLimit / 2.0) : `wrealZState;

endmodule
