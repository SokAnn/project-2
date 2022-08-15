module sort_avalon_tb;

parameter DWIDTH      = 8;
parameter MAX_PKT_LEN = 10;

logic              clk_i;
logic              srst_i;
logic              src_ready_i, snk_ready_o;
logic [DWIDTH-1:0] src_data_o,  snk_data_i;
logic              src_valid_o, snk_valid_i;
logic              src_sop_o,   snk_sop_i;
logic              src_eop_o,   snk_eop_i;


sort_avalon #(
  .DWIDTH              ( DWIDTH      ),
  .MAX_PKT_LEN         ( MAX_PKT_LEN )
) sort_avalon (
  .clk_i               ( clk_i       ),
  .srst_i              ( srst_i      ),
  
  .src_ready_i         ( src_ready_i ),
  
  .snk_data_i          ( snk_data_i  ),
  .snk_valid_i         ( snk_valid_i ),
  .snk_startofpacket_i ( snk_sop_i   ),
  .snk_endofpacket_i   ( snk_eop_i   ),
  
  .src_data_o          ( src_data_o  ),
  .src_valid_o         ( src_valid_o ),
  .src_startofpacket_o ( src_sop_o   ),
  .src_endofpacket_o   ( src_eop_o   ),
  
  .snk_ready_o         ( snk_ready_o )
);

parameter NUM_TESTS = 200;

mailbox #() mb_inp = new();
mailbox #() mb_out = new();
mailbox #() mb_exp = new();

logic [DWIDTH+3:0] temp_1, temp_2;
logic [15:0]       errors = '0;

initial
  begin
    clk_i = 0;
    forever
      #5 clk_i = !clk_i;
  end

default clocking cb
  @ (posedge clk_i);
endclocking

task generate_data ();
  int num_w, count;

  num_w = 0;
  count <= 0;
  ##1;

  num_w = $urandom_range(1, MAX_PKT_LEN);
  mb_inp.put( num_w );
  if( snk_ready_o === 1'b1 )
    begin
      while( count <= num_w - 1 )
        begin
          snk_data_i = $urandom();
          snk_valid_i = $urandom_range(0, 1);
          if( snk_valid_i === 1'b1 )
            begin
              if( count == 0 )
                snk_sop_i = 1'b1;
              else
                snk_sop_i = 1'b0;
                
              if( count == num_w - 1 )
                snk_eop_i = 1'b1;
              else
                snk_eop_i = 1'b0;
              count <= count + 1;

              mb_inp.put( { snk_data_i } );
            end
          else
            begin
              snk_sop_i = 1'b0;
              snk_eop_i = 1'b0;
            end
          ##1;
          snk_valid_i = 1'b0;
          snk_sop_i   = 1'b0;
          snk_eop_i   = 1'b0;
        end
    end
  ##1;
endtask

task reading_outputs();
  while( src_eop_o !== 1'b1 )
    begin
      if( src_valid_o === 1'b1 )
        mb_out.put( { 1'b0, 
                        src_data_o, 
                        src_valid_o, 
                        src_sop_o, 
                        src_eop_o } );
      ##1;
    end
  if( src_valid_o === 1'b1 )
    mb_out.put( { 1'b0, 
                  src_data_o, 
                  src_valid_o, 
                  src_sop_o, 
                  src_eop_o } );
endtask

task expected_outputs();
  int count, num_w, j;
  logic [DWIDTH-1:0] memory [MAX_PKT_LEN-1:0];
  logic [DWIDTH:0] temp;

  mb_inp.get(temp);
  count = 0;
  num_w = temp;

  while( mb_inp.num() != 0 )
    begin
      mb_inp.get(temp);
      memory[count] = temp;
      count = count + 1;
    end
  
  memory.sort();
  //##1;
  for( int i = 0; i < num_w; i++ )
    begin
      mb_exp.put( { memory[num_w - 1 - i], 
                    1'b1, 
                    ( i == 0 ), 
                    ( i == num_w - 1 ) } );
    end
  
  for( int i = 0; i < MAX_PKT_LEN; i++ )
    memory[i] = 'x;
endtask


initial
  begin
    srst_i <= 1'b1;
    ##2;
    srst_i <= 1'b0;

    $display( "Starting tests..." );
    src_ready_i <= 1'b1;
    
    repeat( NUM_TESTS )
      begin
        generate_data();
        
        reading_outputs();
        expected_outputs();
        
        if( mb_out.num() != mb_exp.num() )
          $error( " Error: number of tests " );
        else
          begin
            while( mb_out.num() != 0 )
              begin
                mb_out.get( temp_1 );
                mb_exp.get( temp_2 );
                if( temp_1 !== temp_2 )
                  begin
                    $error( "Error: signals mismatch " );
                    $display( " data: real - (%d) expected - (%d) ", temp_1[DWIDTH+3:3], temp_2[DWIDTH+3:3] );
                    $display( "  val: real - (%b) expected - (%b) ", temp_1[2], temp_2[2] );
                    $display( "  sop: real - (%b) expected - (%b) ", temp_1[1], temp_2[1] );
                    $display( "  eop: real - (%b) expected - (%b) ", temp_1[0], temp_2[0] );
                    errors = errors + 1;
                  end
              end
          end 
      end
    $display( "Tests completed with (%d) errors.", errors );
    $stop;
  end

endmodule
