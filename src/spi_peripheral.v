module spi_peripheral (
    input wire clk,
    input wire rst_n,
    input wire [2:0] ui_in;
    output reg [7:0] en_reg_out_7_0,
    output reg [7:0] en_reg_out_15_8,
    output reg [7:0] en_reg_pwm_7_0,
    output reg [7:0] en_reg_pwm_15_8,
    output reg [7:0] pwm_duty_cycle); // surely this is fine...

    wire sclk_in = ui_in[0];
    wire copi_in = ui_in[1];
    wire ncs_in = ui_in[2];
    
    // Clock domain crossing bit:
    reg [1:0] sclk_chain;
    reg [1:0] copi_chain;
    reg [1:0] ncs_chain;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_chain <= 2'b00;
            copi_chain <= 2'b00;
            ncs_chain <= 2'b00;
        end
        else begin
            sclk_chain <= {sclk_chain[0], sclk_in};
            copi_chain <= {copi_chain[0], copi_in};
            ncs_chain <= {ncs_chain[0], ncs_in};
        end
    end
    // always take the more stable value of ..._chain[1]
    wire sclk_final;
    wire copi_final;
    wire ncs_final;
    assign sclk_final = sclk_chain[1];
    assign copi_final = copi_chain[1];
    assign ncs_final = ncs_chain[1];

    wire ncs_falling_edge;
    wire sclk_rising_edge;
    assign ncs_falling_edge = ~ncs_final & ncs_chain[0]; // previous value of ncs
    assign sclk_rising_edge = sclk_final & ~sclk_chain[0];

    reg [15:0] data; // the packet
    reg [4:0] counter; // counts the number of 1 bit signals sent
    
    // Data sampling logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data <= 16'd0;
            counter <= 5'd0;
        end
        else if (ncs_falling_edge) begin
            counter <= 5'd0; // start a new transaction
        end
        else if (~ncs_final & sclk_rising_edge) begin // collect data when sclk is rising and when not selecting another chip
            data <= {data[14:0], copi_final};
            counter <= counter + 1;
        end
    end

    // Data sending
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            en_reg_out_7_0 <= 8'd0;
            en_reg_out_15_8 <= 8'd0;
            en_reg_pwm_7_0 <= 8'd0;
            en_reg_pwm_15_8 <= 8'd0;
            pwm_duty_cycle <= 8'd0;
        end
        else if (sclk_rising_edge & !ncs_final & counter == 5'd16 & data[15]) begin
            case (data[14:8])
                7'h00 : en_reg_out_7_0 <= data[7:0];
                7'h01 : en_reg_out_15_8 <= data[7:0];
                7'h02 : en_reg_pwm_7_0 <= data[7:0];
                7'h03 : en_reg_pwm_15_8 <= data[7:0];
                7'h04 : pwm_duty_cycle <= data[7:0];
                default : ;// do nothing if address invalid
            endcase
        end 
    end
endmodule