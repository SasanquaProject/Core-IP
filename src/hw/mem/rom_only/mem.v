module mem_rom_only
    (
        /* ----- 制御 ----- */
        // クロック, リセット
        input wire          CLK,
        input wire          RST,

        // パイプライン制御
        output wire         MEM_WAIT,

        /* ----- メモリアクセス信号 ----- */
        // 命令 (優先度 高)
        input wire          INST_RDEN,
        input wire  [31:0]  INST_RIADDR,
        output wire [31:0]  INST_ROADDR,
        output wire         INST_RVALID,
        output wire [31:0]  INST_RDATA,

        // データ (優先度 低)
        input wire          DATA_RDEN,
        input wire  [31:0]  DATA_RIADDR,
        output wire [31:0]  DATA_ROADDR,
        output wire         DATA_RVALID,
        output wire [31:0]  DATA_RDATA,
        input wire          DATA_WREN,
        input wire  [3:0]   DATA_WSTRB,
        input wire  [31:0]  DATA_WADDR,
        input wire  [31:0]  DATA_WDATA
    );

    assign MEM_WAIT = 1'b0;

    /* ----- ROM ----- */
    wire [31:0] rom_inst_roaddr, rom_inst_rdata, rom_data_roaddr, rom_data_rdata;
    wire [11:0] rom_inst_roaddr_12, rom_data_roaddr_12;
    wire        rom_inst_rvalid, rom_data_rvalid;

    assign INST_ROADDR = { 20'b0, rom_inst_roaddr_12 };
    assign DATA_ROADDR = { 20'b0, rom_data_roaddr_12 };

    rom_dualport # (
        .ADDR_WIDTH         (10),   // => SIZE: 1024
        .DATA_WIDTH_2POW    (0)     // => WIDTH: 32bit
    ) rom_dualport (
        // 制御
        .CLK                (CLK),
        .RST                (RST),

        // アクセスポート
        .A_SELECT           (1'b1),
        .A_RDEN             (INST_RDEN),
        .A_RIADDR           (INST_RIADDR),
        .A_ROADDR           (rom_inst_roaddr_12),
        .A_RVALID           (INST_RVALID),
        .A_RDATA            (INST_RDATA),
        .B_SELECT           (1'b1),
        .B_RDEN             (DATA_RDEN),
        .B_RIADDR           (DATA_RIADDR),
        .B_ROADDR           (rom_data_roaddr_12),
        .B_RVALID           (DATA_RVALID),
        .B_RDATA            (DATA_RDATA)
    );

endmodule
