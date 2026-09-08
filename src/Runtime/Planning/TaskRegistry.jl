# Task normalization ends at this file. Execution code consumes TaskDefinition or
# NormalizedTaskPlan values and does not perform string, Dict, or Symbol dispatch.

@enum QuantityID::UInt8 begin
    QUANTITY_SHIFT_CURRENT
    QUANTITY_QUANTUM_HERMITIAN_CONNECTION
    QUANTITY_HERMITIAN_CURVATURE_TENSOR
    QUANTITY_PHOTON_DRAG_SHIFT_CURRENT
    QUANTITY_SHIFT_VECTOR
    QUANTITY_INJECTION_CURRENT
    QUANTITY_INJECTION_SPIN_CURRENT
    QUANTITY_SHIFT_SPIN_CURRENT
    QUANTITY_PHOTON_DRAG_INJECTION_CURRENT
    QUANTITY_BERRY_CURVATURE
    QUANTITY_BERRY_CURVATURE_DIPOLE
    QUANTITY_BERRY_CURVATURE_QUADRUPOLE
    QUANTITY_QUANTUM_METRIC
    QUANTITY_INTERBAND_BERRY_CURVATURE
    QUANTITY_INTERBAND_QUANTUM_METRIC
    QUANTITY_ZEEMAN_INTERBAND_BERRY_CURVATURE
    QUANTITY_ZEEMAN_INTERBAND_QUANTUM_METRIC
    QUANTITY_QUANTUM_METRIC_DIPOLE
    QUANTITY_QUANTUM_METRIC_QUADRUPOLE
    QUANTITY_QUANTUM_CHRISTOFFEL_SYMBOL
    QUANTITY_TRIPLE_PHASE_PRODUCT
    QUANTITY_BAND_STRUCTURE
end

@enum MethodID::UInt8 begin
    METHOD_CONVENTIONAL
    METHOD_PROJECTOR
    METHOD_GEOMETRIC_LOOP
    METHOD_WILSON_LOOP
end

@enum CalculationID::UInt8 begin
    CALCULATION_INTEGRAL
    CALCULATION_KSLICE
    CALCULATION_KPATH
end

@enum ExecutorFamily::UInt8 begin
    EXECUTOR_INTEGRAL_CONVENTIONAL
    EXECUTOR_INTEGRAL_PROJECTOR
    EXECUTOR_INTEGRAL_GEOMETRIC_LOOP
    EXECUTOR_INTEGRAL_WILSON_LOOP
    EXECUTOR_KSLICE_CONVENTIONAL
    EXECUTOR_KSLICE_PROJECTOR
    EXECUTOR_KSLICE_GEOMETRIC_LOOP
    EXECUTOR_KSLICE_WILSON_LOOP
    EXECUTOR_BAND_STRUCTURE
end

@enum MatrixPolicy::UInt8 begin
    MATRIX_CONVENTIONAL_Q0_CURRENT
    MATRIX_CONVENTIONAL_INJECTION_CURRENT
    MATRIX_CONVENTIONAL_INJECTION_SPIN_CURRENT
    MATRIX_CONVENTIONAL_SHIFT_SPIN_CURRENT
    MATRIX_CONVENTIONAL_QHC
    MATRIX_CONVENTIONAL_HCT
    MATRIX_CONVENTIONAL_BERRY_CURVATURE
    MATRIX_CONVENTIONAL_BERRY_CURVATURE_DIPOLE
    MATRIX_CONVENTIONAL_BERRY_CURVATURE_QUADRUPOLE
    MATRIX_CONVENTIONAL_QUANTUM_METRIC
    MATRIX_CONVENTIONAL_INTERBAND_GEOMETRY
    MATRIX_CONVENTIONAL_ZEEMAN_INTERBAND_GEOMETRY
    MATRIX_CONVENTIONAL_QUANTUM_METRIC_DIPOLE
    MATRIX_CONVENTIONAL_QUANTUM_METRIC_QUADRUPOLE
    MATRIX_CONVENTIONAL_QUANTUM_CHRISTOFFEL
    MATRIX_CONVENTIONAL_TRIPLE_PHASE_PRODUCT
    MATRIX_PROJECTOR_SHIFT_CURRENT
    MATRIX_PROJECTOR_QHC
    MATRIX_GEOMETRIC_SHIFT_CURRENT_Q0
    MATRIX_GEOMETRIC_SHIFT_CURRENT_FINITE_Q
    MATRIX_GEOMETRIC_QHC
    MATRIX_GEOMETRIC_SHIFT_VECTOR
    MATRIX_WILSON_SHIFT_CURRENT
    MATRIX_WILSON_QHC
    MATRIX_WILSON_SHIFT_VECTOR
    MATRIX_PHOTON_DRAG_INJECTION_CURRENT
    MATRIX_SPECTRUM
end

@enum BandPolicy::UInt8 begin
    BAND_PAIR
    BAND_RESOLVED
    BAND_TARGET_GROUP
    BAND_INTERBAND_GROUPS
    BAND_TRIPLE_GROUPS
    BAND_ALL
