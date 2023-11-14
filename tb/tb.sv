
`timescale 1ns/1ps
`define twopi 6.28318530718

import cds_rnm_pkg::*;
import EE_pkg::*;

module tb;

    parameter real Fin=10.0e3;
    parameter real Ts = 7;
    parameter real Av = 0.6;

    EEnet vdd;
    EEnet vss;

    logic en;
    wreal4state inp;
    wreal4state inm;
    real outp, outm, vcm;
    real sinReal;
    real Phs=0;
    real inpReal, inmReal;
    real vddReal, vssReal;

    logic samp;
    logic hold;

    assign vdd = '{vddReal,0.0,0.1};
    assign vss = '{vssReal,0.0,0.1};

    assign inp = inpReal;
    assign inm = inmReal;

    samp_hold samp_hold(
        .vdd(vdd),
        .vss(vss),
        .en(en),
        .inp(inp),
        .inm(inm),
        .samp(samp),
        .hold(hold),
        .outp(outp),
        .outm(outm),
        .vcm(vcm)
    );


    initial begin
        en = 0;
        vcm = 0.5;
        inpReal = 0.0;
        inmReal = 0.0;
        vddReal = 0.0;
        vssReal = 0.0;

        // Turn on Supply
        #1us;
        vddReal = 1.8;
        #1us;
        en = 1;
        #1us;
        repeat (5*int'(Fin/Ts)) begin
            sinReal = Av * $sin(`twopi*Phs);
            #Ts Phs = Phs+Ts*Fin/1e9;       // update phase after delay
            if (Phs>=1) Phs -= 1;
            inpReal = vcm + sinReal / 2.0;
            inmReal = vcm - sinReal / 2.0;
        end
        inpReal = vcm;
        inmReal = vcm;
        #1us;
        inpReal = vcm + 0.5;
        inmReal = vcm - 0.5;
        #1us;
        $stop;
    end

    // Non overlap clocks
    logic clk=0;
    always #(5ns) clk = ~clk;

    nor #(0.1) (na,clk,ph2);
    not  #(0.1) (nb,na);
    not  #(0.1) (ph1,nb);

    not  #(0.1) (clkb,clk);
    nor #(0.1) (nc,clkb,ph1);
    not  #(0.1) (nd,nc);
    not  #(0.1) (ph2,nd);

    assign samp = en & ph1;
    assign hold = en & ph2;


endmodule
