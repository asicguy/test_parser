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
//  http://www.asicsolutions.com
//
//  Title       :  Packet Parser
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
//  Parses messages formatter per specification. Avalon streaming in,
//  Avalon streaming out.
//
//  Known Issues:
//  - No error generation/ packet checking
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
`default_nettype none

module pkt_parser
  (
   avalon_stream.slave  data_packet,  // Packet with messages from exchange
   avalon_stream.master message,      // Raw message information

   input wire           clk,          // system clock
   input wire           reset_n       // active low reset
   );

  logic signed [16:0]  msg_count;    // capture the number of messages in the packet
  logic signed [15:0]  msg_count_m1; // capture the number of messages in the packet
  logic [15:0]  msg_len;             // Length of current message
  logic [2:0]   bytes;               // Data is available for use in secondary buffer
  logic [2:0]   new_bytes;           // Data is available for use in secondary buffer
  logic [63:0]  shift_data;          // Data is available for use in secondary buffer
  logic         capt_first;          // Capture first incoming data
  logic         capture_data;        // Data capture phase
  logic         done;                // data capture done
  logic [127:0] new_data;            // Shifted data for processing
  logic         set_sop;             // new packet starting
  logic         hold_output;         // Hold off output for one cycle to recharge
  logic         realign;             // Special case for aligning data
  logic         set_sop_hold;        // hold off SOP
  logic         sop_hold;            // hold off SOP
  logic         int_sop;             // Internal SOP signal
  logic         int_eop;             // Internal EOP signal

  typedef enum logic {IDLE, DATA_PROC} fsm_t;
  fsm_t parse_cs, parse_ns;

  always_comb begin
    parse_ns          = parse_cs;
    capt_first        = '0;
    capture_data      = '0;
    case (parse_cs)
      IDLE: begin
        if (data_packet.sop && data_packet.valid) begin
          capt_first     = '1;
          parse_ns       = DATA_PROC;
        end
      end
      DATA_PROC: begin
        capture_data = '1;
        if (done) begin
          capture_data = '0;
          parse_ns     = IDLE;
        end
      end
    endcase // case (parse_cs)
  end

  always_comb begin
    new_bytes = bytes;
    hold_output = '0;
    if (~realign)
      case (msg_len)
        1: new_bytes = bytes + 5;
        2: new_bytes = bytes + 4;
        3: new_bytes = bytes + 3;
        4: new_bytes = bytes + 2;
        5: new_bytes = bytes + 1;
        6: new_bytes = bytes;
        7: new_bytes = bytes - 1'b1;
        0: begin
          new_bytes  = bytes - 2;
          hold_output = '1;
        end
        default: new_bytes = bytes;
      endcase // case (msg_len)
  end // always_comb

  always_comb begin
    case (bytes)
      1: new_data = {shift_data[63:56], data_packet.data, 56'b0};
      2: new_data = {shift_data[63:48], data_packet.data, 48'b0};
      3: new_data = {shift_data[63:40], data_packet.data, 40'b0};
      4: new_data = {shift_data[63:32], data_packet.data, 32'b0};
      5: new_data = {shift_data[63:24], data_packet.data, 24'b0};
      6: new_data = {shift_data[63:16], data_packet.data, 16'b0};
      7: new_data = {shift_data[63:8],  data_packet.data, 8'b0 };
      0: new_data = {shift_data[63:0],  data_packet.data       };
    endcase // case (orphan_count)
  end // always_comb

  logic [4:0] total_bytes;
  assign total_bytes = bytes + msg_len;

  // Generate ready signal out
  always_comb begin
    data_packet.ready = '1;
    if (done || sop_hold ||
        (capture_data && ~realign &&
         (((bytes >=  3) && (msg_len === 0)) ||
          ((bytes >=  4) && (msg_len === 1)) ||
          ((bytes >=  5) && (msg_len === 2)) ||
          ((bytes >=  6) && (msg_len === 3)) ||
          ((bytes === 7) && (msg_len === 4)) ||
          ((bytes === 0) && (msg_len <   6))
          )))
      data_packet.ready = '0;
    else
      data_packet.ready = '1;
  end

  assign msg_count_m1 = data_packet.data[63:48] - 1'b1;

  assign message.sop = int_sop & message.valid; // gate SOP when not valid
  assign message.eop = int_eop & message.valid; // gate EOP when not valid
  assign done = (message.eop && (msg_count==0));

  always_ff @(posedge clk) begin
    int_sop           <= '0;
    int_eop           <= '0;
    message.valid     <= '0;
    message.error     <= '0;
    message.empty     <= '0;
    //done              <= '0;
    realign           <= '0;

    parse_cs          <= parse_ns;

    if (set_sop && message.ready) begin
      int_sop <= '1;
      set_sop <= '0;
    end

    if (capt_first) begin
      // This is used only on SOP. Capture the message count
      msg_count    <= $signed({1'b0, msg_count_m1});
      msg_len      <= data_packet.data[47:32];
      set_sop      <= '1;
      shift_data   <= data_packet.data << 4*8;
      bytes        <= 4;
      set_sop_hold <= '1; // this will set the sop hold if an EOP comes in
    end

    if (done) begin
      set_sop_hold <= '0;
      sop_hold     <= '0;
    end else if (set_sop_hold && data_packet.eop) begin
      set_sop_hold <= '0;
      sop_hold     <= '1;
    end

    if (capture_data) begin
      message.valid      <= '1;
      case (bytes)
        1:       {message.data, shift_data[63:56]} <= new_data[127:56];
        2:       {message.data, shift_data[63:48]} <= new_data[127:48];
        3:       {message.data, shift_data[63:40]} <= new_data[127:40];
        4:       {message.data, shift_data[63:32]} <= new_data[127:32];
        5:       {message.data, shift_data[63:24]} <= new_data[127:24];
        6:       {message.data, shift_data[63:16]} <= new_data[127:16];
        7:       {message.data, shift_data[63:8]}  <= new_data[127:8];
        default: {message.data, shift_data[63:0]}  <= new_data[127:0];
      endcase // case (bytes)

      if (msg_len < 8) begin
        message.empty <= (8- msg_len);
        if (msg_count >= 0) set_sop <= '1;
        bytes <= new_bytes;
      end // if (msg_len < 8)

      if (msg_len <= 8) int_eop   <= '1;
      if (message.eop) msg_count     <= msg_count - 1;

      if (realign) begin
        shift_data <= new_data[63:0];
      end else begin
        case (msg_len)
          0: begin
            // boundary crossing case
            msg_len    <= new_data[127:112];
            shift_data <= new_data[111:48];
          end
          1: begin
            msg_len    <= new_data[119:104];
            shift_data <= new_data[103:40];
          end
          2: begin
            msg_len    <= new_data[111:96];
            shift_data <= new_data[95:32];
          end
          3: begin
            msg_len    <= new_data[103:88];
            shift_data <= new_data[87:24];
          end
          4: begin
            msg_len    <= new_data[95:80];
            shift_data <= new_data[79:16];
          end
          5: begin
            msg_len    <= new_data[87:72];
            shift_data <= new_data[71:8];
          end
          6: begin
            msg_len    <= new_data[79:64];
            shift_data <= new_data[63:0];
          end
          7: begin
            msg_len    <= new_data[71:56];
            shift_data <= {new_data[55:0], 8'b0};
            if (bytes == 1) realign <= '1;
          end
          // Don't count if we are holding off to align data
          default: if (~(hold_output || realign)) msg_len <= msg_len - 8;
        endcase // case (msg_len)
      end
    end // if (capture_data)

    if (hold_output || realign) begin
      int_sop           <= '0;
      int_eop           <= '0;
      message.valid     <= '0;
    end

    if (~reset_n) begin
      set_sop_hold <= '0;
      set_sop      <= '1;
      parse_cs     <= IDLE;
    end
  end // always_ff @

endmodule // pkt_parser
