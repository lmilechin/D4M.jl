
# DBtable contains the table binding information, as well as the
# d4mQuery Java object for the table.
struct DBtable
    DB::DBserver
    name::String
    security::String
    numLimit::Int
    numRow::Int
    columnfamily::String
    putBytes::Number
    d4mQuery
    tableOps
end

# DBtablePair contains the table pair binding information, as well as the
# d4mQuery Java object for the table.
# The DBtablePair contains bindings to both a table and its transpose.
struct DBtablePair
    DB::DBserver
    name1::String
    name2::String
    security::String
    numLimit::Int
    numRow::Int
    columnfamily::String
    putBytes::Number
    d4mQuery
    tableOps
end

# Deletes specified DB table
# TODO: add check whether want to delete
function delete(table::DBtable)
    jcall(table.tableOps,"deleteTable", Void, (JString,), table.name)
 end
 
 function delete(table::DBtablePair)
     jcall(table.tableOps,"deleteTable", Void, (JString,), table.name1)
     jcall(table.tableOps,"deleteTable", Void, (JString,), table.name2)
 end

 # Helper function to convert Assoc fields to an Accumulo-friendly string
 function toDBstring(input)
    StringArray = Array{T} where T <: AbstractString
    NumericArray = Array{T} where T <: Number
    UnionArray = Array{T} where T <: Union{AbstractString,Number}
    
    if isa(input,StringArray)
        output = join(input,"\n")*"\n"
    elseif isa(input,NumericArray)
        output = join(string.(input),"\n")*"\n"
    elseif isa(input,UnionArray)
        output = join(convert(Array{AbstractString},input),"\n")*"\n"
    elseif isa(input,Colon)
        output = ":"
    elseif isa(input,StartsWith)
        str = input.inputString
        output = ""
        del = str[end]
        idx1 = 1
        idx2 = search(str,del,idx1+1)

        while idx2 > 0
            output = output*str[idx1:idx2]*":"*del*str[idx1:idx2-1]*Char(127)*del
            idx1 = idx2+1
            idx2 = search(str,del,idx2+1)
        end
    else
        output = input
    end
    
    return output
end

# Given a DBtablePair, returns DBtablePair with name1 and name2 reassigned as name2 and name1, respectively.
function transpose(table::DBtablePair)
    return DBtablePair(table.DB, table.name2, table.name1, table.security, table.numLimit, table.numRow, table.columnfamily, table.putBytes, table.d4mQuery, table.tableOps)
end

# Base getindex function- i and j are d4m formatted strings (delimitered)
DBtableType = Union{DBtable,DBtablePair}
function getindex(table::DBtableType,i::AbstractString,j::AbstractString)
    
    jcall(table.d4mQuery,"setCloudType", Void, (JString,), table.DB.dbType)
    jcall(table.d4mQuery,"setLimit", Void, (jint,), table.numLimit)
    jcall(table.d4mQuery,"reset", Void, (),)
    
    dbResultSet = @jimport "edu.mit.ll.d4m.db.cloud.D4mDbResultSet"
    
    if i!=":" || j==":" || isa(table,DBtable)
        
        if isa(table,DBtablePair)
            jcall(table.d4mQuery,"setTableName", Void, (JString,), table.name1)
        end
        jcall(table.d4mQuery,"doMatlabQuery",dbResultSet,(JString,JString,JString,JString,),i,j,table.columnfamily,table.security)

        r = jcall(table.d4mQuery,"getRowReturnString", JString, (),)
        c = jcall(table.d4mQuery,"getColumnReturnString", JString, (),)
        
    else # Search transpose table if column query
        jcall(table.d4mQuery,"setTableName", Void, (JString,), table.name2)
        jcall(table.d4mQuery,"doMatlabQuery",dbResultSet,(JString,JString,JString,JString,),j,i,table.columnfamily,table.security)

        c = jcall(table.d4mQuery,"getRowReturnString", JString, (),)
        r = jcall(table.d4mQuery,"getColumnReturnString", JString, (),)
    end
    
    v = jcall(table.d4mQuery,"getValueReturnString", JString, (),)
    
    return deepCondense(Assoc(r,c,v))
    
end

UnionArray = Array{Union{AbstractString,Number}}
ValidQueryTypes = Union{Colon,AbstractString,Array,UnionArray,StartsWith}

getindex(table::DBtableType,i::ValidQueryTypes,j::ValidQueryTypes) = getindex(table,toDBstring(i),toDBstring(j))

# Query iterator functionality
function getiterator(table::DBtableType,nelements::Number)

    ops = @jimport "edu.mit.ll.d4m.db.cloud.D4mDbTableOperations"
    opsObj = ops((JString, JString, JString, JString,), table.DB.instanceName, table.DB.host, table.DB.user, table.DB.pass)
    
    if isa(table,DBtablePair)
        d4mQuery = @jimport "edu.mit.ll.d4m.db.cloud.D4mDataSearch"
        queryObj = d4mQuery((JString, JString, JString, JString, JString,), table.DB.instanceName, table.DB.host, table.name1, table.DB.user, table.DB.pass)

        Ti = DBtablePair(table.DB, table.name1, table.name2, table.security,
        nelements, table.numRow, table.columnfamily, table.putBytes,
        queryObj,opsObj)
    else
        d4mQuery = @jimport "edu.mit.ll.d4m.db.cloud.D4mDataSearch"
        queryObj = d4mQuery((JString, JString, JString, JString, JString,), table.DB.instanceName, table.DB.host, table.name, table.DB.user, table.DB.pass)
        
        Ti = DBtable(table.DB, table.name, table.security,
        nelements, table.numRow, table.columnfamily, table.putBytes,
        queryObj,opsObj)
    end
    
    return Ti
