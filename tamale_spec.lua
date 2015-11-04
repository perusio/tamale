--- Tests for tamale using busted.
-- @script tamale.spec.lua
-- @author António P. P. Almeida <appa@perusio.net>
--
--

local tamale = require 'tamale'
-- Include Busted modules.
local assert = require 'luassert'
local say = require 'say'

-- Useful definitions.
local V, P = tamale.var, tamale.P
local ipairs = ipairs
local pairs = pairs
local gmatch = string.gmatch
local tonumber = tonumber
local tostring = tostring
local type = type
-- For busted.
local describe = describe
local it = it

-- Avoid polluting the global environment.
-- If we are in Lua 5.1 this function exists.
if _G.setfenv then
  setfenv(1, {})
else -- Lua 5.2.
  _ENV = nil
end

-- Set the test language.
say:set_namespace('en')

-- Simple test from the README.
describe('Example from the README',
         function ()
           -- Setup the matcher.
           local M = tamale.matcher(
             {{{ 'foo', 1, {} },  'one' },
              { 10, function() return 'two' end },
              { { 'bar', 10, 100 }, 'three' },
              { { 'baz', V'X' }, V'X' },
              { { V'X', V'Y' },
                function(cs) return cs.X + cs.Y end },
             })
           it('First pattern',
              function()
                assert.are.equal('one', M({ 'foo', 1, {} }))
              end)
           it('Second pattern',
              function ()
                assert.are.equal('two', M(10))
              end)
           it('Third pattern',
              function ()
                assert.are.equal('three', M({ 'bar', 10, 100 }))
              end)
           it('Fourth pattern',
              function ()
                assert.are.equal('four', M({ 'baz', 'four' }))
              end)
           it('Fifth pattern: variables capture - adds numbers as result',
              function ()
                assert.are.equal(5, M({ 2, 3 }))
              end)
         end)

-- More elabored tests.
describe('More elabored tests',
         function ()
           -- Setup variables.
           local X, A, B, C, D = V'X', V'A', V'B', V'C', V'D'
           -- Setup the matcher.
           local M = tamale.matcher(
             {{ 27, 'twenty-seven' },
              { 'str', 'string' },
              { { 1, 2, 3 }, function(t) return 'one two three' end },
              { { 1, { 2, 'three' }, 4 }, function(t) return 'success' end },
              { { 'gt3', X }, function(t) return 10 * t.X end, when = function (t) return t.X > 3 end },
              { { A, B, C, B }, function(t) return 'ABCB' end },
              { { 'a', { 'b', X }, 'c', X }, function(t) return 'X is ' .. t.X end },
              { { 'extract', { V'_', V'_', V'third', V'_' } }, function(t) return t.third end }
             })
           it('Literal number',
              function ()
                assert.are.equal('twenty-seven', M(27))
              end)
           it('Literal string',
              function ()
                assert.are.equal('string', M('str'))
              end)
           it('Literal number triple',
              function ()
                assert.are.equal('one two three', M({ 1, 2, 3 }))
              end)
           it('Failure on one too many literal number triple',
              function ()
                assert.is_not_true(M({ 1, 2, 3, 4 }))
              end)
           it('Match for literal number triple',
              function ()
                assert.is_not_true(M { 1, 2, 3, 4 })
              end)
           it('Matching with variable',
              function ()
                assert.are.equal(70, M({ 'gt3', 7 }))
              end)
           it('No matching with variable',
              function ()
                assert.is_not_true(M({ 'gt3', 'boo' }))
              end)
           it('Matching with variable in table as field (nested)',
              function ()
                assert.are.equal('success', M({ 1, { 2, 'three' }, 4 }))
              end)
           it('Multiple variable captures with repeated variable',
              function ()
                local apple, banana, corn = {}, {}, {}
                assert.are.equal('ABCB', M({ apple, banana, corn, banana }))
              end)
           it('Unification returns empty set of solutions, insolvable, wrong order in input',
              function ()
                local apple, banana, corn = {}, {}, {}
                assert.is_not_true(M({ apple, corn, banana, banana }))
              end)
           it('Destructuring of nested table',
              function ()
                assert.are.equal('X is FOO', M({ 'a', { 'b', 'FOO' }, 'c', 'FOO' }))
              end)
           it('Variables with ignored values',
              function ()
                assert.are.equal('third',
                                 M({ 'extract',
                                     { 'first', 'second', 'third', 'fourth' }}))
              end)
         end)

