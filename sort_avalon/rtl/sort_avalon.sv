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
logic [MAX_PKT_LEN-1:0][DWIDTH-1:0] sorted_array;

logic [$clog2(MAX_PKT_LEN):0] written_words, read_word;
logic                         out_trans;
logic [$clog2(MAX_PKT_LEN):0] sorted_word;
logic [DWIDTH-1:0]            word;
logic                         sorted_flag;

typedef enum logic [1:0] {INPUT_TRANS_S, READ_FROM_MEM_S, SORTING_DATA_S, OUTPUT_TRANS_S} state_type;
state_type state, next_state;


always_ff @( posedge clk_i )
  begin
    if( srst_i )
      state <= INPUT_TRANS_S;
    else
      state <= next_state;
  end

always_comb
  begin
    next_state = state;
    case( state )
      INPUT_TRANS_S:
        begin
          if( snk_valid_i && snk_endofpacket_i )
            next_state = READ_FROM_MEM_S;;
        end
        
      READ_FROM_MEM_S:
        begin
          next_state = SORTING_DATA_S;
        end
      
      SORTING_DATA_S:
        begin
          if( read_word == written_words - 1 && sorted_flag )
            next_state = OUTPUT_TRANS_S;
          else
           if( sorted_flag || read_word == 0 )
             next_state = READ_FROM_MEM_S;
        end
        
      OUTPUT_TRANS_S:
        begin
          if( src_endofpacket_o )
            next_state = INPUT_TRANS_S;
        end
        
      default: next_state = INPUT_TRANS_S;
    endcase
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      written_words <= '0;
    else
      begin
        if( state == INPUT_TRANS_S )
          if( snk_valid_i )
            written_words <= written_words + 1'(1);
        if( state == OUTPUT_TRANS_S )
          if( src_endofpacket_o )
            written_words <= '0;
      end
  end

always_ff @( posedge clk_i )
  begin
    if( state == INPUT_TRANS_S )
      if( snk_valid_i )
        memory[written_words] <= snk_data_i;
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      read_word <= '0;
    else
      begin
        if( state == INPUT_TRANS_S && next_state == READ_FROM_MEM_S )
          read_word <= '0;
        else
          if( next_state == READ_FROM_MEM_S )
            read_word <= read_word + 1'(1);

        if( state == SORTING_DATA_S && next_state == OUTPUT_TRANS_S )
          read_word <= 1'd1;
        else
          if( state == OUTPUT_TRANS_S )
           read_word <= read_word + 1'(1);
      end
  end

always_ff @( posedge clk_i )
  begin
    if( state == READ_FROM_MEM_S )
      word <= memory[read_word];
    else
      begin
        if( state == SORTING_DATA_S && written_words > 1 )
          if( word < sorted_array[sorted_word] )
            word <= sorted_array[sorted_word];
      end
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      sorted_word <= '0;
    else
      begin
        if( state == READ_FROM_MEM_S && next_state == SORTING_DATA_S )
          sorted_word <= '0;
        else
          if( state == SORTING_DATA_S )
            sorted_word <= sorted_word + 1'(1);
      end
  end

assign sorted_flag = ( state == SORTING_DATA_S ) ? ( sorted_word == read_word ) : ( 1'b0 ) ;

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      sorted_array <= 'x;
    else
      begin
        if( state == INPUT_TRANS_S )
          sorted_array <= 'x;
        else
          begin
            if( state == SORTING_DATA_S && written_words > 1 )
              begin
                if( read_word == 0 )
                  sorted_array[sorted_word] <= word;
                else
                  begin
                    if( word < sorted_array[sorted_word] )
                      sorted_array[sorted_word] <= word;
                    else
                      if( read_word == sorted_word )
                        sorted_array[sorted_word] <= word;
                  end
              end
          end
      end
  end

always_ff @( posedge clk_i )
  begin
    if( state == SORTING_DATA_S && next_state == OUTPUT_TRANS_S )
      begin
        if( written_words > 1)
          src_data_o <= sorted_array[written_words-read_word-1];
        else
          src_data_o <= word;
      end
    else
      if( state == OUTPUT_TRANS_S )
        src_data_o <= sorted_array[read_word];
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      src_valid_o <= 1'b0;
    else
      begin
        if( next_state == OUTPUT_TRANS_S || state == OUTPUT_TRANS_S )
          begin
            if( read_word <= written_words && !src_endofpacket_o )
              src_valid_o <= 1'b1;
            else
              src_valid_o <= 1'b0;
          end
      end
  end

assign src_startofpacket_o = ( src_valid_o && read_word == 1 );
assign src_endofpacket_o   = ( src_valid_o && read_word == written_words && written_words != 0 );

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      snk_ready_o <= 1'b0;
    else
      begin
        if( next_state == INPUT_TRANS_S )
          snk_ready_o <= 1'b1;
        else
          snk_ready_o <= 1'b0;
      end
  end

endmodule