end

@enum OutputPolicy::UInt8 begin
    OUTPUT_INTEGRAL
    OUTPUT_KSLICE_COMPLEX
    OUTPUT_KSLICE_BAND_REAL
    OUTPUT_KSLICE_GROUP_REAL
    OUTPUT_KSLICE_INTERBAND_REAL
    OUTPUT_BAND_STRUCTURE
end

@enum FourierPolicy::UInt8 begin
    FOURIER_CONVENTIONAL_Q0
    FOURIER_CONVENTIONAL_GEOMETRY
    FOURIER_PROJECTOR
    FOURIER_GEOMETRIC_Q0
    FOURIER_GEOMETRIC_FINITE_Q
    FOURIER_WILSON
    FOURIER_SPIN
    FOURIER_HIGH_ORDER
    FOURIER_DIRECT_PATH
end

# Registry row binding quantity/method/calculation to executor, matrix/band/output/Fourier policies, rank, filename suffix and spin/finite-q requirements.
struct TaskDefinition
    quantity::QuantityID
    method::MethodID
    calculation::CalculationID
    task::Symbol
    executor::ExecutorFamily
    matrix_policy::MatrixPolicy
    band_policy::BandPolicy
    output_policy::OutputPolicy
    fourier_policy::FourierPolicy
    tensor_rank::UInt8
    observable_suffix::String
    requires_spin::Bool
    requires_finite_q::Bool
end

# One registry definition with a fixed four-slot Cartesian tuple and explicit tensor rank plus band/output/Fourier policies.
struct NormalizedTaskPlan
    definition::TaskDefinition
    tensor_indices::NTuple{4, Int}
    tensor_rank::UInt8
    band_policy::BandPolicy
    output_policy::OutputPolicy
    fourier_policy::FourierPolicy
end

# Map a normalized public quantity symbol to its typed enum, rejecting unsupported symbols.
quantity_id(q::Symbol) =
    q == :shift_current ? QUANTITY_SHIFT_CURRENT :
    q == :quantum_hermitian_connection ? QUANTITY_QUANTUM_HERMITIAN_CONNECTION :
    q == :hermitian_curvature_tensor ? QUANTITY_HERMITIAN_CURVATURE_TENSOR :
    q == :photon_drag_shift_current ? QUANTITY_PHOTON_DRAG_SHIFT_CURRENT :
    q == :shift_vector ? QUANTITY_SHIFT_VECTOR :
    q == :injection_current ? QUANTITY_INJECTION_CURRENT :
    q == :injection_spin_current ? QUANTITY_INJECTION_SPIN_CURRENT :
    q == :shift_spin_current ? QUANTITY_SHIFT_SPIN_CURRENT :
    q == :photon_drag_injection_current ? QUANTITY_PHOTON_DRAG_INJECTION_CURRENT :
    q == :berry_curvature ? QUANTITY_BERRY_CURVATURE :
    q == :berry_curvature_dipole ? QUANTITY_BERRY_CURVATURE_DIPOLE :
    q == :berry_curvature_quadrupole ? QUANTITY_BERRY_CURVATURE_QUADRUPOLE :
    q == :quantum_metric ? QUANTITY_QUANTUM_METRIC :
    q == :interband_berry_curvature ? QUANTITY_INTERBAND_BERRY_CURVATURE :
    q == :interband_quantum_metric ? QUANTITY_INTERBAND_QUANTUM_METRIC :
    q == :zeeman_interband_berry_curvature ? QUANTITY_ZEEMAN_INTERBAND_BERRY_CURVATURE :
    q == :zeeman_interband_quantum_metric ? QUANTITY_ZEEMAN_INTERBAND_QUANTUM_METRIC :
    q == :quantum_metric_dipole ? QUANTITY_QUANTUM_METRIC_DIPOLE :
    q == :quantum_metric_quadrupole ? QUANTITY_QUANTUM_METRIC_QUADRUPOLE :
    q == :quantum_christoffel_symbol ? QUANTITY_QUANTUM_CHRISTOFFEL_SYMBOL :
    q == :triple_phase_product ? QUANTITY_TRIPLE_PHASE_PRODUCT :
    q == :band_structure ? QUANTITY_BAND_STRUCTURE : error("No QuantityID for quantity=$(q).")

