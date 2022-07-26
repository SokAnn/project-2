module fifo #(
  parameter DWIDTH             = 16,
  parameter AWIDTH             = 5,
  parameter SHOWAHEAD          = 1,
  parameter ALMOST_FULL_VALUE  = 29,
  parameter ALMOST_EMPTY_VALUE = 3,
  parameter REGISTER_OUTPUT    = 0
)(
  input  logic                clk_i,
  input  logic                srst_i,
  
  input  logic  [DWIDTH-1:0]  data_i,
  input  logic                wrreq_i,
  input  logic                rdreq_i,
  
  output logic  [DWIDTH-1:0]  q_o,
  output logic                empty_o,
  output logic                full_o,
  output logic  [AWIDTH:0]    usedw_o,
  output logic                almost_full_o,
  output logic                almost_empty_o
);

logic [DWIDTH-1:0] memory       [2**AWIDTH-1:0];
logic [AWIDTH-1:0] temp_rd;
logic [AWIDTH-1:0] temp_wr;
logic              temp_empty1;
logic              temp_empty2;
logic [AWIDTH:0]   use_dw       = '0;
logic              q_flag       = 1'b0;

always_ff @( posedge clk_i )
  begin
    if( wrreq_i && !full_o )
      begin
        if( rdreq_i )
          begin
            if( temp_wr == temp_rd )
              begin
                if( empty_o )
                  memory[temp_wr] <= data_i;
              end
            else
              memory[temp_wr] <= data_i;
          end
        else
          memory[temp_wr] <= data_i;
      end
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      q_flag <= 1'b1;
    else
      if( !almost_empty_o )
        q_flag <= 1'b0;
  end

assign q_o = ( empty_o ) ? ( ( q_flag ) ? ( 'x ) : ( '0 ) ) : ( memory[temp_rd] );

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      temp_rd <= '0;
    else
      begin
        if( rdreq_i && !empty_o )
          temp_rd <= temp_rd + 1'(1);
      end
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      temp_wr <= '0;
    else
      begin
        if( wrreq_i && !full_o )
          begin
            if( rdreq_i )
              begin
                if( temp_wr == temp_rd )
                  begin
                    if( empty_o )
                      temp_wr <= temp_wr + 1'(1);
                  end
                else
                  temp_wr <= temp_wr + 1'(1);
              end
            else
              temp_wr <= temp_wr + 1'(1);
          end
      end
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      use_dw <= '0;
    else
      begin
        if( !( wrreq_i && !full_o ) || !( rdreq_i && !empty_o ))
          begin
            if( wrreq_i && !full_o )
              use_dw <= use_dw + 1'(1);
            else if( rdreq_i && !empty_o )
              use_dw <= use_dw - 1'(1);
          end
      end
  end

assign usedw_o = use_dw;

assign temp_empty1 = ( usedw_o == 0 );

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      temp_empty2 <= 1'b1;
    else
      temp_empty2 <= temp_empty1;
  end

assign empty_o = ( temp_empty1 || temp_empty2 );
assign full_o  = ( usedw_o == 2 ** AWIDTH );

assign almost_empty_o = ( usedw_o < ALMOST_EMPTY_VALUE );
assign almost_full_o  = ( usedw_o >= ALMOST_FULL_VALUE );

endmodule