-- Logical equation with infinite solutions.
describe('Match against anything: ignore values - dummy variable',
         function ()
           -- Matcher with dummy variable.
           local M = tamale.matcher(
             {{ V'_', function(t) return t end }
             })
           it('Infinite solutions for logical equation: strings',
              function ()
                assert.is_truthy(M('any string'))
              end)
           it('Infinite solutions for logical equation: numbers',
              function ()
                assert.is_truthy(M(4))
              end)
           it('Infinite solutions for logical equation: tables',
              function ()
                assert.is_truthy(M({ 'x', 'y', 'z' }))
              end)
         end)

-- Match against three values that add up to 35, and use structural
-- matching to check that the first and third are the same.
describe('Structural matching with three equations and computation',
         function ()
           -- Matcher with multiple equations.
           local M = tamale.matcher(
             {{{ x = V'X', y = V'Y', z = V'X' },
               function(t) return t.X + t.Y + t.X end }})
           it('Structure match: the first and the third are the same',
              function ()
                assert.are.equal(35, M({ x = 15, y = 5, z = 15 }))
              end)
           it('Structure match: the first and the third differ',
              function ()
                assert.is_not_true(M({ x = 10, y = 20, z = 5 }))
              end)
         end)

-- ID list specification offer the possibility of matching on values
-- rather than on structure, i.e., we can have an input that is a
-- table but although the structure of the pattern and the input are
-- the same, the values differ. We can force the matching to be on
-- values besides the structure.
describe('Using a list of IDs force the matching to be on values besides structure',
         function ()
           local a, b, c = {}, {}, {}
           local M = tamale.matcher(
             {{{ a, b, c }, 'PASS' },
              -- Force matching on values.
              ids = { a, b, c }
             })
           local N = tamale.matcher(
             {{{ a, 1 }, 1 },
              {{ b, 1 }, 2 },
              {{ c, 1 }, 3 },
              -- Force matching on values.
              ids = { a, b, c }
             })
           it('Equal structure and identity',
              function ()
                assert.are.equal('PASS', M({ a, b, c }))
              end)
           it('Equal structure different identity (fails)',
              function ()
                assert.is_not_true(M({ a, c, b }))
              end)
           it('Forcing equality on values with table as pattern field (nested)',
              function ()
                assert.are.equal(1, N({ a, 1 }))
                assert.are.equal(2, N({ b, 1 }))
                assert.are.equal(3, N({ c, 1 }))
              end)
         end)

-- Substitutions in result expression, i.e., involving variables in
-- the pattern and in the result.
describe('Substitutions in results (with variables)',
         function ()
           -- Equations with substitutions.
           local M = tamale.matcher(
             {{{ x = V'x', y = V'y' }, { y = V'x', z = V'y' }},
              {{ 'swap', V'x', V'y' }, { V'y', V'x' }}
             })
           -- Results.
           local res1 = M({ x = 10, y = 20 })
           local res2 = M({ 'swap', 10, 20 })
           -- Just a single variable also in result.
           local N = tamale.matcher({{ V'all', V'all' }})
           -- Just a single variable that is nested in the result.
           local O = tamale.matcher({{ V'all',  { V'all' }}})

           it('Logical equations in pattern with variables in results',
              function ()
                assert.are.equal(10, res1.y)
                assert.are.equal(20, res1.z)
                assert.are.equal(20, res2[1])
                assert.are.equal(10, res2[2])
              end)
           it('Single logical variable in pattern and result',
              function ()
                -- Iterate on an integer variable.
                for i = 1, 10 do assert.are.equal(i, N(i)) end
                -- Iterate on a string.
                for i in gmatch('floccinaucinihilipilification', '.') do
                  assert.are.equal(i, N(i))
                end
              end)
           it('Single logical variable in pattern with table in result (boxed)',
              function ()
                local res
                for i = 1, 10 do
                  res = O(i)
                  assert.are.equal(i, res[1])
                end
              end)
         end)

