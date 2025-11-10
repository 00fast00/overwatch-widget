---@meta

---@class Table
---@field save fun(_, t, filename, header)
table = table

---@generic V
---@param tbl V source
---@return V
function table.copy(tbl) end

---Return a new table of values from mergeData recursively merged into
---mergeTarget, using deep copies. When there is a conflict, values in
---mergeData take precedence.
---@param mergeTarget table
---@param mergeData table
---@return table
function table.merge(mergeTarget, mergeData) end

---Count the number of values in table.
---Note that this always works, whereas the default length operator (#table)
---only works if the table is a Lua sequence (i.e. indexes form a contiguous
---sequence starting from 1).
---@param tbl table
---@return number
function table.count(tbl) end

---Recursively turns a table into a string, suitable for printing.
---
---All types of keys and values are valid. How some special types are handled:
--- * `function` types are turned into "<function>"
--- * `userdata` types are turned into "<userdata>", unless they have a `tostring` metamethod, which is used instead
--- * cyclic or recursive references are turned into "<recursive_reference>"
--- * keys that are not strings or numbers (tables, functions, etc) are first run through table.toString
---
---In order to keep the output deterministic, keys are sorted.
---@param tbl table
---@param options table? Optional parameters
---param options.pretty boolean Whether to add newlines and indentation (default: false)
---param options.indent number If pretty=true, the number of spaces to indent by at each indent step (default: 2)
---param options.keyCmp function Custom comparison function for sorting keys. If provided, this function will be used instead of the default comparison based on `table.toString(key)`.
---@return string
function table.toString(tbl, options) end

--- Applies a function to all elements of a table and returns a new table with the results.
---@generic K, V, RV, RK
---@param tbl table<K, V> The input table.
---@param callback fun(value: V, key: K, tbl: table<K, V>): RV, RK The function to apply to each element. It receives three arguments: the element's value, its key, and the original table. It should return the new value, and optionally, a new key.
---@return table<RK, RV> A new table containing the results of applying the callback to each element.
function table.map(tbl, callback) end

---Check if value is in table.
---@generic V
---@param tbl table<any, V>
---@param value V
---@return boolean
function table.contains(tbl, value) end

---Remove all instances of value in table.
---@generic V
---@param tbl table<any, V>
---@param value V
function table.removeAll(tbl, value) end
