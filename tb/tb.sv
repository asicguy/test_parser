///////////////////////////////////////////////////////////////////////////////
//
//  Copyright (C) 2016 Francis Bruno, All Rights Reserved
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 3 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but
//  WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
//  or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with
//  this program; if not, see <http://www.gnu.org/licenses>.
//
//  http://www.gplgpu.com
//  http://www.asicsolutions.com
//
//  Title       :  Packet Parser Testbench
//  File        :  pkt_parser.v
//  Author      :  Frank Bruno
//  Created     :  07-Apr-2016
//  RCS File    :  $Source:$
//  Status      :  $Id:$
//
//
///////////////////////////////////////////////////////////////////////////////
//
//  Description :
//  Quick testbench to read formatted packet from file and generate random
//  Packets.
//
//////////////////////////////////////////////////////////////////////////////
//
//  Modules Instantiated:
//
///////////////////////////////////////////////////////////////////////////////
//
//  Modification History:
//
//  $Log:$
//
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

module tb;

  avalon_stream data_packet();  // Packet with messages from exchange
  avalon_stream message();      // Raw message information

  logic     clk;          // system clock
  logic     reset_n;       // active low reset
  logic [1499:0][7:0] packet; // packet to send
  //logic [7:0] exp_data[4096]; // packet to send
  int          in_pointer; // input pointer for loading expected data
  int          out_pointer; // output pointer for checking expected data
  logic [3:0]  mask_empty;  // maske empty when not EOP

  // SV queues for testing data
  logic [7:0]  exp_data[$];
  logic [7:0]  exp_byte;

  initial begin
    clk = '0;
    forever clk = #10 ~clk;
  end

  pkt_parser pkt_parser_inst
    (
     .data_packet  (data_packet.slave),
     .message      (message.master),

     .clk          (clk),
     .reset_n      (reset_n)
     );


  initial begin
    in_pointer = 0;
    out_pointer = 0;
    message.ready = '0;
    reset_n = '1;
    repeat (10) @(posedge clk);
    reset_n = '0;
    repeat (10) @(posedge clk);
    reset_n = '1;
    message.ready = '1;
    repeat (10) @(posedge clk);
    //gen_packet;
    $display("Send Supplied Frame\n");
    $display("Send Random Frame (1,1) \n");
    gen_packet_from_file; // supplied test file
    for (int i = 0; i < 5; i++) begin
      $display("Send Random Frame (32,8) %d\n", i);
      gen_packet(32,8); // Random packet
    end
    gen_packet(1,1); // Random packet
    for (int i = 0; i < 1000; i++) begin
      $display("Send Random Frame (32,8) %d\n", i);
      gen_packet(32,1); // Random packet
    end
    repeat (5) @(posedge clk);
    if (in_pointer !== out_pointer) begin
      $display("Test Failed! exp and act pointers do not match");
      $display("exp: %d !== act: %d", in_pointer, out_pointer);
    end else begin
      $display("Test passed!");
    end
    $stop;
  end

  task gen_packet(input int max_size=32, input int min_size=8);
    logic [15:0] msg_len;
    logic [15:0] msg_count;
    int          pkt_len;
    int          new_pkt_len;
    logic        done;
    int          counter;
    int          final_bytes;
    logic [7:0]  temp_byte;

    new_pkt_len = $urandom_range(1500,200);
    pkt_len   = 2;
    msg_count = 0;
    while (1) begin
      //msg_len = $urandom_range(32,8);
      msg_len = $urandom_range(max_size,min_size);
      if (pkt_len + msg_len > new_pkt_len) break;
      msg_count++;
      packet[pkt_len++] = msg_len[15:8];
      packet[pkt_len++] = msg_len[7:0];
      for (int i = 0; i < msg_len; i++) begin
        temp_byte = $random;
        $display("%d = %h", in_pointer, temp_byte);
        packet[pkt_len++] = temp_byte;
        //exp_data[in_pointer++] = temp_byte;
        exp_data.push_front(temp_byte);
        in_pointer++;
      end
    end
    packet[0] = msg_count[15:8];
    packet[1] = msg_count[7:0];
    done    = 0;
    counter = 0;
    // now send it
    data_packet.valid <= '1;
    data_packet.sop   <= '1;
    data_packet.eop   <= '0;
    data_packet.empty <= '0;
    for (int i = 1; i <= 8; i++) begin
      data_packet.data[64-8*i+:8] <= packet[counter++];
    end
    @(posedge clk);
    while ((pkt_len - counter) > 8) begin
      while (!data_packet.ready) @(posedge clk);
      data_packet.valid <= '1;
      data_packet.sop   <= '0;
      data_packet.eop   <= '0;
      data_packet.empty <= '0;
      for (int i = 1; i <= 8; i++) begin
        data_packet.data[64-8*i+:8] <= packet[counter++];
      end
      @(posedge clk);
    end // while ((pkt_len - counter) > 8)
    while (!data_packet.ready) @(posedge clk);
    data_packet.valid <= '1;
    data_packet.sop   <= '0;
    data_packet.eop   <= '1;
    data_packet.empty <= '1;
    final_bytes = pkt_len-counter;
    data_packet.empty <= 7-final_bytes;
    for (int i = 1; i <= final_bytes; i++) begin
      data_packet.data[64-8*i+:8] <= packet[counter++];
    end
    @(posedge clk);
    while (!data_packet.ready) @(posedge clk);
  endtask // gen_packet

  task gen_packet_from_file;
    logic [15:0] msg_len;
    logic [15:0] msg_count;
    int          new_pkt_len;
    logic        done;
    int          counter;
    int status;
    logic [7:0] bytes;

    int pkt_len;
    int parse_count;
    integer file;
    file = $fopen("ref.hex", "r");
    //file = $fopen("reference.hex", "r");

    pkt_len = 0;
    while (!$feof(file)) begin
      status = $fscanf(file, "%h", bytes);
      packet[pkt_len++] = bytes;
    end
    // build expected data
    // parse the packet from the file to extract only data
    parse_count = 2;
    msg_count = {packet[0], packet[1]};
    while (parse_count < pkt_len) begin
      msg_len[15:8] = packet[parse_count++];
      msg_len[7:0]  = packet[parse_count++];
      while (msg_len > 0) begin
        msg_len--;
        $display("%d = %h", in_pointer, packet[parse_count]);
        //exp_data[in_pointer++] = packet[parse_count++];
        exp_data.push_front(packet[parse_count++]);
        in_pointer++;
      end
    end

    //while (!$feof(file)) begin
      //pkt_len++;
    //end
    //pkt_len   = 1500;
    done    = 0;
    counter = 0;
    // now send it
    data_packet.valid <= '1;
    data_packet.sop   <= '1;
    data_packet.eop   <= '0;
    data_packet.empty <= '0;
    for (int i = 1; i <= 8; i++) begin
      data_packet.data[64-8*i+:8] <= packet[counter++];
    end
    @(posedge clk);
    while ((pkt_len - counter) > 8) begin
      while (!data_packet.ready) @(posedge clk);
      data_packet.valid <= '1;
      data_packet.sop   <= '0;
      data_packet.eop   <= '0;
      data_packet.empty <= '0;
      for (int i = 1; i <= 8; i++) begin
        data_packet.data[64-8*i+:8] <= packet[counter++];
      end
      @(posedge clk);
    end // while ((pkt_len - counter) > 8)
    data_packet.valid <= '1;
    data_packet.sop   <= '0;
    data_packet.eop   <= '1;
    //data_packet.empty = '1;
    data_packet.empty <= 9-(pkt_len-counter);
    for (int i = 1; i < pkt_len-counter; i++) begin
      data_packet.data[64-8*i+:8] <= packet[counter++];
      //data_packet.empty[8-i] = '0;
    end
    @(posedge clk);
  endtask // gen_packet

  always @(posedge clk) begin
    if (message.valid && message.ready) begin
      mask_empty = 8 - message.empty;
      for (int i = 7; i >= 0; i--) begin
        if ((message.eop && (mask_empty > 0)) || ~message.eop)begin
          mask_empty -= |mask_empty; // Don't go below 0
          // do the data comparison
          exp_byte = exp_data.pop_back();
          if (message.data[i*8+:8] !== exp_byte) begin
            $display("Data Mismatch: %d, exp: %h != act: %h",
                     out_pointer, exp_byte, message.data[i*8+:8]);
            $stop;
          end else begin
            $display("Data match: %d, exp: %h == act: %h",
                     out_pointer, exp_byte, message.data[i*8+:8]);
          end
          out_pointer++;
        end
      end // for (int i = 7; i >= 0; i--)
    end // if (message.valid && message.ready)
  end
endmodule // tb
