`timescale 1ns / 1ps
//ljt
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/10/09 23:28:37
// Design Name: 
// Module Name: pulse_match
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module pulse_match(
    input clk,
    input rst,
    input   [9:0] fb_ratio,
    input   [9:0] bf_ratio,
    output         flag_cut,
    output  [15:0] energy_pulse_width,
    output  reg    flag,
    output  reg    flag_match
    );
 
    parameter THRESHOLD_SOFT     = 25       ;
    parameter ERRO_RATE_SOFT     = 10       ;
    wire[11:0] THRESHOLD_VIO                ;
    wire[4:0]  ERRO_RATE_VIO                ;

    vio_threshold u_vio_threshold (
      .clk(clk),                // input wire clk
      .probe_out0(THRESHOLD_VIO),  // output wire [11 : 0] probe_out0
      .probe_out1(ERRO_RATE_VIO)  // output wire [4 : 0] probe_out1
    );

    wire [11:0] THRESHOLD;
    wire [4:0] ERRO_RATE;
  
    reg        vio_ctr  =0      ;
    reg        flag_d           ;
    reg        flag_2d          ;
    reg [15:0] cnt              ;
    reg [15:0] cnt_up           ;
    reg [15:0] cnt_down         ;
    reg [15:0] pulse_width      ;


    assign energy_pulse_width = pulse_width;
    assign THRESHOLD = (vio_ctr)?THRESHOLD_VIO:THRESHOLD_SOFT;
    assign ERRO_RATE = (vio_ctr)?ERRO_RATE_VIO:ERRO_RATE_SOFT;

    wire [12:0] PULSE_ONE_DOWN   = 500  - 500*ERRO_RATE/100  ;
    wire [12:0] PULSE_ONE_UP     = 500  + 500*ERRO_RATE/100 ;
    wire [12:0] PULSE_TWO_DOWN   = 750  - 750*ERRO_RATE/100  ;
    wire [12:0] PULSE_TWO_UP     = 750  + 750*ERRO_RATE/100 ;    
    wire [12:0] PULSE_THREE_DOWN = 1000 - 1000*ERRO_RATE/100 ;
    wire [12:0] PULSE_THREE_UP   = 1000 + 1000*ERRO_RATE/100;

    always @(posedge clk or posedge rst) begin
        if(rst)begin
            cnt_up  <= 0;
        end
        else if(fb_ratio> THRESHOLD)begin
            cnt_up  <= cnt_up + 1;
        end
        else if((cnt_up < 5)||(flag))begin //cnt_up reset when flag is set or when the cnt is less than 5
            cnt_up <= 'd0;
        end
    end

    always @(posedge clk or posedge rst) begin
        if(rst)begin
            cnt_down  <= 0;
        end
        else if((~flag)&&(flag_d))begin
            cnt_down <= 'd0;
        end
        else if(bf_ratio> THRESHOLD)begin
            cnt_down  <= cnt_down + 1;
        end
        else if((cnt_down < 5)||(~flag))begin
            cnt_down <= 'd0;
    end

    end

    always @(posedge clk or posedge rst) begin
        if(rst)begin
            flag   <= 0;
        end
        else if(cnt_up == 'd5)begin
            flag   <= 1;
        end
        else if(cnt_down == 'd5)begin
            flag   <= 0;
        end
        else begin
            flag   <= flag;
        end
    end    

    always @(posedge clk or posedge rst) begin
        if(rst)begin
            flag_d   <= 'd0;
            flag_2d  <= 'd0;
        end
        else begin
            flag_d <= flag;
            flag_2d<= flag_d;
        end

    end
    always @(posedge clk or posedge rst) begin
        if(rst)begin
            cnt         <= 'd0;
            pulse_width <= 'd0;
        end
        else if(flag)begin
            cnt <= cnt + 1;
        end
        else if((flag_d)&&(!flag))begin
            pulse_width <= cnt - 'd64;//cnt should be substracted from ENERGY_ACCUM
        end
        else begin
            cnt   <= 'd0;
            pulse_width <= pulse_width;
        end
    end

    localparam IDLE = 0,
               PULSE_ONE_MATCH   = 1,
               PULSE_TWO_MATCH   = 2,
               PULSE_THREE_MATCH = 3;

    reg [2:0] current_state;
    reg [2:0] next_state = IDLE;

    always@(posedge clk or negedge rst)begin
        if(rst)begin
            current_state <= IDLE;
        end
        else begin
            current_state <= next_state;
        end
    end

    always@(*)begin
        case(current_state)
            IDLE:begin
                if((flag_2d)&&(!flag_d))begin
                    next_state <= ((pulse_width>=PULSE_ONE_DOWN)&&(pulse_width<=PULSE_ONE_UP))?PULSE_ONE_MATCH:IDLE;
                end
                else begin
                    next_state <= next_state;
                end
            end
            PULSE_ONE_MATCH:begin
                if((flag_2d)&&(!flag_d))begin
                    next_state <= ((pulse_width>=PULSE_TWO_DOWN)&&(pulse_width<=PULSE_TWO_UP))?PULSE_TWO_MATCH:IDLE;
                end
                else begin
                    next_state <= next_state;
                end
            end
            PULSE_TWO_MATCH:begin
                if((flag_2d)&&(!flag_d))begin
                    next_state <= ((pulse_width>=PULSE_THREE_DOWN)&&(pulse_width<=PULSE_THREE_UP))?PULSE_THREE_MATCH:IDLE;
                end
                else begin
                    next_state <= next_state;
                end
            end  
            PULSE_THREE_MATCH:begin
                if((flag_2d)&&(!flag_d))begin
                    next_state <= IDLE;
                end
                else begin
                    next_state <= next_state;
                end
            end           
        endcase
    end

    always @(*) begin
        if(current_state == PULSE_THREE_MATCH)begin
            flag_match <= 1;
        end
        else begin
            flag_match <= 0;
        end
    end
    
    assign flag_cut = (flag_match&&(flag)&&(!flag_d))?1'b1:1'b0;

endmodule