# Recover the public quantity symbol from a typed quantity enum, rejecting unmapped values.
quantity_symbol(q::QuantityID) =
    q == QUANTITY_SHIFT_CURRENT ? :shift_current :
    q == QUANTITY_QUANTUM_HERMITIAN_CONNECTION ? :quantum_hermitian_connection :
    q == QUANTITY_HERMITIAN_CURVATURE_TENSOR ? :hermitian_curvature_tensor :
    q == QUANTITY_PHOTON_DRAG_SHIFT_CURRENT ? :photon_drag_shift_current :
    q == QUANTITY_SHIFT_VECTOR ? :shift_vector :
    q == QUANTITY_INJECTION_CURRENT ? :injection_current :
    q == QUANTITY_INJECTION_SPIN_CURRENT ? :injection_spin_current :
    q == QUANTITY_SHIFT_SPIN_CURRENT ? :shift_spin_current :
    q == QUANTITY_PHOTON_DRAG_INJECTION_CURRENT ? :photon_drag_injection_current :
    q == QUANTITY_BERRY_CURVATURE ? :berry_curvature :
    q == QUANTITY_BERRY_CURVATURE_DIPOLE ? :berry_curvature_dipole :
    q == QUANTITY_BERRY_CURVATURE_QUADRUPOLE ? :berry_curvature_quadrupole :
    q == QUANTITY_QUANTUM_METRIC ? :quantum_metric :
    q == QUANTITY_INTERBAND_BERRY_CURVATURE ? :interband_berry_curvature :
    q == QUANTITY_INTERBAND_QUANTUM_METRIC ? :interband_quantum_metric :
    q == QUANTITY_ZEEMAN_INTERBAND_BERRY_CURVATURE ? :zeeman_interband_berry_curvature :
    q == QUANTITY_ZEEMAN_INTERBAND_QUANTUM_METRIC ? :zeeman_interband_quantum_metric :
    q == QUANTITY_QUANTUM_METRIC_DIPOLE ? :quantum_metric_dipole :
    q == QUANTITY_QUANTUM_METRIC_QUADRUPOLE ? :quantum_metric_quadrupole :
    q == QUANTITY_QUANTUM_CHRISTOFFEL_SYMBOL ? :quantum_christoffel_symbol :
    q == QUANTITY_TRIPLE_PHASE_PRODUCT ? :triple_phase_product :
    q == QUANTITY_BAND_STRUCTURE ? :band_structure : error("No Symbol for QuantityID=$(q).")

# Map a normalized method symbol to its typed enum for execution dispatch.
method_id(m::Symbol) =
    m == :conventional ? METHOD_CONVENTIONAL :
    m == :projector ? METHOD_PROJECTOR :
    m == :geometric_loop ? METHOD_GEOMETRIC_LOOP :
    m == :wilson_loop ? METHOD_WILSON_LOOP : error("No MethodID for method=$(m).")

# Recover the public method symbol from the typed execution enum.
method_symbol(m::MethodID) =
    m == METHOD_CONVENTIONAL ? :conventional :
    m == METHOD_PROJECTOR ? :projector :
    m == METHOD_GEOMETRIC_LOOP ? :geometric_loop :
    m == METHOD_WILSON_LOOP ? :wilson_loop : error("No Symbol for MethodID=$(m).")

# Map integral, kslice or k-path calculation symbols to their typed dispatch enum.
calculation_id(c::Symbol) =
    c == :integral ? CALCULATION_INTEGRAL :
    c == :kslice ? CALCULATION_KSLICE :
    c == :kpath ? CALCULATION_KPATH : error("No CalculationID for calculation=$(c).")

# Recover the public calculation symbol from its typed dispatch enum.
calculation_symbol(c::CalculationID) =
    c == CALCULATION_INTEGRAL ? :integral :
    c == CALCULATION_KSLICE ? :kslice :
    c == CALCULATION_KPATH ? :kpath : error("No Symbol for CalculationID=$(c).")

# Construct one registry row with explicit task, executor, matrix, selection, output and Fourier policies.
function _task_definition(
    quantity::Symbol,
    method::Symbol,
    calculation::Symbol,
    task::Symbol,
    executor::ExecutorFamily,
    matrix_policy::MatrixPolicy,
    band_policy::BandPolicy,
    output_policy::OutputPolicy,
    fourier_policy::FourierPolicy,
    tensor_rank::Integer,
    observable_suffix::AbstractString;
    requires_spin::Bool = false,
    requires_finite_q::Bool = false,
)
    return TaskDefinition(
        quantity_id(quantity),
        method_id(method),
        calculation_id(calculation),
        task,
        executor,
        matrix_policy,
        band_policy,
        output_policy,
        fourier_policy,
        UInt8(tensor_rank),
        String(observable_suffix),
        requires_spin,
        requires_finite_q,
    )
end

