# Tamale - a TAble MAtching Lua Extension

## Introduction

Tamale is a pattern matching library for Lua. Originaly developed by
[Scott Vokes](https://github.com/silentbicycle/tamale). It hasn't been
updated in a long time, and I've forked it to maintain it more
actively, since it's a really nice piece of software that begs more
usage in your Lua projects. My initial impulse was to use it in a
microservice built around nginx with emebedded Lua or
[Openresty](http://openresty.org) for doing validation. I don't like
the solutions out there for that, they mostly use _method chaining_ to
the hilt, where the methods are nothing more than if-then-else
type check wrappers.

This approach is mere syntatic sugar that doesn't force you to think
about validation in a more subtle and fruitful way. Pattern matching
provides that and much more.

I've commented profusely the source and the tests for myself first and
for others so that the code is easier to read.

I've made some changes based on the
[CloudFlare recommendations](https://github.com/cloudflare/jgc-talks/tree/master/nginx.conf/2014)
for speeding up Lua. Namely whenever possible the avoidance of the
`#t + 1` idiom for adding elements to an array, ditto for the `ipairs`
and `pairs` iterators. My main target is not Lua but
[Luajit](http://luajit.org) when having services running inside nginx. 

I'v also updated the module declaration to be according to the Lua 5.2
preferred way of not using the `module` construct at all. I also
usually sandbox all my modules so that the `_ENV` variable is set to
`nil` as not to open the possibility of nasty pollution of the code by
side effects reliant on upvalues that point to the global environment.

Lua out of the box provides pattern matching only for strings. Tamale
provides pattern matching for **any type of data**, be it numbers,
booleans, strings, functions or tables.

The module defines a `matcher` method that creates a matcher function
that receives as input the value to match against the declared
patterns.

The matcher reads a *rule table* composed of as many rows as wished,
where each row is of the form `{ <pattern>, <result> }`.

 * `<pattern>`: the lua expression defining the pattern.
 + `<result>`: lua expression defining the result when the matching occurs.

The comparison is done by following the order in which the rules are
declared, returning the first result for when match is successful or
returning false if no matching can be found. It's possible to define
your own failure handler. The default failure handler returns `nil,
'Match failed'`.

## Benchmarks

There's a benchmark file `bench.lua` that allows you to get an idea of
the performance. LuaJIT is 4x faster than Lua.

Lua 5.1:

    init: 10000 x: clock 489 ms (0.049 ms per)
    match-first-literal: 10000 x: clock 20 ms (0.002 ms per)
    match-structured-vars: 10000 x: clock 151 ms (0.015 ms per)
    match-structured: 10000 x: clock 176 ms (0.018 ms per)
    match-abcb: 10000 x: clock 97 ms (0.010 ms per)
    match-abcb-fail: 10000 x: clock 117 ms (0.012 ms per)

Lua 5.2:

    init: 10000 x: clock 506 ms (0.051 ms per)
    match-first-literal: 10000 x: clock 19 ms (0.002 ms per)
    match-structured-vars: 10000 x: clock 154 ms (0.015 ms per)
    match-structured: 10000 x: clock 169 ms (0.017 ms per)
    match-abcb: 10000 x: clock 85 ms (0.009 ms per)
    match-abcb-fail: 10000 x: clock 117 ms (0.012 ms per)

LuaJIT:

    init: 10000 x: clock 158 ms (0.016 ms per)
    match-first-literal: 10000 x: clock 5 ms (0.001 ms per)
    match-structured-vars: 10000 x: clock 49 ms (0.005 ms per)
    match-structured: 10000 x: clock 51 ms (0.005 ms per)
    match-abcb: 10000 x: clock 26 ms (0.003 ms per)
    match-abcb-fail: 10000 x: clock 35 ms (0.004 ms per)

## Code documentation

The code is documented with
[ldoc](http://stevedonovan.github.io/ldoc/). See the `tamale.html`
file in the `files` directory.

## Installation

  1. You can install it using luarocks.
     
        luarocks install https://github.com/perusio/tamale/blob/master/tamale-1.3.2-1.rockspec

  2. Debian [package](http://debian.perusio.net).

## Basic Usage

```lua
tamale = require 'tamale'
-- Logical variable.
local V = tamale.var
-- Creating the matching function.
local M = tamale(
  {{{ 'foo', 1, {} }, 'one' },
   { 10, function() return 'two' end },
   {{ 'bar', 10, 100 }, 'three' },
   {{ 'baz', V'X' }, V'X' }, -- V'X' is a variable
   {{ 'add', V'X', V'Y' },  function(cs) return cs.X + cs.Y end }})
 
 print(M( {'foo', 1, {} }))   --> 'one'
 print(M(10))                 --> 'two'
 print(M({ 'bar', 10, 100 })) --> 'three'
 print(M({ 'baz', 'four' }))  --> 'four'
 print(M({ 'add', 2, 3 })     --> 5
 print(M({ 'sub', 2, 3 })     --> nil, 'Match failed'
```

Note that `tamale` is an alias for `tamale.matcher` above.

The result can be either a literal value (number, string, etc.), a
variable, a table, or a function. Functions are called with a table
containing the original input and captures (if any); its result is
returned. Variables in the result (standalone or in tables) are
replaced with their captures.

## Benefits of Pattern Matching

 + Declarative (AKA "data-driven") programming is easy to locally
   reason about, maintain, and debug.
 + Structures do not need to be manually unpacked - pattern variables
   automatically capture the value from their position in the input.
 + "It fits or it doesn't fit" - the contract that code is expected to
   follow is very clear.
 + For rule tables that implement some sort of hierarchical structure,
   e.g., routes in a web service where the URLs reflect an
   hierarchical organization of resources, the rules can be compiled
   to a search tree or evantually a [trie](https://en.wikipedia.org/wiki/Trie)
   so that the search for a match is as efficient as possible. This is
   something to be added possibly in the future.

### Rebalancing of Red-Black Trees

From
[Red-Black Trees in a Functional Setting](https://wiki.rice.edu/confluence/download/attachments/2761212/Okasaki-Red-Black.pdf)
we can enumerate the balancing of a Red-Black tree with three nodes
using pattern matching.

```lua
-- Create red & black tags and local pattern variables.
local R, B, a, x, b, y, c, z, d = 'R', 'B', V'a', V'x', V'b', V'y', V'c', V'z', V'd'
-- Represents the balanced tree that is the result.
local balanced = { R, { B, a, x, b }, y, { B, c, z, d } }
-- R = Red, B = Black. { R, a, x, b } = ((x.R).(a.b)) in dotted pair
-- notation. The balancing function is given by the matcher where each
-- of the rules enumerates the four possible unbalanced trees.
balance = tamale({
  { { B, { R, { R, a, x, b }, y, c }, z, d },  balanced },
  { { B, { R, a, x, { R, b, y, c, } }, z, d }, balanced },
  { { B, a, x, { R, { R, b, y, c, }, z, d } }, balanced },
  { { B, a, x, { R, b, y, { R, c, z, d } } },  balanced },
  { V'body', V'body' }, -- default case, keep the same
})
```

Given a non red-black tree the matcher above can balance the tree so
that it becomes balanced. The code is very simple and easy to
understand if compared with imperative code.

### Further reading

The style of pattern matching used in Tamale is closest to
[Erlang](http://erlang.org)'s. Since pattern-matching comes from
declarative languages, it may help to study them directly.

 * [Pattern Matching in Erlang](http://learnyousomeerlang.com/syntax-in-functions#pattern-matching)
   the online version of the _Learn you some Erlang for great good_. 
 * the [miniKanren](http://minikanren.org/) logic programming language
   for understanding how
   [unification](https://en.wikipedia.org/wiki/Unification_(computer_science))
   works and how it can be exploited for writing expressive concise
   code.

## Rules

Each rule has the form `{ *pattern*, *result*, [ when = function ] }`.

The pattern can be a literal value, table, or function. For tables,
every field is checked against every field in the input (and those
fields may in turn contain literals, variables, tables, or functions).

**when functions** are Tamale's interpretation of both the concept of
[guards](http://learnyousomeerlang.com/syntax-in-functions#guards-guards)
in Erlang and also of transformations to the input. They are invoked
on the input's corresponding field. If the function's first result is
non-false, the field is considered a match, and all results are
appended to the capture table. (See below) If the function returns
false or nil, the match was a failure.

`tamale.P` marks strings as patterns that should be compared with
string.match (possibly returning captures), rather than as a string
literal. Use it like `{ P'aaa(.*)bbb', result }`. The implementation
of P is:

```lua
    function P(str)
      return function(v)
        if type(v) == 'string' then return string.match(v, str) end
      end
    end
```

Rules also have two optional keyword arguments:

### Extra Restrictions - `when = function(captures)` 

This is used to add further restrictions to a rule, such as a rule
that can only take strings *which are also valid e-mail
addresses*. (The function is passed the captures table.)

```lua
-- is_valid(cs) checks cs[1] 
{ P'(.*)', register_address, when = is_valid }
```
`is_valid` can be a predicate, i.e., an Erlang guard analog or a
transformation. The test suite implements an example from
[Learn you some Erlang for great good](http://learnyousomeerlang.com/syntax-in-functions#in-case-of)
where a rule table defines in which condition going to the beach is
acceptable.

```lua
local beach = tamale.matcher(
  {{{ 'celsius', V'N' }, when = between('N', 20, 45), 'favorable' },
   {{ 'kelvin', V'N'}, when = between('N', 293, 318), 'scientifically favorable' },
   {{ 'fahrenheit', V'N' }, when = between('N', 68, 113), 'favorable in the US' },
   { V'_', 'avoid beach' }})
```

Transformations can also be implemented. For example a function that
squares all input fields that are even.

```lua
function square_even(cs)
  local len, res = #cs, {}
  for i = 1, len do
    if cs[i] % 2 == 0 then
      res[i] = math.pow(cs[i], 2)
    else
      res[i] = cs[i]
    end
  return res
end

``` 

The results will appended to the capture table if any variables,
patterns are present in the rule or extra fields are given as input.

### Partial patterns - `partial = true`

This flag allows a table pattern to match an table input value which
has *more fields that are listed in the pattern*. The following rule

    { { tag = 'leaf' }, some_fun, partial = true }

could match against *any* table that has the value t.tag == 'leaf',
regardless of any other fields.

## Logical Variables, Unification and Captures

Patterns can contain logical variables. Unification is performed so
that solutions are found. In practical terms unification amounts to
capturing the contents of the input in that position.

To create a Tamale variable, use `tamale.var('x')` (which can
potentially aliased as `V'x'` for brevity sake.

```lua
local V = tamale.var
```

Variable names can be any string, though any beginning with _ are
ignored during matching (i.e., `{ V'_', V'_', V'X', V'_' }` will
capture the third value from any four-value array). Variable names are
not required to be uppercase, it's just a useful convention adapted
from Prolog and Erlang.

Also, note that declaring local variables for frequently used Tamale
variables can make rule tables cleaner. Compare

```lua
-- Declare three variables.
local X, Y, Z = V'X', V'Y', V'Z'
local M = tamale.matcher(
  {{ { X, X },    1 },   -- capitalization helps to keep
   { { X, Y },    2 },   -- the Tamale vars distinct from
   { { X, Y, Z }, 3 }})  -- the Lua vars
```

with

```lua
local M = tamale.matcher(
  {{ { V'X', V'X' },       1 },
   { { V'X', V'Y' },       2 },
   { { V'X', V'Y', V'Z' }, 3 }})
```

The `_` example above could be reduced to `{ _, _, X, _ }`.

Finally, when the same variable appears in multiple fields in a rule
pattern, such as { X, Y, X }, each repeated field must structurally
match its other occurrences. `{ X, Y, X }` would match `{ 6, 1, 6 }`, but
not `{ 5, 1, 7 }`.

## The Rule Table

The function `tamale.matcher` takes a rule table and returns a matcher
function. The matcher function takes one or more arguments; the first
is matched against the rule table, and any further arguments are saved
in captures.args.

The rule table also takes a couple other options, which are described
below.

## Identifiers - `ids = {<list of ids>}`

Tamale defaults to structural comparison of tables, but sometimes
tables are used as identifiers, e.g. `SENTINEL = {}`. The rule table
can have an optional argument of `ids = {<list_of_ids>}`, for values
that should still be compared by `==` rather than
structure. (Otherwise, *all* such IDs would match each other, and any
empty table.) 

Here's an example from the test suite.

```lua
local a, b, c = {}, {}, {}
local M = tamale.matcher(
  {{{ a, b, c }, 'PASS' },
  -- Force matching on values.
  ids = { a, b, c }})

M({ a, b, c }) 
-- gives 'PASS' since they have the same values.

M({ a, c, b }) 
-- gives false since although they have all the same structure the
-- values differ.

```

## Indexing - `index = field`

Matching can be accelerated by using indexing, in the same way
indexing speeds up relational database queries. Indexing _short
circuits_ the search for a match by iterating through the rules table,
computing the index. Furthermore only strings, numbers and tables are
indexable, which restricts the search for a matching index to only the
indexable rows. By default, the rules are indexed by the first value.

When the rule table

```lua
local M = tamale.matcher(
  {{ { 1, 'a' }, 1 },
   { { 1, 'b' }, 2 },
   { { 1, 'c' }, 3 },
   { { 2, 'd' }, 4 }})
```

is matched against `{ 2, 'd' }`, it only needs one test if the rule
table is indexed by the first field - the fourth rule is the only one
starting with 2. To specify a different index than `pattern[1]`, give
the rule table a keyword argument of `index = I`, where I is either
another key (such as 2 or 'tag'), or a function. If a function is
used, each rule will be indexed by the result of applying the function
to it.

For example, with the rule table:

```lua
local M = tamale.matcher(
  {{ { 'a', 'b', 1 }, 1 }, -- index 'ab'
   { { 'a', 'c', 1 }, 2 }, -- index 'ac'
   { { 'b', 'a', 1 }, 3 }, -- index 'ba'
   { { 'b', 'c', 1 }, 4 }, -- index 'bc'
   index = function(rule) return rule[1] .. rule[2] end })
```
each rule will be indexed based on the first two fields concatenated,
rather than just the first. An input value of { 'a', 'c', 1 } would
only need to check the second row, not the first.

Indexing should never change the *results* of pattern matching, just
make the matcher function do less searching. Note that an indexing
function needs to be deterministic - indexing by (say) `os.time()`
will produce weird results. An argument of `index = false` turns
indexing off.

## Debugging - `debug = true`

Tamale has several debugging traces. They can be enabled either by
setting `tamale.DEBUG` to `true`, for setting it globally, or adding
`debug = true` as a keyword argument to a rule table for a specific
matcher.

Matching `{ 'a', 'c', 1 }` against:

```lua
local M = tamale.matcher
  {{ { 'a', 'b', 1 }, 1 },
   { { 'a', 'c', 1 }, 2 },
   { { 'b', 'a', 1 }, 3 },
   { { 'b', 'c', 1 }, 4 },
   index = function(rule) return rule[1] .. rule[2] end,
   debug = true })
```
will print

```lua
* rule 1: indexing on index(t)=ab
* rule 2: indexing on index(t)=ac
* rule 3: indexing on index(t)=ba
* rule 4: indexing on index(t)=bc
-- Checking rules: 2
-- Trying rule 2...matched
2

```
This can be use for tracing the matching process.
