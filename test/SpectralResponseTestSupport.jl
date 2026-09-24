
using LinearAlgebra

"""Closed two-orbital periodic model with flat zero ambient connection and nonzero Berry geometry."""
function spectral_test_model()
    x=ComplexF64[0 1; 1 0];
    y=ComplexF64[0 -im; im 0];
    z=ComplexF64[1 0; 0 -1]
    vectors=[0 1 -1 0 0 0 0; 0 0 0 1 -1 0 0; 0 0 0 0 0 1 -1]
    h=zeros(ComplexF64, 2, 2, 7)
    h[:, :, 1]=2.7z
    h[:, :, 2]=0.5z-0.5im*x;
    h[:, :, 3]=h[:, :, 2]'
    h[:, :, 4]=0.5z-0.5im*y;
    h[:, :, 5]=h[:, :, 4]'
    h[:, :, 6]=0.1z-0.15im*I(2);
    h[:, :, 7]=h[:, :, 6]'
    lattice=[3.0 0.0 0.0; 0.3 3.4 0.0; 0.2 0.1 4.1]
    position=zeros(ComplexF64, 2, 2, 3, 7)
    for (a, centers) in enumerate(((0.12, 0.63), (0.2, -0.13), (-0.1, 0.41)))
        position[:, :, a, 1]=Diagonal(collect(centers))
    end
    return WannierNLQG.Core.TightBindingModel(lattice, 2, 7, ones(Int, 7), vectors, h, position)
end

# Read only numerical columns, excluding unit/provenance comment lines.
function spectral_test_table(path)
    rows=[
        parse.(Float64, split(line)) for
        line in eachline(path) if !startswith(line, "#")&&!isempty(strip(line))
    ]
    return isempty(rows) ? zeros(0, 0) : permutedims(reduce(hcat, rows))
end
