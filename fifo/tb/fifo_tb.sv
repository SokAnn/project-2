`timescale 1 ps / 1 ps

module fifo_tb;

parameter DWIDTH             = 8;
parameter AWIDTH             = 3;
parameter SHOWAHEAD          = 1;
parameter ALMOST_FULL_VALUE  = 7;
parameter ALMOST_EMPTY_VALUE = 3;
parameter REGISTER_OUTPUT    = 0;
parameter LEN_TEST           = 30;

bit                clk_i;
logic              srst_i;

logic [DWIDTH-1:0] data_i;
logic              wrreq_i;
logic              rdreq_i;
  
logic [DWIDTH-1:0] q_dut,            q_ref;
logic              empty_dut,        empty_ref;
logic              full_dut,         full_ref;
logic [AWIDTH:0]   usedw_dut,        usedw_ref;
logic              almost_full_dut,  almost_full_ref;
logic              almost_empty_dut, almost_empty_ref;

logic              empty_flag;
logic [DWIDTH-1:0] memory     [2**AWIDTH-1:0];
logic [AWIDTH-1:0] temp_rd;
logic [AWIDTH-1:0] temp_wr;
logic              empty;
logic              full;
logic              almost_full;
logic              almost_empty;
logic [AWIDTH:0]   usedw;
logic              temp_empty_1, temp_empty_2;


logic [2*DWIDTH+2*LEN_TEST:0] errors;

initial
  begin
    clk_i = 0;
    forever
      #5 clk_i = !clk_i;
  end

default clocking cb
  @ (posedge clk_i);
endclocking


// my_fifo inst
fifo #(
  .DWIDTH             ( DWIDTH               ),
  .AWIDTH             ( AWIDTH               ),
  .SHOWAHEAD          ( SHOWAHEAD            ),
  .ALMOST_FULL_VALUE  ( ALMOST_FULL_VALUE    ),
  .ALMOST_EMPTY_VALUE ( ALMOST_EMPTY_VALUE   ),
  .REGISTER_OUTPUT    ( REGISTER_OUTPUT      )
) fifo (
  .clk_i              ( clk_i                ),
  .srst_i             ( srst_i               ),
  
  .data_i             ( data_i               ),
  .wrreq_i            ( wrreq_i              ),
  .rdreq_i            ( rdreq_i              ),
  
  .q_o                ( q_dut                ),
  .empty_o            ( empty_dut            ),
  .full_o             ( full_dut             ),
  .usedw_o            ( usedw_dut            ),
  
  .almost_full_o      ( almost_full_dut      ),
  .almost_empty_o     ( almost_empty_dut     )
);

// scfifo inst
scfifo #(
  .lpm_width                 ( DWIDTH                ), 
  .lpm_widthu                ( AWIDTH + 1            ), 
  .lpm_numwords              ( 2 ** AWIDTH           ),
  .lpm_showahead             ( "ON"                  ),
  .lpm_type                  ( "scfifo"              ),
  .lpm_hint                  ( "RAM_BLOCK_TYPE=M10K" ),
  .intended_device_family    ( "Cyclone V"           ),
  .underflow_checking        ( "ON"                  ),
  .overflow_checking         ( "ON"                  ),
  .allow_rwcycle_when_full   ( "OFF"                 ),
  .use_eab                   ( "ON"                  ),
  .add_ram_output_register   ( "OFF"                 ),
  .almost_full_value         ( ALMOST_FULL_VALUE     ), 
  .almost_empty_value        ( ALMOST_EMPTY_VALUE    ), 
  .maximum_depth             ( 0                     ), 
  .enable_ecc                ( "FALSE"               )
) golden_model (
  .clock                     ( clk_i                 ),
  .sclr                      ( srst_i                ),
  
  .data                      ( data_i                ),
  .wrreq                     ( wrreq_i               ),
  .rdreq                     ( rdreq_i               ),
  
  .q                         ( q_ref                 ),
  .empty                     ( empty_ref             ),
  .full                      ( full_ref              ),
  .usedw                     ( usedw_ref             ),
  
  .almost_full               ( almost_full_ref       ),
  .almost_empty              ( almost_empty_ref      ),

  .aclr                      (                       ),
  .eccstatus                 (                       )
);

typedef struct packed {
  logic [DWIDTH-1:0] data;
  logic              wrreq;
  logic              rdreq;
} input_data;

typedef struct packed {
  logic [DWIDTH-1:0] q;
  logic              empty;
  logic              full;
  logic [AWIDTH:0]   usedw;
  logic              almost_full;
  logic              almost_empty;
} output_data;

mailbox #( output_data ) mb_dut = new();
mailbox #( output_data ) mb_ref = new();

mailbox #( input_data )  mb_d   = new();
mailbox #( output_data ) mb_exp = new();


task generate_data (  );
  int r, state;
  
  state = 0;

  while( state < 5 )
    begin
      case( state )
        3'd0:
          begin
            repeat( 2 ** AWIDTH )
              begin
                data_i  = $urandom();
                wrreq_i = 1'b1;
                rdreq_i = 1'b0;
                mb_d.put( { data_i, wrreq_i, rdreq_i } );
                read_dut( mb_dut );
                read_ref( mb_ref );
                ##1;
              end
          end

        3'd1:
          begin
            repeat( 2 ** AWIDTH )
              begin
                data_i  = $urandom();
                wrreq_i = 1'b0;
                rdreq_i = 1'b1;
                mb_d.put( { data_i, wrreq_i, rdreq_i } );
                read_dut( mb_dut );
                read_ref( mb_ref );
                ##1;
            end
          end
    
        3'd2:
          begin
            repeat( LEN_TEST )
              begin
                data_i  = $urandom();
                r = $urandom_range(0, 6);
                wrreq_i = ( r >= 3'd2 );
                rdreq_i = ( r < 3'd2 );
                mb_d.put( { data_i, wrreq_i, rdreq_i } );
                read_dut( mb_dut );
                read_ref( mb_ref );
                ##1;
              end
          end
    
        3'd3:
          begin
            repeat( LEN_TEST )
              begin
                data_i  = $urandom();
                r = $urandom_range(0, 6);
                wrreq_i = ( r < 3'd2 );
                rdreq_i = ( r >= 3'd2 );
                mb_d.put( { data_i, wrreq_i, rdreq_i } );
                read_dut( mb_dut );
                read_ref( mb_ref );
                ##1;
              end
          end

        3'd4:
          begin
            repeat( 2 ** AWIDTH )
              begin
                data_i = $urandom();
                wrreq_i = 1'b1;
                rdreq_i = 1'b1;
                mb_d.put( { data_i, wrreq_i, rdreq_i } );
                read_dut( mb_dut );
                read_ref( mb_ref );
                ##1;
              end
            wrreq_i = 1'b0;
            rdreq_i = 1'b0;
            mb_d.put( { data_i, wrreq_i, rdreq_i } );
            read_dut( mb_dut );
            read_ref( mb_ref );
            ##1;
          end
      endcase
      state = state + 1;
    end
endtask

input_data         in_temp;
output_data        out_temp;
  
assign full = ( usedw === 2 ** AWIDTH );
assign almost_full = ( usedw >= ALMOST_FULL_VALUE );
assign temp_empty_1 = ( usedw === 0 );
assign empty = ( temp_empty_1 || temp_empty_2 );
assign almost_empty = ( usedw < ALMOST_EMPTY_VALUE );

task write_d ( 
               mailbox #( input_data ) mb_d, 
               mailbox #( output_data ) mb_exp 
             );
  logic init_flag;
  
  init_flag <= 1'b1;
  ##1;
  
  repeat( 3 * 2 ** AWIDTH + 2 * LEN_TEST + 1 )
    begin
      if( init_flag === 1'b1 )
        begin
          init_flag    <= 1'b0;
          empty_flag   <= 1'b1;
          usedw        <= '0;
          temp_wr      <= '0;
          temp_rd      <= '0;
          temp_empty_2 <= 1'b1;
          ##1;
        end
      else 
        if( init_flag === 1'b0 )
          begin
            mb_d.get( in_temp );
            ##1;
            out_temp[DWIDTH+AWIDTH+4:AWIDTH+5] = ( empty_flag === 1'b1 ) ? ( 'x ) : 
                                                                           ( ( empty === 1'b1 ) ? ( '0 ) : 
                                                                                                  ( memory[temp_rd] ) );
            out_temp[AWIDTH+4]                 = empty;
            out_temp[AWIDTH+3]                 = full;
            out_temp[AWIDTH+2:2]               = usedw;
            out_temp[1]                        = almost_full;
            out_temp[0]                        = almost_empty;
      
            temp_empty_2 <= temp_empty_1;

            if( usedw >= 1 )
              empty_flag <= 1'b0;

            if( in_temp[1] === 1'b1 && full === 1'b0 )
              begin
                if( in_temp[0] === 1'b1 )
                  begin
                    if( temp_wr == temp_rd )
                      begin
                        if( empty === 1'b1 )
                          begin
                            memory[temp_wr] <= in_temp[DWIDTH+1:2];
                            temp_wr <= temp_wr + 1'(1);
                          end
                      end
                    else
                      begin
                        memory[temp_wr] <= in_temp[DWIDTH+1:2];
                        temp_wr <= temp_wr + 1'(1);
                      end
                  end
                else
                  begin
                    memory[temp_wr] <= in_temp[DWIDTH+1:2];
                    temp_wr <= temp_wr + 1'(1);
                  end
              end

            if( in_temp[0] === 1'b1 && empty === 1'b0 )
              temp_rd <= temp_rd + 1'(1);

            if( !( in_temp[1] && full === 1'b0 ) || !( in_temp[0] && empty === 1'b0 ))
              begin
                if( in_temp[1] && full === 1'b0 )
                  usedw <= usedw + 1'(1);
                else if( in_temp[0] && empty === 1'b0 )
                  usedw <= usedw - 1'(1);
              end

            mb_exp.put( out_temp );
          end
     end
endtask

task read_dut ( mailbox #( output_data ) mb_dut );
  mb_dut.put( { q_dut,     empty_dut,       full_dut, 
                usedw_dut, almost_full_dut, almost_empty_dut } );
endtask

task read_ref ( mailbox #( output_data ) mb_ref );
  mb_ref.put( { q_ref,     empty_ref,       full_ref, 
                usedw_ref, almost_full_ref, almost_empty_ref } );
endtask

task check_rd_wr ( 
                   mailbox #( output_data ) mb_exp, 
                   mailbox #( output_data ) mb_dut, 
                   mailbox #( output_data ) mb_ref 
                 );
  output_data exp, dut, refr;
  $display( "Checking: expectation and reality... " );
  
  while( mb_exp.num() != 0 )
    begin
      ##1;
      mb_exp.get( exp );
      mb_dut.get( dut );
      mb_ref.get( refr );
       
      if( exp[0] !== dut[0] || exp[0] !== refr[0] )
        begin
          $error( " mismatch of expectation and reality: almost_empty " );
          errors = errors + 1'(1);
        end
      
      if( exp[1] !== dut[1] || exp[1] !== refr[1] )
        begin
          $error( " mismatch of expectation and reality: almost_full " );
          errors = errors + 1'(1);
        end
      
      if( exp[AWIDTH+2:2] !== dut[AWIDTH+2:2] || 
          exp[AWIDTH+2:2] !== refr[AWIDTH+2:2] )
        begin
          $error( " mismatch of expectation and reality: usedw " );
          errors = errors + 1'(1);
        end
      
      if( exp[AWIDTH+3] !== dut[AWIDTH+3] || 
          exp[AWIDTH+3] !== refr[AWIDTH+3] )
        begin
          $error( " mismatch of expectation and reality: full " );
          errors = errors + 1'(1);
        end
      
      if( exp[AWIDTH+4] !== dut[AWIDTH+4] || 
          exp[AWIDTH+4] !== refr[AWIDTH+4] )
        begin
          $error( " mismatch of expectation and reality: empty " );
          errors = errors + 1'(1);
        end
      
      if( exp[DWIDTH+AWIDTH+4:AWIDTH+5] !== dut[DWIDTH+AWIDTH+4:AWIDTH+5] || 
          exp[DWIDTH+AWIDTH+4:AWIDTH+5] !== refr[DWIDTH+AWIDTH+4:AWIDTH+5] )
        begin
          $error( " mismatch of expectation and reality: q " );
          errors = errors + 1'(1);
        end
  end
endtask

task compare_signals_dut_ref ();
  $display( "Comparing signals..." );
  forever
    begin
      ##1;
      if( almost_empty_ref !== almost_empty_dut )
        $error( "almost_empty mismatch" );
      
      if( almost_full_ref !== almost_full_dut )
        $error( "almost_full mismatch" );
      
      if( full_ref !== full_dut )
        $error( "full mismatch" );
      
      if( empty_ref !== empty_dut )
        $error( "empty mismatch" );
      
      if( usedw_ref !== usedw_dut )
        $error( "usedw mismatch" );
      
      if( q_ref !== q_dut )
        $error( "q mismatch" );
    end
endtask

initial
  begin
    srst_i <= 1'b0;
    ##1;
    srst_i <= 1'b1;
    ##1;
    srst_i <= 1'b0;
    errors = 0;
    $display("Starting tests...");

    fork
      generate_data(  );
      compare_signals_dut_ref(  );
    join_any

    write_d( mb_d, mb_exp );

    check_rd_wr( mb_exp, mb_dut, mb_ref );
    $display( "Tests completed with ( %d ) errors.", errors );
    $stop;
  end

endmodule
