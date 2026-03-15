module VGA_sync_gen(
    input clk,
    input rst_n,
    output h_sync,
    output v_sync,
    output reg DE,
    output [9:0] pixel_x,
    output [9:0] pixel_y
    );

    localparam H_ACTIVE         = 640;
    localparam H_FRONT_PORCH    = 16;
    localparam H_SYNC           = 96;
    localparam H_BACK_PORCH     = 48;
    localparam H_TOTAL          = H_ACTIVE + H_FRONT_PORCH + H_SYNC + H_BACK_PORCH; // 800

    localparam V_ACTIVE         = 480;
    localparam V_FRONT_PORCH    = 10;
    localparam V_SYNC           = 2;
    localparam V_BACK_PORCH     = 33;
    localparam V_TOTAL          = V_ACTIVE + V_FRONT_PORCH + V_SYNC + V_BACK_PORCH; // 525

    reg [9:0] h_count_r;
    reg [9:0] v_count_r;

    always @ (posedge clk) begin
        if (!rst_n) begin
            h_count_r <= 1'b0;
            v_count_r <= 1'b0;
        end
        else if ((v_count_r == V_TOTAL - 1) && (h_count_r == H_TOTAL - 1)) begin
            v_count_r <= 1'b0;
            h_count_r <= 1'b0;
        end
        else if (h_count_r == H_TOTAL - 1) begin 
            h_count_r <= 1'b0;
            v_count_r <= v_count_r + 1'b1;
        end
        else
            h_count_r <= h_count_r + 1'b1;
    end        

    assign h_sync = ~(h_count_r < H_SYNC); 
    assign v_sync = ~(v_count_r < V_SYNC); 
    
    always @ (*) begin
        if ((v_count_r >= V_SYNC + V_BACK_PORCH) && (v_count_r < V_SYNC + V_BACK_PORCH + V_ACTIVE)) 
            DE = ((h_count_r >=  H_SYNC + H_BACK_PORCH) && (h_count_r < H_SYNC + H_BACK_PORCH + H_ACTIVE)); 
        else 
            DE = 1'b0;
    end

    assign pixel_x = (h_count_r >= H_SYNC + H_BACK_PORCH) ? (h_count_r - (H_SYNC + H_BACK_PORCH)) : 10'd0;
    assign pixel_y = (v_count_r >= V_SYNC + V_BACK_PORCH) ? (v_count_r - (V_SYNC + V_BACK_PORCH)) : 10'd0;

endmodule



