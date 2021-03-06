# Query adjacency matrix in a database table
using PyPlot

# Create a starting set of vertices
Nv0 = 100
v0 = ceil.(Int,10000*rand(Nv0,1))

# Convert to string list.
v0str = string.(v0)

# Get degrees of vertices.
Adeg = str2num(TadjDeg[v0str,:])

# Select vertices in an out degree range.
degMin = 5;  degMax = max(100,minimum(getval(Adeg[:,"OutDeg,"]))+1)
v1str = getrow((Adeg[:,"OutDeg,"] > degMin) < degMax )

# Get vertex neighbors.
A = logical(Tadj[v1str,:])

figure()
spy(A)
xlabel("end vertex")
ylabel("start vertex");