-- Extra argyuments given as input to the matcher are capture in a
-- special 'args' table that can later be retrieved for performing
-- operations in these extra arguments.
describe('Handling of extra arguments',
         function ()
           local M = tamale.matcher(
             {{ 'sum',
                function(cap)
                  local total = 0
                  for _, v in ipairs(cap.args) do total = total + v end
                  return total
                end },
              { 'sumlen',
                function(cap)
                  local total = 0
                  for _, v in ipairs(cap.args) do total = total + #v end
                  return total
                end }})
           it('Sum over all inputs given as extra arguments to the matcher',
              function ()
                assert.are.equal(10, M('sum', 1, 2, 3, 4))
                assert.are.equal(15, M('sum', 1, 2, 3, 4, 5))
              end)
           it('Get the length of the input given as a table with extra arguments to the matcher',
              function ()
                assert.are.equal(10, M('sumlen', 'a', 'ao', 'aoe', 'aoeu'))
              end)
         end)

-- Matching order matters. The order in which the patterns are
-- specified matter for the matching.
describe('Matching order matters',
         function ()
           local is_number = function(t) return type(t.X) == 'number' end
           local M = tamale.matcher(
             {{ V'X', 1, when = is_number },
              { 'y', 2 },
              { V'X', 3 },
              { 'z', 4 }})
           it('Sequential matching',
              function ()
                assert.are.equal(1, M(23))
                assert.are.equal(2, M('y'))
                assert.are.equal(3, M('w'))
              end)
           it('Shadowing of later pattern by previous',
              function ()
                assert.are.equal(3, M('z'))
              end)
         end)

-- By default all string matching is exact (literal). Only by using the
-- P function can Lua patterns be taken into account for matching.
describe('There is no string pattern matching by default. All string matching is exact',
         function ()
           local M = tamale.matcher(
             {{{ 'foo (%d+)' }, function(t) return tonumber(t[1]) end },
              {{ 'foo 23' }, 1 }})
           it('Exact string matching',
              function ()
                assert.are.equal(1, M({'foo 23'}))
              end)
         end)

-- Test Lua patterns for string pattern matching.
describe('Using Lua patterns for string pattern matching',
         function ()
           local M = tamale.matcher(
             -- Always fails.
             {{ function() end, 1 },
              -- Always fails.
              { function() return false end, 2 },
              { P'foo (%d+)', function(t) return tonumber(t[1]) - 20 end },
              -- Always succeeds.
              { function() return 1, 2, 3 end, function(t) return t[1] + t[2] + t[3] end }})
           it('Lua pattern matches',
              function ()
                assert.are.equal(3, M('foo 23'))
                assert.are.equal(6, M(''))
              end)
         end)

-- More elabored string pattern matching tests.
describe('Further tests of string Lua patterns matching',
         function ()
           local M = tamale.matcher(
             {{{ P'foo (%d+)' }, function(t) return tonumber(t[1]) end },
              {{ P'foo (%a+)$' }, function(t) return t[1] end },
              {{ P'foo (%a+) (%d+) (%a+)' },
               function(t) return t[1] .. tostring(t[2]) .. t[3] end },
              {{ 'foo' }, 3 },
              {{ 'bar' }, 4 }})
           it('Lua patterns used in string matching',
              function ()
                assert.are.equal(23, M({ 'foo 23' }))
                assert.are.equal('bar', M({ 'foo bar' }))
                assert.are.equal('bar23baz', M({ 'foo bar 23 baz' }))
                assert.are.equal(3, M({ 'foo' }))
                assert.are.equal(4, M({ 'bar' }))
              end)
         end)

-- Test partial row matching.
describe('Partial row matching',
         function ()

           local function sum_fields(env)
             local tot = 0

             for _, v in pairs(env.input) do
               if type(v) == 'number' then tot = tot + v end
             end

             return tot
           end

           local M = tamale.matcher(
             {{{ tag = 'foo' }, sum_fields, partial = true },
              { V'_', false },})
           it('Partial matches with capture of extra arguments',
              function ()
                assert.are.equal(12, M({ tag = 'foo', x = 3, y = 4, z = 5 }))
              end)
         end)