end

# The getindex function to get the next few elements for an iterator table object
function getindex(table::DBtableType)
    
    #T.d4mQuery.next();
    #dbResultSet = @jimport "edu.mit.ll.d4m.db.cloud.D4mDbResultSet"
    jcall(table.d4mQuery,"next",Void,(),)
    
    # check if transpose table query- if so flip the r and c results.
    tablename = jcall(table.d4mQuery,"getTableName", JString, (),)
    
    if isa(table,DBtablePair) && tablename == table.name2
        c = jcall(table.d4mQuery,"getRowReturnString", JString, (),)
        r = jcall(table.d4mQuery,"getColumnReturnString", JString, (),)
    else
        r = jcall(table.d4mQuery,"getRowReturnString", JString, (),)
        c = jcall(table.d4mQuery,"getColumnReturnString", JString, (),)
    end
    
    v = jcall(table.d4mQuery,"getValueReturnString", JString, (),)
    
    return deepCondense(Assoc(r,c,v))
    
end

# Helper function for ingest
function searchall(str::String,c::Char)
    idx = search(str,c)
    allIdx = idx

    while idx < endof(str)
        idx = search(str,c,idx+1)
        allIdx = [allIdx idx]
    end

    return allIdx
end

# putTriple is the main db ingest function
DBtableType = Union{DBtable,DBtablePair}
function putTriple(table::DBtableType,r::UnionArray,c::UnionArray,v::UnionArray)
    
    # Find chunk size for ingest
    chunkBytes = table.putBytes
    numTriples = length(r);
    avgBytePerTriple = (sum(length.(r)) + sum(length.(c)) + sum(length.(v)))/numTriples;
    chunkSize = min(max(1,round(Integer,chunkBytes/avgBytePerTriple)),numTriples);
    
    # In Matlab D4M this is inside the loop- do we need to make a new object each time?
    dbInsert = @jimport "edu.mit.ll.d4m.db.cloud.D4mDbInsert"
    
    if isa(table,DBtablePair)
        insertObj = dbInsert((JString, JString, JString, JString, JString,), table.DB.instanceName, table.DB.host, table.name1, table.DB.user, table.DB.pass)
        insertObjT = dbInsert((JString, JString, JString, JString, JString,), table.DB.instanceName, table.DB.host, table.name2, table.DB.user, table.DB.pass)
    else
        insertObj = dbInsert((JString, JString, JString, JString, JString,), table.DB.instanceName, table.DB.host, table.name, table.DB.user, table.DB.pass)
    end
        
    # Insert each chunk
    for i in 1:chunkSize:numTriples
        iNext = min(i + chunkSize,numTriples);
        rr = toDBstring(r[i:iNext]);
        cc = toDBstring(c[i:iNext]);
        vv = toDBstring(v[i:iNext]);
        
        jcall(insertObj,"doProcessing",Void,(JString,JString,JString,JString,JString,),rr, cc, vv, table.columnfamily, table.security)
        
        # Insert transpose into transpose table if DBtablePair
        if isa(table,DBtablePair)
            jcall(insertObjT,"doProcessing",Void,(JString,JString,JString,JString,JString,),cc, rr, vv, table.columnfamily, table.security)
        end
    end
    
end

function ingestprep(input)
    StringArray = Array{T} where T <: AbstractString
    NumericArray = Array{T} where T <: Number
    UnionArray = Array{Union{AbstractString,Number}}
    
    if isa(input,StringArray)
        output = convert(UnionArray,input)
    elseif isa(input,NumericArray)
        output = string.(input)
    elseif isa(input,AbstractString)
        output = split(input,input[end],limit=NumStr(input))
    else
        output = input
    end
    
    return output
end

UnionArray = Array{Union{AbstractString,Number}}
#StringOrNumArray = Union{AbstractString,Array,Number}
ValidType = Union{UnionArray,AbstractString,Array,Number}
putTriple(table::DBtableType,r::ValidType,c::ValidType,v::ValidType) = putTriple(table,ingestprep(r),ingestprep(c),ingestprep(v))

# The put function deconstructs A and calls putTriple
function put(table::DBtableType,A::Assoc)
    r,c,v = find(A)
    putTriple(table,r,c,v)
end

#addColCombiner: Adds combiners to specific column names.
# Inputs: T = database table object
    # colNames = string list of column names. If ':,' (default) then sets all columns to combining.
    # combineType = combiner name "min", "max", or "sum";
    #      IF D4M_API_JAVA.jar is installed on the Accumulo instance, you can
    #      specify "min_decimal", "max_decimal", or "sum_decimal"
    #      to obtain the ability to combine on decimals
function addColCombiner(table::DBtable,colNames=":,",combineType="sum")   
        jcall(table.tableOps,"designateCombiningColumns", Void, (JString, JString, JString, JString,), table.name, colNames, combineType, table.columnfamily)
end

# nnz returns the number of entries in specified table
function nnz(table::DBtableType)
    if isa(table,DBtablePair)
        tname = table.name1
    else
        tname = table.name
    end
    
    arrayList = @jimport "java.util.ArrayList"
    list = @jimport "java.util.List"
    
    tableList = arrayList((),)
    jcall(tableList,"add",jboolean,(JObject,),tname)
    
    jcall(table.tableOps,"getNumberOfEntries",jlong,(list,),tableList)
end