const TASK_DEFINITIONS = (
    _task_definition(
        :band_structure,
        :conventional,
        :kpath,
        :band_structure,
        EXECUTOR_BAND_STRUCTURE,
        MATRIX_SPECTRUM,
        BAND_ALL,
        OUTPUT_BAND_STRUCTURE,
        FOURIER_DIRECT_PATH,
        0,
        "band",
    ),
    (
        _task_definition(
            :shift_current,
            method,
            calculation,
            calculation == :integral ? :shift_current_integral : :shift_current_kslice,
            calculation == :integral ?
            (
                method == :conventional ? EXECUTOR_INTEGRAL_CONVENTIONAL :
                method == :projector ? EXECUTOR_INTEGRAL_PROJECTOR :
                method == :geometric_loop ? EXECUTOR_INTEGRAL_GEOMETRIC_LOOP :
                EXECUTOR_INTEGRAL_WILSON_LOOP
            ) :
            (
                method == :conventional ? EXECUTOR_KSLICE_CONVENTIONAL :
                method == :projector ? EXECUTOR_KSLICE_PROJECTOR :
                method == :geometric_loop ? EXECUTOR_KSLICE_GEOMETRIC_LOOP :
                EXECUTOR_KSLICE_WILSON_LOOP
            ),
            method == :conventional ? MATRIX_CONVENTIONAL_Q0_CURRENT :
            method == :projector ? MATRIX_PROJECTOR_SHIFT_CURRENT :
            method == :geometric_loop ? MATRIX_GEOMETRIC_SHIFT_CURRENT_Q0 :
            MATRIX_WILSON_SHIFT_CURRENT,
            BAND_PAIR,
            calculation == :integral ? OUTPUT_INTEGRAL : OUTPUT_KSLICE_COMPLEX,
            method == :conventional ? FOURIER_CONVENTIONAL_Q0 :
            method == :projector ? FOURIER_PROJECTOR :
            method == :geometric_loop ? FOURIER_GEOMETRIC_Q0 : FOURIER_WILSON,
            3,
            calculation == :integral ? "sc" : "sck",
        ) for calculation in (:integral, :kslice) for
        method in (:conventional, :projector, :geometric_loop, :wilson_loop)
    )...,
    (
        _task_definition(
            :quantum_hermitian_connection,
            method,
            :kslice,
            :quantum_hermitian_connection_kslice,
            method == :conventional ? EXECUTOR_KSLICE_CONVENTIONAL :
            method == :projector ? EXECUTOR_KSLICE_PROJECTOR :
            method == :geometric_loop ? EXECUTOR_KSLICE_GEOMETRIC_LOOP :
            EXECUTOR_KSLICE_WILSON_LOOP,
            method == :conventional ? MATRIX_CONVENTIONAL_QHC :
            method == :projector ? MATRIX_PROJECTOR_QHC :
            method == :geometric_loop ? MATRIX_GEOMETRIC_QHC : MATRIX_WILSON_QHC,
            BAND_PAIR,
            OUTPUT_KSLICE_COMPLEX,
            method == :conventional ? FOURIER_CONVENTIONAL_GEOMETRY :
            method == :projector ? FOURIER_PROJECTOR :
            method == :geometric_loop ? FOURIER_GEOMETRIC_Q0 : FOURIER_WILSON,
            3,
            "qhck",
        ) for method in (:conventional, :projector, :geometric_loop, :wilson_loop)
    )...,
    _task_definition(
        :hermitian_curvature_tensor,
        :conventional,
        :kslice,
        :hermitian_curvature_tensor_kslice,
        EXECUTOR_KSLICE_CONVENTIONAL,
        MATRIX_CONVENTIONAL_HCT,
        BAND_PAIR,
        OUTPUT_KSLICE_COMPLEX,
        FOURIER_HIGH_ORDER,
        4,
        "hctk",
    ),
    _task_definition(
        :berry_curvature,
        :conventional,
        :kslice,
        :berry_curvature_kslice,
        EXECUTOR_KSLICE_CONVENTIONAL,
        MATRIX_CONVENTIONAL_BERRY_CURVATURE,
        BAND_RESOLVED,
        OUTPUT_KSLICE_BAND_REAL,
        FOURIER_CONVENTIONAL_GEOMETRY,
        2,
        "bck",
    ),
    _task_definition(
        :berry_curvature_dipole,
        :conventional,
        :kslice,
        :berry_curvature_dipole_kslice,
        EXECUTOR_KSLICE_CONVENTIONAL,
        MATRIX_CONVENTIONAL_BERRY_CURVATURE_DIPOLE,
        BAND_TARGET_GROUP,
        OUTPUT_KSLICE_GROUP_REAL,
        FOURIER_HIGH_ORDER,
        3,
        "bcdk",
    ),
    _task_definition(
        :berry_curvature_quadrupole,
        :conventional,
        :kslice,
        :berry_curvature_quadrupole_kslice,
        EXECUTOR_KSLICE_CONVENTIONAL,
        MATRIX_CONVENTIONAL_BERRY_CURVATURE_QUADRUPOLE,
        BAND_TARGET_GROUP,
        OUTPUT_KSLICE_GROUP_REAL,
        FOURIER_HIGH_ORDER,
        4,
        "bcqk",
    ),
    _task_definition(
        :quantum_metric,
        :conventional,
        :kslice,
        :quantum_metric_kslice,
        EXECUTOR_KSLICE_CONVENTIONAL,
        MATRIX_CONVENTIONAL_QUANTUM_METRIC,
        BAND_RESOLVED,
        OUTPUT_KSLICE_BAND_REAL,
        FOURIER_CONVENTIONAL_GEOMETRY,
        2,
        "qmk",
    ),
    _task_definition(
        :interband_berry_curvature,
        :conventional,
        :kslice,
        :interband_berry_curvature_kslice,
        EXECUTOR_KSLICE_CONVENTIONAL,
        MATRIX_CONVENTIONAL_INTERBAND_GEOMETRY,
        BAND_INTERBAND_GROUPS,
        OUTPUT_KSLICE_INTERBAND_REAL,
        FOURIER_CONVENTIONAL_GEOMETRY,
        2,
        "ibck",
    ),
    _task_definition(
        :interband_quantum_metric,
        :conventional,
        :kslice,
        :interband_quantum_metric_kslice,
        EXECUTOR_KSLICE_CONVENTIONAL,
        MATRIX_CONVENTIONAL_INTERBAND_GEOMETRY,
        BAND_INTERBAND_GROUPS,
        OUTPUT_KSLICE_INTERBAND_REAL,
        FOURIER_CONVENTIONAL_GEOMETRY,
        2,
        "iqmk",
    ),
    _task_definition(
        :zeeman_interband_berry_curvature,
        :conventional,
        :kslice,
        :zeeman_interband_berry_curvature_kslice,
        EXECUTOR_KSLICE_CONVENTIONAL,
        MATRIX_CONVENTIONAL_ZEEMAN_INTERBAND_GEOMETRY,
        BAND_INTERBAND_GROUPS,
        OUTPUT_KSLICE_INTERBAND_REAL,
        FOURIER_SPIN,
        2,
        "zibck";
        requires_spin = true,
    ),
    _task_definition(
        :zeeman_interband_quantum_metric,
        :conventional,
        :kslice,
        :zeeman_interband_quantum_metric_kslice,
        EXECUTOR_KSLICE_CONVENTIONAL,
        MATRIX_CONVENTIONAL_ZEEMAN_INTERBAND_GEOMETRY,
        BAND_INTERBAND_GROUPS,
        OUTPUT_KSLICE_INTERBAND_REAL,
        FOURIER_SPIN,
        2,
        "ziqmk";
        requires_spin = true,
    ),
    _task_definition(
        :quantum_metric_dipole,
        :conventional,
        :kslice,
        :quantum_metric_dipole_kslice,
        EXECUTOR_KSLICE_CONVENTIONAL,
        MATRIX_CONVENTIONAL_QUANTUM_METRIC_DIPOLE,
        BAND_TARGET_GROUP,
        OUTPUT_KSLICE_GROUP_REAL,
        FOURIER_HIGH_ORDER,
        3,
        "qmdk",
    ),
    _task_definition(
        :quantum_metric_quadrupole,
        :conventional,
        :kslice,
        :quantum_metric_quadrupole_kslice,
        EXECUTOR_KSLICE_CONVENTIONAL,
        MATRIX_CONVENTIONAL_QUANTUM_METRIC_QUADRUPOLE,
        BAND_TARGET_GROUP,
        OUTPUT_KSLICE_GROUP_REAL,
        FOURIER_HIGH_ORDER,
        4,
        "qmqk",
    ),
    _task_definition(
        :quantum_christoffel_symbol,
        :conventional,
        :kslice,
        :quantum_christoffel_symbol_kslice,
        EXECUTOR_KSLICE_CONVENTIONAL,
        MATRIX_CONVENTIONAL_QUANTUM_CHRISTOFFEL,
        BAND_TARGET_GROUP,
        OUTPUT_KSLICE_GROUP_REAL,
        FOURIER_HIGH_ORDER,
        3,
        "qcsk",
    ),
    _task_definition(
        :triple_phase_product,
        :conventional,
        :kslice,
        :triple_phase_product_kslice,
        EXECUTOR_KSLICE_CONVENTIONAL,
        MATRIX_CONVENTIONAL_TRIPLE_PHASE_PRODUCT,
        BAND_TRIPLE_GROUPS,
        OUTPUT_KSLICE_COMPLEX,
        FOURIER_CONVENTIONAL_GEOMETRY,
        3,
        "tppk",
    ),
    (
        _task_definition(
            :photon_drag_shift_current,
            :geometric_loop,
            calculation,
            calculation == :integral ? :photon_drag_shift_current_integral :
            :photon_drag_shift_current_kslice,
            calculation == :integral ? EXECUTOR_INTEGRAL_GEOMETRIC_LOOP :
            EXECUTOR_KSLICE_GEOMETRIC_LOOP,
            MATRIX_GEOMETRIC_SHIFT_CURRENT_FINITE_Q,
            BAND_PAIR,
            calculation == :integral ? OUTPUT_INTEGRAL : OUTPUT_KSLICE_COMPLEX,
            FOURIER_GEOMETRIC_FINITE_Q,
            3,
            calculation == :integral ? "pdsc" : "pdsck";
            requires_finite_q = true,
        ) for calculation in (:integral, :kslice)
    )...,
    (
        _task_definition(
            :shift_vector,
            method,
            :kslice,
            :shift_vector_kslice,
            method == :geometric_loop ? EXECUTOR_KSLICE_GEOMETRIC_LOOP :
            EXECUTOR_KSLICE_WILSON_LOOP,
            method == :geometric_loop ? MATRIX_GEOMETRIC_SHIFT_VECTOR : MATRIX_WILSON_SHIFT_VECTOR,
            BAND_PAIR,
            OUTPUT_KSLICE_COMPLEX,
            method == :geometric_loop ? FOURIER_GEOMETRIC_Q0 : FOURIER_WILSON,
            3,
            "svk",
        ) for method in (:geometric_loop, :wilson_loop)
    )...,
    (
        _task_definition(
            :injection_current,
            :conventional,
            calculation,
            calculation == :integral ? :injection_current_integral : :injection_current_kslice,
            calculation == :integral ? EXECUTOR_INTEGRAL_CONVENTIONAL :
            EXECUTOR_KSLICE_CONVENTIONAL,
            MATRIX_CONVENTIONAL_INJECTION_CURRENT,
            BAND_PAIR,
            calculation == :integral ? OUTPUT_INTEGRAL : OUTPUT_KSLICE_COMPLEX,
            FOURIER_CONVENTIONAL_Q0,
            3,
            calculation == :integral ? "ic" : "ick",
        ) for calculation in (:integral, :kslice)
    )...,
    (
        _task_definition(
            :injection_spin_current,
            :conventional,
            calculation,
            calculation == :integral ? :injection_spin_current_integral :
            :injection_spin_current_kslice,
            calculation == :integral ? EXECUTOR_INTEGRAL_CONVENTIONAL :
            EXECUTOR_KSLICE_CONVENTIONAL,
            MATRIX_CONVENTIONAL_INJECTION_SPIN_CURRENT,
            BAND_PAIR,
            calculation == :integral ? OUTPUT_INTEGRAL : OUTPUT_KSLICE_COMPLEX,
            FOURIER_SPIN,
            4,
            calculation == :integral ? "isc" : "isck";
            requires_spin = true,
        ) for calculation in (:integral, :kslice)
    )...,
    (
        _task_definition(
            :shift_spin_current,
            :conventional,
            calculation,
            calculation == :integral ? :shift_spin_current_integral : :shift_spin_current_kslice,
            calculation == :integral ? EXECUTOR_INTEGRAL_CONVENTIONAL :
            EXECUTOR_KSLICE_CONVENTIONAL,
            MATRIX_CONVENTIONAL_SHIFT_SPIN_CURRENT,
            BAND_PAIR,
            calculation == :integral ? OUTPUT_INTEGRAL : OUTPUT_KSLICE_COMPLEX,
            FOURIER_SPIN,
            4,
            calculation == :integral ? "ssc" : "ssck";
            requires_spin = true,
        ) for calculation in (:integral, :kslice)
    )...,
    (
        _task_definition(
            :photon_drag_injection_current,
            :conventional,
            calculation,
            calculation == :integral ? :photon_drag_injection_current_integral :
            :photon_drag_injection_current_kslice,
            calculation == :integral ? EXECUTOR_INTEGRAL_CONVENTIONAL :
            EXECUTOR_KSLICE_CONVENTIONAL,
            MATRIX_PHOTON_DRAG_INJECTION_CURRENT,
            BAND_PAIR,
            calculation == :integral ? OUTPUT_INTEGRAL : OUTPUT_KSLICE_COMPLEX,
            FOURIER_GEOMETRIC_FINITE_Q,
            3,
            calculation == :integral ? "pdic" : "pdick";
            requires_finite_q = true,
        ) for calculation in (:integral, :kslice)
    )...,
)

