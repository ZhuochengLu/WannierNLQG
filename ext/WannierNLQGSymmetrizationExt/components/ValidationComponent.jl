# Include-only component root for workflow validation and qualification.

include("../MagneticMomentReaders.jl")
include("validation/OperatorWorkflowValidation.jl")
include("validation/GaugeAwareValidation.jl")
include("../ResponseSymmetryQualification.jl")
