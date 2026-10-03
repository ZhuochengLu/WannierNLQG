# Literal compiler-only append contract; never executes a target.
function type_operand(x)
    x isa Union{Symbol, QuoteNode, LineNumberNode, Number, String} && return true
    x isa Expr || return false
    if x.head==:call
        x==Meta.parse("Base.Core.AddrSpace{Base.Core}(0x00)") && return true
        length(x.args)==2 && x.args[1]==:typeof || return false
        return name_operand(x.args[2])
    end
    x.head in (:curly, :where, :., :quote, :tuple, :braces, :(<:), :(>:)) || return false
    all(type_operand, x.args)
end
name_operand(
    x,
)=x isa Symbol ||
  x isa QuoteNode ||
  (x isa Expr && x.head==:quote && length(x.args)==1 && x.args[1] isa Symbol) ||
  (x isa Expr && x.head==:. && all(a->a isa QuoteNode || name_operand(a), x.args))
function compile_append(text, flag)
    parsed=Meta.parseall(text);
    count=0
    block_index=0
    expected_flags=flag isa String ? [flag] : flag
    for macro_node in parsed.args
        macro_node isa LineNumberNode && continue
        macro_node isa Expr &&
        macro_node.head==:macrocall &&
        macro_node.args[1]==Symbol("@compile_workload") || error("APPEND_NOT_COMPILE_WORKLOAD")
        block=macro_node.args[end]
        block isa Expr && block.head==:block || error("WORKLOAD_NOT_BLOCK")
        children=filter(x->!(x isa LineNumberNode), block.args)
        length(children)==1 || error("WORKLOAD_EXTRA_STATEMENT")
        block_index+=1
        block_index<=length(expected_flags) || error("EXTRA_WORKLOAD_BLOCK")
        branch=only(children)
        branch isa Expr &&
        branch.head==:if &&
        length(branch.args)==2 &&
        branch.args[1]==Meta.parse(expected_flags[block_index]) || error("WORKLOAD_GUARD_CHANGED")
        body=branch.args[2];
        body isa Expr && body.head==:block || error("GUARD_NOT_BLOCK")
        for call in body.args
            call isa LineNumberNode && continue
            call isa Expr &&
            call.head==:call &&
            length(call.args)==2 &&
            call.args[1]==:precompile || error("NOT_LITERAL_PRECOMPILE")
            operand=call.args[2]
            operand isa Expr &&
            operand.head==:curly &&
            operand.args[1]==:Tuple &&
            type_operand(operand) || error("NON_LITERAL_TYPE_OPERAND: $(operand)")
            count+=1
        end
    end
    block_index==length(expected_flags) || error("WORKLOAD_BLOCK_COUNT")
    count>0 || error("NO_DECLARATIONS")
    count
end