# Build one immutable short-label definition.
function _quantity_short_label_definition(
    quantity::Symbol,
    calculation::Symbol,
    label::AbstractString,
)
    return (
        quantity = quantity_id(quantity),
        calculation = calculation_id(calculation),
        label = String(label),
    )
end

const QUANTITY_SHORT_LABELS = (
    _quantity_short_label_definition(:band_structure, :kpath, "BAND"),
    _quantity_short_label_definition(:shift_current, :integral, "SC"),
    _quantity_short_label_definition(:photon_drag_shift_current, :integral, "PDSC"),
    _quantity_short_label_definition(:injection_current, :integral, "IC"),
    _quantity_short_label_definition(:injection_spin_current, :integral, "ISC"),
    _quantity_short_label_definition(:shift_spin_current, :integral, "SSC"),
    _quantity_short_label_definition(:photon_drag_injection_current, :integral, "PDIC"),
    _quantity_short_label_definition(:shift_current, :kslice, "SCK"),
    _quantity_short_label_definition(:quantum_hermitian_connection, :kslice, "QHCK"),
    _quantity_short_label_definition(:hermitian_curvature_tensor, :kslice, "HCTK"),
    _quantity_short_label_definition(:berry_curvature, :kslice, "BCK"),
    _quantity_short_label_definition(:berry_curvature_dipole, :kslice, "BCDK"),
    _quantity_short_label_definition(:berry_curvature_quadrupole, :kslice, "BCQK"),
    _quantity_short_label_definition(:quantum_metric, :kslice, "QMK"),
    _quantity_short_label_definition(:interband_berry_curvature, :kslice, "IBCK"),
    _quantity_short_label_definition(:interband_quantum_metric, :kslice, "IQMK"),
    _quantity_short_label_definition(:zeeman_interband_berry_curvature, :kslice, "ZIBCK"),
    _quantity_short_label_definition(:zeeman_interband_quantum_metric, :kslice, "ZIQMK"),
    _quantity_short_label_definition(:quantum_metric_dipole, :kslice, "QMDK"),
    _quantity_short_label_definition(:quantum_metric_quadrupole, :kslice, "QMQK"),
    _quantity_short_label_definition(:quantum_christoffel_symbol, :kslice, "QCSK"),
    _quantity_short_label_definition(:triple_phase_product, :kslice, "TPPK"),
    _quantity_short_label_definition(:photon_drag_shift_current, :kslice, "PDSCK"),
    _quantity_short_label_definition(:shift_vector, :kslice, "SVK"),
    _quantity_short_label_definition(:injection_current, :kslice, "ICK"),
    _quantity_short_label_definition(:injection_spin_current, :kslice, "ISCK"),
    _quantity_short_label_definition(:shift_spin_current, :kslice, "SSCK"),
    _quantity_short_label_definition(:photon_drag_injection_current, :kslice, "PDICK"),
)

