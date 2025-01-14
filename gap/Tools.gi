# SPDX-License-Identifier: GPL-2.0-or-later
# ZXCalculusForCAP: The category of ZX-diagrams
#
# Implementations
#

if IsPackageMarkedForLoading( "json", "2.1.1" ) then

  InstallGlobalFunction( ExportAsQGraph,
    
    function ( phi, filename )
      local tuple, labels, input_positions, output_positions, edges, input_positions_indices, output_positions_indices, wire_vertices, node_vertices, vertex_names, padding_length, get_vertex_name, vertex_name, is_input, is_output, undir_edges, edge, edge_name, src_vertex_name, tgt_vertex_name, qgraph, pos, edge_counter;
        
        tuple := ZX_RemovedInnerNeutralNodes( MorphismDatum( phi ) );
        
        labels := ShallowCopy( tuple[1] );
        input_positions := ShallowCopy( tuple[2] );
        output_positions := ShallowCopy( tuple[3] );
        edges := ShallowCopy( tuple[4] );
        
        # nodes which are simultaneously inputs and outputs or multiple inputs or outputs are not supported by PyZX
        # split such nodes into multiple input or outputs nodes connected by an edge
        for pos in [ 1 .. Length( labels ) ] do
            
            # find input and output indices corresponding to this node
            input_positions_indices := Positions( input_positions, pos - 1 );
            output_positions_indices := Positions( output_positions, pos - 1 );
            
            if Length( input_positions_indices ) = 0 and Length( output_positions_indices ) = 0 then
                
                # not an input or output node
                
                # inner neutral nodes have been removed above
                Assert( 0, labels[pos] <> "neutral" );
                
                continue;
                
            fi;
            
            Assert( 0, labels[pos] = "neutral" );
            
            if Length( input_positions_indices ) = 1 and Length( output_positions_indices ) = 0 then
                
                # normal input node
                continue;
                
            elif Length( input_positions_indices ) = 0 and Length( output_positions_indices ) = 1 then
                
                # normal output node
                continue;
                
            elif Length( input_positions_indices ) = 1 and Length( output_positions_indices ) = 1 then
                
                # simultaneously an input and an output:
                # add a new neutral node for the output and an edge between input and output
                Add( labels, "neutral" );
                output_positions[output_positions_indices[1]] := Length( labels ) - 1;
                Add( edges, [ pos - 1, Length( labels ) - 1 ] );
                
            elif Length( input_positions_indices ) = 2 and Length( output_positions_indices ) = 0 then
                
                # simultaneously two inputs:
                # add a new neutral node for a separate input and a dummy Z node to connect the two inputs
                Add( labels, "neutral" );
                input_positions[input_positions_indices[2]] := Length( labels ) - 1;
                Add( labels, "Z" );
                Add( edges, [ input_positions[input_positions_indices[1]], Length( labels ) - 1 ] );
                Add( edges, [ input_positions[input_positions_indices[2]], Length( labels ) - 1 ] );
                
            elif Length( input_positions_indices ) = 0 and Length( output_positions_indices ) = 2 then
                
                # simultaneously two outputs:
                # add a new neutral node for a separate output and a dummy Z node to connect the two outputs
                Add( labels, "neutral" );
                output_positions[output_positions_indices[2]] := Length( labels ) - 1;
                Add( labels, "Z" );
                Add( edges, [ output_positions[output_positions_indices[1]], Length( labels ) - 1 ] );
                Add( edges, [ output_positions[output_positions_indices[2]], Length( labels ) - 1 ] );
                
            else
                
                # COVERAGE_IGNORE_NEXT_LINE
                Error( "this case should not appear in a well-defined ZX-diagram" );
                
            fi;
            
        od;
        
        edges := Set( edges );
        
        wire_vertices := rec( );
        node_vertices := rec( );
        
        vertex_names := [ ];
        
        # we want to pad all numbers with zeros on the left so the order does not change when ordering them as strings
        # this helps to work around https://github.com/Quantomatic/pyzx/issues/168
        padding_length := Int( Log10( Float( Length( labels ) ) ) ) + 1;
        
        get_vertex_name := function ( prefix, record )
          local id, id_string, vertex_name;
            
            id := Length( RecNames( record ) );
            
            id_string := String( id, padding_length );
            
            vertex_name := Concatenation( prefix, ReplacedString( id_string, " ", "0" ) );
            
            Assert( 0, not IsBound( record.(vertex_name) ) );
            
            return vertex_name;
            
        end;
        
        # See https://github.com/Quantomatic/quantomatic/blob/stable/docs/json_formats.txt
        # for a rough overview of the qgraph format.
        
        for pos in [ 1 .. Length( labels ) ] do
            
            if labels[pos] = "Z" then
                
                vertex_name := get_vertex_name( "v", node_vertices );
                
                node_vertices.(vertex_name) := rec(
                    annotation := rec(
                        coord := [ 1, - pos ],
                    ),
                    data := rec(
                        type := "Z",
                    )
                );
                
            elif labels[pos] = "X" then
                
                vertex_name := get_vertex_name( "v", node_vertices );
                
                node_vertices.(vertex_name) := rec(
                    annotation := rec(
                        coord := [ 1, - pos ],
                    ),
                    data := rec(
                        type := "X",
                    )
                );
                
                
            elif labels[pos] = "H" then
                
                vertex_name := get_vertex_name( "v", node_vertices );
                
                node_vertices.(vertex_name) := rec(
                    annotation := rec(
                        coord := [ 1, - pos ],
                    ),
                    data := rec(
                        type := "hadamard",
                        # always use Hadamard edges to work around https://github.com/Quantomatic/pyzx/issues/161
                        is_edge := "true",
                        value := "\\pi",
                    ),
                );
                
            elif labels[pos] = "neutral" then
                
                vertex_name := get_vertex_name( "b", wire_vertices );
                
                is_input := (pos - 1) in input_positions;
                is_output := (pos - 1) in output_positions;
                
                if is_input and is_output then
                    
                    # COVERAGE_IGNORE_NEXT_LINE
                    Error( "found neutral node which is simultaneously an input and an output, this is not supported by PyZX" );
                    
                elif is_input then
                    
                    wire_vertices.(vertex_name) := rec(
                        annotation := rec(
                            boundary := true,
                            coord := [ 0, - pos ],
                            input := SafeUniquePosition( input_positions, pos - 1 ) - 1,
                        ),
                    );
                    
                elif is_output then
                    
                    wire_vertices.(vertex_name) := rec(
                        annotation := rec(
                            boundary := true,
                            coord := [ 2, - pos ],
                            output := SafeUniquePosition( output_positions, pos - 1 ) - 1,
                        ),
                    );
                    
                else
                    
                    # COVERAGE_IGNORE_NEXT_LINE
                    Error( "found inner neutral node, this is not supported by PyZX" );
                    
                fi;
                
            else
                
                # COVERAGE_IGNORE_NEXT_LINE
                Error( "unknown label ", labels[pos] );
                
            fi;
            
            Assert( 0, Length( vertex_names ) = pos - 1 );
            Add( vertex_names, vertex_name );
            
        od;
        
        Assert( 0, Length( vertex_names ) = Length( labels ) );
        
        undir_edges := rec( );
        
        for edge_counter in [ 1 .. Length( edges ) ] do
            
            edge := edges[edge_counter];
            
            edge_name := Concatenation( "e", String( edge_counter - 1 ) );
            
            src_vertex_name := vertex_names[edge[1] + 1];
            tgt_vertex_name := vertex_names[edge[2] + 1];
            
            undir_edges.(edge_name) := rec( src := src_vertex_name, tgt := tgt_vertex_name );
            
        od;
        
        qgraph := rec( wire_vertices := wire_vertices,
                       node_vertices := node_vertices,
                       undir_edges := undir_edges );
        
        qgraph := GapToJsonString( qgraph );
        
        FileString( Concatenation( filename, ".qgraph" ), qgraph );
        
    end );
    
fi;
