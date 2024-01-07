module mmu_sv32
    (
        /* ----- 制御 ----- */
        input wire          CLK,
        input wire          RST,
        input wire  [31:0]  SATP,

        /* ----- MMU->Mem 接続 (物理アドレス) ----- */
        // 命令
        output wire         MEM_INST_RDEN,
        output wire [31:0]  MEM_INST_RIADDR,
        input wire  [31:0]  MEM_INST_ROADDR,
        input wire          MEM_INST_RVALID,
        input wire  [31:0]  MEM_INST_RDATA,

        // データ
        output wire         MEM_DATA_RDEN,
        output wire [31:0]  MEM_DATA_RIADDR,
        input wire  [31:0]  MEM_DATA_ROADDR,
        input wire          MEM_DATA_RVALID,
        input wire  [31:0]  MEM_DATA_RDATA,
        output wire         MEM_DATA_WREN,
        output wire [3:0]   MEM_DATA_WSTRB,
        output wire [31:0]  MEM_DATA_WADDR,
        output wire [31:0]  MEM_DATA_WDATA,

        // ハザード
        input wire          MEM_WAIT,

        /* ----- Core->MMU 接続 (物理アドレス or 仮想アドレス) ----- */
        // 命令
        input wire          MAIN_INST_RDEN,
        input wire  [31:0]  MAIN_INST_RIADDR,
        output wire [31:0]  MAIN_INST_ROADDR,
        output wire         MAIN_INST_RVALID,
        output wire [31:0]  MAIN_INST_RDATA,

        // データ
        input wire          MAIN_DATA_RDEN,
        input wire  [31:0]  MAIN_DATA_RIADDR,
        output wire [31:0]  MAIN_DATA_ROADDR,
        output wire         MAIN_DATA_RVALID,
        output wire [31:0]  MAIN_DATA_RDATA,
        input wire          MAIN_DATA_WREN,
        input wire  [3:0]   MAIN_DATA_WSTRB,
        input wire  [31:0]  MAIN_DATA_WADDR,
        input wire  [31:0]  MAIN_DATA_WDATA,

        // ハザード
        output wire         MMU_WAIT
    );

    /* ----- Mem 接続 ---- */
    assign MEM_INST_RDEN    = trans_inst_done ? MAIN_INST_RDEN : 1'b0;
    assign MEM_INST_RIADDR  = trans_inst_done ? trans_inst_paddr : 32'b0;
    assign MAIN_INST_ROADDR = MEM_INST_ROADDR;
    assign MAIN_INST_RVALID = MEM_INST_RVALID;
    assign MAIN_INST_RDATA  = MEM_INST_RDATA;

    assign MEM_DATA_RDEN    = state == S_INST ? trans_inst_rden : (
                              state == S_DATA ? trans_data_rden :
                              trans_data_done ? MAIN_DATA_RDEN : (
                                                1'b0));
    assign MEM_DATA_RIADDR  = state == S_INST ? trans_inst_raddr : (
                              state == S_DATA ? trans_data_raddr :
                              trans_data_done ? trans_data_paddr : (
                                                32'b0));
    assign MAIN_DATA_ROADDR = state == S_IDLE ? MEM_DATA_ROADDR : 32'b0;
    assign MAIN_DATA_RVALID = state == S_IDLE ? MEM_DATA_RVALID : 1'b0;;
    assign MAIN_DATA_RDATA  = state == S_IDLE ? MEM_DATA_RDATA : 32'b0;

    assign MEM_DATA_WREN    = MAIN_DATA_WREN;
    assign MEM_DATA_WSTRB   = MAIN_DATA_WSTRB;
    assign MEM_DATA_WADDR   = MAIN_DATA_WADDR;
    assign MEM_DATA_WDATA   = MAIN_DATA_WDATA;

    assign MMU_WAIT         = MEM_WAIT || next_state != S_IDLE;

    /* ----- Mem アクセス制御用ステートマシン ----- */
    parameter S_IDLE = 2'b00;
    parameter S_INST = 2'b01;
    parameter S_DATA = 2'b11;

    reg [1:0] state, next_state;

    always @ (posedge CLK) begin
        if (RST)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    always @* begin
        case (state)
            S_IDLE:
                if (!trans_inst_done && MAIN_INST_RDEN)
                    next_state <= S_INST;
                else if (!trans_data_done && MAIN_DATA_RDEN)
                    next_state <= S_DATA;
                else
                    next_state <= S_IDLE;

            S_INST:
                if (trans_inst_done)
                    if (!trans_data_done && MAIN_DATA_RDEN)
                        next_state <= S_DATA;
                    else
                        next_state <= S_IDLE;
                else
                    next_state <= S_INST;

            S_DATA:
                if (trans_data_done)
                    next_state <= S_IDLE;

            default:
                next_state <= S_IDLE;
        endcase
    end

    /* ----- 変換処理 ----- */
    // 命令
    wire        trans_inst_done, trans_inst_rden, trans_inst_rvalid;
    wire [31:0] trans_inst_paddr, trans_inst_raddr, trans_inst_rdata;

    assign trans_inst_rvalid = state == S_INST ? MEM_DATA_RVALID : 1'b0;
    assign trans_inst_rdata  = state == S_INST ? MEM_DATA_RDATA : 32'b0;

    mmu_sv32_translate translate_inst (
        // 制御
        .CLK        (CLK),
        .RST        (RST),
        .SATP       (SATP),

        // 変換
        .REQ        (MAIN_INST_RDEN),
        .VADDR      (MAIN_INST_RIADDR),
        .DONE       (trans_inst_done),
        .PADDR      (trans_inst_paddr),

        // Mem 接続
        .RDEN       (trans_inst_rden),
        .RADDR      (trans_inst_raddr),
        .RVALID     (trans_inst_rvalid),
        .RDATA      (trans_inst_rdata)
    );

    // データ
    wire        trans_data_done, trans_data_rden, trans_data_rvalid;
    wire [31:0] trans_data_paddr, trans_data_raddr, trans_data_rdata;

    assign trans_data_rvalid = state == S_DATA ? MEM_DATA_RVALID : 1'b0;
    assign trans_data_rdata  = state == S_DATA ? MEM_DATA_RDATA : 32'b0;

    mmu_sv32_translate translate_data (
        // 制御
        .CLK        (CLK),
        .RST        (RST),
        .SATP       (SATP),

        // 変換
        .REQ        (MAIN_DATA_RDEN),
        .VADDR      (MAIN_DATA_RIADDR),
        .DONE       (trans_data_done),
        .PADDR      (trans_data_paddr),

        // Mem 接続
        .RDEN       (trans_data_rden),
        .RADDR      (trans_data_raddr),
        .RVALID     (trans_data_rvalid),
        .RDATA      (trans_data_rdata)
    );

endmodule

module mmu_sv32_translate
    (
        /* ----- 制御 ----- */
        input  wire         CLK,
        input  wire         RST,
        input  wire [31:0]  SATP,

        /* ----- 変換 ----- */
        input  wire         REQ,
        input  wire [31:0]  VADDR,
        output wire         DONE,
        output wire [31:0]  PADDR,

        /* ----- Mem 接続 ----- */
        output reg          RDEN,
        output reg  [31:0]  RADDR,
        input  wire         RVALID,
        input  wire [31:0]  RDATA
    );

    /* ----- モード判定 ----- */
    assign DONE  = SATP[31] ? translate_done : 1'b1;
    assign PADDR = SATP[31] ? translate_paddr : VADDR;

    /* ----- 変換処理用ステートマシン ----- */
    parameter S_IDLE    = 2'b00;
    parameter S_LEVEL_2 = 2'b01;
    parameter S_LEVEL_1 = 2'b11;
    parameter S_WAIT    = 2'b10;

    reg  [1:0]  state, next_state;

    reg         translate_done;
    reg  [31:0] translate_paddr;

    always @ (posedge CLK) begin
        if (RST)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    always @* begin
        case (state)
            S_IDLE:
                if (REQ && SATP[31])
                    next_state <= S_LEVEL_2;
                else
                    next_state <= S_IDLE;

            S_LEVEL_2:
                if (RVALID)
                    if (RDATA[3:0] == 4'b0001)  // XMR = 000, V = 1, Next level
                        next_state <= S_LEVEL_1;
                    else                        // XMR = xxx, V = 1, PTE
                        next_state <= S_WAIT;
                else
                    next_state <= S_LEVEL_2;

            S_LEVEL_1:
                if (RVALID)                     // XMR = xxx, V = 1, PTE
                    next_state <= S_WAIT;
                else
                    next_state <= S_LEVEL_1;

            S_WAIT:
                if (!REQ)
                    next_state <= S_IDLE;
                else
                    next_state <= S_WAIT;

            default:
                next_state <= S_IDLE;
        endcase
    end

    always @ (posedge CLK) begin
        if (RST) begin
            RDEN <= 1'b0;
            RADDR <= 32'b0;
        end
        else if (state == S_IDLE && next_state == S_LEVEL_2) begin
            RDEN <= 1'b1;
            RADDR <= { ({ SATP[21:0], 8'b0 } + { 20'b0, VADDR[31:22] }), 2'b00 };
        end
        else if (state == S_LEVEL_2 && next_state == S_LEVEL_1) begin
            RDEN <= 1'b1;
            RADDR <= { ({ RDATA[21:0], 8'b0 } + { 20'b0, VADDR[21:12] }), 2'b00 };
        end
        else if (next_state == S_WAIT) begin
            RDEN <= 1'b0;
            RADDR <= 32'b0;
        end
    end

    always @ (posedge CLK) begin
        if (RST) begin
            translate_done <= 1'b0;
            translate_paddr <= 32'b0;
        end
        else if ((state == S_LEVEL_2 || state == S_LEVEL_1) && next_state == S_WAIT) begin
            translate_done <= 1'b1;
            translate_paddr <= { RDATA[31:12], VADDR[11:0] };
        end
        else if (state == S_WAIT && !REQ) begin
            translate_done <= 1'b0;
            translate_paddr <= 32'b0;
        end
    end

endmodule
