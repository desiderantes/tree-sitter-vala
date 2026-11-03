function comma_sep1(rule) {
  return seq(rule, repeat(seq(',', rule)));
}

function comma_sep(rule) {
  return optional(comma_sep1(rule));
}

function comma_sep1_trailing(rule) {
  return seq(rule, repeat(seq(',', rule)), optional(','));
}

function comma_sep_trailing(rule) {
  return optional(comma_sep1_trailing(rule));
}

module.exports = grammar({
  name: 'vala',

  word: $ => $.identifier,

  rules: {
    source_file: $ => seq(repeat($.using_directive), repeat(choice($.namespace_member, $._statement))),

    // taken from tree-sitter-c
    // http://stackoverflow.com/questions/13014947/regex-to-match-a-c-style-multiline-comment/36328890#36328890
    comment: $ => token(prec(1, choice(
      seq('//', /(\\(.|\r?\n)|[^\\\n])*/),
      seq(
        '/*',
        /[^*]*\*+([^/*][^*]*\*+)*/,
        '/'
      )
    ))),

    using_directive: $ => seq(
      'using',
      comma_sep1($.symbol),
      ';'
    ),

    symbol: $ => choice(
      seq($.symbol, '.', $.identifier),
      seq(optional('global::'), $.identifier)
    ),

    identifier: $ => /[@A-Za-z_]\w*/,

    namespace_member: $ => seq(
      repeat($._attribute_list),
      choice(
        $.namespace_declaration,
        $.class_declaration,
        $.interface_declaration,
        $.struct_declaration,
        $.enum_declaration,
        $.errordomain_declaration,
        $.delegate_declaration,
        $.method_declaration,
        $.signal_declaration,
        $.field_declaration,
        $.constant_declaration
      )
    ),

    _attribute_list: $ => seq(
      '[',
      comma_sep1($.attribute),
      ']'
    ),

    attribute: $ => seq(
      $.identifier,
      optional($.attribute_argument_list)
    ),

    attribute_argument_list: $ => seq(
      '(',
      comma_sep($.attribute_argument),
      ')'
    ),

    attribute_argument: $ => seq(
      $.identifier,
      '=',
      $._expression
    ),

    _expression: $ => choice(
        $._contained_expression,
        $.initializer,
        $.yield_expression,
        $.lambda_expression,
        $.static_cast_expression,
        $._unary_expression,
        $.multiplicative_expression,
        $.arithmetic_expression,
        $.in_expression,
        $.bitshift_expression,
        $.dynamic_cast_expression,
        $.type_relational_expression,
        $.relational_expression,
        $.equality_expression,
        $.bitwise_and_expression,
        $.bitwise_xor_expression,
        $.bitwise_or_expression,
        $.logical_and_expression,
        $.logical_or_expression,
        $.null_coalescing_expression,
        $.ternary_expression,
        $.assignment_expression
    ),

    // expressions that never need to be wrapped in parentheses
    _contained_expression: $ => choice(
        seq('(', $._expression, ')'),
        $.literal,
        $.array_creation_expression,
        $.object_creation_expression,
        $.this_access,
        $.base_access,
        $.value_access,
        $.member_access_expression,
        $.element_access_expression,
        $.method_call_expression,
        $.sizeof_expression,
        $.typeof_expression,
        $.postfix_expression,
    ),

    // expressions that are contained by an operator to the left
    // for example:
    // if (!yield x())
    //      ^^^^^^^^^ -- we don't need parens here because of the '!' operator
    _left_contained_expression: $ => choice(
        $._contained_expression,
        $.yield_expression,
        $.static_cast_expression,
        $._unary_expression
    ),

    member_access_expression: $ => seq(
      optional(seq(
        $._contained_expression,
        choice('.', '?.', '->'),
      )),
      $.identifier
    ),

    element_access_expression: $ => seq(
      $._contained_expression,
      repeat1($.element_access)
    ),

    element_access: $ => seq(
      '[',
      comma_sep1(choice($._expression, $.slice_expression)),
      ']'
    ),

    slice_expression: $ => choice(
      seq($._expression, ':', optional($._expression)),
      seq(':', optional($._expression))
    ),

    argument: $ => choice(
      seq('ref', $._expression),
      seq('out', $._expression),
      $._expression,
      seq($.identifier, ':', $._expression)
    ),

    method_call_expression: $ => seq(
      field('function', choice(
        seq('(', $._expression, ')'),
        seq($.member_access_expression, optional($.type_arguments)),
        $._contained_expression
      )),
      '(',
      comma_sep(field('argument', $.argument)),
      ')',
      optional(field('initializer', $.object_initializers))
    ),

    yield_expression: $ => seq('yield', $._expression),

    lambda_expression: $ => seq(
      choice(
        $.identifier,
        seq('(', comma_sep($.identifier), ')')
      ),
      '=>',
      choice($._expression, $.block)
    ),

    postfix_expression: $ => prec.left(15, seq($._expression, choice('++', '--'))),
    static_cast_expression: $ => prec.right(14, seq('(', choice($.type, '!', 'owned'), ')', $._expression)),
    typeof_expression: $ => prec.right(14, seq('typeof', '(', $.type, ')')),
    sizeof_expression: $ => prec.right(14, seq('sizeof', '(', $.type, ')')),
    dereferencing_expression: $ => prec.right(14, seq('*', $._left_contained_expression)),
    addressof_expression: $ => prec.right(14, seq('&', $._left_contained_expression)),
    unary_plus_expression: $ => prec.right(14, seq('+', $._left_contained_expression)),
    arithmetic_negation_expression: $ => prec.right(14, seq('-', $._left_contained_expression)),
    prefix_expression: $ => prec.right(14, seq(choice('++', '--'), $._left_contained_expression)),
    bitwise_negation_expression: $ => prec.right(14, seq('~', $._left_contained_expression)),
    logical_negation_expression: $ => prec.right(14, seq(choice('!', 'not'), $._left_contained_expression)),
    _unary_expression: $ => prec.right(14, choice(
        $.dereferencing_expression,
        $.addressof_expression,
        $.unary_plus_expression,
        $.arithmetic_negation_expression,
        $.prefix_expression,
        $.bitwise_negation_expression,
        $.logical_negation_expression
    )),
    multiplicative_expression: $ => prec.left(13, seq($._expression, choice('*', '/', '%'), $._expression)),
    arithmetic_expression: $ => prec.left(12, seq($._expression, choice('+', '-'), $._expression)),
    bitshift_expression: $ => prec.left(11, seq($._expression, choice('<<', '>>'), $._expression)),
    in_expression: $ => prec.left(10, seq($._expression, optional('not'), 'in', $._expression)),
    dynamic_cast_expression: $ => prec.left(10, seq($._expression, 'as', $.type)),
    type_relational_expression: $ => prec.left(10, seq($._expression, 'is', optional('not'), $.type)),
    relational_expression: $ => prec.left(10, seq($._expression, choice('<', '<=', '>=', '>'), $._expression)),
    equality_expression: $ => prec.left(9, seq($._expression, choice('==', '!='), $._expression)),
    bitwise_and_expression: $ => prec.left(8, seq($._expression, '&', $._expression)),
    bitwise_xor_expression: $ => prec.left(7, seq($._expression, '^', $._expression)),
    bitwise_or_expression: $ => prec.left(6, seq($._expression, '|', $._expression)),
    logical_and_expression: $ => prec.left(5, seq($._expression, choice('&&', 'and'), $._expression)),
    logical_or_expression: $ => prec.left(4, seq($._expression, choice('||', 'or'), $._expression)),
    null_coalescing_expression: $ => prec.left(3, seq($._expression, '??', $._expression)),
    ternary_expression: $ => prec.right(2, seq($._expression, '?', $._expression, ':', $._expression)),

    _assignment_operator: $ => choice('=', '+=', '-=', '|=', '&=', '^=', '/=', '*=', '%=', '<<=', '>>='),
    assignment_expression: $ => prec.right(1, seq(field('left', $._expression), field('operator', $._assignment_operator), field('right', $._expression))),

    this_access: $ => 'this',

    base_access: $ => 'base',

    value_access: $ => 'value',

    array_creation_expression: $ => seq(
      'new',
      field('type', $.type),
      field('size', $.inline_array_type),
      optional(field('initializer', $.initializer))
    ),

    object_creation_expression: $ => seq(
      'new',
      field('type', $.type),
      optional(seq('.', field('constructor', $.identifier))),
      '(',
      comma_sep(field('argument', $.argument)),
      ')',
      optional(field('initializer', $.object_initializers))
    ),

    object_initializers: $ => seq(
      '{',
      comma_sep_trailing($.member_initializer),
      '}'
    ),

    member_initializer: $ => seq(
      $.identifier,
      '=',
      $._expression
    ),

    initializer: $ => seq(
      '{',
      comma_sep_trailing($.argument),
      '}'
    ),

    boolean: $ => choice('true', 'false'),
    character: $ => token(seq(
      "'",
      choice(
        /[^'\\\n]/,
        /\\([abefnrtv\\\x27"?0$ ]|[0-7]{1,3}|[xX][0-9a-fA-F]+|[uU][0-9a-fA-F]+|.)/
      ),
      "'"
    )),
    integer: $ => token(seq(
      choice(
        /0[xX][0-9a-fA-F]+/,
        /0[bB][01]+/,
        /0[oO][0-7]+/,
        /[0-9]+/
      ),
      optional(choice(
        /[uU][lL]{0,2}/,
        /[lL]{1,2}[uU]?/
      ))
    )),
    null: $ => 'null',
    real: $ => token(choice(
      /0[xX][0-9a-fA-F]*(\.[0-9a-fA-F]+)?[pP][+-]?[0-9]+[fFdD]?/,
      /([0-9]+\.[0-9]+([eE][+-]?[0-9]+)?|[0-9]+[eE][+-]?[0-9]+)[fFdD]?/,
      /[0-9]+[fFdD]/
    )),
    regex: $ => /\/([^/\\\n]|\\.)+\/[imsxog]*/,
    string: $ => seq(
      '"',
      repeat(choice(
        token(prec(2, /[^"%\\]+/)),
        $.escape_sequence,
        /\\[^abefnrtv\\\x27"?0$ xXuU]/,
        $.string_formatter,
        /%[^$#0\- +'I\d\\.hlqLjzZtdiouxXeEfFgGaAcsCSpnm%"]/
      )),
      token(prec(2, '"'))
    ),
    escape_sequence: $ => token(/\\([abefnrtv\\\x27"?0$ ]|[0-7]{1,3}|[xX][0-9a-fA-F]+|[uU][0-9a-fA-F]{4,8})/),
    string_formatter: $ => /%\$?[#0\- +'I]?\d*(\.\d+)?(hh?|ll?|q|L|j|z|Z|t)?[diouxXeEfFgGaAcsCSpnm%]?/,
    template_string: $ => seq(
      '@"',
      repeat(choice(
        token(prec(2, /([^$"\\]|\\.)+/)),
        $.template_string_expression,
        '$$'
      )),
      token(prec(2, '"'))
    ),
    template_string_expression: $ => choice(
      seq('$(', $._expression, ')'),
      seq('$', $.identifier)
    ),
    verbatim_string: $ => token(seq(
      '"""',
      repeat(choice(
        /[^"]+/,
        /"[^"]/,
        /""[^"]/
      )),
      '"""'
    )),

    literal: $ => choice(
        $.boolean,
        $.null,
        $.character,
        $.integer,
        $.real,
        $.regex,
        $.string,
        $.template_string,
        $.verbatim_string
    ),

    type: $ => choice(
      'var',
      seq(
        optional('dynamic'),
        optional(choice('unowned', 'owned', 'weak')),
        choice(
          seq('void', repeat('*')),
          seq(
            $.symbol,
            optional($.type_arguments),
            repeat('*'),
            optional('?')
          )
        ),
        repeat($.array_type)
      ),
      seq(
        optional('dynamic'),
        optional(choice('unowned', 'owned', 'weak')),
        '(',
        $.type,
        ')',
        repeat($.array_type)
      )
    ),

    unqualified_type: $ => seq(
      $.symbol,
      optional($.type_arguments)
    ),

    type_arguments: $ => seq(
      '<',
      comma_sep1($.type),
      '>'
    ),

    array_type: $ => seq(
      '[',
      choice(
        repeat1(','),
        seq(
          optional(comma_sep1($._expression)),
          optional(seq(':', $.type))
        )
      ),
      ']',
      optional('?')
    ),

    array_size: $ => comma_sep1($._expression),

    member_declaration_modifier: $ => choice(
      $.access_modifier,
      'async',
      'class',
      'extern',
      'inline',
      'static',
      'abstract',
      'virtual',
      'override',
      'sealed',
      'new'
    ),

    access_modifier: $ => choice(
      'private',
      'protected',
      'internal',
      'public'
    ),

    namespace_declaration: $ => seq(
      'namespace',
      field('name', $.symbol),
      '{',
      repeat($.using_directive),
      repeat($.namespace_member),
      '}'
    ),

    type_declaration_modifier: $ => choice(
      $.access_modifier,
      'partial',
      'abstract',
      'sealed',
      'extern',
      'static'
    ),

    class_declaration: $ => seq(
      repeat(field('modifier', $.type_declaration_modifier)),
      'class',
      field('name', $.unqualified_type),
      optional(seq(':', comma_sep1(field('base_type', $.type)))),
      '{',
      repeat(field('member', $.class_member)),
      '}'
    ),

    class_member: $ => seq(
      repeat($._attribute_list),
      choice(
        $.class_declaration,
        $.interface_declaration,
        $.struct_declaration,
        $.enum_declaration,
        $.delegate_declaration,
        $.method_declaration,
        $.creation_method_declaration,
        $.signal_declaration,
        $.field_declaration,
        $.constant_declaration,
        $.property_declaration,
        $.constructor_declaration,
        $.destructor_declaration
      ),
    ),

    interface_declaration: $ => seq(
      repeat(field('modifier', $.type_declaration_modifier)),
      'interface',
      field('name', $.unqualified_type),
      optional(seq(':', comma_sep1(field('base_type', $.type)))),
      '{',
      repeat(field('member', $.interface_member)),
      '}'
    ),

    interface_member: $ => seq(
      repeat($._attribute_list),
      choice(
        $.class_declaration,
        $.interface_declaration,
        $.struct_declaration,
        $.enum_declaration,
        $.delegate_declaration,
        $.method_declaration,
        $.signal_declaration,
        $.field_declaration,
        $.constant_declaration,
        $.property_declaration
      )
    ),

    struct_declaration: $ => seq(
      repeat(field('modifier', $.type_declaration_modifier)),
      'struct',
      field('name', $.unqualified_type),
      optional(seq(':', comma_sep1(field('base_type', $.type)))),
      '{',
      repeat(field('member', $.struct_member)),
      '}'
    ),

    struct_member: $ => seq(
      repeat($._attribute_list),
      choice(
        $.method_declaration,
        $.creation_method_declaration,
        $.field_declaration,
        $.constant_declaration,
        $.property_declaration
      )
    ),

    enum_declaration: $ => seq(
      repeat(field('modifier', $.type_declaration_modifier)),
      'enum',
      field('name', $.symbol),
      '{',
      comma_sep1(field('value', $.enum_value)),
      optional(choice(
        ',',    // support trailing ','
        seq(';', repeat(seq(
          repeat($._attribute_list),
          choice($.method_declaration, $.constant_declaration)
        )))
      )),
      '}'
    ),

    enum_value: $ => seq(
      repeat($._attribute_list),
      field('name', $.identifier),
      optional(seq('=', field('value', $._expression)))
    ),

    errordomain_declaration: $ => seq(
      repeat(field('modifier', $.type_declaration_modifier)),
      'errordomain',
      field('name', $.symbol),
      '{',
      comma_sep1(field('value', $.errorcode)),
      optional(choice(
        ',',    // support trailing ','
        seq(';', repeat(seq(repeat($._attribute_list), $.method_declaration)))
      )),
      '}'
    ),

    errorcode: $ => seq(
      repeat($._attribute_list),
      field('name', $.identifier),
      optional(seq('=', field('value', $._expression)))
    ),

    parameter: $ => seq(
      repeat($._attribute_list),
      choice(
        seq(
          optional('params'),
          optional(field('modifier', choice('out', 'ref'))),
          field('type', $.type),
          field('name', $.identifier),
          optional(field('array_dimension', $.inline_array_type)),
          optional(seq('=', field('default_value', $._expression)))
        ),
        '...'
      )
    ),

    creation_method_declaration: $ => seq(
      repeat(field('modifier', $.member_declaration_modifier)),
      field('name', $.symbol),
      '(',
      comma_sep(field('parameter', $.parameter)),
      ')',
      optional(seq('throws', comma_sep1(field('error_type', $.type)))),
      repeat($.contract_clause),
      field('body', choice($.block, ';'))
    ),

    contract_clause: $ => seq(
      choice('requires', 'ensures'),
      '(',
      field('condition', $._expression),
      ')'
    ),

    delegate_declaration_modifier: $ => choice(
      $.access_modifier,
      'async',
      'class',
      'extern',
      'inline',
      'abstract',
      'virtual',
      'override',
      'static'
    ),

    delegate_declaration: $ => seq(
      repeat(field('modifier', $.delegate_declaration_modifier)),
      'delegate',
      field('type', $.type),
      field('name', $.symbol),
      optional(field('type_arguments', $.type_arguments)),
      '(',
      comma_sep(field('parameter', $.parameter)),
      ')',
      optional(seq('throws', comma_sep1(field('error_type', $.type)))),
      ';'
    ),

    method_declaration: $ => seq(
      repeat(field('modifier', $.member_declaration_modifier)),
      field('type', $.type),
      field('name', $.symbol),
      optional(field('type_arguments', $.type_arguments)),
      '(',
      comma_sep(field('parameter', $.parameter)),
      ')',
      optional(seq('throws', comma_sep1(field('error_type', $.type)))),
      repeat($.contract_clause),
      field('body', choice($.block, ';'))
    ),

    signal_declaration_modifier: $ => choice(
      $.access_modifier,
      'async',
      'extern',
      'inline',
      'abstract',
      'virtual',
      'override',
      'new'
    ),

    signal_declaration: $ => seq(
      repeat(field('modifier', $.signal_declaration_modifier)),
      'signal',
      field('type', $.type),
      field('name', $.symbol),
      '(',
      comma_sep(field('parameter', $.parameter)),
      ')',
      field('body', choice($.block, ';'))
    ),

    field_declaration: $ => seq(
      repeat(field('modifier', $.member_declaration_modifier)),
      field('type', $.type),
      field('name', $.identifier),
      optional(field('array_dimension', $.inline_array_type)),
      optional(seq('=', field('value', $._expression))),
      ';'
    ),

    constant_declaration: $ => seq(
      repeat(field('modifier', $.member_declaration_modifier)),
      'const',
      field('type', $.type),
      field('name', $.identifier),
      optional(field('array_dimension', $.inline_array_type)),
      optional(seq('=', field('value', $._expression))),
      ';'
    ),

    inline_array_type: $ => seq(
      '[',
      choice(
        repeat1(','),
        seq(
          optional(comma_sep1($._expression)),
          optional(seq(':', $.type))
        )
      ),
      ']'
    ),
    
    property_declaration: $ => seq(
      repeat(field('modifier', $.member_declaration_modifier)),
      field('type', $.type),
      field('name', $.symbol),
      '{',
      choice($.property_default, $.property_accessor),
      repeat(choice($.property_default, $.property_accessor)),
      '}'
    ),

    property_default: $ => seq('default', '=', $._expression, ';'),

    property_accessor: $ => seq(
      repeat($._attribute_list),
      optional($.access_modifier),
      choice(
        seq(optional('owned'), 'get'),
        seq(optional('owned'), 'set', optional('construct')),
        seq('construct', optional('set'))
      ),
      choice(';', $.block)
    ),

    constructor_declaration_modifier: $ => choice(
      'async',
      'class',
      'extern',
      'inline',
      'static',
      'abstract',
      'virtual',
      'override'
    ),

    constructor_declaration: $ => seq(
      repeat(field('modifier', $.constructor_declaration_modifier)),
      'construct',
      field('body', $.block)
    ),

    destructor_declaration: $ => seq(
      repeat(field('modifier', $.constructor_declaration_modifier)),
      '~',
      field('name', $.identifier),
      '(', ')',
      field('body', $.block)
    ),

    local_declaration: $ => seq(
      optional('const'),
      field('type', $.type),
      comma_sep1(field('declarator', $.assignment)),
      ';'
    ),

    local_function_declaration: $ => seq(
        repeat(field('modifier', choice('static', 'extern'))),
        field('type', $.type),
        field('name', $.identifier),
        '(',
        comma_sep(field('parameter', $.parameter)),
        ')',
        field('body', $.block)
    ),

    assignment: $ => prec.dynamic(20, seq(
      field('name', $.identifier),
      optional(field('array_dimension', $.inline_array_type)),
      optional(seq('=', field('value', $._expression)))
    )),

    block: $ => seq('{', repeat(choice($._statement, $.local_declaration, $.local_function_declaration)), '}'),

    _statement: $ => choice(
      $.if_statement,
      $._statement_without_if
    ),

    // resolves ambiguities with 'else if'
    _statement_without_if: $ => choice(
      $.block,
      $.empty_statement,
      $.expression_statement,
      $.return_statement,
      $.try_statement,
      $.while_statement,
      $.do_statement,
      $.for_statement,
      $.foreach_statement,
      $.break_statement,
      $.continue_statement,
      $.lock_statement,
      $.delete_statement,
      $.throw_statement,
      $.yield_statement,
      $.switch_statement,
      $.with_statement
    ),

    empty_statement: $ => ';',

    expression_statement: $ => seq($._expression, ';'),

    return_statement: $ => seq('return', optional($._expression), ';'),

    if_statement: $ => seq(
      'if', '(', $._expression, ')',
      $._statement,
      repeat($.elseif_statement),
      optional($.else_statement)
    ),

    elseif_statement: $ => seq(
      'else', 'if', '(', $._expression, ')',
      $._statement
    ),

    else_statement: $ => seq(
      'else',
      $._statement_without_if
    ),

    try_statement: $ => seq(
      'try',
      $.block,
      repeat($.catch_clause),
      optional($.finally_clause)
    ),

    catch_clause: $ => seq(
      'catch',
      optional(seq('(', $.type, $.identifier, ')')),
      $.block
    ),

    finally_clause: $ => seq(
      'finally', $.block
    ),

    while_statement: $ => seq(
      'while',
      '(',
      $._expression,
      ')',
      $._statement
    ),

    do_statement: $ => seq(
      'do',
      $._statement,
      'while',
      '(', $._expression, ')',
      ';'
    ),

    for_statement: $ => seq(
      'for',
      '(',
      optional(choice($.local_declaration, seq($._expression, ';'), ';')),
      optional($._expression),
      ';',
      comma_sep($._expression),
      ')',
      $._statement
    ),

    foreach_statement: $ => seq(
      'foreach',
      '(',
      $.type,
      $.identifier,
      'in',
      $._expression,
      ')',
      $._statement
    ),

    break_statement: $ => seq('break', ';'),

    continue_statement: $ => seq('continue', ';'),

    lock_statement: $ => seq(
      'lock', '(', $._expression, ')',
      $._statement
    ),

    delete_statement: $ => seq(
      'delete', $._expression, ';'
    ),

    throw_statement: $ => seq(
      'throw', $._expression, ';'
    ),

    yield_statement: $ => seq(
      'yield',
      optional(seq('return', $._expression)),
      ';'
    ),

    switch_statement: $ => seq(
      'switch', '(', $._expression, ')',
      '{',
      repeat($.switch_section),
      '}'
    ),

    switch_section: $ => seq(
      choice(
        seq('case', $._expression),
        'default'
      ),
      ':',
      repeat(choice($._statement, $.local_declaration))
    ),

    with_statement: $ => seq(
      'with', '(', $._expression, ')',
      $._statement
    ),

    // --- preprocessor

    _preprocessor_directive_start: $ => /#[\t ]*/,

    _preprocessor_statement: $ => seq(
      $._preprocessor_directive_start,
      choice(
        $.if_directive,
        $.elif_directive,
        $.else_directive,
        $.endif_directive
      ),
      /\r?\n/
    ),

    if_directive: $ => seq('if', field('expression', $._preprocessor_contained_expression)),

    elif_directive: $ => seq('elif', field('expression', $._preprocessor_contained_expression)),

    else_directive: $ => 'else',

    endif_directive: $ => 'endif',

    _preprocessor_expression: $ => choice(
      seq('(', $._preprocessor_contained_expression, ')'),
      $.identifier,
      $.literal
    ),

    _preprocessor_contained_expression: $ => choice(
      $._preprocessor_expression,
      prec.right(4, seq('!', $._preprocessor_contained_expression)),
      prec.left(3, seq($._preprocessor_contained_expression, choice('==', '!='), $._preprocessor_contained_expression)),
      prec.left(2, seq($._preprocessor_contained_expression, '&&', $._preprocessor_contained_expression)),
      prec.left(1, seq($._preprocessor_contained_expression, '||', $._preprocessor_contained_expression)),
    )
  },

  conflicts: $ => [
    [$.member_declaration_modifier, $.class_declaration],               // because both can start with 'class'
    [$.member_declaration_modifier, $.type_declaration_modifier],       // because both share 'extern'
    [$.member_declaration_modifier, $.object_creation_expression],      // because OCEs can appear in the main block
    [$.member_declaration_modifier, $.signal_declaration_modifier],     // both can start with 'new'
    [$.member_declaration_modifier,
     $.type_declaration_modifier,
     $.signal_declaration_modifier],                                    // ambiguity between all three
    [$.member_declaration_modifier, $.delegate_declaration_modifier],   // both can start with 'new'
    [$.member_declaration_modifier, $.delegate_declaration_modifier, $.signal_declaration_modifier],
    [$.member_declaration_modifier, $.type_declaration_modifier, $.delegate_declaration_modifier],
    [$.member_declaration_modifier, $.type_declaration_modifier, $.delegate_declaration_modifier, $.signal_declaration_modifier],
    [$.member_declaration_modifier, $.delegate_declaration_modifier, $.signal_declaration_modifier, $.constructor_declaration_modifier],
    [$.member_declaration_modifier, $.type_declaration_modifier, $.delegate_declaration_modifier, $.constructor_declaration_modifier],
    [$.member_declaration_modifier, $.type_declaration_modifier, $.delegate_declaration_modifier, $.signal_declaration_modifier, $.constructor_declaration_modifier],
    [$.array_creation_expression, $.member_declaration_modifier],       // because both can start with 'new ('
    [$.array_creation_expression,
     $.object_creation_expression,
     $.member_declaration_modifier],                                    // because these all start with 'new'
    [$.member_declaration_modifier,
     $.delegate_declaration_modifier,
     $.constructor_declaration_modifier],                               // these all start with 'class'
    [$.member_declaration_modifier,
     $.signal_declaration_modifier,
     $.constructor_declaration_modifier],                               // these all start with 'class'
    [$.member_declaration_modifier,
     $.constructor_declaration_modifier],                               // these start with 'class'
    [$.member_declaration_modifier,
     $.type_declaration_modifier,
     $.constructor_declaration_modifier],                               // these start with 'class'
    [$.member_declaration_modifier,
     $.type_declaration_modifier,
     $.signal_declaration_modifier,
     $.constructor_declaration_modifier],                               // these start with 'class'
    [$.symbol, $.member_access_expression],                             // disambiguate member access and static cast expressions
    [$.symbol, $.member_access_expression, $.lambda_expression],        // head of lambda expression may be head of symbol or MA
    [$.type],                                                           // disambiguate between 'X as <type *> ...'  and '(X as <type>)* ...'
    [$.array_type],                                                     // when 'X[]? ...' could also be '(X[]) ? ...'
    [$.symbol, $.type],                                                 // for object creation expression
    [$._expression, $.method_call_expression],                          // 'X <' may be start of comparison or method call
    [$._contained_expression, $.method_call_expression],                // for ambiguity because of contained expressions
    [$._expression, $.element_access_expression],                       // because EAEs have a prefix that is a member access
    [$.element_access_expression],                                      // for ambiguity because of contained expressions
    [$.initializer, $.block],                                           // because {} is ambiguous in statement-expression contexts
    [$.if_statement],                                                   // because of ambiguity with nested if statements
    [$._expression, $._left_contained_expression]
  ],

  extras: $ => [
    /\s|\\\r?\n/,
    $.comment,
    $._preprocessor_statement
  ],
});
