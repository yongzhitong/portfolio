module apb_timer_formal;

    logic clk;
    logic rst;
    logic [3:0] paddr;
    logic psel;
    logic penable;
    logic pwrite;
    logic [7:0] pwdata;
    logic [7:0] prdata;
    logic [7:0] ctrl_reg_o;
    logic [7:0] limit_reg_o;
    logic [7:0] count_reg_o;
    logic flag_reg_o;

    logic [2:0] rst_count;
    logic write, read;
    logic limit_change;
    logic limit_larger, limit_smaller;

    assign write = psel && penable && pwrite;
    assign read = psel && penable && !pwrite;
    
    apb_slave2 dut (
        .clk(clk),
        .rst(rst),
        .paddr(paddr),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .prdata(prdata),
        .ctrl_reg_o(ctrl_reg_o),
        .limit_reg_o(limit_reg_o),
        .count_reg_o(count_reg_o),
        .flag_reg_o(flag_reg_o)
    );

    initial begin
        assume(rst);
        assume(rst_count == 3'b0);
        assume(limit_change == 1'b0);
        assume(limit_larger == 1'b0);
        assume(limit_smaller == 1'b0);
    end

    always @(posedge clk) begin
        if(rst_count < 3'd2) begin
            rst_count <= rst_count + 1;
            assume(rst);
            assume(!psel);
            assume(!penable);
            assume(limit_change == 1'b0);
            assume(limit_larger == 1'b0);
            assume(limit_smaller == 1'b0);
        end else begin
            assume(!rst);
            assume((paddr == 4'h0) || (paddr == 4'h4) || (paddr == 4'h8) || (paddr == 4'hC));
        end
    end

    always @(posedge clk) begin
        if(write)
            assume(paddr == 4'h0 || paddr == 4'h4);
    end

    //writing must not change prdata
    always @(posedge clk) begin
        if (write)
            assert(prdata == 8'h0);
    end

    //if psel or penable is low, prdata must not change
    always @(posedge clk) begin
        if (!psel || !penable)
            assert(prdata == 8'h0);
    end

    //writing must write correctly, reading must read correctly
    always @(posedge clk) begin
        if (!rst && $past(write)) begin
            if($past(paddr) == 4'h0)
                assert(ctrl_reg_o == $past(pwdata));
            else
                assert(limit_reg_o == $past(pwdata));
        end else if (read) begin
            if(paddr == 4'h0)
                assert(prdata == ctrl_reg_o);
            else if(paddr == 4'h4)
                assert(prdata == limit_reg_o);
            else if(paddr == 4'h8)
                assert(prdata == count_reg_o);
            else
                assert(prdata == flag_reg_o);
        end
    end

    //counter assertions
    always @(posedge clk) begin
        if(!rst && !$past(ctrl_reg_o[0]))
            assert(count_reg_o == $past(count_reg_o));
        else if(!rst && $past(ctrl_reg_o[0])) begin
            if(count_reg_o != 8'h0)
                assert(count_reg_o == $past(count_reg_o) + 1);
            else if($past(count_reg_o) == $past(limit_reg_o))
                assert(flag_reg_o);
        end
    end

    //limit changing during counter active
    always_ff @(posedge clk) begin
        if(!rst) begin
            if(limit_reg_o != $past(limit_reg_o)) begin
                limit_change <= 1'b1;
                if(limit_reg_o >= count_reg_o)
                    limit_larger <= 1'b1;
                else
                    limit_smaller <= 1'b1;
            end
            else if(flag_reg_o) begin
                limit_change <= 1'b0;
                limit_larger <= 1'b0;
                limit_smaller <= 1'b0;
            end
        end
    end

    //covers
    always @(posedge clk) begin
        if(!rst) begin
            cover(count_reg_o == 8'h15); //counter reaches 15
            cover(count_reg_o == 8'h0 && $past(count_reg_o) == 8'hFF); //counter fully wraps
            cover($past(write) && $past(paddr)==4'h0 && ctrl_reg_o[0]); //disable counter
            cover(flag_reg_o); //flag is set                                        
            cover(read && paddr==4'hC && prdata[0]); //read flag and flag is set                  
            cover($past(write) && read && paddr==$past(paddr)); //read right after write
            cover(limit_smaller);
            cover(limit_larger);
        end   
    end

    //cover counter staying at limit (enable disabled the moment it reaches limit)
    always @(posedge clk) begin
        if(!rst && ($past(count_reg_o) == $past(limit_reg_o)) && ($past(count_reg_o) > 8'h0) &&
        !flag_reg_o)
            cover(count_reg_o == limit_reg_o);
    end

    //cover flag behaviour when limit changes
    always @(posedge clk) begin
        if(limit_larger) begin
            cover(flag_reg_o);
        end else if(limit_smaller) begin
            cover(flag_reg_o);
        end
    end

endmodule