# Find a short-label definition from user input.
function quantity_short_label_definition(value::AbstractString)
    key = replace(_canonical_key(value), "_" => "")
    for definition in QUANTITY_SHORT_LABELS
        lowercase(definition.label) == key && return definition
    end
    return nothing
end

# Find the short label for one registered quantity and calculation.
function _find_quantity_short_label(quantity::Symbol, calculation::Symbol)
    quantity_value = quantity_id(quantity)
    calculation_value = calculation_id(calculation)
    for definition in QUANTITY_SHORT_LABELS
        if definition.quantity == quantity_value && definition.calculation == calculation_value
            return definition.label
        end
    end
    return nothing
end

# Return the short label for one registered quantity and calculation.
function quantity_short_label(quantity::Symbol, calculation::Symbol)
    label = _find_quantity_short_label(quantity, calculation)
    label === nothing && error(
        "No short label for quantity=$(canonical_quantity_name(quantity)), calculation=$(canonical_calculation_name(calculation)).",
    )
    return label
end

# Validate the complete short-label registry against registered tasks and output suffixes.
function validate_quantity_short_label_registry()
    registered_pairs =
        Set((definition.quantity, definition.calculation) for definition in TASK_DEFINITIONS)
    label_pairs =
        [(definition.quantity, definition.calculation) for definition in QUANTITY_SHORT_LABELS]
    length(label_pairs) == length(unique(label_pairs)) ||
        error("Quantity short-label registry contains duplicate quantity/calculation pairs.")
    Set(label_pairs) == registered_pairs ||
        error("Quantity short-label registry does not cover the registered task surface.")

    labels = [definition.label for definition in QUANTITY_SHORT_LABELS]
    normalized_labels = [replace(_canonical_key(label), "_" => "") for label in labels]
    length(normalized_labels) == length(unique(normalized_labels)) ||
        error("Quantity short-label registry contains duplicate labels.")

    for label_definition in QUANTITY_SHORT_LABELS
        calculation = calculation_symbol(label_definition.calculation)
        if calculation == :kslice
            endswith(label_definition.label, "K") ||
                error("K-slice short label must end in K: $(label_definition.label).")
        end
        suffixes = unique([
            definition.observable_suffix for definition in TASK_DEFINITIONS if
            definition.quantity == label_definition.quantity &&
            definition.calculation == label_definition.calculation
        ])
        length(suffixes) == 1 || error(
            "Registered task methods disagree on observable suffix for label=$(label_definition.label).",
        )
        lowercase(label_definition.label) == only(suffixes) || error(
            "Short label $(label_definition.label) does not match observable suffix $(only(suffixes)).",
        )
    end
    return nothing
