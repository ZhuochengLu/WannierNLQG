"""Small fixture definitions compared as actual data, never through a certificate."""
module NativeDefinitionTestSupport
using WannierNLQG
export native_definition_bytes

function native_definition_bytes(input)
    buffer = IOBuffer()
    WannierNLQG.IO.write_native_model_definition(buffer, input)
    return take!(buffer)
end
end
