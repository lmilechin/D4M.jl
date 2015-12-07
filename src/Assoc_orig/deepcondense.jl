
#=
deepCondense : remove empty mapping of row, column, and value, and return the condensed of the input Assoc.
=#
function deepCondense(A::Assoc)
    Anew = condense(A)
#TODO
    row,col,val = findnz(A.A)
    uniVal = sort!(unique(val))
    valMap = [searchsortedfirst(x,uniVal) for x in val]
    val = map(x -> valMapp[x], val)
    Anew.A = sparse(row,col,val)
    Anew.val = uniVal
    return Anew
    
end


########################################################
# D4M: Dynamic Distributed Dimensional Data Model
# Architect: Dr. Jeremy Kepner (kepner@ll.mit.edu)
# Software Engineer: Alexander Chen (alexc89@mit.edu)
########################################################

