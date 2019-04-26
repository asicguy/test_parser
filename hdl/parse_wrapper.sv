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
//  
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
  
  module parse_wrapper
    (
     input wire 	 logic clk,
     input wire 	 logic reset_n,

     output logic 	 in_ready,
     input wire 	 logic in_valid,
     input wire 	 logic in_startofpacket,
     input wire 	 logic in_endofpacket,
     input wire 	 logic [63:0] in_data,
     input wire 	 logic [7:0] in_empty,
     input wire 	 logic in_error,
     input wire 	 logic out_ready,

     output logic 	 out_valid,
     output logic 	 out_startofpayload,
     output logic 	 out_endofpayload,
     output logic [63:0] out_data,
     output logic [7:0]  out_empty,
     output logic 	 out_error
     );

  avalon_stream data_packet();  // Packet with messages from exchange
  avalon_stream message();      // Raw message information

  always_ff @(posedge clk) begin
    in_ready <= data_packet.ready;
    data_packet.valid <= in_valid;
    data_packet.sop <= in_startofpacket; 
    data_packet.eop <= in_endofpacket;
    data_packet.data <= in_data;
    data_packet.empty <= in_empty;
    data_packet.error <= in_error;
    message.ready <= out_ready;
    
    
    out_valid <= message.valid;
    out_startofpayload <= message.sop;
    out_endofpayload <= message.eop;
    out_data  <= message.data;
    out_empty <= message.empty;
    out_error <= message.error;
  end // always_ff @
  
  pkt_parser parse_inst
    (
     .data_packet   (data_packet.slave),
     .message       (message.master),
     
     .clk           (clk),    
     .reset_n       (reset_n)
     );
endmodule // pkt_parser