-- The special variable with '...' captures all fields beyond the ones
-- on the input that match the arity of the pattern.
describe('Special variables that captures or ignore all values in an array',
         function ()
           local function sum_fields(env)
             local tot = 0
             for _, v in ipairs(env['...']) do
               if type(v) == 'number' then tot = tot + v end
             end
             return tot
           end

           local M = tamale.matcher(
             {{{ 'foo', V'...' }, sum_fields },
              { V'_', 'nope' }})
           it("Testing V'...'",
              function ()
                assert.are.equal(15, M({ 'foo', 1, 2, 3, 4, 5}))
              end)
           it("Testing V'_'",
              function ()
                assert.are.equal('nope', M({1, 2, 3, 4, 5}))
              end)
         end)

-- Example from 'Learn You Some Erlang for Great Good':
-- http://learnyousomeerlang.com/syntax-in-functions#in-case-of.
describe('Matching in multiple ranges',
         function ()
           local function between(key, x, y)
             return function(cs) local v = cs[key]; return v >= x and v <= y end
           end
           local beach = tamale.matcher(
             {{{ 'celsius', V'N' }, when = between('N', 20, 45),
               'favorable' },
              {{ 'kelvin', V'N'}, when = between('N', 293, 318),
               'scientifically favorable' },
              {{ 'fahrenheit', V'N' }, when = between('N', 68, 113),
               'favorable in the US' },
              { V'_', 'avoid beach' }})
           it('Weather progonosis for the beach',
              function ()
                assert.are.equal('favorable', beach({'celsius', 23}))
                assert.are.equal('avoid beach', beach({'kelvin', 23}))
                assert.are.equal('favorable in the US', beach({'fahrenheit', 97}))
                assert.are.equal('avoid beach', beach({'fahrenheit', -5}))
              end)
         end)

-- Testing the indexing.
describe('Indexing in action',
         function ()
           -- Custom index.
           local M1 = tamale.matcher(
             {{{ 1, 'a' }, 1 },
              {{ 1, 'b' }, 2 },
              {{ 1, 'c' }, 3 },
              {{ 1, 'd' }, 4 },
              index = 2 })
           -- Custom index function.
           local M2 = tamale.matcher(
             {{{ 1, 'a', 1 }, 1 },
              {{ 1, 'b', 2 }, 2 },
              {{ 1, 'c', 3 }, 3 },
              {{ 1, 'd', 4 }, 4 },
              index = function(r) return r[1] + 3 * r[3] end })
           -- Nested tables with no indexing.
           local M3 = tamale.matcher(
             {{ {{ 'T', V'X' }}, function(c) return 'ok' end },
              { V'default', function() return 'fail' end }, index = false })
           -- Nested tables with custom index.
           local M4 = tamale.matcher(
             {{ {{ 'T', V'X' }}, function(c) return 'ok' end },
              { V'default', function() return 'fail' end },
              index = function(pat) return (pat[1] or {})[1] end })
           it('Custom index',
              function ()
                assert.are.equal(1, M1({ 1, 'a' }, 'a'))
                assert.are.equal(2, M1({ 1, 'b' }, 'b'))
                assert.are.equal(3, M1({ 1, 'c' }, 'c'))
                assert.are.equal(4, M1({ 1, 'd' }, 'd'))
                assert.is_not_true(M1({ 3, 'b' }))
              end)
           it('Custom index function',
              function ()
                assert.are.equal(1, M2({ 1, 'a', 1 }, 'a'))
                assert.are.equal(2, M2({ 1, 'b', 2 }, 'b'))
                assert.are.equal(3, M2({ 1, 'c', 3 }, 'c'))
                assert.are.equal(4, M2({ 1, 'd', 4 }, 'd'))
                assert.is_not_true(M2({ 1, 'b', 1 }))
              end)
           it('Nested tables with no indexing',
              function ()
                assert.are.equal('ok', M3({ { 'T', 'foo' } }))
              end)
           it('Nested tables with custom index',
              function ()
                assert.are.equal('ok', M4({ { 'T', 'foo' } }))
              end)
         end)
