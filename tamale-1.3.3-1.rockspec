-- -*- mode: lua; mode: flyspell-prog; ispell-local-dictionary: "american" -*-
package = 'tamale'
version = '1.3.3-1'
source = {
  url = 'git://github.com/perusio/tamale.git',
  tag = 'v1.3.3'
}
description = {
  summary = 'Erlang-style pattern matching for Lua',
  detailed =
    [[
       Tamale adds structural pattern matching (as in Erlang, Prolog, etc.) to
       Lua. Pattern matching unpacks and matches on data structures like
       regular expressions match on strings.

       Instead of dwindling in "if-then-else hell" you write a table of
       patterns to be matched against the input.

       The pattern table defines rules that can have any type of
       entries, strings, numbers, booleans, functions, Lua patterns as
       well as logical variables, in which case unification is
       performed.

       The matching on inputs is performed via a dispatcher function.

       Validation using pattern matching is concise and expressive
       opposed to the usual forest of conditionals. Decision trees can
       also be easily implemented with pattern matching.
     ]],
    homepage = 'http://github.com/perusio/tamale',
    license = 'MIT/X11'
}
dependencies = {
  'lua >= 5.1'
}
build = {
  type = 'builtin',
  modules = {
    tamale = 'tamale.lua'
  }
}
