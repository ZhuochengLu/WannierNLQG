"""Bloch-sum convention used for Wannier-basis matrix elements."""
@enum WannierCenterConvention::UInt8 begin
    CONVENTION_I = 1
    CONVENTION_II = 2
end

"""Return the stable public label for a Wannier-center convention."""
function wannier_center_convention_name(convention::WannierCenterConvention)
    convention == CONVENTION_I && return "Convention_I"
    convention == CONVENTION_II && return "Convention_II"
    error("Unsupported Wannier-center convention $(convention).")
end
