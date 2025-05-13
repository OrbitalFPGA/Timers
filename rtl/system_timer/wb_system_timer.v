`default_nettype none
module wb_system_timer #(
        parameter integer WB_ADDRESS_WIDTH = 32,
        parameter WB_BASE_ADDRESS = 32'h4001_0000,
        parameter integer WB_REGISTER_ADDRESS_WIDTH = 16,
        parameter integer WB_DATA_WIDTH = 32,
        parameter integer WB_DATA_GRANULARITY = 8,
        parameter IP_VERSION = 32'h0001_0000,
        parameter IP_DEVICE_ID = 32'h0002_0001,

        parameter ONESHOT_INTERRUPT = 1
    )(
        i_wb_clk,
        i_wb_rst,

        // Wishbone data signals
        i_wb_addr,
        i_wb_dat,
        o_wb_dat,

        // Wishbone control signals
        i_wb_cyc,
        i_wb_stb,
        i_wb_we,
        i_wb_sel,
        o_wb_ack,

        o_interrupt

    );

    localparam integer COUNTER_WIDTH = WB_DATA_WIDTH * 2;
    localparam integer SELECT_WIDTH = WB_DATA_WIDTH / WB_DATA_GRANULARITY;

    localparam integer ENABLE = 0;
    localparam integer COMPARE_ENABLE = 1;
    localparam integer LOAD_COMPARE = 2;
    localparam integer INT_PENDING = 3;
    localparam integer INT_CLEAR = 4;
    localparam integer AUTO_RELOAD = 5;
    localparam integer LOAD_PERIOD = 6;
    localparam integer RESET_COUNTER = 7;

    input wire i_wb_clk;
    input wire i_wb_rst;
    input wire[WB_ADDRESS_WIDTH-1:0] i_wb_addr;
    input wire[WB_DATA_WIDTH-1:0] i_wb_dat;
    output reg[WB_DATA_WIDTH-1:0] o_wb_dat;
    input wire i_wb_cyc;
    input wire i_wb_stb;
    input wire i_wb_we;
    input wire[SELECT_WIDTH-1:0] i_wb_sel;

    output reg o_wb_ack;
    output reg o_interrupt;

    reg[WB_DATA_WIDTH-1:0] control;
    reg[WB_DATA_WIDTH-1:0] next_control;

    reg[COUNTER_WIDTH-1:0] counter;
    wire[WB_DATA_WIDTH-1:0] counter_low;
    wire[WB_DATA_WIDTH-1:0] counter_high;

    reg[COUNTER_WIDTH-1:0] compare;
    reg[WB_DATA_WIDTH-1:0] compare_low;
    reg[WB_DATA_WIDTH-1:0] compare_high;

    reg[COUNTER_WIDTH-1:0] period;
    reg[WB_DATA_WIDTH-1:0] period_low;
    reg[WB_DATA_WIDTH-1:0] period_high;


    wire active_address;
    assign active_address = (i_wb_addr[WB_ADDRESS_WIDTH-1:WB_REGISTER_ADDRESS_WIDTH] == WB_BASE_ADDRESS[WB_ADDRESS_WIDTH-1:WB_REGISTER_ADDRESS_WIDTH]);

    reg[WB_DATA_WIDTH-1:0] active_reg;
    reg[WB_DATA_WIDTH-1:0] write_data;

    wire match;

    // Read mask
    integer i;
    always @(i_wb_clk)
        if(i_wb_rst)
            o_wb_dat <= 0;
        else
            if(!i_wb_we)
                for(i = 0; i < SELECT_WIDTH; i = i +1)
                    if(i_wb_sel[i])
                        o_wb_dat[i*WB_DATA_GRANULARITY +: WB_DATA_GRANULARITY] <= active_reg[i*WB_DATA_GRANULARITY +: WB_DATA_GRANULARITY];
                    else
                        o_wb_dat[i*WB_DATA_GRANULARITY +: WB_DATA_GRANULARITY] <= 0;



    always @(i_wb_clk)
        if(i_wb_rst)
            write_data <= 0;
        else
            if(i_wb_we)
                for(i = 0; i < SELECT_WIDTH; i = i + 1)
                    if(i_wb_sel[i])
                        write_data[i*WB_DATA_GRANULARITY +: WB_DATA_GRANULARITY] = i_wb_dat[i*WB_DATA_GRANULARITY +: WB_DATA_GRANULARITY];
                    else
                        write_data[i*WB_DATA_GRANULARITY +: WB_DATA_GRANULARITY] = active_reg[i*WB_DATA_GRANULARITY +: WB_DATA_GRANULARITY];

    wire ack;
    assign ack = (active_address) & (i_wb_cyc) & (i_wb_stb);
    // Wishbone ack logic
    always @(posedge i_wb_clk)
        if(i_wb_rst)
            o_wb_ack <= 0;
        else
            o_wb_ack <= ack;

    // Wishbone read logic
    always @(*)
    begin
        if((active_address) & (i_wb_cyc) & (i_wb_stb))
        begin
            case(i_wb_addr[5:0])
                6'h00:
                    active_reg = IP_VERSION;
                6'h04:
                    active_reg = IP_DEVICE_ID;
                6'h08:
                    active_reg = control;
                6'h20:
                    active_reg = counter_low;
                6'h24:
                    active_reg = counter_high;
                6'h28:
                    active_reg = compare_low;
                6'h2C:
                    active_reg = compare_high;
                6'h30:
                    active_reg = period_low;
                6'h34:
                    active_reg = period_high;
                default:
                    active_reg = 0;
            endcase
        end
    end

    // Wishbone write logic
    always @(posedge i_wb_clk)
    begin
        if (i_wb_rst)
        begin
            compare_low <= 0;
            compare_high <= 0;
            period_low <= 0;
            period_high <= 0;

        end
        else
            if((active_address) & (i_wb_cyc) & (i_wb_stb) & (i_wb_we))
            begin
                case(i_wb_addr[5:0])
                    6'h00:
                        ; // Read only
                    6'h04:
                        ; // Read only
                    6'h08:
                        ; // Logic elsewhere
                    6'h20:
                        ; // Read only
                    6'h24:
                        ; // Read only
                    6'h28:
                        compare_low <= write_data;
                    6'h2C:
                        compare_high <= write_data;
                    6'h30:
                        period_low <= write_data;
                    6'h34:
                        period_high <= write_data;
                endcase
            end
    end

    always @(posedge i_wb_clk)
    begin
        if (i_wb_rst)
            control <= 0;
        else
            if((active_address) & (i_wb_cyc) & (i_wb_stb) & (i_wb_we) & (i_wb_addr[5:0] == 6'h8))
                control <= write_data;
            else
            begin
                control <= next_control;
            end
    end

    always @(*)
    begin
        next_control = control;
        if(control[LOAD_COMPARE])
            next_control[LOAD_COMPARE] = 1'b0;
        if(control[LOAD_PERIOD])
            next_control[LOAD_PERIOD] = 1'b0;
        if(control[INT_CLEAR] & (!o_interrupt))
        begin
            next_control[INT_CLEAR] = 1'b0;
            next_control[INT_PENDING] = 1'b0;
        end
        else if (match)
            next_control[INT_PENDING] = 1'b1;
    end

    // Counter Logic
    assign counter_low = counter[WB_DATA_WIDTH-1:0];
    assign counter_high = counter[COUNTER_WIDTH-1:WB_DATA_WIDTH];

    always @(posedge i_wb_clk)
    begin
        if(i_wb_rst)
            counter <= 0;
        else
            if(control[RESET_COUNTER])
                counter <= 0;
            else
                if(control[ENABLE])
                    counter <= counter + 1;
    end

    always @(posedge i_wb_clk)
    begin
        if(i_wb_rst)
            compare <= 0;
        else
            if(control[LOAD_COMPARE])
            begin
                compare <= {compare_high, compare_low};
            end
            else if((o_interrupt) & (control[AUTO_RELOAD]))
            begin
                compare <= compare + period;
            end
    end

    always @(posedge i_wb_clk)
    begin
        if(i_wb_rst)
            period <= 0;
        else
            if(control[LOAD_PERIOD])
            begin
                period <= {period_high, period_low};
            end
    end


    assign match = (counter == (compare-1)) ? 1'b1 : 1'b0;
    // Interrupt logic
    always @(posedge i_wb_clk)
    begin
        if(i_wb_rst)
            o_interrupt <= 1'b0;
        else
            if(ONESHOT_INTERRUPT)
                o_interrupt <= match;
            else
                o_interrupt <=  control[INT_PENDING];
    end

endmodule
