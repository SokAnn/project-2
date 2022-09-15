module sort_avalon #(
  parameter DWIDTH      = 6,
  parameter MAX_PKT_LEN = 10
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

logic [$clog2(MAX_PKT_LEN):0] written_words, read_sort_word;
logic [$clog2(MAX_PKT_LEN):0] sorted_word,   read_words;
logic [DWIDTH-1:0]            word,          temp_word;
logic                         flag;

logic we_a, we_b;
logic re_a, re_b;

typedef enum logic [2:0] {INPUT_TRANS_S, READ_FROM_MEM_S, SORTING_DATA_S, WRITE_TO_MEM_S, OUTPUT_TRANS_S} state_type;
state_type state, next_state;

assign we_a = ( ( state == INPUT_TRANS_S ) && snk_valid_i );
assign re_a = ( ( next_state == OUTPUT_TRANS_S ) || ( state == OUTPUT_TRANS_S ) );

assign we_b = ( state == WRITE_TO_MEM_S );
assign re_b = ( state == READ_FROM_MEM_S );

// state-next_state logic
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      state <= INPUT_TRANS_S;
    else
      state <= next_state;
  end

// next_state logic
always_comb
  begin
    next_state = state;
    case( state )
      INPUT_TRANS_S:
        begin
          if( snk_valid_i && snk_endofpacket_i )
            next_state = SORTING_DATA_S;
        end
      
      SORTING_DATA_S:
        begin
          if( read_sort_word == ( written_words - 1 ) && read_sort_word == sorted_word || ( read_sort_word == ( written_words ) ) )
            next_state = OUTPUT_TRANS_S;
          else
            if( memory[read_sort_word] < memory[sorted_word] )
              next_state = READ_FROM_MEM_S;
        end
      
      READ_FROM_MEM_S:
        begin
          next_state = WRITE_TO_MEM_S;
        end
      
      WRITE_TO_MEM_S:
        begin
          if( read_sort_word == sorted_word )
            next_state = SORTING_DATA_S;
          else
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

// written_words
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

// read_words
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      read_words <= '0;
    else
      begin
        if( re_a )
          if( read_words < written_words )
            read_words <= read_words + 1'(1);
        else
          read_words <= '0;
      end
  end

// block a
always_ff @( posedge clk_i )
  begin
    if( we_a )
      memory[written_words] <= snk_data_i;
    else
      if( re_a )
        src_data_o <= memory[read_words];
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      flag <= 1'b0;
    else
      begin
        if( we_b )
          flag <= 1'b1;
        
        if( next_state == SORTING_DATA_S )
          flag <= 1'b0;
      end
  end

// block b
always_ff @( posedge clk_i )
  begin
    if( we_b )begin
      if( flag )
        memory[sorted_word] <= temp_word;
      else
        memory[sorted_word] <= memory[read_sort_word];end
    else
      if( re_b )
        if( sorted_word != read_sort_word )
          word <= memory[sorted_word];
  end

always_ff @( posedge clk_i )
  begin
    temp_word <= word;
  end

// read_sort_word
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      read_sort_word <= '0;
    else
      begin
        if( state == INPUT_TRANS_S )
          read_sort_word <= '0;
        
        if( state == SORTING_DATA_S )
          begin
            if( read_sort_word < written_words )begin
              if( read_sort_word == sorted_word )
                read_sort_word <= read_sort_word + 1'(1);end
            else
              read_sort_word <= '0;
          end
        
        if( we_b && next_state == SORTING_DATA_S )
          begin
            if( read_sort_word < written_words )
              read_sort_word <= read_sort_word + 1'(1);
            else
              read_sort_word <= '0;
          end
      end
  end

// sorted_word
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      sorted_word <= '0;
    else
      begin
        if( state == INPUT_TRANS_S )
          sorted_word <= '0;

        if( state == SORTING_DATA_S && next_state == SORTING_DATA_S )
          begin
            if( sorted_word != read_sort_word )
              sorted_word <= sorted_word + 1'(1);
            else
              sorted_word <= '0;
          end
        else
          if( state == WRITE_TO_MEM_S )
            if( next_state != SORTING_DATA_S )
              sorted_word <= sorted_word + 1'(1);
            else
              sorted_word <= '0;
      end
  end

// src_valid_o
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      src_valid_o <= 1'b0;
    else
      begin
        if( ( next_state == OUTPUT_TRANS_S ) || ( state == OUTPUT_TRANS_S ) )
          begin
            if( !src_endofpacket_o )
              src_valid_o <= 1'b1;
            else
              src_valid_o <= 1'b0;
          end
      end
  end

assign src_startofpacket_o = ( src_valid_o && ( read_words == 1 ) );
assign src_endofpacket_o   = ( src_valid_o && ( read_words == written_words ) && ( written_words != 0 ) );

// snk_ready_o
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