end

validate_quantity_short_label_registry()

# Look up the registered quantity/method/calculation combination, returning nothing when it is unsupported.
function task_definition(quantity::Symbol, method::Symbol, calculation::Symbol)
    quantity_value = quantity_id(quantity)
    method_value = method_id(method)
    calculation_value = calculation_id(calculation)
    for definition in TASK_DEFINITIONS
        if definition.quantity == quantity_value &&
           definition.method == method_value &&
           definition.calculation == calculation_value
            return definition
        end
    end
    return nothing
end

# List registry-supported methods for a quantity/calculation combination in the registry's stable order.
function registry_supported_methods(quantity::Symbol, calculation::Symbol)
    quantity_value = quantity_id(quantity)
    calculation_value = calculation_id(calculation)
    methods = Symbol[]
    for definition in TASK_DEFINITIONS
        if definition.quantity == quantity_value && definition.calculation == calculation_value
            method = method_symbol(definition.method)
            method in methods || push!(methods, method)
        end
    end
    return methods
end

# Choose the report label for a task's matrix policy, including finite-momentum configuration where required.
function matrix_family_label(definition::TaskDefinition, cfg::EffectiveTaskConfig)
    policy = definition.matrix_policy
    return policy == MATRIX_CONVENTIONAL_Q0_CURRENT ? "conventional_q0_current" :
           policy == MATRIX_SPECTRUM ? "spectrum" :
           policy == MATRIX_CONVENTIONAL_INJECTION_CURRENT ? "conventional_q0_current" :
           policy == MATRIX_CONVENTIONAL_INJECTION_SPIN_CURRENT ? "conventional_q0_current" :
           policy == MATRIX_CONVENTIONAL_SHIFT_SPIN_CURRENT ? "conventional_q0_current" :
           policy == MATRIX_CONVENTIONAL_QHC ? "conventional_geometry_qhc" :
           policy == MATRIX_CONVENTIONAL_HCT ? "conventional_hermitian_curvature_tensor" :
           policy == MATRIX_CONVENTIONAL_BERRY_CURVATURE ? "conventional_berry_curvature" :
           policy == MATRIX_CONVENTIONAL_BERRY_CURVATURE_DIPOLE ?
           "conventional_berry_curvature_dipole" :
           policy == MATRIX_CONVENTIONAL_BERRY_CURVATURE_QUADRUPOLE ?
           "conventional_berry_curvature_quadrupole" :
           policy == MATRIX_CONVENTIONAL_QUANTUM_METRIC ? "conventional_quantum_metric" :
           policy == MATRIX_CONVENTIONAL_INTERBAND_GEOMETRY ?
           "conventional_interband_quantum_geometry" :
           policy == MATRIX_CONVENTIONAL_ZEEMAN_INTERBAND_GEOMETRY ?
           "conventional_zeeman_interband_quantum_geometry" :
           policy == MATRIX_CONVENTIONAL_QUANTUM_METRIC_DIPOLE ?
           "conventional_quantum_metric_dipole" :
           policy == MATRIX_CONVENTIONAL_QUANTUM_METRIC_QUADRUPOLE ?
           "conventional_quantum_metric_quadrupole" :
           policy == MATRIX_CONVENTIONAL_QUANTUM_CHRISTOFFEL ? "conventional_quantum_christoffel" :
           policy == MATRIX_CONVENTIONAL_TRIPLE_PHASE_PRODUCT ?
           "conventional_triple_phase_product" :
           policy == MATRIX_PROJECTOR_SHIFT_CURRENT ? "projector_response_shift_current" :
           policy == MATRIX_PROJECTOR_QHC ? "projector_response_qhc" :
           policy == MATRIX_GEOMETRIC_SHIFT_CURRENT_Q0 ? "geometric_loop_shift_current_q0" :
           policy == MATRIX_GEOMETRIC_SHIFT_CURRENT_FINITE_Q ?
           "geometric_loop_shift_current_q=$(cfg.photon_momentum)" :
           policy == MATRIX_GEOMETRIC_QHC ? "geometric_loop_qhc_q=$(cfg.photon_momentum)" :
           policy == MATRIX_GEOMETRIC_SHIFT_VECTOR ?
           "geometric_loop_shift_vector_q=$(cfg.photon_momentum)" :
           policy == MATRIX_WILSON_SHIFT_CURRENT ? "wilson_loop_response_shift_current_q0" :
           policy == MATRIX_WILSON_QHC ? "wilson_loop_response_qhc_q0" :
           policy == MATRIX_WILSON_SHIFT_VECTOR ? "wilson_loop_response_shift_vector_q0" :
           policy == MATRIX_PHOTON_DRAG_INJECTION_CURRENT ?
           "conventional_finite_q_photon_drag_injection" :
           error("No matrix-family label for policy=$(policy).")
end

# Validate and copy tensor axes into the fixed tuple for a registered task, retaining its explicit rank and policy fields.
function normalized_task_plan(spec::NormalizedTaskSpec, tensor_indices::AbstractVector{<:Integer})
    definition = task_definition(spec.quantity, spec.method, spec.calculation)
    definition === nothing && error("Missing TaskDefinition for $(spec.label).")
    rank = Int(definition.tensor_rank)
    length(tensor_indices) == rank ||
        error("Task plan for $(spec.label) expected $(rank) tensor indices, got $(tensor_indices).")
    fixed_indices = ntuple(index -> index <= rank ? Int(tensor_indices[index]) : 0, 4)
    return NormalizedTaskPlan(
        definition,
        fixed_indices,
        definition.tensor_rank,
        definition.band_policy,
        definition.output_policy,
        definition.fourier_policy,
    )
end
