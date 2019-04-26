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
//  Title       :  Avalon interface
//  File        :  int_avalon.v
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

interface avalon_stream 
  #(parameter DWIDTH=64);       // Data bus width
  
  logic ready;                 // Slave is ready for data
  logic valid;                 // Data is valid when high
  logic error;                 // master indicates error to the slave
  logic sop;                   // Start of packet indicator
  logic eop;                   // End of packet indicator
  logic [DWIDTH-1:0] data;     // incoming data
  logic [$clog2(DWIDTH/8)-1:0] empty;  // Flag unused bytes on EOP
   
  modport master
    (
     input  ready,
     
     output error,
     output valid,
     output sop,
     output eop,
     output data,
     output empty
     );
  
  modport slave
    (
     
     output ready,

     input  error,
     input  valid,
     input  sop,
     input  eop,
     input  data,
     input  empty
     );
endinterface : avalon_stream // avalon_stream

   