module tb_wb_system_timer();

    parameter integer WB_ADDRESS_WIDTH = 32;
    parameter WB_BASE_ADDRESS = 32'h4001_0000;
    parameter integer WB_REGISTER_ADDRESS_WIDTH = 16;
    parameter integer WB_DATA_WIDTH = 32;
    parameter integer WB_DATA_GRANULARITY = 8;
    parameter IP_VERSION = 32'h0001_0000;
    parameter IP_DEVICE_ID = 32'h0002_0001;
    localparam COUNTER_WIDTH =  WB_DATA_WIDTH*2;

    localparam CONTROL_ADDR = WB_BASE_ADDRESS | 32'h08;
    localparam COUNTER_LOW_ADDR = WB_BASE_ADDRESS | 32'h20;
    localparam COUNTER_HIGH_ADDR = WB_BASE_ADDRESS | 32'h24;
    localparam COMPARE_LOW_ADDR = WB_BASE_ADDRESS | 32'h28;
    localparam COMPARE_HIGH_ADDR = WB_BASE_ADDRESS | 32'h2C;
    localparam PERIOD_LOW_ADDR = WB_BASE_ADDRESS | 32'h30;
    localparam PERIOD_HIGH_ADDR = WB_BASE_ADDRESS | 32'h34;

    localparam integer ENABLE = 32'h1;
    localparam integer COMPARE_ENABLE = 32'h2;
    localparam integer LOAD_COMPARE = 32'h4;
    localparam integer INT_PENDING = 32'h8;
    localparam integer INT_CLEAR = 32'h10;
    localparam integer AUTO_RELOAD = 32'h20;
    localparam integer LOAD_PERIOD = 32'h40;
    localparam integer RESET_COUNTER = 32'h80;

    logic wb_clk;
    logic wb_rst;

    logic[WB_ADDRESS_WIDTH-1:0] wb_addr;
    logic[WB_DATA_WIDTH-1:0] wb_m_data;
    logic[WB_DATA_WIDTH-1:0] wb_s_data;

    logic wb_cyc;
    logic wb_stb;
    logic wb_we;
    logic wb_sel;
    logic wb_ack;

    logic interrupt;


    initial
        $timeformat(-9, 0, " ns", 10);

    wb_system_timer timer(
                        .i_wb_clk(wb_clk),
                        .i_wb_rst(wb_rst),
                        .i_wb_addr(wb_addr),
                        .i_wb_dat(wb_m_data),
                        .o_wb_dat(wb_s_data),
                        .i_wb_cyc(wb_cyc),
                        .i_wb_stb(wb_stb),
                        .i_wb_we(wb_we),
                        .i_wb_sel(wb_sel),
                        .o_wb_ack(wb_ack),
                        .o_interrupt(interrupt)
                    );

    wb_master_bfm wb_bfm(
                      .clk(wb_clk),
                      .rst(wb_rst),
                      .o_wb_addr(wb_addr),
                      .o_wb_dat(wb_m_data),
                      .i_wb_dat(wb_s_data),
                      .o_wb_cyc(wb_cyc),
                      .o_wb_stb(wb_stb),
                      .o_wb_we(wb_we),
                      .o_wb_sel(wb_sel),
                      .i_wb_ack(wb_ack)
                  );

    initial
    begin
        wb_clk = 1'b0;
        wb_rst = 1'b1;
        #100 wb_rst = 1'b0;
    end

    always #5 wb_clk = ~wb_clk;

    logic[WB_DATA_WIDTH-1:0] rd_data = '0;
    logic[COUNTER_WIDTH-1:0] counter_data;
    logic[COUNTER_WIDTH-1:0] prev_counter_data;


    initial
    begin
        wait (wb_rst == 0);
        #100;

        // Test if counter works
        wb_bfm.single_read(COUNTER_LOW_ADDR, counter_data[WB_DATA_WIDTH-1:0]);
        wb_bfm.single_read(COUNTER_HIGH_ADDR, counter_data[COUNTER_WIDTH-1:WB_DATA_WIDTH]);

        if(counter_data != '0)
            $display("ERROR: %t expected counter to be 0, got 0x%016x", $time, counter_data);

        prev_counter_data = counter_data;

        wb_bfm.single_write(CONTROL_ADDR, ENABLE);
        repeat (20) @(posedge wb_clk);
        wb_bfm.single_write(CONTROL_ADDR, 0);

        wb_bfm.single_read(COUNTER_LOW_ADDR, counter_data[WB_DATA_WIDTH-1:0]);
        wb_bfm.single_read(COUNTER_HIGH_ADDR, counter_data[COUNTER_WIDTH-1:WB_DATA_WIDTH]);

        if(counter_data == prev_counter_data)
            $display("ERROR: %t expected counter greater then 0x%016x, got 0x%016x", $time, prev_counter_data, counter_data);

        wb_bfm.single_write(CONTROL_ADDR, RESET_COUNTER);
        wb_bfm.single_write(CONTROL_ADDR, 0);

        // Test if interrupt goes high when counter matches compare
        wb_bfm.single_write(COMPARE_LOW_ADDR, 32'd20);
        wb_bfm.single_write(COMPARE_HIGH_ADDR, 32'd0);

        wb_bfm.single_write(CONTROL_ADDR, LOAD_COMPARE | COMPARE_ENABLE);
        @(posedge wb_clk);
        fork
            begin
                wb_bfm.single_write(CONTROL_ADDR, ENABLE | COMPARE_ENABLE);

            end

            begin
                wait (wb_ack == 1)
                     repeat (19) @(posedge wb_clk); // Counter does first increment on ack
                @(negedge wb_clk);
                if(interrupt == 1'b0)
                    $display("ERROR: %t interrupt did not go high", $time);
            end
        join

        wb_bfm.single_read(CONTROL_ADDR, rd_data);
        if((rd_data & INT_PENDING) != INT_PENDING)
            $display("ERROR: %t control register does not indicate pending interrupt", $time);

        // Test if int_clear works
        wb_bfm.single_write(CONTROL_ADDR, INT_CLEAR);

        wb_bfm.single_read(CONTROL_ADDR, rd_data);
        if((rd_data & INT_PENDING) != 32'h0)
            $display("ERROR: %t control register still indicates an interupt", $time);


        // Test Auto-Reload
        wb_bfm.single_write(PERIOD_HIGH_ADDR, 32'h0);
        wb_bfm.single_write(PERIOD_LOW_ADDR, 32'd20);

        wb_bfm.single_write(CONTROL_ADDR, LOAD_PERIOD | RESET_COUNTER);
        wb_bfm.single_write(CONTROL_ADDR, ENABLE | COMPARE_ENABLE | AUTO_RELOAD);

        wait (interrupt == 1'b1);
        repeat (20) @(posedge wb_clk); // Counter does first increment on ack
        @(negedge wb_clk);
        if(interrupt == 1'b0)
            $display("ERROR: %t interrupt did not go high", $time);

        $finish;

    end

endmodule

