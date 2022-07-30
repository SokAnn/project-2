module sort_avalon #(
  parameter DWIDTH      = 4,
  parameter MAX_PKT_LEN = 5
)(
  input logic               clk_i,
  input logic               srst_i,
  
  input  logic              src_ready_i,
  
  input  logic [DWIDTH-1:0] snk_data_i,
  input  logic              snk_valid_i,
  input  logic              snk_startofpacket_i,
  input  logic              snk_endofpacket_i,
  
  output logic [DWIDTH-1:0] src_data_o,
  output logic              src_valid_o,
  output logic              src_startofpacket_o,
  output logic              src_endofpacket_o,
  
  output logic              snk_ready_o
);

logic [DWIDTH-1:0] memory [MAX_PKT_LEN-1:0];
logic [$clog2(MAX_PKT_LEN):0] temp_w, temp_r;
logic sort_flag, out_trans;

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      temp_w <= '0;
    else
      begin
        if( snk_ready_o )
          if( snk_valid_i )
            temp_w <= temp_w + 1'(1);
        if( src_endofpacket_o )
          temp_w <= '0;
      end
  end

always_ff @( posedge clk_i )
  begin
    if( snk_ready_o ) 
      if( snk_valid_i )
        memory[temp_w] <= snk_data_i;
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      temp_r <= '0;
    else
      begin
        if( out_trans )
          begin
            if( temp_r <= temp_w && !src_endofpacket_o )
              temp_r <= temp_r + 1'(1);
            else
              temp_r <= '0;
          end
      end
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      src_data_o <= 'x;
    else
      begin
        if( out_trans )
          begin
            if( temp_r < temp_w )
              src_data_o <= memory[temp_r];
          end
      end
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      src_valid_o <= 1'b0;
    else
      begin
        if( out_trans )
          begin
            if( temp_r <= temp_w && !src_endofpacket_o )
              src_valid_o <= 1'b1;
            else
              src_valid_o <= 1'b0;
          end
      end
  end

assign src_startofpacket_o = ( src_valid_o && temp_r == 1 );
assign src_endofpacket_o   = ( src_valid_o && temp_r == temp_w && temp_w != 0 );

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      snk_ready_o <= 1'b0;
    else
      begin
        if( snk_endofpacket_i )
          snk_ready_o <= 1'b0;
        else
          begin
            if( sort_flag || out_trans )
              snk_ready_o <= 1'b0;
            else
              snk_ready_o <= 1'b1;
          end
      end
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      sort_flag <= 1'b0;
    else
      begin
        if( snk_endofpacket_i )
          sort_flag <= 1'b1;
        else
          sort_flag <= 1'b0;
      end
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      out_trans <= 1'b0;
    else
      begin
        if( sort_flag )
          out_trans <= my_insert_sort();
        else   
          if( temp_r == temp_w )
            out_trans <= 1'b0;
      end
  end

function logic my_insert_sort();
  int j;
  logic [DWIDTH-1:0] temp;
  
  if( temp_w > 1)
    begin
      for( int i = 1; i < temp_w; i++ )
        begin
          j = i - 1;
          while( j >= 0 && memory[j] > memory[j+1] )
            begin
              temp = memory[j];
              memory[j] = memory[j+1];
              memory[j+1] = temp;
              j--;
            end
        end
    end
  return 1'b1;
endfunction

endmodule
