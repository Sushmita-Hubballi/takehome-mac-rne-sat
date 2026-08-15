`timescale 1ns/1ps
//
// mac_rne_sat -- implement your golden solution in this file per
// docs/spec.md, and push it to your fork's mac_rne_sat_golden branch.
//
module mac_rne_sat (
    input  logic               clk,
    input  logic               rst,       // synchronous, active-high
    input  logic               en,        // accumulate a*b this cycle
    input  logic               clr,       // clear accumulator this cycle
    input  logic               rd,        // request readout snapshot this cycle
    input  logic signed [7:0]  a,
    input  logic signed [7:0]  b,
    output logic signed [15:0] res,       // rounded + saturated snapshot
    output logic               res_valid, // 1-cycle pulse, one cycle after rd
    output logic               ovf        // sticky saturation flag
);
    logic signed [27:0] accumulate;
    logic signed [15:0] product;
    logic signed [19:0] quotient;
    logic [7:0] remainder;
    logic signed [16:0] rounded;
    logic saturation_done = 1'b0;
    assign product = a*b;
    //assign quotient = product >>> 8;

    always_ff @(posedge clk) begin
	if(rst) begin
            res       <= 16'b0;
            res_valid <= 1'b0;
            ovf       <= 1'b0;
            accumulate <= 28'b0;
	end else begin

            //accumulate
            if(clr && en) begin  //clr = 1 and en = 1
                accumulate <= {{12{product[15]}}, product};
            end else if(!clr && en) begin  //clr = 0 and en = 1
                accumulate <= accumulate + {{12{product[15]}}, product};
	    end else if(clr) begin //clr = 1 and en = 0
                accumulate <= 28'b0;
            end;

            //readout and saturation
            //round half to even at 8-LSBs
	    res_valid <= rd;
	    if(rd) begin
                quotient =  accumulate >>> 8;
                remainder = accumulate[7:0];
                //remainder = accumulate - ({accumulate[27:8],8'b0});
	        if(remainder > 128 || (remainder == 128 && quotient[0] == 1)) begin
                    rounded = quotient+ 1;
	        //end else if(remainder < 128 || (remainder == 128 && quotient[0] == 0)) begin
	        end else begin
                    rounded = quotient;
	        end;

		if(rounded[16] != rounded[15]) begin
			saturation_done = 1'b1;
			if(rounded[16] == 1'b0)
				res <= 16'h7fff;
			else
				res <= 16'h8000;
		end else begin
			saturation_done = 1'b0;
			res <= rounded;
		end;
	     end;

	     //ovf update
	     if(clr == 1 && saturation_done == 0)
		     ovf <= 1'b0;
	     else
		     ovf <= saturation_done;

	end;
    end;

endmodule
