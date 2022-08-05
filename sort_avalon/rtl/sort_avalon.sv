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
logic [DWIDTH-1:0] sorted_array [MAX_PKT_LEN-1:0];

logic [$clog2(MAX_PKT_LEN):0] written_words, read_words;
logic                         out_trans;
logic [$clog2(MAX_PKT_LEN):0] sorted_word;
logic [DWIDTH-1:0]            word;

typedef enum logic [1:0] {INPUT_TRANS_S, SORT_S, OUTPUT_TRANS_S} state_type;
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
            next_state = SORT_S;
        end
        
      SORT_S:
        begin
          if( out_trans )
            next_state = OUTPUT_TRANS_S;
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
      read_words <= '0;
    else
      begin
        if( next_state == OUTPUT_TRANS_S || state == OUTPUT_TRANS_S )
          begin
            if( read_words <= written_words && !src_endofpacket_o )
              read_words <= read_words + 1'(1);
            else
              read_words <= '0;
          end
      end
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      src_data_o <= 'x;
    else
      begin
        if( next_state == OUTPUT_TRANS_S || state == OUTPUT_TRANS_S )
          begin
            if( read_words < written_words )
              src_data_o <= sorted_array[read_words];
          end
      end
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      src_valid_o <= 1'b0;
    else
      begin
        if( next_state == OUTPUT_TRANS_S || state == OUTPUT_TRANS_S )
          begin
            if( read_words <= written_words && !src_endofpacket_o )
              src_valid_o <= 1'b1;
            else
              src_valid_o <= 1'b0;
          end
      end
  end

assign src_startofpacket_o = ( src_valid_o && read_words == 1 );
assign src_endofpacket_o   = ( src_valid_o && read_words == written_words && written_words != 0 );

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

always_ff @( posedge clk_i )
  begin
    if( snk_endofpacket_i )
      sorted_word <= '0;
    else
      if( state == SORT_S )
        sorted_word <= sorted_word + 1'(1);
  end

always_ff @( posedge clk_i )
  begin
    if( next_state == SORT_S || state == SORT_S )
      word <= memory[sorted_word];
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      out_trans <= 1'b0;
    else
      begin
        if( state == SORT_S )
          out_trans <= my_insert_sort( sorted_word, written_words, word, sorted_array );
        else 
          out_trans <= 1'b0;  
      end
  end

function automatic logic my_insert_sort( logic [$clog2(MAX_PKT_LEN):0] sorted_word,
                                         logic [$clog2(MAX_PKT_LEN):0] written_words,
                                         logic [DWIDTH-1:0] word,
                                         ref logic [DWIDTH-1:0] array [MAX_PKT_LEN-1:0] );
  int j;
  logic [DWIDTH-1:0] temp;
  
  if( sorted_word == 0 )
    for(int i = 0; i < MAX_PKT_LEN; i++)
      array[i] = 'x;
  
  if( sorted_word <= written_words )
    array[sorted_word-1] = word;

  if( sorted_word > written_words )
    return 1'b1;
  else
    begin
      if( sorted_word-1 > 0 && sorted_word <= written_words )
        begin
          for(int j = MAX_PKT_LEN-2; j >= 0; j--)
            begin
              if( array[j] > array[j+1] )
                begin
                  temp = array[j];
                  array[j] = array[j+1];
                  array[j+1] = temp;
                end
            end
        end
      return 1'b0;
    end
endfunction

endmodule